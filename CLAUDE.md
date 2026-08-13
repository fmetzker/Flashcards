# App de estudo — Concursos públicos

> **Onde procurar o quê.** Este arquivo tem as **regras e os porquês** — o
> que não pode ser quebrado e a razão de ser assim. O **mapa** (onde mora
> cada função do `index.html`, o esquema completo do cartão, os fluxos de
> gravação, as listas que precisam andar juntas) está em `ESTRUTURA.md`, e é
> o que evita grepar o app de 3.300 linhas. O padrão de escrita dos cartões
> está em `PADRAO-DOS-CARTOES.md`. Os três não se repetem de propósito:
> fato duplicado é fato que vai envelhecer errado em um dos lados — **em
> caso de conflito, este arquivo manda.**

Aplicativo web de questões com repetição espaçada, contas e banco
colaborativo. Hoje atende quatro concursos: Enfermeiro/Volta Redonda (edital
003/2026-SMA, prova 20/09/2026), CAAQ-CDM/Marinha, Psicologia/Transpetro,
cadastrado como **pré-edital** (estrutura copiada do edital de 2023 enquanto
o de 2026 não sai), e Manutenção Mecânica/Transpetro (Edital nº 03 -
TRANSPETRO/PSP/TERRA/NÍVEL MÉDIO-2026.3, ênfase 11, polo Rio de Janeiro,
prova 29/11/2026). Novo concurso é editar `concursos.json` — não exige
mexer no código.

Moço de Máquinas e Enfermagem do Trabalho, ambos da Transpetro, saíram de
`concursos.json` porque ninguém mais vai prestar essas provas — mas os
bancos de questões (`banco/maritimo-maquinas.json` e
`banco/enfermagem-trabalho.json`) continuam no repositório, intactos, para
o caso de precisarem voltar. Matéria sem concurso ativo é situação normal
no app (Psicologia já vivia assim antes de ganhar um concurso próprio): a
matéria só não aparece pra ninguém estudar até algum concurso voltar a
referenciá-la em `blocos[].materias`.

## Estrutura

**A tabela completa de arquivos — o que é cada um e quem escreve nele — está
em `ESTRUTURA.md` §2 e §3.** O que importa saber aqui, e que nenhuma tabela
substitui: o banco **não** vive no `index.html`, e só três scripts escrevem
em `banco/*.json` (regra 9).

Sem build, sem dependências, sem framework. É proposital: o app precisa rodar
no Safari do iPhone sem nenhuma etapa de compilação.


## Regras invioláveis

1. **Nunca usar `localStorage` fora do que já existe.** A conta é a
   identidade — não existe "perfil" separado da conta. O progresso é
   chaveado pelo id real da conta (o `sub` do token, via `idDoToken()`).

   | chave | o quê |
   |---|---|
   | `vr:sessao` | login (uma só: um logado por vez no aparelho) |
   | `vr:conta:<userId>` | o estado (mesmo JSON de sempre) |
   | `vr:fila:<userId>`, `vr:fila-sim:<userId>` | eventos e simulados ainda não confirmados no servidor |
   | `vr:cursor-eventos:<userId>`, `vr:cursor-simulados:<userId>` | até onde o pull já leu |

   `CONTA_ID`, `CHAVE` e `E` são resolvidos **uma vez, no início do script**.
   Por isso entrar e sair recarregam a página em vez de repintar: sem o
   reload, quem acabou de logar seguiria com o `E` vazio e gravaria por cima
   do progresso de verdade. Deslogado, `CHAVE` é `null` e `salvar()` só
   guarda em memória. `offline.html` é a exceção: usa a chave fixa
   `vr:conta:local`, porque nunca tem sessão.

   Esquemas antigos de chave são lidos para migrar e nunca apagados — custam
   alguns KB e são rede de segurança. Não introduzir outra chave sem
   migração.
