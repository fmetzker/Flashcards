# App de estudo — Concursos públicos

Aplicativo web de questões com repetição espaçada, contas e banco
colaborativo. Hoje atende cinco concursos: Enfermeiro/Volta Redonda (edital
003/2026-SMA, prova 20/09/2026), CAAQ-CDM/Marinha e três da Transpetro
cadastrados como **pré-edital** (Moço de Máquinas, Enfermagem do Trabalho e
Psicologia), com estrutura copiada dos editais de 2023 enquanto os de 2026
não saem. Novo concurso é editar `concursos.json` — não exige mexer no
código.

## Estrutura

| Arquivo | Papel |
|---|---|
| `index.html` | App inteiro: HTML, CSS e JS. O banco **não** vive aqui |
| `concursos.json` | Receitas de prova: data, composição, regra de aprovação |
| `banco/materias.json` | Lista de matérias, na ordem de exibição |
| `banco/topicos.json` | Árvore oficial do edital — deixa a tela Matérias mostrar tópico que a prova cobra e o banco ainda não cobre |
| `banco/<matéria>.json` | Questões daquela matéria, uma por linha |
| `banco/indice-legado.json` | Ids na ordem antiga do array — migra progresso pré-id estável |
| `banco/reescritas.json` | Mapa id antigo→novo de enunciados corrigidos — preserva progresso |
| `sw.js` | Service worker — faz o app funcionar offline |
| `manifest.json` | Metadados do PWA |
| `icone-192.png`, `icone-512.png`, `apple-touch-icon.png` | Ícones |
| `PADRAO-DOS-CARTOES.md` | O padrão dos cartões — como escrever, o que não fazer, como priorizar |
| `validar.py` / `validar.ps1` | Verificação de integridade do banco — **rodar antes de publicar**. Com `-Rascunho`/`--rascunho`, valida candidatos sem gravar |
| `rascunho.json` | Cartões em elaboração, sem `id`. Vazio quando não há trabalho em curso |
| `incorporar-rascunho.ps1` | Grava o rascunho no banco — só se o validador passar. Ver regra 9 |
| `auditar-banco.py` / `.ps1` | Mede o banco contra `PADRAO-DOS-CARTOES.md`. Mede, não reprova |
| `reescrever-questoes.ps1` | Corrige enunciado sem perder progresso — ver regra 5 |
| `incorporar-propostas.ps1` | Grava proposta aprovada como questão de verdade — ver regra 9 |
| `servidor.ps1` | Servidor local para desenvolver: `http://localhost:8080` |
| `gerar-offline.ps1` | Gera `offline.html`: o app inteiro num arquivo só |
| `offline.html` | **Gerado** — abre com duplo clique, sem servidor e sem rede |
| `supabase/schema.sql` | Tabelas, RLS, triggers — colar no SQL Editor do Supabase |
| `supabase/conferir.sql` | Confere o que a RLS **nega**; rodar sempre depois do schema |
| `supabase.json` | URL e chave pública do projeto Supabase |
| `TUTORIAL.md` | Publicar e instalar — o único tutorial que existe |

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
   caixa de entrada. Só **dois** scripts gravam em `banco/*.json`, os dois
   rodados à mão e seguidos de `validar` e commit manuais:
   `incorporar-propostas.ps1` (caixa do Supabase) e
   `incorporar-rascunho.ps1` (cartão escrito localmente). **Não escrever
   script de gravação por lote** — foi o que corrompeu o banco por encoding
   e passou por cima de regra que o validador reprova.
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

## Formato do banco de questões

Arquivos `banco/<matéria>.json`, um objeto por linha (mantém o diff pequeno):

```json
{"id":"a1b2c3d4e5","m":"enfermagem","t":"Imunização","s":"Rede de frio","q":"enunciado","o":["A","B","C","D","E"],"c":1,"e":"explicação","f":"fonte"}
```

- `id` — SHA-1 do enunciado, 10 hexadecimais. Ver regra 5.
- `m` — matéria; precisa existir em `banco/materias.json` e bater com o arquivo
- `t` — tópico, o assunto dentro da matéria
- `s` — subtópico, o detalhe dentro do tópico. **Opcional**: Português e SUS
  não usam, porque os tópicos deles já são o nível certo. Quando existe, não
  pode repetir o nome do tópico — o validador barra
- `c` — índice da correta, 0 a 4
- `f` — **obrigatório**: lei e artigo, ou manual e capítulo. Questão sem
  fonte não entra
