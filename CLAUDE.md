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
no app: a matéria só não aparece pra ninguém estudar até algum concurso
voltar a referenciá-la em `blocos[].materias`, **ou** até ser marcada
`"avulsa": true` em `banco/materias.json` — o segundo caminho, hoje usado
por Enfermagem do Trabalho, Psicologia e Máquinas e Prática Marítima (nenhuma
delas referenciada por concurso algum no momento) além de Biologia Celular
(nunca teve concurso, avulsa desde que nasceu). Ver regra 12.

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

   **`CACHE` (com `VERSAO`) e `CACHE_BANCO` (nome fixo) são caches
   separados.** `CACHE_BANCO` guarda tudo debaixo de `banco/` e **não** é
   apagado quando `VERSAO` sobe — só o app shell (`CACHE`) é recriado a cada
   deploy. Antes de existir essa separação, um bump de `VERSAO` (regra 2,
   qualquer mudança em `index.html`) derrubava o cache do banco inteiro
   junto — 3,6 MB em 10 matérias, refeitos do zero a cada deploy de código,
   mesmo sem questão nenhuma ter mudado. Nunca incluir `CACHE_BANCO` no
   filtro de limpeza do `activate()`.
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
    e `banco/enfermagem-trabalho.json` continuam intactos. As duas matérias
    — mais `psicologia`, que nunca teve bloco de concurso próprio apesar de
    o concurso "Psicologia/Transpetro" existir em `concursos.json` — foram
    depois marcadas `"avulsa": true` em `banco/materias.json`: continuam sem
    concurso atrás, mas passaram a ser conteúdo avulso de propósito, à
    disposição de quem quiser seguir sem prova nenhuma. Matéria sem concurso
    ativo **e** sem avulsa declarada não é estudada automaticamente por
    ninguém — só entra na sessão de quem, na tela de seleção, marcá-la à mão
    como matéria avulsa (ver "Matéria, tópico e subtópico").

    **Guardar é uma coisa, escrever é outra: cartão novo só entra em matéria
    ativa.** O que já existe fica intacto — corrigir alternativa, explicação,
    fonte ou `eo` de cartão de matéria inativa continua livre, é manutenção do
    que já foi feito. Mas escrever cartão NOVO para matéria que nenhum
    concurso referencia é trabalho que ninguém vai ver, enquanto matéria ativa
    tem item de edital sem cartão nenhum. `validar` reprova o rascunho que
    tente isso, e lista numa linha as matérias inativas a cada execução.

    **Ativa** é referenciada por algum concurso de `concursos.json` OU
    marcada `"avulsa": true` em `banco/materias.json`. O flag existe porque a
    tela de seleção lista TODAS as matérias do arquivo na seção "matérias
    avulsas", sem distinção — sem um jeito de declarar qual delas tem alguém
    de verdade estudando por conta própria agora, "ativa" viraria a lista
    inteira, e a regra perderia sentido. `"avulsa": true` é essa declaração:
    não "alguém poderia estudar isso um dia", mas "isso é conteúdo avulso de
    propósito — sem concurso nenhum atrás, ex.: uma matéria de curso próprio
    que a conta usa o app pra revisar". Se o concurso vai voltar, o caminho é
    cadastrá-lo em `concursos.json`; se é avulso de propósito, marcar o flag
    — os dois caminhos tornam a matéria ativa e a escrita legítima.

## Formato do banco de questões

Arquivos `banco/<matéria>.json`, **um objeto por linha** — mantém o diff
pequeno e é o que permite gravar cartão sem reescrever o arquivo inteiro.

**O esquema campo a campo está em `ESTRUTURA.md` §1**, com a coluna que mais
importa: quais campos entram no `id`. Só `q` entra. O que fica aqui são as
regras que o esquema não expressa:

- **`f` é obrigatório**: lei e artigo, ou manual e capítulo. Questão sem
  fonte não entra. Sem fonte à mão, não escreva o cartão (regra 11).