2. **Ao alterar `index.html`, incrementar `VERSAO` em `sw.js`.** O service
   worker é **rede-primeiro**, com o cache só como reserva para quando não
   há internet. Não voltar para cache-primeiro: o aparelho continua servindo
   a versão antiga mesmo depois de publicar.
3. **Rodar `validar.py` (ou `validar.ps1`) antes de qualquer commit.** Falha
   se houver questão malformada, duplicada, sem fonte ou com viés
   estatístico piorando (ver seção de viés, abaixo).
4. **Não adicionar dependências externas nem CDN.**
5. **O `id` da questão é o SHA-1 do enunciado**, truncado em 10 hexadecimais,
   e é o que amarra o progresso salvo à questão. O validador confere que
   `id == sha1(q)`. Corrigir alternativas, explicação e fonte é livre — não
   mexe no id.

   **Para mudar um enunciado, use `reescrever-questoes.ps1`.** Ele recalcula
   o id e grava o par antigo→novo em `banco/reescritas.json`, que
   `migrarReescritas()` aplica no boot para transportar o progresso (e o
   script ainda acerta o `indice-legado.json`). Editar o enunciado à mão
   **zera o histórico daquele cartão para todo mundo**.
6. **Arquivos `.ps1` com acento precisam de UTF-8 COM BOM.** Sem BOM, o
   Windows PowerShell 5.1 os lê como ANSI e o parser quebra.
7. **A chave `service_role` do Supabase nunca entra no repositório.** Ela
   ignora toda a RLS. A chave pública (`sb_publishable_...`/`anon`) pode
   ficar no cliente. `validar.ps1`/`validar.py` varrem o repositório e
   acusam se a secreta vazar em algum arquivo.
8. **Nomes de classe CSS genéricos (`.vazio`, `.card`, `.stat`...) combinam
   com qualquer elemento que os use, mesmo junto de outra classe.** Ao
   nomear uma classe de estado (vazio, cheio, ativo...), checar se o nome já
   existe em outro contexto antes de reusar.
9. **O banco é sempre estático e versionado — nunca escrito em tempo real.**
   Propor/aprovar questão (Supabase) e reportar problema só alimentam uma
   caixa de entrada. Só **três** scripts gravam em `banco/*.json`, todos
   rodados à mão e seguidos de `validar` e commit manuais:
   `incorporar-propostas.ps1` (caixa do Supabase), `incorporar-rascunho.ps1`
   (cartão escrito localmente) e `explicar-alternativas.ps1` (acrescenta
   `eo` a cartão que já existe, casando por `id`). **Não escrever script de
   gravação por lote** — foi o que corrompeu o banco por encoding e passou
   por cima de regra que o validador reprova. Os três não se qualificam como
   isso porque nenhum reimplementa checagem: rodam `validar` de verdade
   antes de gravar (via `-Patches` no caso de `explicar-alternativas.ps1`,
   que valida a alteração em memória, contra o banco inteiro, sem tocar
   disco) e falham fechado se ele reprovar.
10. **`schema.sql`: a seção que torna as FKs para `auth.users` adiáveis
    precisa ser a ÚLTIMA do arquivo.** Ela descobre as chaves estrangeiras
    dinamicamente via `pg_constraint` — só enxerga o que já existe no
    momento em que roda. Tabela nova com FK para `auth.users` adicionada
    depois dela nunca vira adiável, e `conferir.sql` quebra com
    `violates foreign key constraint` ao inserir dado de teste.
11. **Nunca inventar conteúdo de edital.** Cargo, composição da prova,
    regra de aprovação e conteúdo programático saem do edital publicado, e
    o campo `edital` de `concursos.json` diz de onde. Quando a fonte não
    existe (pré-edital, cargo novo), registrar o que é certo e deixar o
    resto **vazio e declarado** — como `transpetro-psi`, que tem o bloco de
    Específicos contado mas sem tópicos, porque Psicologia é ênfase nova em
    2026 e não há edital anterior da Transpetro para esse cargo. Assunto
    inventado é pior que assunto faltando: a pessoa estuda com sensação de
    cobertura e chega na prova sem ter visto o que caiu.
