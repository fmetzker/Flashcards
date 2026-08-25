# Auditoria do banco — agosto de 2026

> Registro do que foi encontrado e do que foi corrigido nesta rodada de
> auditoria. **Não é um documento vivo** — é o retrato de uma auditoria
> parcial (interrompida por limite de sessão da conta antes de cobrir o
> banco inteiro). Serve de lista de trabalho para continuar depois.

## Complemento — auditoria do grafo de pré-requisitos (barata, sem ler cartão)

Pedido à parte: em vez de reler conteúdo de cartão, auditar só
`banco/requisitos.json` — o grafo é pequeno (~5KB) e a checagem mecânica
(ciclo, referência inexistente, escada sem degrau 1) já roda de graça em
todo `validar`. O que sobrava era julgamento: o grafo faz sentido? falta
algum elo óbvio? Bastou ler o arquivo inteiro + a contagem de tópicos por
matéria (sem tocar em texto de cartão) para achar 4 coisas, todas
corrigidas:

- **Órfão real, corrigido**: "Interpretação de texto" (singular, 26
  cartões — questões presas a texto nomeado de prova) e "Interpretação de
  textos" (plural, 11 cartões — exercício genérico de inferência/coesão/
  explícito×implícito, incluindo 2 cartões de definição) cobriam o mesmo
  assunto sob nomes diferentes; só o plural tinha requisito declarado
  (Semântica, Coerência), e nenhum dos dois estava na lista de tópicos
  intencionalmente livres. Fundidos sob o nome singular (37 cartões), os
  11 antigos "textos" ganharam o subtópico "Inferência e coesão" para
  preservar a diferença de estilo. Precisou atualizar também
  `Intertextualidade` (que exigia o nome antigo) e o escopo de Português
  do bloco `lp` de `transpetro-mec` em `concursos.json`, que citava
  "Interpretação de textos" nominalmente.
- **Órfão por documentação, corrigido**: "Fonética" (6 cartões,
  fonema/sílaba/dígrafo) não tinha requisito nem estava na lista dos
  tópicos autocontidos — devia estar. Acrescentado à lista, sem mudança
  de grafo.
- **Lacuna de manutenção, corrigida**: "Vetores" e "Matrizes" (tópicos
  que só existem desde a mineração da pasta 3 das provas antigas, depois
  deste arquivo ter sido escrito) não apareciam em `requisitos.json` de
  jeito nenhum. Adicionados: `Matrizes` exige `{Álgebra, Sistemas de
  equações}` (os 4 cartões são sobre determinante/invertibilidade, que
  decidem se um sistema linear tem solução); `Vetores` exige `{Geometria,
  Geometria analítica}` (os 5 cartões são produto escalar/módulo/vetor
  posição em coordenadas).
- **Aresta sem base real, removida**: `Trigonometria` exigia `Funções`
  além de `{Geometria, Triângulos}`, mas os subtópicos de Trigonometria no
  banco (círculo trigonométrico, leis do triângulo, razões no triângulo
  retângulo, ângulos notáveis) não pressupõem gráfico/domínio de função —
  a aresta parecia estética, não uma dependência real. Removida.

`Coordenação` exigir só `Classes de palavras` (sem `Sintaxe`, diferente da
irmã `Subordinação`) foi revisto e **mantido**: classificar conjunção
coordenativa (aditiva, adversativa...) não precisa de função sintática,
mas classificar oração subordinada substantiva muitas vezes precisa saber
qual função sintática ela substitui — a assimetria é intencional, não
descuido.

## Complemento — Português/Classes de palavras (auditoria focada, cobertura 100%)

Pedido à parte, depois da rodada principal: reler os 118 cartões de
`Classes de palavras` um por um (sem subagente — feito diretamente),
checando também "existem boas definições antes dos exercícios?".

**Conteúdo**: nenhum erro factual nos 118 cartões — resposta, `e` e `eo`
conferidos um a um.

**Definições antes do exercício**: para as classes gramaticais de verdade
(substantivo, artigo, adjetivo, numeral, pronome, verbo, advérbio,
preposição, conjunção, interjeição) está exemplar — cada uma tem um cartão
`n=1` bem escrito antes dos cartões de aplicação, mais um cartão definindo
"locução".