- **`s` não pode repetir o nome do `t`** — o validador barra. Toda matéria
  pode usar subtópico; a granularidade é decisão de quem escreve o cartão, e
  não é mais exclusividade de matéria com árvore grande (Enfermagem). Desde
  que `banco/requisitos.json` passou a poder travar por subtópico (não só por
  tópico inteiro — ver seção "Ordem de aprendizado"), subtópico ganhou um
  segundo uso: além de agrupar na tela Matérias, pode ser alvo de
  pré-requisito.
- **Reusar `t` e `s` que já existam** em vez de inventar rótulo novo: a
  árvore só é útil enquanto os níveis se mantêm poucos.
- `eo` é obrigatório DECIDIR em cartão novo (`validar --rascunho` reprova se
  o campo faltar, mesmo que todo vazio — ver PADRAO-DOS-CARTOES.md §1.4.1).
  Sobre o que já existe sem `eo`, não é retroação automática (regra 9): há
  uma campanha em andamento, matéria por matéria, cartão revisado um a um
  via `explicar-alternativas.ps1` — ver a mesma seção pra ordem e critério.

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
  **Pode ser `null`** — ver `E.materiasAvulsas` abaixo.

**`E.materiasAvulsas`** é um terceiro jeito de expandir o banco carregado,
sem concurso nenhum por trás: matéria avulsa entra em `materiasInscritas()`
do mesmo jeito que a de um concurso inscrito. Diferente de concurso, ela não
vem de um `bloco` de `concursos.json` — mas `blocosDaMeta()` cria um bloco
sintético pra cada matéria avulsa, com cota fixa `META_MATERIA_AVULSA` (20
por dia), então ela **entra** em `BLOCOS_META` e conta pra meta do dia,
igual a qualquer bloco de concurso. Se a mesma matéria já tem bloco de algum
concurso seguido, vale a **maior** cota entre os dois — a mesma regra de
"matéria repetida não soma" que já valia entre concursos (ver acima), agora
estendida à avulsa. O que ela não faz é entrar no simulado (inventar data de
prova e regra de aprovação pra ela violaria a regra 11) — por isso o botão
Simulado permanece ligado a `CONCURSO`, não a `BLOCOS_META`.

Dá pra seguir só matéria avulsa, sem concurso nenhum — nesse caso `CONCURSO`
fica `null`, `BLOCOS` (que é `CONCURSO.blocos`, usado pelo simulado e pela
regra de aprovação) fica `[]`, mas `BLOCOS_META` **não** fica vazio: tem um
bloco sintético por matéria avulsa seguida. A tela inicial mostra "Estudo
livre" em vez do cabeçalho de prova, o botão Simulado some, e o rótulo da
meta muda para "Sessão de hoje" — não porque o número deixou de ser uma meta
de verdade (cada matéria avulsa tem cota própria, soma igual a qualquer
outra), mas porque não existe **prova** nenhuma atrás dela. `E.meta` só cai
no fallback `SESSAO_SEM_CONCURSO` (20) no caso residual de `BLOCOS_META`
ficar mesmo vazio — nem concurso, nem avulsa — o que hoje só acontece em
estado transitório do boot ou pra quem ainda não seguiu nada.
`exigeEscolherConcurso()` também aceita matéria avulsa sozinha: só força a
tela de portão se não houver concurso **nem** avulsa nenhuma.

Concurso e processo seletivo (campo `tipo` em `concursos.json`, usado só
para agrupar as telas de seleção em três divisórias — não muda nenhuma
regra do motor) seguem a nomenclatura do próprio edital: **concurso
público** é administração direta (ex.: prefeitura, regra constitucional do
art. 37, II); **processo seletivo** é o termo que empresa de economia mista
(Transpetro) ou a Marinha já usam no nome oficial do próprio edital
("PS"/"PSP") — não é rótulo nosso.

O teto do Leitner continua em `diasAteMaisProxima()` sobre **todos** os
inscritos, mesmo com escopo restrito: estudar só para um concurso hoje não
adia a prova do outro. Sem concurso nenhum inscrito, `INSCRITOS` fica vazio
e a função devolve `Infinity` — sem prova nenhuma apertando, os intervalos
do Leitner (1/3/7/14 dias) valem sem teto.