12. **Concurso que ninguém mais vai prestar sai de `concursos.json`, mas o
    banco de questões da matéria fica.** Remover o concurso é só parar de
    oferecer aquele cargo pra estudo — não apaga o trabalho de escrever as
    questões, que pode servir de novo se o concurso voltar (mudança de
    edital, prova adiada) ou se outro concurso vier a usar a mesma matéria.
    Foi o caso de Moço de Máquinas e Enfermagem do Trabalho, ambos da
    Transpetro: saíram de `concursos.json`, e `banco/maritimo-maquinas.json`
    e `banco/enfermagem-trabalho.json` continuam intactos. Matéria sem
    concurso ativo não aparece pra ninguém estudar (nenhum bloco a
    referencia em `materias`), mas também não é erro nem lixo — é
    exatamente a mesma situação que `psicologia` viveu antes de ganhar
    concurso próprio.

    **Guardar é uma coisa, escrever é outra: cartão novo só entra em matéria
    ativa.** O que já existe fica intacto — corrigir alternativa, explicação,
    fonte ou `eo` de cartão de matéria inativa continua livre, é manutenção do
    que já foi feito. Mas escrever cartão NOVO para matéria que nenhum
    concurso referencia é trabalho que ninguém vai ver, enquanto matéria ativa
    tem item de edital sem cartão nenhum. `validar` reprova o rascunho que
    tente isso, e lista numa linha as matérias inativas a cada execução. Se o
    concurso vai voltar, o caminho é cadastrá-lo em `concursos.json` primeiro
    — aí a matéria volta a ser ativa e a escrita é legítima.

## Formato do banco de questões

Arquivos `banco/<matéria>.json`, **um objeto por linha** — mantém o diff
pequeno e é o que permite gravar cartão sem reescrever o arquivo inteiro.

**O esquema campo a campo está em `ESTRUTURA.md` §1**, com a coluna que mais
importa: quais campos entram no `id`. Só `q` entra. O que fica aqui são as
regras que o esquema não expressa:

- **`f` é obrigatório**: lei e artigo, ou manual e capítulo. Questão sem
  fonte não entra. Sem fonte à mão, não escreva o cartão (regra 11).
- **`s` não pode repetir o nome do `t`** — o validador barra. Português e SUS
  não usam subtópico porque os tópicos deles já são o nível certo.
- **Reusar `t` e `s` que já existam** em vez de inventar rótulo novo: a
  árvore só é útil enquanto os níveis se mantêm poucos.
- `eo` não é retroativo (regra 9): só cartão novo ou em reescrita.

Antes de escrever qualquer cartão, ler `PADRAO-DOS-CARTOES.md`.

## Matéria, tópico e subtópico

**Matéria é o bloco do edital.** O banco de cada matéria costuma vir da união
dos concursos cadastrados em `concursos.json` que a usam, mas matéria sem
nenhum concurso ativo é situação normal, não erro: fica no banco, disponível
pra quando algum concurso voltar a referenciá-la (é o caso de
`maritimo-maquinas` e `enfermagem-trabalho` hoje, e já foi o caso de
`psicologia` antes dela ganhar um concurso próprio):

**Não há tabela de contagem aqui de propósito.** Ela existiu, era atualizada
à mão a cada lote e chegou a ter três números errados ao mesmo tempo —
contagem mantida por humano num arquivo que ninguém relê é pior que
contagem nenhuma, porque parece verdade. O número real sai de:

```bash
python - <<'PY'
import json, sys
sys.stdout.reconfigure(encoding='utf-8', errors='replace')
for m in json.load(open('banco/materias.json', encoding='utf-8')):
    qs = json.load(open(f"banco/{m['id']}.json", encoding='utf-8'))
    print(f"{m['id']:<22}{len(qs):>5} cartões  {len({q['t'] for q in qs}):>3} tópicos")
PY
```

