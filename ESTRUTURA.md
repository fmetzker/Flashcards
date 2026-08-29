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
| `t` / `s` | no cartão | agrupa por assunto; `s` também pode ser alvo de `requisitos`/`requisitos_subtopicos` |
| `requisitos` | `banco/requisitos.json` | **trava** tópico até a base do exigido (tópico inteiro ou só um `{t,s}`) estar dominada |
| `requisitos_subtopicos` | `banco/requisitos.json` | **trava** subtópico até a base do exigido (sempre `{t,s}`) estar dominada — um nível mais fundo que `requisitos`, dentro de um tópico grande |
| `n` | no cartão | **trava** degrau dentro do tópico |

---

## 2. Os arquivos

| Arquivo | Papel |
|---|---|
| `index.html` | App inteiro: HTML, CSS e JS. O banco **não** vive aqui |
| `concursos.json` | Receitas de prova: data, composição, regra de aprovação |
| `banco/materias.json` | Lista de matérias, na ordem de exibição |
| `banco/<matéria>.json` | Questões daquela matéria, uma por linha |
| `banco/topicos.json` | Árvore oficial do edital — mostra tópico que a prova cobra e o banco não cobre |
| `banco/requisitos.json` | Pré-requisitos entre tópicos e entre subtópicos — **travam** cartão novo até a base do exigido |
| `banco/indice-legado.json` | Ids na ordem antiga do array — migra progresso pré-id estável |
| `banco/reescritas.json` | Mapa id antigo→novo de enunciados corrigidos — preserva progresso |
| `sw.js` | Service worker, rede-primeiro. `VERSAO` sobe a cada mudança no app |
| `manifest.json`, `icone-*.png`, `apple-touch-icon.png` | PWA |
| `validar.py` | Integridade do banco **e** conduta do motor (roda o `testar.js`). `--rascunho` valida candidato, `--patches` valida `eo`/`n`/`o`/`s`/`c`/`e`/`t`, nenhum dos dois grava |
| `validar.ps1` | Invólucro: só chama o `validar.py` com os mesmos argumentos. Não valida nada por conta própria |
| `testar.js` + `testes/*.js` | Conduta do **motor** (Leitner, pré-requisito, nível, meta, fuso). `node testar.js [filtro]`; o `validar.py` roda sozinho |
| `auditar-banco.py` / `.ps1` | Mede contra o `PADRAO-DOS-CARTOES.md`. Mede, não reprova |
| `rascunho.json` | Cartões em elaboração, sem `id`. Vazio quando não há trabalho |
| `explicacoes.json` | Patches por `id`: `eo`, `n`, `o`, `s`, `c`, `e` e/ou `t`. Vazio quando não há trabalho |
| `servidor.ps1` | Servidor local, `http://localhost:8080` |
| `gerar-offline.ps1` → `offline.html` | App inteiro num arquivo. **Gerado — não editar** |
| `supabase/schema.sql` | Tabelas, RLS, triggers |
| `supabase/conferir.sql` | Confere o que a RLS **nega**; rodar sempre depois do schema |
| `supabase/limpar-colunas-mortas.sql` | Remove colunas de `perfis` que o app não usa. **Manual, irreversível** — separado do schema de propósito |
| `supabase.json` | URL e chave pública |
| `CLAUDE.md` | Regras invioláveis e os porquês |
| `PADRAO-DOS-CARTOES.md` | Como escrever cartão |
| `TUTORIAL.md` | Publicar e instalar |

## 3. Quem escreve em `banco/*.json`

Três scripts, e só eles (regra 9). Todos rodam o validador de verdade antes e
falham fechado.

| Script | Entrada | Escreve | Uso |
|---|---|---|---|
| `incorporar-rascunho.ps1` | `rascunho.json` | cartão novo inteiro | cartão escrito à mão |
| `explicar-alternativas.ps1` | `explicacoes.json` | `eo`, `n`, `o`, `s`, `c`, `e` e/ou `t` por `id` | campo em cartão que já existe |
| `incorporar-propostas.ps1` | Supabase | cartão novo inteiro | caixa de entrada colaborativa |
| `reescrever-questoes.ps1` | — | `q` + `banco/reescritas.json` | único jeito de mudar enunciado |

Campo ausente no patch é **preservado**: mandar só `n` não apaga o `eo`.

---

## 4. Anatomia do `index.html`

Um arquivo, ~3.300 linhas: CSS, HTML e JS. Ordem real do arquivo.

### 4.1 Carga e configuração