Quem entra sem nenhum concurso escolhido (primeira vez, ou o que seguia
sumiu de `concursos.json`) cai em `tela-escolher-concurso`
(`exigeEscolherConcurso()`) antes da tela inicial. Se só existe um concurso
cadastrado no arquivo inteiro, não há o que escolher e a tela é pulada.

Consequência assumida desta modelagem: como "Enfermagem" é uma matéria só,
o compartilhamento do acervo vale entre concursos **de enfermagem**.
Português e Legislação do SUS, que caem em quase toda prova da área da
saúde, continuam compartilháveis com qualquer cargo.

A tela **Matérias** mostra a árvore inteira, inclusive o que ainda não foi
visto, e permite estudar qualquer um dos três níveis isoladamente. A tela
**Estatísticas** ranqueia do menos dominado para o mais dominado, pelo nível
mais fino de cada questão, considerando só o que já foi respondido. O
critério é **caixa média do Leitner**, não acurácia: acurácia mistura
"acertei de sorte" com "já domino" (duas respostas certas dão 100% mesmo
sem nunca ter sido revisado de verdade), enquanto caixa alta só se ganha
voltando a acertar depois do espaçamento crescer — é o sinal de retenção
mais forte que o motor já produz. A acurácia continua exibida (mini barra em
cada linha), só não é mais quem ordena. Não duplicar uma tela na outra.

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
o escopo alcança, mais a cota de cada matéria avulsa seguida
(`blocosDaMeta()` → `BLOCOS_META`, recalculado em `aplicarFoco()`): todos os
inscritos por padrão, ou um só quando `E.escopoEstudo` aponta para um —
matéria avulsa entra **sempre**, não depende do escopo (ver
`E.materiasAvulsas` acima).

- **Matéria repetida não soma, vale a maior cota.** Português cai nos quatro
  concursos cadastrados; somar daria 40 questões/dia da mesma matéria.
  Estudar 10 de Português serve para as quatro provas ao mesmo tempo. A mesma
  regra vale entre bloco de concurso e matéria avulsa: se a mesma matéria
  aparece nos dois, fica a maior cota, nunca a soma.
- **A cota de cada bloco é novos + revisão pendente, não só o número do
  edital.** `blocosDaMeta()` soma à cota de novos (a do edital, como sempre
  foi) quantos cartões daquela matéria já estão vencidos agora — capado em
  **2× a cota de novos**, pra um backlog grande (dias sem estudar) não
  inflar a sessão de um dia só. O excedente do teto continua vencido, só
  sai do número da meta: `iniciarSessao("normal")` intercala revisão e
  cartão novo dentro da cota (proporção real, não mais um corte fixo de
  metade), e quem bate a meta e continua estudando recebe esse excedente
  **inteiro, antes de qualquer cartão novo** — só volta a oferecer novo
  depois de esvaziar o atrasado. A cota fica congelada no mesmo momento em
  que `BLOCOS_META` já era recalculado (boot, troca de dia, troca de foco),
  não a cada resposta — vira alvo móvel senão.
- **`BLOCOS` ≠ `BLOCOS_META`.** `BLOCOS` é da prova (`CONCURSO`) e manda no
  simulado, na contagem regressiva, na regra de aprovação e em
  `blocoDaMateria` (peso usado por `prioridade()`). `BLOCOS_META` manda só na
  meta: `progressoDoDia`, `progressoPorBloco` e `iniciarSessao("normal")`.
  Não unificar os dois — são perguntas diferentes.
- **A Sequência de estudo não é de concurso nenhum.** Card no topo da tela
  inicial, contagem de dias consecutivos (terminando hoje ou ontem) em que
  a meta do dia foi batida — mede constância da conta, não de uma prova
  específica. Não conta a partir de `CONCURSO.inicio`: trocar de concurso
  não redesenha nada, e a contagem continua fazendo sentido depois da
  prova. Existiu antes uma cartela visual de 100 dias (janela fixa,
  10×10, colorida por meta batida) que fazia esse mesmo papel de forma
  mais elaborada; foi removida por ser cara de carregar/pintar sem
  acrescentar informação que a contagem simples de dias seguidos já não
  desse.
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
realiza por três mecanismos, os três de bloqueio — não existe nenhum
mecanismo que apenas *ordene*:

| | onde vive | o que trava |
|---|---|---|
| **pré-requisito** entre tópicos | `banco/requisitos.json` → `requisitos` | o tópico, até a base do exigido estar dominada |
| **pré-requisito** entre subtópicos | `banco/requisitos.json` → `requisitos_subtopicos` | o subtópico, até a base do exigido estar dominada |
| **nível do cartão** dentro do tópico | campo `n` | o degrau, até o anterior estar acertado |

Os três são opcionais: sem eles, nada trava. Formato e mecânica em
`ESTRUTURA.md`.

**Pré-requisito de tópico pode apontar para um subtópico do exigido, não só
para o tópico inteiro.** Uma entrada de `requisitos` é uma lista onde cada
item é uma string (tópico inteiro, como sempre foi) ou um objeto
`{"t":"Tópico", "s":"Subtópico"}` (só aquele subtópico). Existe para o caso
em que só uma fatia do tópico exigido é base de verdade — ex.: para abrir
"Flexão verbal" não é preciso dominar Classes de palavras inteira, só o
subtópico Verbo dela. Isso **não** cria uma segunda escada: o subtópico aqui
é só o alvo do pré-requisito, e a trava continua sendo do tópico inteiro que
o declara — o que muda é a granularidade do que precisa estar pronto do lado
exigido, não como o lado exigente é travado.