Dois fatos sobre matérias que **não** saem de contagem nenhuma:

- **`psicologia` não tem árvore em `topicos.json`** porque não existe edital
  anterior do cargo na Transpetro — regra 11, e não esquecimento.
- **`matematica` tem o tópico `Lógica`, que não consta do Anexo IV.** Fica no
  banco por ser útil, mas está fora do escopo declarado do concurso.

Dentro delas, dois níveis: **tópico** (Imunização, Urgência, Saúde da Mulher)
e **subtópico** (Rede de frio, Calendário vacinal). Português e SUS param no
tópico — os assuntos deles já são específicos o bastante.

**`banco/topicos.json` é a árvore oficial do edital**, separada do banco de
propósito: tópico só existe como campo `t` de uma questão, então item do
conteúdo programático sem nenhum cartão seria invisível — o pior caso do
Sinal 2 do `PADRAO-DOS-CARTOES.md`. `resumoDoBanco()` mescla essa árvore com
o que o banco tem, e a tela Matérias mostra o que falta apagado, escrito
"sem cartão" e sem botão de estudar. O arquivo é **opcional**: se sumir, o
app volta a mostrar só o que existe. Cada matéria ali precisa de `fonte`
dizendo de qual edital a árvore foi transcrita — o validador barra sem.

**O concurso é uma receita** em `concursos.json`: cargo, órgão, banca, data,
duração, blocos (nome, quantas questões, quais matérias) e regra de
aprovação. Uma matéria não pode aparecer em dois blocos do mesmo concurso; o
validador barra.

**Uma conta pode seguir mais de um concurso ao mesmo tempo.** Duas noções
que não podem ser confundidas:

- `INSCRITOS` / `E.concursos` — todos os que a conta estuda. Definem o
  **banco carregado** (união das matérias de todos, via
  `materiasInscritas()`) e o **teto do Leitner**, que usa
  `diasAteMaisProxima()`: seguir um concurso distante não pode afrouxar a
  revisão por causa de outro que é semana que vem.
- `E.escopoEstudo` — **o que conta hoje**: `null` estuda para todos (meta
  somada, o padrão) e um id estuda só para aquele concurso, encolhendo a meta
  para a dele. É o seletor da tela inicial, que só aparece com mais de um
  inscrito. Muda `BLOCOS_META`, a meta e a sessão; **não** muda o banco
  carregado, por isso trocar o escopo (`aplicarFoco()`) só repinta, enquanto
  **mudar a lista de inscritos recarrega**.
- `CONCURSO` / `E.concursoAtivo` — **qual prova**: simulado, regra de
  aprovação, contagem regressiva, alerta de bloco fraco. Com escopo, é o
  escolhido; sem escopo, é a **prova mais próxima** entre os inscritos
  (`provaMaisProxima()`), que é a que aperta primeiro. Não é escolhido à mão
  quando não há escopo — some a ideia de "foco cosmético" que existia antes.

O teto do Leitner continua em `diasAteMaisProxima()` sobre **todos** os
inscritos, mesmo com escopo restrito: estudar só para um concurso hoje não
adia a prova do outro.

Quem entra sem nenhum concurso escolhido (primeira vez, ou o que seguia
sumiu de `concursos.json`) cai em `tela-escolher-concurso`
(`exigeEscolherConcurso()`) antes da tela inicial. Se só existe um concurso
cadastrado no arquivo inteiro, não há o que escolher e a tela é pulada.

Consequência assumida desta modelagem: como "Conhecimentos Específicos de
Enfermagem" é uma matéria só, o compartilhamento do acervo vale entre
concursos **de enfermagem**. Português e Legislação do SUS, que caem em
quase toda prova da área da saúde, continuam compartilháveis com qualquer
cargo.