| Função | Papel |
|---|---|
| `pega` | lê JSON; em `offline.html` lê de `window.DADOS` |
| `carregarConfig` | concursos, matérias, `topicos.json`, `requisitos.json` |
| `indexarRequisitos` | achata `requisitos.json` em `REQUISITOS` (tópico) e `REQUISITOS_SUB` (subtópico) |
| `carregarBanco` | carrega só as matérias inscritas |
| `blocosDaMeta` / `aplicarFoco` | monta `BLOCOS_META` e a meta do dia |
| `provaMaisProxima` | define `CONCURSO` quando não há escopo |

### 4.2 Conta, sessão e sincronismo

`lerSessao`, `capturarSessaoDoHash`, `idDoToken`, `entrar`, `criarConta`,
`sair`, `renovarSessao`, `verificarSituacao`, `verificarRevisor`,
`verificarAprovador` · fila de saída: `empurrarFila`/`empurrarLote`
(em lote, não item a item), `puxarPaginado` (genérico, usado por
`puxarEventos`/`puxarSimulados`), `sincronizar`, `aplicarEventoRemoto`.

Migrações que rodam no boot: `migrarSessaoDoPerfil`, `migrarEstadoDoPerfil`,
`migrarParaIds`, `migrarReescritas`.

### 4.3 Datas — tudo no fuso de Brasília

`FUSO_BRASILIA`, `fmtDiaBrasilia`, `hoje`, `diaUTC`, `somarDias`, `diasAte`,
`diasAteMaisProxima`. Nenhum cálculo de data usa `new Date()` puro.

### 4.4 Motor de estudo — o coração

| Função | Papel |
|---|---|
| `proximaData` | Leitner: caixas 1–8, intervalos 1/3/7/14/30/60/120, teto por proximidade da prova |
| `prioridade` | ordena **vencidas**: caixa, taxa de erro, peso do bloco |
| `grauDe` | nível do cartão; ausente = 1 |
| `grauLiberado` | até que degrau abriu (caixa ≥ 2 em todos do degrau); aceita `s` opcional — escopa a SUBTÓPICO quando passado, a TÓPICO inteiro quando não |
| `requisitosPendentes` / `topicoAberto` | pré-requisitos entre tópicos |
| `requisitosPendentesSub` / `subtopicoAberto` | pré-requisitos entre subtópicos — exige `topicoAberto` primeiro |
| `grauAberto` | tópico aberto **e** subtópico aberto (se houver requisito) **e** degrau alcançado — degrau é sempre medido no recorte mais fino que o cartão tem (subtópico, se tiver) |
| `fila` | separa `revisar` (por `prioridade`) de `novas` (filtradas por `grauAberto`; sem reordenação) |
| `intercalar` | entrelaça revisão e novas na sessão, proporcional ao tamanho de cada lista |
| `iniciarSessao` | modos `normal`, `filtro`, `erros` |
| `registrar` | grava resposta, atualiza caixa, alimenta a fila de sync |

**O invariante que nada pode quebrar:** trava e ordenação agem **só sobre
`novas`**. `revisar` nunca é filtrado — revisão vencida sempre aparece.

### 4.5 Telas

`ir` roteia. `pintarInicio`, `pintarMaterias`, `pintarStats`, `pintarGraficos`,
`pintarConta`, `pintarLogin`, `pintarEspera`, `pintarConcursos`,
`pintarEscolherConcurso`, `pintarAjustes`, `pintarPropor`, `pintarRevisar`,
`pintarReportes`, `pintarAprovar`, `pintarPainel` (aprovador; desempenho de
todo mundo, via `eventos_resposta`/`simulados`/`resumo_desempenho`).

Auxiliares da tela Matérias: `resumoDoBanco` (agrega por matéria/tópico/
subtópico **e por degrau**, este último dos dois: `dt.graus` por tópico,
`ds.graus` por subtópico), `porDesbloqueio`/`profundidadeTopico` e
`porDesbloqueioSub`/`profundidadeSubtopico` (ordem de EXIBIÇÃO — sempre
pela profundidade no grafo de pré-requisitos, nunca por tamanho/alfabeto,
ver CLAUDE.md), `travaDoTopico`/`travaDoSubtopico`, `linhaNivel`,
`miniBarra`.

Simulado: `pintarSimuladoInicio`, `sorteia`, `iniciarSimulado`, `mostrarSim`,
`finalizarSimulado`. **Ignora `n` e requisitos de propósito** — imita a prova.

### 4.6 Portões do boot

`falhaBoot`, `exigeLogin`, `exigeAprovacao`, `exigeEscolherConcurso`.

---

## 5. Listas que precisam andar juntas

