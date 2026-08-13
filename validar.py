#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Verifica a integridade do banco de questões e mede os vieses estatísticos.

Uso:  python3 validar.py
      python3 validar.py --rascunho rascunho.json
      python3 validar.py --patches explicacoes.json

Sai com código 1 se encontrar erro que impeça a publicação.

--rascunho avalia cartões candidatos COMO SE já estivessem no banco, sem
gravar nada. É o que permite descobrir viés, formatação proibida, id duplicado
ou fonte faltando antes de a questão existir — em vez de gravar, reprovar e
desfazer à mão. Quem grava é o incorporar-rascunho.ps1, e só depois disto
passar limpo.

--patches aplica 'eo' (explicação por alternativa) em memória sobre cartão
que JÁ EXISTE no banco, casando por id, sem gravar nada — mesma ideia do
--rascunho, mas para editar em vez de acrescentar. Quem grava é o
explicar-alternativas.ps1, e só depois disto passar limpo.
"""
import json, re, subprocess, sys, tempfile, os, collections, hashlib

RAIZ = os.path.dirname(os.path.abspath(__file__))
HTML = os.path.join(RAIZ, 'index.html')
SW = os.path.join(RAIZ, 'sw.js')
BANCO_DIR = os.path.join(RAIZ, 'banco')
CONCURSOS = os.path.join(RAIZ, 'concursos.json')

erros, avisos = [], []
materias = []          # [{id, nome}] na ordem de exibição
nome_materia = {}      # id -> nome


def id_questao(enunciado):
    """Id estável da questão: SHA-1 do enunciado, truncado em 10 hexadecimais.
    Precisa dar o mesmo resultado aqui, no validar.ps1 e no reescrever-questoes.ps1."""
    return hashlib.sha1(enunciado.encode('utf-8')).hexdigest()[:10]


def carrega_banco():
    """Lê o banco: um arquivo por matéria, listadas em banco/materias.json.
    Desde a Fase 0 ele não vive mais no HTML; desde a Fase 1 é por matéria."""
    global materias, nome_materia
    fonte = open(HTML, encoding='utf-8').read()

    caminho = os.path.join(BANCO_DIR, 'materias.json')
    if not os.path.exists(caminho):
        erros.append("banco/materias.json ausente")
        return None, fonte
    materias = json.load(open(caminho, encoding='utf-8'))
    nome_materia = {m['id']: m['nome'] for m in materias}

    B = []
    for m in materias:
        caminho = os.path.join(BANCO_DIR, m['id'] + '.json')
        if not os.path.exists(caminho):
            erros.append(f"arquivo ausente: banco/{m['id']}.json")
            continue
        try:
            qs = json.load(open(caminho, encoding='utf-8'))
        except Exception as e:
            erros.append(f"banco/{m['id']}.json ilegível: {e}")
            continue
        for q in qs:
            if q.get('m') != m['id']:
                erros.append(f"[{q.get('id')}] está em banco/{m['id']}.json mas diz pertencer a '{q.get('m')}'")
        B.extend(qs)

    # arquivo de matéria que não está no materias.json passaria despercebido
    for nome in sorted(os.listdir(BANCO_DIR)):
        base = os.path.splitext(nome)[0]
        if not nome.endswith('.json') or base in ('materias', 'indice-legado', 'reescritas', 'topicos'):
            continue
        if base not in nome_materia:
            erros.append(f"banco/{nome} não corresponde a nenhuma matéria de materias.json")

    if erros or not B:
        return None, fonte
    return B, fonte


def valida_concursos(B):
    """O concurso é uma receita: composição da prova e regra de aprovação.
    A questão pertence a uma matéria, nunca a um concurso."""
    if not os.path.exists(CONCURSOS):
        erros.append("concursos.json ausente — o app não tem como saber data, "
                     "composição nem regra de aprovação")
        return
    cfg = json.load(open(CONCURSOS, encoding='utf-8'))
    if not cfg.get('concursos'):
        erros.append("concursos.json não tem nenhum concurso")
        return
    por_materia = collections.Counter(q['m'] for q in B)
    for c in cfg['concursos']:
        rot = c.get('id', '(sem id)')
        for campo in ('id', 'cargo', 'data', 'blocos', 'aprovacao'):
            if campo not in c:
                erros.append(f"concurso [{rot}]: campo '{campo}' ausente")
        if not re.match(r'^\d{4}-\d{2}-\d{2}$', c.get('data', '')):
            erros.append(f"concurso [{rot}]: data '{c.get('data')}' fora do formato AAAA-MM-DD")
        usadas = set()
        for bl in c.get('blocos', []):
            if not all(k in bl for k in ('id', 'nome', 'questoes')):
                erros.append(f"concurso [{rot}]: bloco incompleto (precisa de id, nome e questoes)")
                continue
            disp = 0
            for mid in bl.get('materias', []):
                if mid not in nome_materia:
                    erros.append(f"concurso [{rot}], bloco '{bl['id']}': matéria inexistente '{mid}'")
                    continue
                if mid in usadas:
                    erros.append(f"concurso [{rot}]: matéria '{mid}' aparece em mais de um bloco")
                usadas.add(mid)
                disp += por_materia[mid]
            # Escopo de tópicos do bloco (opcional): restringe quais tópicos da
            # matéria caem NESTE concurso. Tópico escrito errado aqui não daria
            # erro visível — só sumiria em silêncio da sessão de estudo, que é
            # pior que um erro. Mesma checagem que o validar.ps1 já fazia.
            if bl.get('topicos'):
                do_bloco = [q for q in B if q['m'] in bl.get('materias', [])]
                existentes = {q['t'] for q in do_bloco}
                for t in bl['topicos']:
                    if t not in existentes:
                        erros.append(f"concurso [{rot}], bloco '{bl['id']}': tópico '{t}' "
                                     "não existe no banco das matérias deste bloco")
                if len(set(bl['topicos'])) != len(bl['topicos']):
                    erros.append(f"concurso [{rot}], bloco '{bl['id']}': tópico repetido "
                                 "na lista de escopo")
                disp = sum(1 for q in do_bloco if q['t'] in bl['topicos'])
                if disp < bl['questoes']:
                    avisos.append(f"concurso [{rot}], bloco '{bl['nome']}': dentro do escopo "
                                  f"declarado há {disp} questões para {bl['questoes']} da prova")
            if disp < bl['questoes']:
                avisos.append(f"concurso [{rot}], bloco '{bl['nome']}': o banco tem {disp} "
                              f"questões para {bl['questoes']} da prova")
        total = sum(bl.get('questoes', 0) for bl in c.get('blocos', []))
        if c.get('aprovacao', {}).get('minimoTotal', 0) > total:
            erros.append(f"concurso [{rot}]: mínimo para aprovação "
                         f"({c['aprovacao']['minimoTotal']}) é maior que o total da prova ({total})")
        orfas = [m for m in nome_materia if m not in usadas]
        if orfas:
            avisos.append(f"concurso [{rot}]: {len(orfas)} matéria(s) do banco não entram "
                          f"nesta prova ({', '.join(orfas)})")


def valida_migracao(B, ids):
    """O mapa índice→id é o que converte o progresso salvo antes da Fase 0."""
    caminho = os.path.join(BANCO_DIR, 'indice-legado.json')
    if not os.path.exists(caminho):
        erros.append("banco/indice-legado.json ausente — o progresso salvo por índice não seria migrado")
        return
    legado = json.load(open(caminho, encoding='utf-8'))
    orfaos = [x for x in legado if x not in ids]
    if orfaos:
        erros.append(f"indice-legado.json aponta para {len(orfaos)} id(s) que não existem mais no banco")
    if len(legado) != len(B):
        avisos.append(f"indice-legado.json tem {len(legado)} ids e o banco tem {len(B)} questões "
                      "(esperado se o banco cresceu depois da Fase 0)")


def valida_topicos(B, materias):
    """A árvore oficial do edital (opcional) precisa apontar para matéria que
    existe, senão vira tópico órfão que nunca aparece na tela. Também avisa
    quando um tópico do registro já tem cartão escrito com nome diferente —
    quase sempre é divergência de grafia, e as duas versões apareceriam
    separadas como se fossem assuntos distintos."""
    caminho = os.path.join(BANCO_DIR, 'topicos.json')
    if not os.path.exists(caminho):
        return
    reg = json.load(open(caminho, encoding='utf-8')).get('materias', {})
    ids_mat = {m['id'] for m in materias}
    for mid, dado in reg.items():
        if mid not in ids_mat:
            erros.append(f"topicos.json: matéria '{mid}' não existe em materias.json")
            continue
        oficiais = dado.get('topicos', [])
        if not oficiais:
            avisos.append(f"topicos.json: matéria '{mid}' está sem nenhum tópico")
        if len(set(oficiais)) != len(oficiais):
            erros.append(f"topicos.json: matéria '{mid}' tem tópico repetido")
        if not dado.get('fonte'):
            erros.append(f"topicos.json: matéria '{mid}' sem 'fonte' — de qual edital veio esta árvore?")
        # tópico que já existe no banco sob outro nome não é erro, mas confunde
        no_banco = {q['t'] for q in B if q.get('m') == mid}
        soltos = no_banco - set(oficiais)
        if soltos:
            avisos.append(f"topicos.json: matéria '{mid}' tem {len(soltos)} tópico(s) no banco "
                          f"fora da árvore do edital: {', '.join(sorted(soltos)[:4])}")


def valida_js(fonte):
    """Confere a sintaxe de todo o JavaScript do app."""
    scripts = re.findall(r'<script>(.*?)</script>', fonte, re.S)
    if not scripts:
        erros.append("nenhum bloco <script> encontrado")
        return
    with tempfile.NamedTemporaryFile('w', suffix='.js', delete=False, encoding='utf-8') as f:
        f.write(scripts[-1])
        tmp = f.name
    try:
        r = subprocess.run(['node', '--check', tmp], capture_output=True, text=True)
        if r.returncode != 0:
            erros.append("erro de sintaxe no JS do app: " + r.stderr.strip()[:300])
    except FileNotFoundError:
        # sem node instalado não dá para conferir a sintaxe — avisar e seguir,
        # em vez de derrubar o validador inteiro e deixar o banco sem checagem
        # nenhuma. O validar.ps1 não depende de node e cobre todo o resto.
        avisos.append("node não encontrado: sintaxe do JS do index.html NÃO foi conferida")
    finally:
        os.unlink(tmp)


def valida_questoes(B):
    v, ids = set(), set()
    for q in B:
        rot = q.get('id', '(sem id)')
        for campo in ('id', 'm', 't', 'q', 'o', 'c', 'e', 'f'):
            if campo not in q:
                erros.append(f"[{rot}] campo '{campo}' ausente")
        if q.get('m') not in nome_materia:
            erros.append(f"[{rot}] matéria inexistente: {q.get('m')}")
        # o subtópico é opcional, mas quando existe não pode repetir o tópico
        if q.get('s') and q.get('s') == q.get('t'):
            erros.append(f"[{rot}] subtópico é cópia do tópico: '{q.get('t')}'")
        if len(q.get('o', [])) != 5:
            erros.append(f"[{rot}] não tem exatamente 5 alternativas")
        if not isinstance(q.get('c'), int) or not 0 <= q.get('c', -1) <= 4:
            erros.append(f"[{rot}] índice da correta inválido: {q.get('c')}")
        if len(set(q.get('o', []))) != len(q.get('o', [])):
            erros.append(f"[{rot}] alternativas repetidas dentro da questão")
        if not q.get('f'):
            erros.append(f"[{rot}] sem fonte")
        # 'eo' é opcional (explicação por alternativa, ver PADRAO-DOS-CARTOES.md
        # seção 1.4.1) — quando existe, precisa cobrir toda alternativa em posição
        # (vazio = "sem nota pra esta", não elemento faltando)
        if 'eo' in q:
            eo = q.get('eo')
            if not isinstance(eo, list) or len(eo) != len(q.get('o', [])):
                erros.append(f"[{rot}] 'eo' precisa ter o mesmo tamanho de 'o' — uma posição por "
                              "alternativa (string vazia pula, mas a posição tem que existir)")
            elif not any(isinstance(x, str) and x.strip() for x in eo):
                erros.append(f"[{rot}] 'eo' está presente mas vazio em todas as alternativas — "
                              "tire o campo se nenhuma vai ser preenchida")
        # o id precisa continuar derivando do enunciado, senão o progresso
        # salvo deixa de encontrar a questão
        esperado = id_questao(q.get('q', ''))
        if q.get('id') != esperado:
            erros.append(f"[{rot}] id não corresponde ao enunciado (esperado {esperado})")
        if q.get('q') in v:
            erros.append(f"[{rot}] enunciado duplicado")
        v.add(q.get('q'))
        if q.get('id') in ids:
            erros.append(f"[{rot}] id duplicado")
        ids.add(q.get('id'))
        texto = (q.get('q', '') + ' '.join(q.get('o', [])) + q.get('e', '')
                  + ' '.join(x for x in q.get('eo', []) if isinstance(x, str)))
        if re.search(r'destacad|grifad|sublinhad|em negrito', texto, re.I):
            erros.append(f"[{rot}] refere-se a formatação que não existe no texto puro")
    return ids


def mede_vies(B):
    def d(q):
        c = len(q['o'][q['c']])
        outros = [len(x) for j, x in enumerate(q['o']) if j != q['c']]
        return c - max(outros)

    difs = [d(q) for q in B]
    n = len(B)
    mais_longa = sum(1 for x in difs if x > 0)
    print(f"  correta é a mais longa:        {mais_longa}/{n} ({mais_longa/n*100:.1f}%)   [ideal ~20%]")
    print(f"  excede a 2ª maior em >20 char: {sum(1 for x in difs if x > 20)}")
    print(f"  excede em >40 char:            {sum(1 for x in difs if x > 40)}")
    # Linha de base do 3º passe: zero questão acima de 20 chars de folga.
    # Se algum destes voltar a subir, o viés de comprimento regrediu.
    if sum(1 for x in difs if x > 40) > 0:
        erros.append("viés de comprimento regrediu: há questão excedendo a 2ª maior em +40 chars (linha de base: 0)")
    if sum(1 for x in difs if x > 20) > 0:
        erros.append("viés de comprimento regrediu: há questão excedendo a 2ª maior em +20 chars (linha de base: 0)")
    if mais_longa > 240:
        avisos.append(f"'correta é a mais longa' subiu para {mais_longa} (linha de base: 228, todas com folga <= 10 chars)")

    # A pista só é explorável quando existe UMA alternativa visivelmente mais longa.
    # Nesses casos ela deve ser a correta em no máximo ~20% das vezes (acaso).
    com_pista = acertos = 0
    for q in B:
        tam = [len(x) for x in q['o']]
        maior = max(tam)
        idx = tam.index(maior)
        segundo = max(t for j, t in enumerate(tam) if j != idx)
        if maior - segundo > 10:
            com_pista += 1
            acertos += (idx == q['c'])
    taxa = (acertos / com_pista * 100) if com_pista else 0.0
    print(f"  pista 'mais longa' existe em:  {com_pista} questões; acerta {taxa:.1f}%   [acaso 20%]")
    if taxa > 40:
        erros.append(f"chutar na alternativa mais longa acerta {taxa:.1f}% das vezes (acaso = 20%)")

    # o viés de letra só importa se o embaralhamento for removido
    fonte = open(HTML, encoding='utf-8').read()
    if 'embaralhaOrdem' not in fonte:
        erros.append("função embaralhaOrdem ausente — o viés de posição da correta volta a valer")
    if 'const BANCO = [' in fonte:
        erros.append("index.html ainda tem o array BANCO embutido — o banco agora vive em banco/*.json")


def confere_versao():
    sw = open(SW, encoding='utf-8').read()
    m = re.search(r'const VERSAO = "([^"]+)"', sw)
    if not m:
        erros.append("VERSAO não encontrada em sw.js")
        return
    print(f"  versão do service worker:      {m.group(1)}")
    avisos.append(f"confirme que a VERSAO ({m.group(1)}) mudou desde a última publicação")
    # os arquivos de matéria entram no cache a partir do materias.json,
    # então basta conferir os fixos
    for a in ('concursos.json', 'supabase.json', 'banco/materias.json', 'banco/indice-legado.json'):
        if a not in sw:
            erros.append(f"sw.js não guarda {a} no cache")


def confere_supabase():
    caminho = os.path.join(RAIZ, 'supabase.json')
    if not os.path.exists(caminho):
        erros.append("supabase.json ausente — a Fase 3b lê a URL e a chave anon dali")
        return
    try:
        supa = json.load(open(caminho, encoding='utf-8'))
    except Exception as e:
        erros.append(f"supabase.json não é JSON válido: {e}")
        return
    if not supa.get('url') or not supa.get('anonKey'):
        erros.append("supabase.json precisa dos campos 'url' e 'anonKey'")
    elif 'SEU-PROJETO' in supa['url']:
        # desde que o login passou a ser obrigatório, isto não é mais "sem
        # sincronizar" — é "ninguém consegue nem abrir o app"
        erros.append("supabase.json ainda tem a URL de exemplo — como o login é obrigatório, "
                     "publicar assim tranca todo mundo pra fora do app")


def papel_do_jwt(jwt):
    """Decodifica o miolo de um JWT (formato antigo de chave do Supabase) pra achar 'role'."""
    partes = jwt.split('.')
    if len(partes) < 2:
        return ''
    p = partes[1].replace('-', '+').replace('_', '/')
    p += '=' * (-len(p) % 4)
    try:
        import base64
        return base64.b64decode(p).decode('utf-8', errors='replace')
    except Exception:
        return ''


def confere_chave_secreta():
    """A chave pública (anon / sb_publishable_...) pode ficar no repositório; a
    secreta (service_role / sb_secret_...) ignora toda a RLS. Dois formatos:
    o novo já denuncia pelo prefixo; o antigo é JWT e exige decodificar."""
    exts = ('.html', '.js', '.json', '.ps1', '.py', '.sql', '.md')
    for raiz_dir, dirs, arquivos in os.walk(RAIZ):
        if os.path.normpath(raiz_dir).startswith(os.path.normpath(BANCO_DIR)):
            continue
        for nome in arquivos:
            if not nome.endswith(exts) or nome == 'offline.html':
                continue
            caminho = os.path.join(raiz_dir, nome)
            try:
                texto = open(caminho, encoding='utf-8').read()
            except Exception:
                continue
            if re.search(r'sb_secret_[A-Za-z0-9_-]{10,}', texto):
                erros.append(f"chave secreta do Supabase (sb_secret_...) encontrada em {nome} — "
                             "ela ignora a RLS; use a sb_publishable_ e regenere esta no painel")
            for m in re.finditer(r'eyJ[A-Za-z0-9_-]{5,}\.eyJ[A-Za-z0-9_-]{5,}\.[A-Za-z0-9_-]{5,}', texto):
                if 'service_role' in papel_do_jwt(m.group(0)):
                    erros.append(f"chave service_role do Supabase encontrada em {nome} — "
                                 "ela ignora a RLS; use a chave anon e revogue esta no painel")


VAZIAS = {'a', 'o', 'as', 'os', 'um', 'uma', 'de', 'do', 'da', 'dos', 'das', 'em', 'no', 'na',
          'nos', 'nas', 'e', 'ou', 'que', 'com', 'para', 'por', 'ao', 'aos', 'se', 'sua', 'seu',
          'suas', 'seus', 'qual', 'é', 'ser', 'não', 'sobre', 'entre', 'como', 'mais', 'menos',
          'pelo', 'pela', 'pelos', 'pelas'}


def _tokens(t):
    """Número nunca é descartado por tamanho, mesmo com 1-2 dígitos: em questão
    de aritmética é o número que distingue um fato do outro ("3 × 4" vs
    "3 × 8"). Cortá-los pela mesma regra de tamanho das palavras (>2
    caracteres) fazia toda questão de Tabuada colapsar no mesmo token só
    ("quanto"), tratando dezenas de fatos aritméticos diferentes como se
    fossem a mesma pergunta repetida."""
    limpo = re.sub(r'[^\w\s]', ' ', t.lower(), flags=re.UNICODE)
    return {p for p in limpo.split() if p.isdigit() or (len(p) > 2 and p not in VAZIAS)}


def _norm_resp(t):
    """Caixa, pontuação e espaço não distinguem um fato de outro."""
    return re.sub(r'\s+', ' ', re.sub(r'[^\w\s]', '', t.lower(), flags=re.UNICODE)).strip()


def valida_redundancia(B):
    """Princípio 1.5: dois cartões que cobram o MESMO FATO competem entre si.

    Os limiares saíram de medição no banco de 946 questões, não de chute:

    - "mesma resposta correta" sozinho dá 10 pares, TODOS legítimos — sen(30°)
      e cos(60°) valem 1/2, atropina é antídoto de organofosforado E droga da
      bradicardia. Sozinho é 100% ruído e não serve de regra.
    - "enunciado parecido" sozinho também não serve: fórmula repetida de
      enunciado ("regência do verbo assistir/visar/aspirar") é boa prática.

    Sobra a combinação, que hoje não ocorre nenhuma vez no banco. Por isso é
    aviso, nunca erro: quando dispara, pede olho humano; não pode incomodar.
    """
    meta = {q['id']: (_tokens(q.get('q', '')), _norm_resp(q['o'][q['c']]))
            for q in B if q.get('o') and isinstance(q.get('c'), int)}
    grupos = collections.defaultdict(list)
    for q in B:
        if q['id'] in meta:
            grupos[(q.get('m'), q.get('t'))].append(q)

    for itens in grupos.values():
        for i in range(len(itens)):
            for j in range(i + 1, len(itens)):
                ta, ca = meta[itens[i]['id']]
                tb, cb = meta[itens[j]['id']]
                if not ta or not tb:
                    continue
                sim = len(ta & tb) / len(ta | tb)
                par = f"[{itens[i]['id']}] e [{itens[j]['id']}]"
                if sim >= 0.85 and ca == cb:
                    avisos.append(f"redundância provável {par}: enunciados {sim*100:.0f}% parecidos "
                                  "E mesma resposta certa. Testam o mesmo fato? Ver princípio 1.5")
                elif sim >= 0.90:
                    avisos.append(f"{par}: enunciados {sim*100:.0f}% parecidos (respostas diferentes). "
                                  "Confirme que o fato cobrado é outro")


def carrega_rascunho(B, caminho):
    """Junta cartões candidatos ao banco em memória, sem gravar nada.

    Existe para que toda regra deste arquivo — viés, formatação, id duplicado,
    fonte, matéria — alcance a questão ANTES de ela ser gravada. A ordem antiga
    era escrever no banco e só então descobrir o que o validador reprova; o
    desfazer manual disso já corrompeu o banco por encoding uma vez."""
    if not os.path.exists(caminho):
        print(f"ERRO: rascunho não encontrado: {caminho}")
        sys.exit(1)
    cands = json.load(open(caminho, encoding='utf-8')) or []
    if isinstance(cands, dict):
        cands = [cands]
    for q in cands:
        if q.get('id'):
            erros.append("rascunho: questão não deve trazer 'id' — ele é calculado do enunciado ao incorporar")
        else:
            q['id'] = id_questao(q.get('q', ''))
        B.append(q)
    print(f"Rascunho: {len(cands)} candidato(s) avaliados junto do banco (nada foi gravado)\n")
    return B


def carrega_patches(B, caminho):
    """Aplica 'eo' (explicação por alternativa) em memória sobre cartão que já
    existe no banco, casando por 'id' — usado por explicar-alternativas.ps1.

    Mesmo motivo do carrega_rascunho: toda regra deste arquivo precisa
    alcançar a mudança ANTES dela ser gravada. Diferença aqui é que a questão
    já existe — o patch só altera o campo 'eo' de um objeto que valida_questoes
    já vai conferir do mesmo jeito que confere qualquer outro cartão."""
    if not os.path.exists(caminho):
        print(f"ERRO: patches não encontrado: {caminho}")
        sys.exit(1)
    patches = json.load(open(caminho, encoding='utf-8')) or []
    if isinstance(patches, dict):
        patches = [patches]
    por_id = {q['id']: q for q in B}
    aplicados = 0
    for p in patches:
        pid = p.get('id')
        if not pid or pid not in por_id:
            erros.append(f"patches: id '{pid}' não existe no banco")
            continue
        por_id[pid]['eo'] = p.get('eo')
        aplicados += 1
    print(f"Patches: {aplicados} de {len(patches)} aplicado(s) em memória (nada foi gravado)\n")
    return B


def main():
    B, fonte = carrega_banco()
    if B is None:
        for e in erros:
            print("ERRO:", e)
        sys.exit(1)

    # --rascunho <arquivo>: avalia candidatos como se já estivessem no banco
    if '--rascunho' in sys.argv:
        i = sys.argv.index('--rascunho')
        alvo = sys.argv[i + 1] if i + 1 < len(sys.argv) else 'rascunho.json'
        if not os.path.isabs(alvo):
            alvo = os.path.join(os.path.dirname(os.path.abspath(__file__)), alvo)
        B = carrega_rascunho(B, alvo)

    # --patches <arquivo>: aplica eo em memória sobre cartão existente
    if '--patches' in sys.argv:
        i = sys.argv.index('--patches')
        alvo = sys.argv[i + 1] if i + 1 < len(sys.argv) else 'explicacoes.json'
        if not os.path.isabs(alvo):
            alvo = os.path.join(os.path.dirname(os.path.abspath(__file__)), alvo)
        B = carrega_patches(B, alvo)

    valida_js(fonte)
    ids = valida_questoes(B)
    valida_migracao(B, ids)
    valida_topicos(B, materias)
    valida_redundancia(B)
    valida_concursos(B)

    print(f"\nBanco: {len(B)} questões em {len(materias)} matérias")
    for m in materias:
        qs = [q for q in B if q['m'] == m['id']]
        tops = collections.Counter(q['t'] for q in qs)
        subs = {q['s'] for q in qs if q.get('s')}
        print(f"  {len(qs):4}q  {len(tops):3} tópicos  {len(subs):3} subtópicos   {m['nome']}")
        for t, n in tops.most_common():
            ns = len({q['s'] for q in qs if q['t'] == t and q.get('s')})
            print(f"        {n:4}  {t}" + (f"  ({ns} subtópicos)" if ns else ""))
    print("\nVieses:")
    mede_vies(B)
    confere_versao()
    confere_supabase()
    confere_chave_secreta()

    print()
    for a in avisos:
        print("aviso:", a)
    if erros:
        for e in erros[:40]:
            print("ERRO:", e)
        if len(erros) > 40:
            print(f"... e mais {len(erros)-40} erros")
        print(f"\n{len(erros)} erro(s). Não publicar.")
        sys.exit(1)
    print("Sem erros. Pode publicar.")


if __name__ == '__main__':
    main()