A tela **Matérias** mostra a árvore inteira, inclusive o que ainda não foi
visto, e permite estudar qualquer um dos três níveis isoladamente. A tela
**Estatísticas** ranqueia do mais fraco para o mais forte, pelo nível mais
fino de cada questão, considerando só o que já foi respondido. Não duplicar
uma na outra.

## Contas e aprovação

Login é **obrigatório** para entrar no app — exceto no `offline.html`, que
nunca fala com o servidor. Sem sessão válida, o boot mostra a tela de
entrar/criar conta (`exigeLogin()`/`pintarLogin()`).

**O link do e-mail de confirmação de cadastro não visita uma página do
Supabase** — o GoTrue confere o token no servidor e redireciona de volta pro
app com a sessão pronta em `#access_token=...&refresh_token=...&type=signup`
na URL (fragmento). `capturarSessaoDoHash()` lê isso **antes** de
`lerSessao()` decidir a sessão normal, grava e limpa o hash com
`history.replaceState` (o token não pode sobreviver a um F5 nem ficar
visível na URL). Sem isso, abrir o link parecia não fazer nada — o app
ignorava o fragmento inteiro e mostrava a tela de login comum.

**Cadastro é aberto; o controle é aprovação depois do cadastro.** Qualquer
e-mail cria conta, ela nasce `pendente` e **não enxerga nada** até um
aprovador liberar:

- Quem barra é a **RLS**, não a tela: `eventos_resposta`, `simulados`,
  `propostas` e `reportes` exigem `conta_aprovada()` nas policies.
- `perfis` é a exceção deliberada: a pessoa precisa ler a própria linha
  mesmo pendente, senão o app não teria como mostrar a tela de espera.
- Ninguém se auto-aprova: o gatilho `proteger_status_perfil` separa `status`
  (só um aprovador muda) dos campos que a própria pessoa edita (nome, meta),
  assina `aprovado_por` com `auth.uid()` do servidor e congela o `email`.
- `aprovadores`/`sou_aprovador()` e `revisores`/`sou_revisor()` seguem o
  mesmo padrão: tabela ilegível direto, function `security definer`
  devolvendo só booleano.
- **É obrigatório ter pelo menos um aprovador cadastrado** (seção final de
  `schema.sql`) — sem isso, toda conta nova fica presa em `pendente` para
  sempre.
- `SITUACAO` nulo (servidor não respondeu) **não** conta como pendente de
  propósito — ficar offline não pode trancar quem já usava o app, e a RLS
  nega os dados de qualquer jeito.

## Banco colaborativo

O banco continua estático (regra 9). `propostas` é a caixa de entrada de
questão nova (revisor aprova/rejeita), `reportes` é o canal de "isso aqui
está errado" numa questão existente — os dois reaproveitam os mesmos
`revisores`/`sou_revisor()`, porque julgar proposta e julgar reporte são o
mesmo tipo de trabalho.

## Meta e progresso do dia

A meta diária **não é configurável** — é a soma das cotas dos concursos que
o escopo alcança (`blocosDaMeta()` → `BLOCOS_META`, recalculado em
`aplicarFoco()`): todos os inscritos por padrão, ou um só quando
`E.escopoEstudo` aponta para um.

- **Matéria repetida não soma, vale a maior cota.** Português cai nos quatro
  concursos cadastrados; somar daria 40 questões/dia da mesma matéria.
  Estudar 10 de Português serve para as quatro provas ao mesmo tempo.
- **`BLOCOS` ≠ `BLOCOS_META`.** `BLOCOS` é da prova (`CONCURSO`) e manda no
  simulado, na contagem regressiva, na regra de aprovação e em
  `blocoDaMateria` (peso usado por `prioridade()`). `BLOCOS_META` manda só na
  meta: `progressoDoDia`, `progressoPorBloco` e `iniciarSessao("normal")`.
  Não unificar os dois — são perguntas diferentes.