Arquivo novo em `banco/` tem de entrar nos **quatro** lugares abaixo. Já
falhou duas vezes: o app instalado fica sem o arquivo, ou o validador acusa
matéria órfã.

| Onde | O quê |
|---|---|
| `sw.js` → lista dentro de `install()` (cache `CACHE_BANCO`) | cache do PWA |
| `gerar-offline.ps1` → `$arquivos` | embutir no `offline.html` |
| `validar.py` → lista em `carrega_banco` | exceção de "matéria órfã" |

Uma lista a menos desde agosto/2026: o `validar.ps1` tinha uma cópia desta
e precisava andar junto. Hoje ele é só invólucro do `validar.py`, então
existe um validador só — e um lugar só para manter em dia.

---

## 6. Dois fluxos, do início ao fim

**Cartão novo:** escrever em `rascunho.json` (sem `id`) → `validar.py
--rascunho` → `incorporar-rascunho.ps1` → `validar` → `VERSAO` no `sw.js` →
`gerar-offline.ps1` → commit.

**Campo em cartão existente:** montar `explicacoes.json` com `{id, n}`,
`{id, eo}`, `{id, o}`, `{id, s}`, `{id, c, e}` e/ou `{id, t}` →
`validar.py --patches` → `explicar-alternativas.ps1` → mesma cauda. Patch de
`o` **sem** `c` só pode mexer em **distrator** (corrige viés de comprimento):
os dois validadores reprovam se a correta mudar de texto ou de posição sem
`c` avisando disso. Mandando `o`, mande `eo` junto — `eo[i]` explica `o[i]`.
Patch de `c` (resposta marcada estava errada de fato, achado de auditoria)
exige `e` no mesmo patch — os dois validadores reprovam `c` sem `e`, porque a
explicação antiga não serve para a resposta nova.

**Um dia de estudo:** `fila()` separa vencidas de novas → novas passam por
`grauAberto`, sem reordenação → `iniciarSessao("normal")`
distribui pelas cotas de `BLOCOS_META` → `registrar` grava e enfileira sync.

---

## 7. Diagnósticos que evitam grep

```bash
# contagem por tópico e nível de uma matéria
python -c "import json,collections,sys; sys.stdout.reconfigure(encoding='utf-8',errors='replace'); qs=json.load(open('banco/portugues.json',encoding='utf-8')); [print(t, dict(sorted(collections.Counter(q.get('n',1) for q in qs if q['t']==t).items()))) for t in sorted({q['t'] for q in qs})]"
```

```bash
# o que o /decidir mede: prazo, peso, densidade, dívida de cobertura
# (o script inteiro vive em .claude/commands/decidir.md, passo 1)
python validar.py 2>&1 | tail -20
```

### Rodar o app

```bash
powershell -ExecutionPolicy Bypass -File servidor.ps1        # http://localhost:8080
powershell -ExecutionPolicy Bypass -File gerar-offline.ps1   # gera offline.html
```

`servidor.ps1` reflete o app publicado (service worker, PWA, arquivos
separados) — é o de desenvolver. `offline.html` é arquivo único, dispensa
servidor **e login**, e é onde dá para verificar mudança de JS sem Supabase.
Abrir `index.html` direto do disco não funciona: o banco é lido por `fetch`,
bloqueado em `file://`.

### Testar o motor

```bash
node testar.js
```

```bash
node testar.js requisito    # só os testes cujo nome casa com o filtro
```

`testar.js` lê o **próprio `index.html`**, extrai o bloco `<script>` e roda
dentro de um `vm` do node com o mínimo de browser fingido — não existe cópia
do motor que possa divergir do que vai pro ar. O banco entra por
`window.DADOS`, o mesmo gancho do `offline.html`, então os testes correm
contra `banco/*.json` de verdade. Um teste por invariante do `CLAUDE.md`, com
o nome dizendo qual; os casos vivem em `testes/*.js`, um arquivo por assunto
(datas, leitner, requisitos, meta, sessão).

`validar.py` roda isso sozinho e **reprova o commit** se a conduta mudar.

---

## 8. Onde cada coisa está documentada

| Pergunta | Arquivo |
|---|---|
| Posso mexer nisso? Por quê é assim? | `CLAUDE.md` (regras invioláveis) |
| Como escrever um bom cartão? | `PADRAO-DOS-CARTOES.md` |
| Onde fica a função X? | este arquivo |
| O motor pode se comportar assim? | `testes/*.js` — a regra em forma executável |
| O que fazer agora? | `.claude/commands/decidir.md` |
| Como publicar? | `TUTORIAL.md` |