- `eo` — explicação por alternativa, **opcional**. Array do mesmo tamanho de
  `o`, uma posição por alternativa (`""` pula a posição, mas ela precisa
  existir). Ao responder, o app mostra essa nota junto da própria
  alternativa, ao lado de `e` (que continua sendo a explicação da questão
  como um todo). Ver `PADRAO-DOS-CARTOES.md` seção 1.4.1 — não é retroativo
  para as questões já escritas (regra 9), só para cartão novo ou em reescrita

Ao acrescentar questão, **reusar um `t` e um `s` que já existam** em vez de
inventar rótulos novos; a árvore só é útil enquanto os níveis se mantêm
poucos. Antes de escrever, ler `PADRAO-DOS-CARTOES.md`.

## Matéria, tópico e subtópico

**Matéria é o bloco do edital.** O banco é a união das matérias de **todos**
os concursos cadastrados em `concursos.json`:

| id | nome | questões | tópicos | subtópicos |
|---|---|--:|--:|--:|
| `portugues` | Língua Portuguesa | 127 | 23 | — |
| `ingles` | Língua Inglesa | 0 | 2¹ | — |
| `sus` | Legislação do SUS | 103 | 10 | — |
| `enfermagem` | Conhecimentos Específicos de Enfermagem | 677 | 19 | 120 |
| `enfermagem-trabalho` | Enfermagem do Trabalho | 0 | 17¹ | — |
| `psicologia` | Psicologia | 0 | 0² | — |
| `maritimo-maquinas` | Máquinas e Prática Marítima | 0 | 16¹ | — |
| `matematica` | Matemática | 39 | 6 | — |

¹ tópicos vindos só de `banco/topicos.json` (árvore do edital), ainda sem
cartão escrito. ² Psicologia não tem árvore porque não existe edital
anterior do cargo na Transpetro — ver regra 11.

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

- **Matéria repetida não soma, vale a maior cota.** Português cai nos cinco
  concursos cadastrados; somar daria 50 questões/dia da mesma matéria.
  Estudar 10 de Português serve para as cinco provas ao mesmo tempo.
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
  é ontem, célula 2 é hoje, e as 98 seguintes olham pra FRENTE — amanhã,
  depois de amanhã, até 97 dias no futuro. As células futuras nascem em
  branco (`progressoDoDia` de um dia que ainda não aconteceu é sempre 0) e
  vão se colorindo sozinhas conforme os dias chegam, sem código extra pra
  isso — é a fórmula `somarDias(hoje(), i-1)` em vez de voltar no tempo.
- **Escopo de tópicos por bloco** (`blocos[].topicos`, opcional): a mesma
  matéria pode ter conteúdo programático diferente por cargo. O Português do
  Moço de Máquinas tem 8 itens no edital e não cobra regência, colocação
  pronominal, coordenação/subordinação nem sintaxe; o de nível superior tem
  12 e cobre praticamente tudo. Bloco sem `topicos` significa **matéria
  inteira**, e por isso o nível superior não declara nada.
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

Duas formas, para usos diferentes.

**Servidor local** — reflete o app publicado (service worker, PWA, arquivos
separados). Use esta para desenvolver:

```
powershell -ExecutionPolicy Bypass -File servidor.ps1
```

e abra `http://localhost:8080`. Abrir o `index.html` direto do disco **não**
funciona: o banco é lido por `fetch`, que o navegador bloqueia em `file://`.

**Arquivo único** — para testar sem servidor, num aparelho sem nada
instalado, ou para mandar por e-mail:

```
powershell -ExecutionPolicy Bypass -File gerar-offline.ps1
```

Gera `offline.html` com o banco embutido em `window.DADOS`, de onde `pega()`
lê sem requisição nenhuma. Abre com duplo clique, salva progresso no
`localStorage` normalmente (chave fixa `vr:conta:local`) e não toca a rede.
Nunca exige login. É um **artefato gerado**: não editar à mão, e refazer
depois de mexer no `index.html` ou no banco — o validador avisa quando está
para trás.

## Publicação

Netlify (arrastar a pasta) ou GitHub Pages (git push + Settings → Pages).
Precisa ir junto: `index.html`, `sw.js`, `manifest.json`, os ícones,
`concursos.json`, `supabase.json` e a pasta `banco/` inteira — sem ela o app
cai na tela de erro de boot. Passo a passo em `TUTORIAL.md`.