- **A cartela de Constância não é de concurso nenhum.** Janela fixa de
  `DIAS_CARTELA` (100, em 10 colunas: 10×10 exato), colorida por meta
  batida — mede constância da conta. Era de `CONCURSO.inicio` até
  `CONCURSO.data`, o que amarrava esforço pessoal às datas de uma prova:
  trocar de concurso redesenhava tudo, e depois da prova não faria sentido.
  Não existe mais quadradinho de dia de prova (`.dia.prova` foi removido).
  **A janela não é retrospectiva** (não é "os últimos 100 dias"): célula 1
  é o dia mais antigo com dado em `E.dias`, hoje ocupa a célula logo depois
  de TODO o histórico da conta, e o resto olha pra FRENTE — amanhã, depois
  de amanhã, até fechar as 100 células. Quem tem 30 dias de uso tem 30
  células de passado e hoje é a 31ª. As células futuras nascem em branco
  (`progressoDoDia` de um dia que ainda não aconteceu é sempre 0) e vão se
  colorindo sozinhas conforme os dias chegam, sem código extra pra isso.
  Conta sem nenhum dia estudado antes de hoje (primeiro dia de uso) não tem
  passado pra mostrar — célula 1 já nasce em hoje. Histórico maior que 99
  dias é limitado aos últimos 99 (`Math.min`) — sempre sobra pelo menos 1
  célula pra hoje dentro das 100 fixas; nesse caso hoje vira a última
  célula, sem sobra pra futuro.
- **Escopo de tópicos por bloco** (`blocos[].topicos`, opcional): a mesma
  matéria pode ter conteúdo programático diferente por cargo — um cargo de
  nível fundamental/médio, por exemplo, cobre menos itens de Português que
  um de nível superior, que costuma cobrir praticamente tudo. Bloco sem
  `topicos` significa **matéria inteira**. Quem usa o escopo hoje é
  `transpetro-mec`: o Anexo IV de nível médio lista 8 itens de Português
  (sem regência, colocação pronominal, coordenação/subordinação nem
  sintaxe — 132 dos 172 cartões entram) e 10 de Matemática (sem lógica —
  116 dos 129). O bloco de Específicos não declara escopo porque a matéria
  inteira *é* o conteúdo da ênfase.
  - Ao deduplicar, o escopo é **união**, não o do bloco vencedor: se um
    concurso restringe e outro não, quem segue os dois estuda a matéria
    inteira. União é o que garante não estudar de menos.
  - O mapeamento item-do-edital → tópico-do-banco é **interpretação**, não
    transcrição (os itens são categorias largas). Na dúvida, **inclui**:
    acentuação entra em "ortografia oficial", pronomes em "classes de
    palavras". Mapear ao pé da letra já cortou 67 de 127 questões de
    Português por engano.
  - `validar` confere cada tópico declarado contra o banco — tópico com
    grafia errada some silenciosamente da sessão, que é pior que um erro.
- `E.diasMateria[dia][materia]` guarda respostas **por matéria** (não por
  bloco: id de bloco é por concurso, guardar por bloco quebraria ao trocar
  o foco).
- `progressoDoDia(k)` agrega esses números nos blocos da meta, cada um
  limitado à própria cota (`bl.questoes`). Matéria fora de todos os
  inscritos não conta; excedente de um bloco não compensa outro.
- `iniciarSessao("normal")` monta a sessão respeitando essas cotas **e** o
  escopo de tópicos — não sorteia matéria nem tópico que depois não conta.
- A **gravação** não filtra pelo foco (`registrar()`/`aplicarEventoRemoto()`
  gravam sempre); o filtro é só na **leitura**, porque quem alterna o foco
  precisa do histórico certo para os dois concursos.
- O gráfico "Cartões estudados" usa a contagem bruta (`E.dias`) de
  propósito: ali a pergunta é "quanto você estudou", não "quanto contou".

## Padrão dos cartões