**Achado estrutural, corrigido**: o subtópico "Formação de palavras" (17
cartões, só aplicação — derivação prefixal/sufixal/parassintética,
composição etc.) não tinha nenhuma definição própria. As definições reais
desses processos (radical, prefixo×sufixo, parassintética, justaposição×
aglutinação) já existiam, mas num **tópico separado e homônimo**
("Formação de palavras", 23 cartões), sem nenhum pré-requisito ligando um
ao outro — quem estudasse só "Classes de palavras" nunca era obrigado a
ver a definição antes do exercício. Corrigido: os 17 cartões foram
retagueados (`t`) do subtópico dentro de "Classes de palavras" para o
tópico "Formação de palavras" já existente, que passou a ter 40 cartões
num lugar só, definição incluída.

**Achado menor, corrigido**: 9 dos 10 cartões sem subtópico marcado dentro
de "Classes de palavras" ganharam `s` (Substantivo/Adjetivo/Advérbio,
conforme o caso). Os outros 2 (um sobre "locução" em geral, outro que
mistura várias classes na mesma questão) seguem sem subtópico único de
propósito — não haveria um `s` que os descrevesse sem forçar.

**Nota lateral, não corrigida**: um cartão classifica "pernilongo" como
formado por processo diferente do de "girassol" (por causa da vogal de
ligação `i`). É uma leitura gramatical defensável — alguns manuais tratam
essa mudança fonética como aglutinação, não justaposição pura — mas é
matéria de debate entre gramáticas, não erro claro. Fica registrado, não
alterado.

26 cartões corrigidos (17 retag de tópico + 9 subtópico completado), 0
cartões com erro de conteúdo.

## Cobertura

Auditados de verdade (cada cartão reverificado por um agente independente,
sem confiar no gabarito do próprio cartão): **Inglês** (97), **Legislação do
SUS** (126), **Matemática** completa (887 — Aritmética, Álgebra, Geometria,
Lógica, Multiplicação, Trigonometria, Funções, Análise combinatória,
Probabilidade, Estatística, Vetores), e **Português/Sintaxe** (66).

**Não auditados** (subagentes esbarraram repetidamente num limite de
sessão da conta antes de terminar — nenhum resultado a reportar, não é
"limpo", é "não verificado"): o resto de Português (Classes de palavras,
Flexão verbal, Semântica, Subordinação, Pontuação, Acentuação, Ortografia,
Interpretação de texto/textos, Concordância, Pronomes, e mais uma dezena de
tópicos menores), Enfermagem inteira (686 cartões), Enfermagem do Trabalho,
Máquinas e Prática Marítima, Manutenção Mecânica.

## Cobertura do conteúdo programático (Sinal 2)

Conferido `banco/topicos.json` contra todo cartão existente: só uma lacuna —
**Matrizes** tinha o tópico declarado na árvore (Anexo II CAAQ-CDM) mas
nenhum cartão usava esse `t`; os 4 cartões de determinante/matriz existentes
estavam classificados em Álgebra/Sistemas de equações. Corrigido (ver
abaixo). Nenhuma outra lacuna de "tópico sem cartão nenhum" nas matérias com
árvore cadastrada.

## Corrigido nesta rodada (24 cartões)

Todos via `explicar-alternativas.ps1`, que ganhou suporte a `c`/`e`/`t`
(antes só aceitava `eo`/`n`/`o`/`s` — ver commit e `ESTRUTURA.md`).

**Resposta marcada estava errada (`c`):**
- `4dcffec96a` (Português/Sintaxe) — transposição de discurso indireto para
  direto: a correlação verbal é pretérito imperfeito (indireto) ↔ presente
  (direto), não "mantém o mesmo tempo verbal" como o cartão ensinava.

**Distrator numericamente igual à resposta certa (Matemática/Probabilidade)** —
quem respondia a alternativa "errada" estava, na prática, certo:
- `c7bdd850c2` (3/6 = 1/2), `bc5810a6c8` (2/6 = 1/3), `2f6a2b1d85` (1/2 = 2/4).

