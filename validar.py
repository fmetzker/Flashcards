#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Verifica a integridade do banco de questões e mede os vieses estatísticos.

Uso:  python3 validar.py
Sai com código 1 se encontrar erro que impeça a publicação.
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
        texto = (q.get('q', '') + ' '.join(q.get('o', [])) + q.get('e', ''))
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


def main():
    B, fonte = carrega_banco()
    if B is None:
        for e in erros:
            print("ERRO:", e)
        sys.exit(1)

    valida_js(fonte)
    ids = valida_questoes(B)
    valida_migracao(B, ids)
    valida_topicos(B, materias)
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