Está em `PADRAO-DOS-CARTOES.md`: recordação ativa, um fato por cartão,
distratores plausíveis, explicação que ensina, como priorizar sem inventar
dado de incidência que este projeto não tem (não existe base de provas
anteriores da banca — a priorização usa peso do bloco no edital, cobertura
do conteúdo programático e onde a pessoa erra mais).

Três pontos de lá que decidem trabalho:

- **Um fato, um cartão — e só um cartão** (seção 1.5). Dois cartões cobrando
  o mesmo fato competem entre si e gastam duas revisões para fixar uma
  informação. **Não há atalho mecânico** (1.5.1): medido no banco, "mesma
  resposta certa" dá 10 pares e os 10 são legítimos (`sen(30°)` e `cos(60°)`
  valem 1/2), e enunciado parecido costuma ser boa prática. Só a combinação
  dos dois indica algo, e o `validar` a trata como aviso — julgamento é seu.
- **Saturação** (3.5): o critério de parada é cobertura de fatos, não número
  de cartões. Tópico saturado é onde o cartão novo não passaria no teste 1.5.
- **Manutenção** (5): corrigir alternativa/explicação/fonte é livre; corrigir
  **enunciado** só por `reescrever-questoes.ps1`, senão zera o histórico de
  todo mundo (regra 5). Aposentar quase nunca é a resposta certa.

`auditar-banco.ps1`/`.py` mede o banco contra esse padrão — diferente do
`validar`, **não reprova nada**; a saída só ajuda a escolher o que corrigir
primeiro.

## Ordem de aprendizado

**Entender o conceito antes de exercitar.** É o único princípio, e ele se
realiza por dois mecanismos, os dois de bloqueio — não existe mais nenhum
mecanismo que apenas *ordene*:

| | onde vive | o que trava |
|---|---|---|
| **pré-requisito** entre tópicos | `banco/requisitos.json` | o tópico, até a base do exigido estar dominada |
| **nível do cartão** dentro do tópico | campo `n` | o degrau, até o anterior estar acertado |

Os dois são opcionais: sem eles, nada trava. Formato e mecânica em
`ESTRUTURA.md`.

**Não existe nível ENTRE tópicos.** Existiu — camadas que agrupavam os
tópicos em "a palavra / a relação entre palavras / o texto" — e foi removido
porque era rótulo decorativo que contradizia o motor: ao dominar Classes de
palavras abriam ao mesmo tempo um tópico rotulado camada 1 e outro rotulado
camada 3, porque quem decide o que abre é o grafo de pré-requisitos. A tela
anunciava uma hierarquia que não existia. **Nível é uma noção só, e ela vive
dentro do tópico.**

Os invariantes, que não podem ser afrouxados:

- **Trava só cartão NOVO.** Revisão vencida entra sempre, venha do degrau ou
  do tópico que vier. Travar revisão viraria um jeito de esconder justamente
  o que a pessoa já errou.
- **Cartão sem `n` vale 1, e o degrau 1 nunca trava.** Enquanto o banco não
  estiver todo classificado, ligar o recurso não pode trancar o que ninguém
  classificou.
- **Sempre existe tópico sem pré-requisito** — o validador reprova se não
  houver nenhum. A trava não pode deixar a pessoa sem nada para estudar.
- **O simulado ignora os dois eixos.** Ele imita a prova, e a prova não
  respeita escada nenhuma.
- **A trava não tem escape.** Tópico fechado por pré-requisito não ganha
  botão Estudar; degrau fechado não é alcançável nem pelo atalho de "revisar
  adiantado".
- **`criterio`, não `fonte`.** `topicos.json` transcreve edital e exige
  `fonte`; ordem de estudo é julgamento nosso, e nenhum edital diz de que
  tópico depende qual. Chamar de "fonte" fingiria autoridade que não existe —
  mesmo cuidado da regra 11.

`validar.py` barra grafia que não existe no banco, pré-requisito circular,
tópico que exige a si mesmo, matéria em que nenhum tópico abriria, e nível
fora de 1–9. E **avisa** qual tópico tem cartão de nível 2+ sem nenhum de
nível 1: ali a escada não segura nada, e esse aviso é a lista de trabalho de
quais definições ainda faltam escrever.

