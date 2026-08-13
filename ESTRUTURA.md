# Estrutura — o mapa do app e do cartão

**Para que serve:** achar as coisas sem grepar. Este arquivo é o *onde*.
O *porquê* e as regras invioláveis ficam no `CLAUDE.md`; o padrão de escrita
dos cartões, no `PADRAO-DOS-CARTOES.md`.

**Regra de coesão deste arquivo:** nada aqui repete regra que já está no
`CLAUDE.md`. Se um fato aparecer nos dois, um dos dois vai envelhecer errado
— quando houver conflito, o `CLAUDE.md` manda e este arquivo é que está
desatualizado.

> Números de linha são pista, não endereço: mudam a cada commit. O endereço
> estável é o **nome da função** — `grep -na "^function nome" index.html`.

---

## 1. O cartão, campo a campo

```json
{"id":"a1b2c3d4e5","m":"portugues","t":"Regência","s":null,"n":2,
 "q":"enunciado","o":["A","B","C","D","E"],"c":1,
 "e":"explicação","f":"fonte","eo":["…","…","…","…","…"]}
```

| Campo | Obrigatório | O que é | Entra no `id`? |
|---|---|---|---|
| `id` | sim | SHA-1 do enunciado, 10 hex | é o próprio |
| `m` | sim | matéria; existe em `banco/materias.json` e bate com o arquivo | não |
| `t` | sim | tópico | não |
| `s` | não | subtópico; não pode repetir o `t` | não |
| `n` | não | nível do cartão dentro do tópico (1=definição). Ausente vale 1 | não |
| `q` | sim | enunciado — **muda o `id`** | **sim** |
| `o` | sim | exatamente 5 alternativas, sem repetir | não |
| `c` | sim | índice da correta, 0 a 4 | não |
| `e` | sim | explicação da questão inteira | não |
| `f` | sim | fonte: lei e artigo, ou manual e capítulo | não |
| `eo` | não | explicação por alternativa; tamanho igual ao de `o` | não |

Só `q` entra no `id`. Por isso corrigir `o`, `e`, `f`, `n`, `eo` é barato, e
corrigir `q` exige `reescrever-questoes.ps1` (regra 5 do `CLAUDE.md`).

### Os três eixos de organização

| Eixo | Onde | Efeito |
|---|---|---|
| `t` / `s` | no cartão | agrupa por assunto |
| `niveis[].topicos` | `banco/niveis.json` | **ordena** tópicos entre si |
| `requisitos` | `banco/niveis.json` | **trava** tópico até a base do exigido |
| `n` | no cartão | **trava** degrau dentro do tópico |

---

## 2. Quem escreve em `banco/*.json`

Três scripts, e só eles (regra 9). Todos rodam o validador de verdade antes e
falham fechado.

| Script | Entrada | Escreve | Uso |
|---|---|---|---|
| `incorporar-rascunho.ps1` | `rascunho.json` | cartão novo inteiro | cartão escrito à mão |
| `explicar-alternativas.ps1` | `explicacoes.json` | `eo` e/ou `n` por `id` | campo em cartão que já existe |
| `incorporar-propostas.ps1` | Supabase | cartão novo inteiro | caixa de entrada colaborativa |
| `reescrever-questoes.ps1` | — | `q` + `banco/reescritas.json` | único jeito de mudar enunciado |

Campo ausente no patch é **preservado**: mandar só `n` não apaga o `eo`.

---

## 3. Anatomia do `index.html`

Um arquivo, ~3.300 linhas: CSS, HTML e JS. Ordem real do arquivo.

### 3.1 Carga e configuração

| Função | Papel |
|---|---|
| `pega` | lê JSON; em `offline.html` lê de `window.DADOS` |
| `carregarConfig` | concursos, matérias, `topicos.json`, `niveis.json` |
| `indexarNiveis` | achata `niveis.json` em `NIVEL_T`, `NIVEL_S`, `REQUISITOS` |
| `carregarBanco` | carrega só as matérias inscritas |
| `blocosDaMeta` / `aplicarFoco` | monta `BLOCOS_META` e a meta do dia |
| `provaMaisProxima` | define `CONCURSO` quando não há escopo |

### 3.2 Conta, sessão e sincronismo

`lerSessao`, `capturarSessaoDoHash`, `idDoToken`, `entrar`, `criarConta`,
`sair`, `renovarSessao`, `verificarSituacao`, `verificarRevisor`,
`verificarAprovador` · fila de saída: `empurrarUm`, `puxarEventos`,
`puxarSimulados`, `sincronizar`, `aplicarEventoRemoto`.

Migrações que rodam no boot: `migrarSessaoDoPerfil`, `migrarEstadoDoPerfil`,
`migrarParaIds`, `migrarReescritas`.

### 3.3 Datas — tudo no fuso de Brasília

`FUSO_BRASILIA`, `fmtDiaBrasilia`, `hoje`, `diaUTC`, `somarDias`, `diasAte`,
`diasAteMaisProxima`. Nenhum cálculo de data usa `new Date()` puro.

