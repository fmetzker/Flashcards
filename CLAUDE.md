# App de estudo — Concursos públicos

Aplicativo web de questões com repetição espaçada, contas e banco
colaborativo. Hoje atende dois concursos: Enfermeiro/Volta Redonda (edital
003/2026-SMA, prova 20/09/2026) e CAAQ-CDM/Marinha. Novo concurso é editar
`concursos.json` — não exige mexer no código.

## Estrutura

| Arquivo | Papel |
|---|---|
| `index.html` | App inteiro: HTML, CSS e JS. O banco **não** vive aqui |
| `concursos.json` | Receitas de prova: data, composição, regra de aprovação |
| `banco/materias.json` | Lista de matérias, na ordem de exibição |
| `banco/<matéria>.json` | Questões daquela matéria, uma por linha |
| `banco/indice-legado.json` | Ids na ordem antiga do array — migra progresso pré-id estável |
| `banco/reescritas.json` | Mapa id antigo→novo de enunciados corrigidos — preserva progresso |
| `sw.js` | Service worker — faz o app funcionar offline |
| `manifest.json` | Metadados do PWA |
| `icone-192.png`, `icone-512.png`, `apple-touch-icon.png` | Ícones |
| `METODOLOGIA.md` | O padrão dos cartões — como escrever, o que não fazer, como priorizar |
| `validar.py` / `validar.ps1` | Verificação de integridade do banco — **rodar antes de publicar** |
| `auditar-banco.py` / `.ps1` | Mede o banco contra `METODOLOGIA.md`. Mede, não reprova |
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
   caixa de entrada; `incorporar-propostas.ps1` é o único caminho que grava
   em `banco/*.json`, rodado à mão, seguido de `validar.py` e commit manuais.
10. **`schema.sql`: a seção que torna as FKs para `auth.users` adiáveis
    precisa ser a ÚLTIMA do arquivo.** Ela descobre as chaves estrangeiras
    dinamicamente via `pg_constraint` — só enxerga o que já existe no
    momento em que roda. Tabela nova com FK para `auth.users` adicionada
    depois dela nunca vira adiável, e `conferir.sql` quebra com
    `violates foreign key constraint` ao inserir dado de teste.

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

Ao acrescentar questão, **reusar um `t` e um `s` que já existam** em vez de
inventar rótulos novos; a árvore só é útil enquanto os níveis se mantêm
poucos. Antes de escrever, ler `METODOLOGIA.md`.

## Matéria, tópico e subtópico

**Matéria é o bloco do edital.** O banco é a união das matérias de **todos**
os concursos cadastrados em `concursos.json`:

| id | nome | questões | tópicos | subtópicos |
|---|---|--:|--:|--:|
| `portugues` | Língua Portuguesa | 109 | 23 | — |
| `sus` | Legislação do SUS | 99 | 10 | — |
| `enfermagem` | Conhecimentos Específicos de Enfermagem | 677 | 19 | 120 |
| `matematica` | Matemática | 39 | 6 | — |

Dentro delas, dois níveis: **tópico** (Imunização, Urgência, Saúde da Mulher)
e **subtópico** (Rede de frio, Calendário vacinal). Português e SUS param no
tópico — os assuntos deles já são específicos o bastante.

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
- `CONCURSO` / `E.concursoAtivo` — apenas o que está **em foco na tela**:
  cabeçalho, contagem regressiva, cartela, simulado, alerta de bloco fraco,
  e **meta diária** (ver "Meta e progresso do dia", abaixo). Trocar o foco
  (`aplicarFoco()`) só repinta; **mudar a lista de inscritos recarrega**,
  porque a união de matérias muda.

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

A meta diária **não é configurável** — é sempre o total de questões da prova
do concurso em foco (`metaDoConcurso()`, somada em `aplicarFoco()`), e só
conta o que pertence a esse concurso:

- `E.diasMateria[dia][materia]` guarda respostas **por matéria** (não por
  bloco: id de bloco é por concurso, guardar por bloco quebraria ao trocar
  o foco).
- `progressoDoDia(k)` agrega esses números nos blocos do foco, cada um
  limitado à própria cota (`bl.questoes`). Matéria fora do foco não conta;
  excedente de um bloco não compensa outro.
- `iniciarSessao("normal")` monta a sessão de estudo respeitando essas
  cotas — não sorteia matéria que depois não vai contar para a meta.
- A **gravação** não filtra pelo foco (`registrar()`/`aplicarEventoRemoto()`
  gravam sempre); o filtro é só na **leitura**, porque quem alterna o foco
  precisa do histórico certo para os dois concursos.
- O gráfico "Cartões estudados" usa a contagem bruta (`E.dias`) de
  propósito: ali a pergunta é "quanto você estudou", não "quanto contou".

## Metodologia dos cartões

O padrão está em `METODOLOGIA.md`: recordação ativa, um fato por cartão,
distratores plausíveis, explicação que ensina, como priorizar sem inventar
dado de incidência que este projeto não tem (não existe base de provas
anteriores da banca — a priorização usa peso do bloco no edital, cobertura
do conteúdo programático e onde a pessoa erra mais).

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