**Pré-requisito entre subtópicos afina o lado que TRAVA, não só o exigido —
para tópico grande e heterogêneo o suficiente pra merecer ordem interna.**
Aritmética (16 subtópicos que não têm nada a ver entre si — Frações,
Progressões, Sistema de unidades de medida...) é o primeiro caso: abrir
tudo de uma vez, no dia em que a matéria libera, não ensina em ordem
nenhuma, e o campo `n` não resolve isso porque gradua definição→exercício
DENTRO do mesmo fato, não sequencia subtópicos irmãos entre si. Chave
`requisitos_subtopicos` em `banco/requisitos.json`, formato `"Tópico|Subtópico":
[{"t":..,"s":..}, ...]` — cada dependência é **sempre** `{t,s}`, nunca string
solta (dentro de uma chave de subtópico, string ambiguaria entre "o tópico X
inteiro" e "o subtópico X deste mesmo tópico"). Um subtópico só abre se o
TÓPICO dele já estiver aberto — a trava de subtópico é uma camada A MAIS,
nunca um atalho que pule a de tópico — e tópico sem nenhuma entrada aqui
continua com todos os subtópicos abertos assim que ele mesmo abrir: é
opcional em cima de opcional. Exige `criterio_subtopicos` pela mesma razão
de `criterio` — é julgamento pedagógico nosso, não transcrição de edital.

**Não existe nível ENTRE tópicos.** Existiu — camadas que agrupavam os
tópicos em "a palavra / a relação entre palavras / o texto" — e foi removido
porque era rótulo decorativo que contradizia o motor: ao dominar Classes de
palavras abriam ao mesmo tempo um tópico rotulado camada 1 e outro rotulado
camada 3, porque quem decide o que abre é o grafo de pré-requisitos. A tela
anunciava uma hierarquia que não existia. **Nível é uma noção só.**

**Nível (`n`) de cartão com subtópico é avaliado DENTRO DO SUBTÓPICO, nunca
do tópico inteiro.** `grauLiberado`/`grauAberto` escalam pelo recorte mais
fino que o cartão tem: `{m,t,s}` quando existe subtópico, `{m,t}` quando
não. Existe desde agosto/2026, quando a escada de subtópico (audite acima)
expôs um impasse que a escada de tópico nunca tinha: medir o nível 1 pelo
TÓPICO inteiro soma cartão de todo subtópico, inclusive os ainda fechados
pela escada de desbloqueio — e cartão fechado é inacessível, nunca dá pra
dominar. O nível 1 do tópico inteiro nunca "vencia", e nível 2 de NENHUM
subtópico jamais abria, até a cadeia de subtópico inteira ser percorrida.
Escalar por subtópico resolve: cada um tem a própria escada de
definição→exercício, independente dos outros — exatamente como a escada de
desbloqueio já pressupunha. Tópico sem subtópico continua idêntico a
sempre (o cartão não tem `s`, cai no recorte de tópico automaticamente).

Os invariantes, que não podem ser afrouxados:

- **Trava só cartão NOVO.** Revisão vencida entra sempre, venha do degrau, do
  tópico ou do subtópico que vier. Travar revisão viraria um jeito de
  esconder justamente o que a pessoa já errou.
- **Cartão sem `n` vale 1, e o degrau 1 nunca trava.** Enquanto o banco não
  estiver todo classificado, ligar o recurso não pode trancar o que ninguém
  classificou.
- **Sempre existe tópico sem pré-requisito** — o validador reprova se não
  houver nenhum. A trava não pode deixar a pessoa sem nada para estudar. Vale
  também por subtópico: todo tópico que declara `requisitos_subtopicos` para
  algum dos seus subtópicos precisa deixar pelo menos um subtópico dele sem
  requisito — senão o tópico abre e nenhum subtópico dele nunca abriria.
- **Subtópico só abre com o tópico já aberto — transitivo, como topicoAberto().**
  `baseDominada()` verifica `subtopicoAberto()` (não só a caixa em dia) antes
  de considerar uma dependência `{t,s}` cumprida, pelo mesmo motivo que já
  valia para tópico: histórico espalhado (de antes da cadeia existir, ou de
  quando cabia estudar em qualquer ordem) não pode destravar o que vem depois
  sem ter passado pela base de verdade.
- **O simulado ignora os três eixos.** Ele imita a prova, e a prova não
  respeita escada nenhuma.
- **A trava não tem escape.** Tópico ou subtópico fechado por pré-requisito
  não ganha botão Estudar; degrau fechado não é alcançável nem pelo atalho de
  "revisar adiantado".
- **`criterio`/`criterio_subtopicos`, não `fonte`.** `topicos.json` transcreve
  edital e exige `fonte`; ordem de estudo é julgamento nosso, e nenhum edital
  diz de que tópico (ou subtópico) depende qual. Chamar de "fonte" fingiria
  autoridade que não existe — mesmo cuidado da regra 11.

`validar.py` barra grafia que não existe no banco, pré-requisito circular,
tópico que exige a si mesmo, matéria em que nenhum tópico abriria, e nível
fora de 1–9. E **avisa** qual tópico tem cartão de nível 2+ sem nenhum de
nível 1: ali a escada não segura nada, e esse aviso é a lista de trabalho de
quais definições ainda faltam escrever. As mesmas checagens de pré-requisito
valem por subtópico em `requisitos_subtopicos` (dependência que não existe
no banco, ciclo — combinando o grafo de tópico com o de subtópico, já que um
subtópico depende implicitamente do próprio tópico —, subtópico que exige a
si mesmo, tópico em que nenhum subtópico abriria).

O campo `n` é gravado pelos caminhos de sempre — `incorporar-rascunho.ps1` e
`explicar-alternativas.ps1`. Nenhum script novo: a regra 9 segue com três.


## Motor de repetição espaçada

Leitner de 8 caixas, intervalos 1, 3, 7, 14, 30, 60 e 120 dias, com **teto
dinâmico**: nenhum intervalo pode passar de ⅓ dos dias restantes até a
prova, e a partir de D-10 tudo vira revisão diária. Ver `proximaData()`.
`CAIXA_MAX` (hoje 8) e o `check (caixa_depois between 1 and 8)` de
`eventos_resposta` em `supabase/schema.sql` precisam concordar — nada os
liga automaticamente, e o Postgres rejeita o evento se `index.html` gravar
caixa mais alta do que o banco aceita.

**O teto dinâmico é invisível por padrão** — a pessoa vê os cartões
voltando mais rápido perto da prova sem saber por quê. `pintarInicio()`
torna isso visível com três coisas: contagem regressiva no cabeçalho
(`#cabecalho-contagem`, `diaUTC(CONCURSO.data) - diaUTC(hoje())` — a mesma
conta de `diasAteMaisProxima()`); e, em `#alerta-area`, um aviso quando o
teto está de fato apertando (D-10, ou `Math.floor(dias/3) < 30` — os mesmos
limiares que `proximaData()` já usa, não números novos) seguido de um
aviso de **backlog vs. tempo restante**, cruzando `revisoesPorDia()` com
`diasAteMaisProxima()` — só dispara quando o atrasado é matematicamente
maior que `E.meta × dias restantes`, ou seja, quando nem estudando a meta
inteira todo santo dia até a prova daria pra zerar. Limiar matemático de
propósito, não estimativa arbitrária (mesmo espírito da regra 11: não
inventar números como se fossem certeza).

Três respostas possíveis: "Sabia" sobe uma caixa; "Chutei" e "Errei" voltam
para a caixa 1. O botão "Chutei" é central — não removê-lo nem transformá-lo
em acerto.

**A sessão intercala revisão e cartão novo, não concatena.** `intercalar()`
espalha as duas listas já escolhidas pela sessão (proporção de cada uma no
total, tipo Bresenham) — sem isso, uma fila de revisão grande engolia o
`E.meta` inteiro da sessão e cartão novo nunca aparecia enquanto o backlog
não zerasse. Só muda a ORDEM de apresentação; quem entra na sessão continua
decidido por fora (cota do bloco, escada de pré-requisito).

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

Acurácia de hoje soma `E.diasCertas`/`E.diasTotal` do dia — campos paralelos
a `E.dias` (que só conta quantidade), para não fazer dia antigo aparecer
como 0%. Existiu também em janela de 7 e 30 dias; removida da tela
Estatísticas por diluir rápido demais para servir de sinal (um mês de
acerto quase não move com um erro isolado). No lugar, a tela mostra
**revisões pendentes** (`revisoesPorDia()`) — contagem de verdade do que
vem por aí, não média histórica. Os baldes (Atrasadas, Hoje, Amanhã, 2 a 7
dias, 8 a 30, 31 a 120) não são cortes redondos escolhidos à toa: são os
próprios intervalos do Leitner (`INTERVALOS`) — cada fronteira é onde uma
caixa nova passa a vencer. Exclusivos, não cumulativos, e contam a data
**real** de vencimento (`prox`), não a caixa nominal — perto da prova o
teto dinâmico comprime intervalos que seriam maiores, e os baldes devem
refletir essa pressão de verdade, não a promessa que o teto vai quebrar.

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

**Medir por MATÉRIA, nunca pelo banco inteiro.** O número agregado é média de
coisas opostas e mente com cara de saúde: já esteve em 18% — dentro do acaso —
com *toda* matéria ativa em 0% e as duas inativas em 59%. Medido de outro
jeito: com Português a 100% (viés máximo) injetado num teste, o número do banco
chegou a 40,3%, mal cruzando o limiar. Quem estuda vê uma matéria, não o banco.
Por isso `validar.py`/`validar.ps1` quebram a conta por matéria, e só olham
matéria com 20+ questões de pista — abaixo disso a amostra não diz nada.

**0% também é viés, e é o mais fácil de criar sem perceber.** "A mais longa
nunca é a correta" elimina uma alternativa de graça, igual a 60% servir a
correta de bandeja. O alvo é o **acaso: ~20%**, não o zero. Foi assim que uma
correção deste viés já estragou três matérias que estavam saudáveis (Português
a 25%, Matemática a 20%, SUS a 12,5%) — perseguindo o agregado, zeraram as
três. Antes de "corrigir" uma matéria, olhe a taxa dela: entre ~5% e ~40% não
há o que fazer.

**Para corrigir matéria com pista invertida (abaixo de 5%), enxugue o distrator
que se destaca — não alongue a correta.** Alongar a correta para bater uma
estatística é fabricar o viés que a regra existe para impedir.

O campo `o` é editável por `explicar-alternativas.ps1`, junto de `eo`, pelo
mesmo caminho de patch de sempre (regra 9 segue com três scripts). Os dois
validadores reprovam patch de `o` em que a correta mude de texto ou de posição:
`c` é índice, não texto, e reordenar as alternativas trocaria a resposta certa
para todo mundo sem aparecer no diff. Sobra exatamente o que esta seção manda —
mexer em distrator.

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
