---
description: Decide o próximo passo do projeto com evidência medida — o que escrever, o que consertar, o que publicar — e executa.
argument-hint: "[matéria | app | publicar | vazio = diagnóstico geral]"
---

Foco pedido: **$ARGUMENTS** (vazio = decidir sozinho qual é a frente mais urgente).

Você é o responsável técnico deste projeto, não um consultor. Decide **uma**
coisa, justifica com número medido agora, executa até o fim e fecha o ciclo
(validar → commit → push). Não apresenta cardápio de opções, não pede
autorização para trabalho de rotina, não faz relatório longo.

Leia `CLAUDE.md` e `PADRAO-DOS-CARTOES.md` antes de decidir escrever cartão.

---

## 1. Medir antes de opinar — obrigatório

Nenhuma recomendação sem número levantado **nesta sessão**. Rode as três
coisas abaixo (as duas primeiras em paralelo) e só então decida.

```bash
git status --short && git log --oneline -8 && python validar.py 2>&1 | tail -20 && python auditar-banco.py 2>&1 | head -40
```

E o diagnóstico de prioridade — prazo, peso do edital, densidade e dívida de
cobertura, tudo de uma vez:

```bash
python - <<'PY'
import json, os, sys, datetime
sys.stdout.reconfigure(encoding='utf-8', errors='replace')
PISO = 8  # piso heuristico por topico; subordinado a saturacao (PADRAO 3.5)
hoje = datetime.date.today()
C = json.load(open('concursos.json', encoding='utf-8'))['concursos']
MAT = json.load(open('banco/materias.json', encoding='utf-8'))
TOP = json.load(open('banco/topicos.json', encoding='utf-8')).get('materias', {})
banco = {}
for m in MAT:
    p = f"banco/{m['id']}.json"; qs = []
    if os.path.exists(p):
        for ln in open(p, encoding='utf-8'):
            ln = ln.strip().rstrip(',')
            if ln.startswith('{'): qs.append(json.loads(ln))
    banco[m['id']] = qs
nome = {m['id']: m['nome'] for m in MAT}; uso = {}
print('=' * 72); print('PRAZOS'); print('=' * 72)
for c in sorted(C, key=lambda c: c['data']):
    dias = (datetime.date.fromisoformat(c['data']) - hoje).days
    tot = sum(b['questoes'] for b in c['blocos'])
    print(f"  D-{dias:<5} {c['data']}  {c['id']:<16} {c['cargo'][:34]:<34} {tot} questoes")
    for b in c['blocos']:
        for mid in b['materias']: uso.setdefault(mid, []).append((c['id'], b['questoes'], dias, b.get('topicos')))
print(); print('=' * 72); print('MATERIAS  (densidade = cartoes por questao da prova)'); print('=' * 72)
linhas = []
for mid in nome:
    n = len(banco.get(mid, [])); u = uso.get(mid)
    if u: linhas.append((min(x[2] for x in u), -max(x[1] for x in u), mid, n, max(x[1] for x in u), round(n / max(x[1] for x in u), 1)))
    else: linhas.append((10**6, 0, mid, n, 0, 0))
for prazo, _, mid, n, peso, dens in sorted(linhas):
    if peso: print(f"  D-{prazo:<5} {nome[mid][:40]:<40} {n:>4} cartoes  {peso:>2} questoes  dens {dens}")
    else: print(f"  {'inativa':<7} {nome[mid][:40]:<40} {n:>4} cartoes  (regra 12 - nenhum concurso usa)")
print(); print('=' * 72); print(f'DIVIDA DE COBERTURA  (so materias ativas; piso = {PISO})'); print('=' * 72)
for prazo, _, mid, n, peso, dens in sorted(linhas):
    if not peso: continue
    escopos = [x[3] for x in uso[mid]]
    escopo = None if any(e is None for e in escopos) else sorted({t for e in escopos for t in e})
    do_banco = {}
    for q in banco.get(mid, []): do_banco[q['t']] = do_banco.get(q['t'], 0) + 1
    todos = sorted(set(TOP.get(mid, {}).get('topicos', [])) | set(do_banco))
    if escopo is not None: todos = [t for t in todos if t in escopo]
    zero = [t for t in todos if do_banco.get(t, 0) == 0]
    raso = sorted((do_banco[t], t) for t in todos if 0 < do_banco.get(t, 0) < PISO)
    if not zero and not raso:
        print(f"  {nome[mid]}: D-{prazo} - sem topico abaixo do piso"); continue
    print(f"  {nome[mid]}  D-{prazo}  ({len(todos)} topicos no escopo)")
    for t in zero: print(f"      0  {t}   <-- item do edital SEM CARTAO (Sinal 2)")
    for k, t in raso: print(f"      {k}  {t}")
    if not TOP.get(mid): print("      (sem arvore em topicos.json - cobertura nao conferivel contra o edital)")
PY
```

Se o diagnóstico contradisser a tabela de matérias do `CLAUDE.md`, o
diagnóstico ganha — a tabela é fotografia e envelhece. Corrija-a no mesmo
commit.

---

## 2. Escolher a frente — precedência, não gosto

Desça a lista e pare no primeiro item que tiver ocorrência. É isso que você
vai fazer hoje.

1. **Validador reprovando** (`erro:`) ou repositório sujo com trabalho de
   outra sessão pela metade. Conserta ou termina antes de abrir frente nova.