**Nota de alternativa (`eo`) com conta que não bate com o valor que deveria
justificar** — a explicação ensinava um caminho que não chega no número do
distrator (viola a seção 1.4.1 do padrão, "não escreva a nota sem saber de
onde vem o erro"):
- `fd596d5b52`, `c660638412`, `81d7daa57e`, `15edf21f13`, `b783b268ad`,
  `876b3402cc`, `e853fac1f0`, `94877aca75`, `f1548e4e5a`, `68d129947c`,
  `ce90d20d10`, `4956bba74d` (Matemática) e `dd92b7a997` (Português).

**Explicação com erro conceitual ou dado inventado:**
- `5ef60f4b0e` (Português) — etimologia falsa ("medo" não vem de "temer").
- `2cc1edb5c4` (Matemática/Lógica) — citava "Davi", pessoa que não existe
  no enunciado.

**Classificação errada (`t`):**
- `3738723092` — `t="Matemática"` (nome da matéria, não um tópico) →
  `t="Análise combinatória"`.
- `2d9bab91d7`, `58cdc00837`, `d9ec3b06cc`, `ee6fc7a056` — de
  `Álgebra/Sistemas de equações` para `Matrizes` (fecha a lacuna do Sinal 2
  acima).

## Encontrado, mas NÃO corrigido — fica para depois

Estes exigem trabalho de conteúdo (reescrever para testar outro fato, ou
escrever cartão novo), não um patch mecânico de campo. Retirar cartão
"quase nunca é a resposta certa" (padrão, seção 5) — a ação certa é
diferenciar ou complementar, não apagar.

**Duplicatas (regra 1.5 — mesmo fato, dois cartões):**
- SUS: `c1382cfbe1`/`a3d971bb9f` (periodicidade da Conferência de Saúde),
  `e297dd349c`/`eff3f01d76` (paridade no Conselho de Saúde),
  `7d89af1495`/`4944d47510` (preferência do setor filantrópico).
- Matemática: `5a2ed3ceaa`/`536a8b4e68`, `c553a7bb93`/`67bcdc8daa`,
  `28294bf106`/`30ec16bd30`, `5a3b3f8384`/`83c9849b77`,
  `295d55bba9`/`ce042b8b2a`, `7b3894c1d4`/`4f1679a41c` (+`17cbad8039`),
  `4c8b9650da`/`ab008be512`, e o grupo de 4 problemas de associação lógica
  com estrutura idêntica (`7e16c910c7`, `2cc1edb5c4`, `c8ce4cd23f`,
  `3ae0e151c7`).
- Português/Sintaxe: `8c31933017`/`ab1a4a9c4c`, `95d5fc7a0d`/`503f51f742`,
  `a472ee4a34`/`415e741e2e` (mais `503f51f742`/`95d5fc7a0d` — 4 cartões no
  mesmo fato), `8e3d2dbc1f`/`74e54347d3`/`e60e6ee2f5`.

**Falta cartão de definição (nível 1) para tópico que só tem exercício:**
- Matemática: Probabilidade condicional/sem reposição; Vetores (produto
  escalar/vetorial/misto, soma por componentes); Multiplicação (comutativa,
  elemento neutro); Lógica/Conjuntos (inclusão-exclusão de 2 e 3 conjuntos,
  diferença de conjuntos).
- Português/Sintaxe: tipos de sujeito (simples/composto/elíptico/posposto).

**Formato proibido pela seção 2 do padrão (afirmativas I/II/III combinadas
em alternativa) — mérito conferido e está certo, mas testa vários fatos num
cartão só:**
- `115c360e1b` (Vetores), `b0fc08f3f4` (Lógica — também com `s` inconsistente
  com a `f` citada).

**Fonte genérica demais (não é erro de conteúdo, é rastreabilidade — CLAUDE.md
exige "lei e artigo, ou manual e capítulo"):**
- ~129 cartões de Matemática (Trigonometria, Lógica, Análise combinatória)
  citam só "Anexo II — PS CAAQ-CDM-01/2025" (a lista de assuntos do edital,
  não uma fonte que confirme o fato). Cartões vizinhos do mesmo assunto já
  citam a apostila certa — vale reapontar, mas é troca cartão a cartão, não
  patch em lote.

**Achado incerto, não corrigido por falta de confiança suficiente:**
- `aef07ce7d1` (Português/Sintaxe) — a auditoria questionou se "da doença"
  em "o ataque da doença" é mesmo complemento nominal (o cartão afirma que
  sim) ou se deveria ser adjunto adnominal (agente, como em "o ataque do
  inimigo", exemplo clássico de gramática). Há leitura gramatical legítima
  dos dois lados dependendo da tradição seguida — fica para revisão humana,
  não uma correção mecânica.

**Viés de comprimento/formato:** dentro da faixa aceitável no agregado do que
foi auditado (ver saída do `validar` — nenhuma matéria auditada nesta rodada
ficou fora de ~5–40%), então não gerou item de correção aqui.