### 3.4 Motor de estudo — o coração

| Função | Papel |
|---|---|
| `proximaData` | Leitner: caixas 1–5, intervalos 1/3/7/14, teto por proximidade da prova |
| `prioridade` | ordena **vencidas**: caixa, taxa de erro, peso do bloco |
| `grauDe` | nível do cartão; ausente = 1 |
| `grauLiberado` | até que degrau o tópico abriu (caixa ≥ 2 em todos do degrau) |
| `requisitosPendentes` / `topicoAberto` | pré-requisitos entre tópicos |
| `grauAberto` | tópico aberto **e** degrau alcançado |
| `fila` | separa `revisar` (por `prioridade`) de `novas` (filtradas por `grauAberto`, ordenadas por `nivelDe`) |
| `iniciarSessao` | modos `normal`, `filtro`, `erros` |
| `registrar` | grava resposta, atualiza caixa, alimenta a fila de sync |

**O invariante que nada pode quebrar:** trava e ordenação agem **só sobre
`novas`**. `revisar` nunca é filtrado — revisão vencida sempre aparece.

### 3.5 Telas

`ir` roteia. `pintarInicio`, `pintarMaterias`, `pintarStats`, `pintarGraficos`,
`pintarConta`, `pintarLogin`, `pintarEspera`, `pintarConcursos`,
`pintarEscolherConcurso`, `pintarAjustes`, `pintarPropor`, `pintarRevisar`,
`pintarReportes`, `pintarAprovar`.

Auxiliares da tela Matérias: `resumoDoBanco` (agrega por matéria/tópico/
subtópico **e por degrau**), `porNivel`, `travaDoTopico`, `linhaNivel`,
`miniBarra`.

Simulado: `pintarSimuladoInicio`, `sorteia`, `iniciarSimulado`, `mostrarSim`,
`finalizarSimulado`. **Ignora `n` e requisitos de propósito** — imita a prova.

### 3.6 Portões do boot

`falhaBoot`, `exigeLogin`, `exigeAprovacao`, `exigeEscolherConcurso`.

---

## 4. Listas que precisam andar juntas

Arquivo novo em `banco/` tem de entrar nos **quatro** lugares abaixo. Já
falhou duas vezes: o app instalado fica sem o arquivo, ou o validador acusa
matéria órfã.

| Onde | O quê |
|---|---|
| `sw.js` → `ARQUIVOS` | cache do PWA |
| `gerar-offline.ps1` → `$arquivos` | embutir no `offline.html` |
| `validar.py` → lista em `carrega_banco` | exceção de "matéria órfã" |
| `validar.ps1` → mesma lista | idem |

Os dois validadores precisam concordar: `validar.ps1` é o que roda antes de
**gravar**, `validar.py` é o mais completo (só ele confere `topicos.json`,
`niveis.json` e a sintaxe do JS, esta última se houver Node).

---

## 5. Dois fluxos, do início ao fim

**Cartão novo:** escrever em `rascunho.json` (sem `id`) → `validar.py
--rascunho` → `incorporar-rascunho.ps1` → `validar` → `VERSAO` no `sw.js` →
`gerar-offline.ps1` → commit.

**Nível/`eo` em cartão existente:** montar `explicacoes.json` com `{id, n}`
e/ou `{id, eo}` → `validar.py --patches` → `explicar-alternativas.ps1` →
mesma cauda.

**Um dia de estudo:** `fila()` separa vencidas de novas → novas passam por
`grauAberto` e são ordenadas por `nivelDe` → `iniciarSessao("normal")`
distribui pelas cotas de `BLOCOS_META` → `registrar` grava e enfileira sync.

---

## 6. Diagnósticos que evitam grep

```bash
# contagem por tópico e nível de uma matéria
python -c "import json,collections,sys; sys.stdout.reconfigure(encoding='utf-8',errors='replace'); qs=json.load(open('banco/portugues.json',encoding='utf-8')); [print(t, dict(sorted(collections.Counter(q.get('n',1) for q in qs if q['t']==t).items()))) for t in sorted({q['t'] for q in qs})]"
```

```bash
# o que o /decidir mede: prazo, peso, densidade, dívida de cobertura
# (o script inteiro vive em .claude/commands/decidir.md, passo 1)
python validar.py 2>&1 | tail -20
```

Verificação no navegador sem login: `gerar-offline.ps1` e abrir
`offline.html` — é o caminho que dispensa Supabase e onde as travas foram
medidas. **Não há Node nesta máquina**, então `validar.py` não confere a
sintaxe do JS: mudança em `index.html` só está verificada depois de rodar no
navegador.

---

## 7. Onde cada coisa está documentada

| Pergunta | Arquivo |
|---|---|
| Posso mexer nisso? Por quê é assim? | `CLAUDE.md` (regras invioláveis) |
| Como escrever um bom cartão? | `PADRAO-DOS-CARTOES.md` |
| Onde fica a função X? | este arquivo |
| O que fazer agora? | `.claude/commands/decidir.md` |
| Como publicar? | `TUTORIAL.md` |