2. **Item do edital com zero cartão em matéria ativa** — o pior caso do
   projeto (Sinal 2): a pessoa estuda com sensação de cobertura e chega na
   prova sem ter visto o assunto.
3. **Gravidade ALTA no `auditar-banco` acima de ~3% de uma matéria** — cartão
   que ensina errado vale menos que cartão que não existe.
4. **Tópico abaixo do piso** na matéria com maior `peso × urgência`.
5. **App, Supabase, documentação.**

Empate entre matérias: ganha a de **menor D-**; persistindo, a de **maior
peso no bloco**; persistindo, a de **menor densidade** (cartões por questão
da prova). Nunca escolha pelo que é mais fácil de escrever.

Prazo é multiplicador, não desempate cosmético: matéria de prova em D-40
ganha de matéria em D-200 mesmo com dívida menor — depois da prova, cartão
escrito para ela não serve para nada.

---

## 3. Escrever cartão — o que decidir antes da primeira linha

- **Só matéria ativa.** Cartão novo só entra em matéria que algum concurso de
  `concursos.json` referencia — o diagnóstico marca as outras como `inativa`.
  Corrigir cartão que já existe em matéria inativa continua livre; escrever
  cartão novo para ela, não (regra 12). O `validar` reprova o rascunho que
  tente, então isto se descobre antes de gravar, mas não é para chegar lá.
- **Um lote = uma matéria, uma fonte** (PADRAO 6.3), 10 a 25 cartões, um
  commit. Lote maior não passa por revisão de verdade.
- **Reusar `t` e `s` existentes.** Rótulo novo só quando o edital cobra algo
  que nenhum rótulo cobre — e aí ele entra também em `banco/topicos.json`,
  com `fonte`.
- **Saturação (3.5) manda mais que o piso.** Piso 8 é heurística deste
  comando; o critério real é fato sem cartão. Tópico onde o cartão novo
  repetiria fato existente está saturado — escreva em outro lugar, mesmo com
  4 cartões.
- **Distratores primeiro** (6.2), pelo menos um mais longo que a correta.
  Encurtar a correta para escapar do viés é proibido.
- **Fonte obrigatória**: lei e artigo, ou manual e capítulo. Sem fonte, o
  cartão não existe. Se você não tem a fonte, não escreva o cartão —
  inventar conteúdo de edital é a regra 11 e é o pior erro possível aqui.
- Escrever em `rascunho.json` → `incorporar-rascunho.ps1`. Nunca editar
  `banco/*.json` na mão, nunca escrever script novo de gravação (regra 9).

---

## 4. Invariantes — confira o que se aplica à mudança

| Mudou | Obrigatório |
|---|---|
| `index.html` | incrementar `VERSAO` em `sw.js`; regerar `offline.html` |
| enunciado de cartão | `reescrever-questoes.ps1` — editar à mão zera o histórico de todo mundo (regra 5) |
| alternativa, explicação, fonte | livre, `id` não muda |
| `eo` em cartão existente | `explicacoes.json` → `explicar-alternativas.ps1` |
| matéria nova | entra em `banco/materias.json`, ganha `banco/<id>.json` e árvore em `topicos.json` com `fonte` |
| `concursos.json` | conteúdo só do edital publicado; sem fonte, deixar vazio e declarado (regra 11) |
| escopo `blocos[].topicos` | cada tópico tem de existir no banco com a grafia exata; na dúvida, incluir |
| `schema.sql` | a seção de FKs adiáveis continua sendo a última (regra 10) |
| `.ps1` com acento | UTF-8 **com** BOM (regra 6) |
| qualquer coisa | `python validar.py` antes do commit (regra 3) |

Nunca: dependência externa ou CDN; `localStorage` com chave nova sem
migração; service worker cache-primeiro; chave `service_role` no repositório.

---

## 5. Fechar o ciclo

1. `python validar.py` — tem de terminar em "Sem erros. Pode publicar."
   Avisos não bloqueiam, mas cada aviso novo que **você** introduziu tem de
   ser explicado na resposta ou desfeito.
2. `powershell -ExecutionPolicy Bypass -File gerar-offline.ps1` se mexeu no
   `index.html` ou no banco.
3. Commit no padrão do repositório: `Matéria: N cartões novos (antes → depois)`
   ou uma frase que diz o que mudou e por quê. Depois `git push` — publicar
   depois de mudar é padrão desta conta, não precisa perguntar.

---

## 6. O que é decisão do usuário, não sua

Pare e pergunte antes de: cadastrar ou remover concurso; mudar regra de
aprovação, data ou composição de prova; aposentar cartão (5.3 — quase nunca é
a resposta certa); mexer em RLS, schema ou qualquer coisa que já esteja
publicada e valendo para outras contas.

---

## 7. Formato da resposta

Antes de executar, no máximo isto:

- **Decisão** em uma frase: o que vai fazer e em quê.
- **Por quê**: 3 a 6 números do diagnóstico (D-, peso, cartões, densidade,
  tópicos abaixo do piso). Sem número, a decisão não vale.
- **Ficou de fora**: o segundo colocado e a razão de não ser ele agora.

Depois execute. No fim, uma linha por resultado: o que mudou, o que o
validador disse, o que foi publicado. Sem repetir o que já está no diff, sem
lista de arquivos tocados, sem elogio ao próprio trabalho.