O campo `n` é gravado pelos caminhos de sempre — `incorporar-rascunho.ps1` e
`explicar-alternativas.ps1`. Nenhum script novo: a regra 9 segue com três.


## Motor de repetição espaçada

Leitner de 5 caixas, intervalos 1, 3, 7 e 14 dias, com **teto dinâmico**:
nenhum intervalo pode passar de ⅓ dos dias restantes até a prova, e a partir
de D-10 tudo vira revisão diária. Ver `proximaData()`.

Três respostas possíveis: "Sabia" sobe uma caixa; "Chutei" e "Errei" voltam
para a caixa 1. O botão "Chutei" é central — não removê-lo nem transformá-lo
em acerto.

**A ordem dentro do que já venceu** é decidida por `prioridade()`: caixa,
taxa de erro da questão e peso do bloco na prova. Os pesos são calibrados
para o desconto somado ficar **abaixo de 1** — erro e peso ordenam *dentro*
da caixa e nunca atravessam a fronteira dela, porque caixa 1 ("errei na
revisão mais recente") é o sinal mais forte que existe.

**O dia sempre vira no fuso de Brasília, nunca no fuso do aparelho.**
`hoje()` usa `Intl.DateTimeFormat` com `timeZone:"America/Sao_Paulo"` fixo —
não um offset `-3` na unha. Qualquer soma ou comparação de data usa
`diaUTC()`/`somarDias()`, nunca `new Date()` puro nem `.setDate()`: misturar
hora local do aparelho com formatação UTC no meio do cálculo faz o dia virar
errado dependendo de onde o aparelho está. `aplicarEventoRemoto()` usa a
mesma formatação de fuso ao decidir em qual dia contar a resposta de outro
aparelho.

Acurácia por período (hoje/7 dias/30 dias) soma `E.diasCertas`/`E.diasTotal`
numa janela — campos paralelos a `E.dias` (que só conta quantidade), para
não fazer dias antigos aparecerem como 0%.

## Viés de comprimento e de posição

**Resolvido, e é regra permanente, não histórico.** A alternativa correta
não pode ser visivelmente mais longa que os distratores — isso permite
acertar sem saber o conteúdo. `validar.py`/`validar.ps1` falham se alguma
questão exceder a segunda alternativa mais longa em mais de 20 caracteres;
diferenças de 1 a 10 caracteres são ruído, não pista.

**Como corrigir uma questão enviesada:** reescrever os *distratores*, nunca
encurtar a correta. Distratores devem ser condutas plausíveis que alguém
adotaria por engano — não frases curtas do tipo "Apenas X" ou "Somente Y".
Em boa parte dos casos, escrever pelo menos um distrator **mais longo** que
a correta.

As alternativas são embaralhadas em tempo de execução (`embaralhaOrdem`), no
estudo e no simulado — não reintroduzir ordem fixa.

## Rodar localmente

Duas formas, e a escolha importa: **`servidor.ps1`** reflete o app publicado
(service worker, PWA, arquivos separados) e é a de desenvolver;
**`gerar-offline.ps1`** produz o `offline.html`, arquivo único que dispensa
servidor e login — é onde dá para verificar mudança de JS sem Supabase.
Comandos e detalhes em `ESTRUTURA.md` §7.

Abrir o `index.html` direto do disco **não** funciona: o banco é lido por
`fetch`, que o navegador bloqueia em `file://`.


## Publicação

Netlify (arrastar a pasta) ou GitHub Pages (git push + Settings → Pages).
Precisa ir junto: `index.html`, `sw.js`, `manifest.json`, os ícones,
`concursos.json`, `supabase.json` e a pasta `banco/` inteira — sem ela o app
cai na tela de erro de boot. Passo a passo em `TUTORIAL.md`.
