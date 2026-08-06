# App de estudo — Concurso Enfermeiro / Volta Redonda

Aplicativo web de questões com repetição espaçada. Prova em **20/09/2026**.
Edital 003/2026-SMA · banca FEVRE · cargo Enfermeiro.

## Estrutura

| Arquivo | Papel |
|---|---|
| `index.html` | App: HTML, CSS e JS. O banco **não** vive mais aqui |
| `concursos.json` | Receitas de prova: data, composição, regra de aprovação |
| `banco/materias.json` | Lista de matérias, na ordem de exibição |
| `banco/<matéria>.json` | Questões daquela matéria, uma por linha |
| `banco/indice-legado.json` | Ids na ordem antiga do array — migra progresso salvo antes da Fase 0 |
| `banco/reescritas.json` | Mapa id antigo→novo de enunciados corrigidos — preserva o histórico |
| `sw.js` | Service worker — faz o app funcionar offline |
| `manifest.json` | Metadados do PWA |
| `icone-192.png`, `icone-512.png`, `apple-touch-icon.png` | Ícones |
| `METODOLOGIA.md` | **O padrão dos cartões** — como escrever, o que não fazer, como priorizar |
| `validar.py` | Verificação de integridade do banco — **rodar sempre antes de publicar** |
| `validar.ps1` | Mesma verificação, para máquinas sem Python |
| `auditar-banco.py` / `.ps1` | Mede o banco contra `METODOLOGIA.md`. Mede, não reprova |
| `reescrever-questoes.ps1` | Corrige enunciado sem perder o progresso de quem já estudou |
| `extrair-banco.ps1` | Ferramenta da Fase 0: extraiu o array `BANCO` do HTML para os JSON |
| `fase1-materias.ps1` | Ferramenta da Fase 1: reagrupou os tópicos em matérias |
| `fase1b-topicos.ps1` | Ferramenta da Fase 1b: subdividiu as matérias em tópicos reais |
| `fase1c-tres-materias.ps1` | Ferramenta da Fase 1c: reduziu as matérias às três do edital |
| `incorporar-propostas.ps1` | Ferramenta da Fase 4c: transforma proposta aprovada em questão de verdade |
| `servidor.ps1` | Servidor local para testar em `http://localhost:8080` |
| `gerar-offline.ps1` | Gera `offline.html`: o app inteiro num arquivo só |
| `offline.html` | **Gerado** — abre com duplo clique, sem servidor e sem rede |
| `supabase/schema.sql` | Fase 3a: tabelas, RLS e allowlist — colar no SQL Editor |
| `supabase/conferir.sql` | Confere o que a RLS **nega**; rodar depois do schema |
| `supabase.json` | URL e chave `anon` do projeto — a chave é pública por design |
| `TUTORIAL-SUPABASE.md` | Configurar conta/sincronização — feito uma vez pelo mantenedor |
| `FASES.md` | Plano de evolução para contas, banco compartilhado e concursos |

Sem build, sem dependências, sem framework. É proposital: o app precisa rodar
no Safari do iPhone sem nenhuma etapa de compilação.

## Regras invioláveis

1. **Nunca usar `localStorage` fora do que já existe.** **A conta é a
   identidade — não existe mais "perfil".** O progresso é chaveado pelo id
   real da conta (o `sub` do token, via `idDoToken()`), não por um id local
   escolhido na tela. É isso que garante que duas pessoas usando o mesmo
   aparelho não misturem progresso, mesmo antes de a sincronização rodar.

   | chave | o quê |
   |---|---|
   | `vr:sessao` | login (uma só: um logado por vez no aparelho) |
   | `vr:conta:<userId>` | o estado (mesmo JSON de sempre) |
   | `vr:fila:<userId>`, `vr:fila-sim:<userId>` | eventos e simulados ainda não confirmados no servidor |
   | `vr:cursor-eventos:<userId>`, `vr:cursor-simulados:<userId>` | até onde o pull já leu |

   `CONTA_ID`, `CHAVE` e `E` são resolvidos **uma vez, no início do script**.
   Por isso entrar e sair recarregam a página em vez de repintar: sem o
   reload, quem acabou de logar seguiria com o `E` vazio de antes do login e
   gravaria por cima do progresso de verdade. Deslogado, `CHAVE` é `null` e
   `salvar()` só guarda em memória.

   Esquemas antigos (`vr:perfis`, `vr:perfil:<id>`, `vr:sessao:<id>`, e a
   chave única pré-Fase 2 `vr-enf-2026`) são **lidos para migrar e nunca
   apagados** — custam alguns KB e são rede de segurança. Ver
   `migrarSessaoDoPerfil()` e `migrarEstadoDoPerfil()`. Não introduzir outra
   chave sem migração.
2. **Ao alterar `index.html`, incrementar `VERSAO` em `sw.js`.** Formato:
   `v13-852q-materias` → `v14-...`. Desde a v14 o service worker é
   **rede-primeiro**, com o cache só como reserva para quando não há internet —
   antes era o contrário, e o aparelho continuava servindo a versão antiga
   mesmo depois de publicar. Não voltar para cache-primeiro: foi a causa de
   duas rodadas de depuração em que a mudança simplesmente não aparecia.
3. **Rodar `validar.py` (ou `validar.ps1`) antes de qualquer commit.** Falha se
   houver questão malformada, duplicada ou com viés estatístico piorando.
4. **Não adicionar dependências externas nem CDN.**
5. **O `id` da questão é o SHA-1 do enunciado**, truncado em 10 hexadecimais,
   e é o que amarra o progresso salvo à questão. O validador confere que
   `id == sha1(q)`. Corrigir alternativas, explicação e fonte é livre — não
   mexe no id.

   **Para mudar um enunciado, use `reescrever-questoes.ps1`.** Ele recalcula o
   id e grava o par antigo→novo em `banco/reescritas.json`, que
   `migrarReescritas()` aplica no boot para transportar o progresso (e o
   script ainda acerta o `indice-legado.json`, que apontaria para um id
   inexistente). Editar o enunciado à mão **zera o histórico daquele cartão
   para todo mundo** — foi o que tornava proibitivo consertar questão ruim,
   e é o problema que esse caminho resolve.
6. **Arquivos `.ps1` com acento precisam de UTF-8 COM BOM.** Sem BOM, o Windows
   PowerShell 5.1 os lê como ANSI e o parser quebra com erro de chave faltando.
7. **A chave `service_role` do Supabase nunca entra no repositório.** Ela
   ignora toda a RLS. A chave `anon` é pública por design e pode ficar no
   cliente. As duas são JWT, começam iguais e ficam lado a lado no painel —
   `validar.ps1` decodifica e barra a errada.
8. **Nomes de classe CSS genéricos (`.vazio`, `.card`, `.stat`...) combinam com
   qualquer elemento que os use, mesmo junto de outra classe.** `.vazio` é a
   classe de "tela sem dados ainda" (`padding:40px 20px`); a cartela chegou a
   usar `class="dia vazio"` para dias passados, e herdou esse padding — os
   quadradinhos viravam retângulos de 82×42 em vez de 40×40. Ao nomear uma
   classe de estado (vazio, cheio, ativo...), checar se o nome já existe em
   outro contexto antes de reusar.

## Formato do banco de questões

Arquivos `banco/<matéria>.json`, um objeto por linha (mantém o diff pequeno):

```json
{"id":"a1b2c3d4e5","m":"enfermagem","t":"Imunização","s":"Rede de frio","q":"enunciado","o":["A","B","C","D","E"],"c":1,"e":"explicação","f":"fonte"}
```

- `id` — SHA-1 do enunciado, 10 hexadecimais. Ver regra 5.
- `m` — matéria; precisa existir em `banco/materias.json` e bater com o arquivo
- `t` — tópico, o assunto dentro da matéria
- `s` — subtópico, o detalhe dentro do tópico. **Opcional**: Português e SUS não
  usam, porque os tópicos deles já são o nível certo. Quando existe, não pode
  repetir o nome do tópico — o validador barra
- `c` — índice da correta, 0 a 4
- `f` — **obrigatório**: lei e artigo, ou manual e capítulo. Questão sem fonte não entra.

Ao acrescentar questão, **reusar um `t` e um `s` que já existam** em vez de
inventar rótulos novos; a árvore só é útil enquanto os níveis se mantêm poucos.

## Matéria, tópico e subtópico

**Matéria é o bloco do edital.** Eram três, e só três, enquanto só havia um
concurso (o vestibular de enfermeiro). Com o suporte a múltiplos concursos, o
banco é a união das matérias de **todos** os concursos cadastrados em
`concursos.json` — hoje quatro, porque o CAAQ-CDM (Marinha) acrescentou
`matematica`:

| id | nome | questões | tópicos | subtópicos |
|---|---|--:|--:|--:|
| `portugues` | Língua Portuguesa | 99 | 23 | — |
| `sus` | Legislação do SUS | 99 | 10 | — |
| `enfermagem` | Conhecimentos Específicos de Enfermagem | 654 | 17 | 114 |
| `matematica` | Matemática | 24 | 6 | — |

Dentro delas, dois níveis: **tópico** (Imunização, Urgência, Saúde da Mulher) e
**subtópico** (Rede de frio, Calendário vacinal). Português e SUS param no
tópico — os assuntos deles já são específicos o bastante.

**O concurso é uma receita** em `concursos.json`: cargo, órgão, banca, data,
duração, blocos (nome, quantas questões, quais matérias) e regra de aprovação.
Acrescentar um concurso é editar esse arquivo — não exige mexer no código. Uma
matéria não pode aparecer em dois blocos do mesmo concurso; o validador barra.

**Uma conta pode seguir mais de um concurso ao mesmo tempo.** Duas noções que
não podem ser confundidas — é o erro fácil de cometer ao mexer nesta parte:

- `INSCRITOS` / `E.concursos` — todos os que a conta estuda. Definem o
  **banco carregado** (união das matérias de todos, via `materiasInscritas()`)
  e o **teto do Leitner**, que usa `diasAteMaisProxima()`: seguir um concurso
  distante não pode afrouxar a revisão por causa de outro que é semana que
  vem.
- `CONCURSO` / `E.concursoAtivo` — apenas o que está **em foco na tela**:
  cabeçalho, contagem regressiva (`diasAte()`), cartela, simulado e alerta de
  bloco fraco. Trocar o foco (`aplicarFoco()`) só repinta; **mudar a lista de
  inscritos recarrega**, porque a união de matérias muda.

Estados de antes desta versão guardavam `E.concurso` (singular);
`carregarConfig()` migra para lista na primeira execução, sem perder a escolha.

Consequência assumida desta modelagem: como "Conhecimentos Específicos de
Enfermagem" é uma matéria só, o compartilhamento do acervo de enfermagem vale
entre concursos **de enfermagem**. Português e Legislação do SUS, que são as que
caem em quase toda prova da área da saúde, continuam compartilháveis com
qualquer cargo.

A tela **Matérias** mostra a árvore inteira, inclusive o que ainda não foi
visto, e permite estudar qualquer um dos três níveis isoladamente. A tela
**Estatísticas** tem outro papel: ranquear do mais fraco para o mais forte, pelo
nível mais fino de cada questão, considerando só o que já foi respondido. Não
duplicar uma na outra.

## Rodar localmente

Duas formas, para usos diferentes.

**Servidor local** — é a que reflete o app publicado (service worker, PWA,
arquivos separados). Use esta para desenvolver:

```
powershell -ExecutionPolicy Bypass -File servidor.ps1
```

e abra `http://localhost:8080`. Abrir o `index.html` direto do disco **não**
funciona: o banco é lido por `fetch`, que o navegador bloqueia em `file://`.

**Arquivo único** — para testar sem servidor, num aparelho sem nada instalado,
ou para mandar por e-mail:

```
powershell -ExecutionPolicy Bypass -File gerar-offline.ps1
```

Gera `offline.html` (~578 KB) com o banco embutido em `window.DADOS`, de onde a
função `pega()` lê sem requisição nenhuma. Abre com duplo clique, salva
progresso no `localStorage` normalmente e não toca a rede.

É um **artefato gerado**: não editar à mão, e refazer depois de mexer no
`index.html` ou no banco. O validador avisa quando está para trás.

Se o carregamento falhar, o app mostra uma tela explicando em vez de ficar em
branco.

Composição da prova real: 10 Português + 10 SUS + 50 Específicos = 70 questões.
Aprovação: 35 pontos **e** nenhuma área zerada.

## Estado atual e trabalho pendente

Banco com **899 questões** (99 lp, 99 sus, 677 esp, 24 matemática).

**Fases 0 a 4c concluídas**, mais o suporte a múltiplos concursos por conta. O
projeto migrou de app de prova única para plataforma com contas, banco
compartilhado por matéria e concurso escolhido por cada pessoa. O plano
completo está em `FASES.md`. A Fase 0 deu id estável a cada questão, tirou o
banco do `index.html` e converteu o progresso de índice de array para id; a
Fase 1 reagrupou os 85 tópicos em matérias e transformou o concurso em dado; a
Fase 1b subdividiu essas matérias em tópicos reais; a Fase 1c reduziu as
matérias às três do edital, virando uma árvore de três níveis; a Fase 2 deu
suporte a múltiplos perfis no mesmo aparelho; a Fase 3a criou o schema do
Supabase (RLS, allowlist, log append-only); a Fase 3b deu login por e-mail e
senha; a Fase 3c deu o motor de
sincronização — fila local, push idempotente, pull incremental com merge por
evento mais recente; a Fase 4a deu o formulário de proposta de questão; a Fase
4b deu a tela de revisão (aprovar/rejeitar); a Fase 4c fechou o ciclo com
`incorporar-propostas.ps1`, que grava a proposta aprovada em
`banco/<matéria>.json` — commit e `validar.py` continuam manuais depois. O
banco em si continua estático o tempo todo: a proposta nunca escreve direto
nele. Depois disso, a conta ganhou suporte a mais de um concurso ao mesmo
tempo, com um em foco e os demais só inscritos.

**Login passou a ser obrigatório para entrar no app** (antes era opcional).
Sem sessão válida no aparelho, o boot mostra uma tela de entrar/criar conta
em vez da tela inicial — ver `pintarLogin()`/`exigeLogin()` em `index.html`.
Isso não vale para o `offline.html`, que nunca fala com o servidor e continua
funcionando sem conta, de propósito.

**O cadastro é aberto, e o controle virou aprovação depois do cadastro.** O
gatilho `exigir_convite` está **desligado** (a tabela `convidados` continua
de pé, sem uso, caso se queira voltar ao modelo fechado). Agora qualquer
pessoa cria conta, ela nasce `pendente` e **não enxerga nada** até um
aprovador liberar:

- Quem barra é a **RLS**, não a tela: `eventos_resposta`, `simulados` e
  `propostas` exigem `conta_aprovada()` nas policies. Esconder o botão no app
  não protegeria nada.
- `perfis` é a exceção deliberada: a pessoa **precisa** ler a própria linha
  mesmo pendente, senão o app não teria como saber que está esperando.
- Ninguém se auto-aprova: `status` mora na mesma linha que nome e meta, que a
  pessoa pode editar, então quem separa as duas coisas é o gatilho
  `proteger_status_perfil` — que também assina `aprovado_por` com
  `auth.uid()` do servidor e congela o `email` (é por ele que o aprovador
  reconhece quem está na fila).
- `aprovadores` + `sou_aprovador()` seguem o mesmo padrão de
  `revisores`/`sou_revisor()`: tabela ilegível, function `security definer`
  devolvendo só booleano.
- **É obrigatório rodar a seção 11 do `schema.sql`** para virar aprovador.
  Sem nenhum aprovador cadastrado, toda conta nova fica presa em `pendente`
  para sempre.
- No app: `verificarSituacao()` → `exigeAprovacao()` → tela de espera
  (`pintarEspera()`); a tela de aprovação é `pintarAprovar()`. `SITUACAO`
  nulo (servidor não respondeu) **não** conta como pendente de propósito —
  ficar offline não pode trancar quem já usava o app, e a RLS nega os dados
  de qualquer jeito.

**Depois de aprovada, a conta ainda passa por uma escolha de concurso na
primeira vez.** `carregarConfig()` deixa `E.concursos` vazio de propósito
quando não há nada escolhido ainda (nem o formato antigo `E.concurso`, nem
uma lista válida) — em vez de cair sozinho no primeiro item de
`concursos.json`. Com `E.concursos` vazio, `INSCRITOS` também fica vazio e
`carregarBanco()` roda sem buscar nenhum arquivo de matéria; o boot então
mostra `tela-escolher-concurso` (`exigeEscolherConcurso()`/
`pintarEscolherConcurso()`) em vez da tela inicial. Confirmar a escolha salva
e **recarrega a página** — mesmo padrão de `alternarConcurso()` — para que
`carregarBanco()` rode de novo, agora buscando as matérias certas. Se só
existe um concurso cadastrado no arquivo inteiro, não há o que escolher e a
tela é pulada.

**O conceito de perfil local foi removido** logo depois: com login
obrigatório, a conta já era a identidade, e o id local (`p1`, `p2`...) só
criava a chance de duas pessoas compartilharem a mesma gaveta de progresso no
mesmo aparelho. Ver a regra 1 para o esquema de chaves atual e as migrações.

Projeto Supabase real criado, `supabase.json` preenchido, e o `schema.sql`
inteiro (Fases 3a a 4c: RLS, allowlist, `propostas`/`revisores`,
`sou_revisor`, `marcar_revisor`, `incorporada_em`) confirmado contra o projeto
— `conferir.sql` roda sem nenhum `FALHOU` nem `WARNING`. Sem o `supabase.json`
preenchido, a conta fica indisponível e o app funciona exatamente como na
Fase 2.

**A meta diária vale só para o concurso em foco, e por área.** Antes, qualquer
questão respondida enchia a meta — quem segue dois concursos batia a meta do
concurso de Enfermeiro estudando só Matemática, que nem cai nele. Agora:

- `E.diasMateria[dia][materia]` guarda as respostas **por matéria**. Chaveado
  por matéria e não por bloco de propósito: id de bloco é por concurso (`lp`
  num, `port` noutro), então guardar por bloco quebraria ao trocar o foco.
- `progressoDoDia(k)` agrega esses números nos blocos do concurso **em foco**,
  cada um limitado à sua cota (`bl.questoes`). Matéria fora do foco não conta;
  excedente de um bloco não compensa outro. É isso que faz a meta só fechar
  quando todas as áreas foram estudadas.
- `iniciarSessao("normal")` monta a sessão respeitando essas cotas — antes
  sorteava do banco inteiro e mandava estudar matéria que depois não contava.
- A gravação **não** filtra pelo foco (`registrar()` e `aplicarEventoRemoto()`
  gravam sempre): quem alterna o foco precisa do histórico certo para os dois
  concursos. O filtro é na leitura.
- O gráfico "Cartões estudados" segue usando a contagem **bruta** (`E.dias`),
  de propósito: ali a pergunta é "quanto você estudou", e estudar matéria de
  outro concurso é esforço real.
- Dias anteriores a esta versão não têm `diasMateria` e caem no `dias` bruto —
  mesmo tratamento de `diasTotal`/`diasCertas`.

**Navegação por abas.** Barra fixa no rodapé com quatro destinos (Hoje,
Matérias, Estatísticas, Ajustes). A tela inicial ficou só com o que é do
**dia** (meta, cartela, sequência); os gráficos e o card "Banco" foram para
Estatísticas. `SEM_NAV` lista as telas que escondem a barra: as de foco
(estudo, simulado) e as de portão (login, espera, escolher concurso), onde
navegar para o lado é justamente o que não pode.

**Reportar problema numa questão** (Bloco A do plano de melhorias):
tabela `reportes` reaproveita os mesmos `revisores`/`sou_revisor()` de
`propostas` — julgar se uma questão está certa é o mesmo tipo de trabalho,
não precisou de um papel novo. Botão na tela de estudo (`reportarProblema()`,
visível só com conta), tela "Reportes de questões" pro revisor
(`pintarReportes()`/`decidirReporte()`). Ainda **não confirmado** contra o
projeto real — rodar `schema.sql`/`conferir.sql` antes de usar.

**Viés de comprimento — resolvido.** A resposta certa costumava ser visivelmente
mais longa que os distratores, o que permitia acertar sem saber o conteúdo. Foram
reescritas 564 questões ao todo: 150 nos dois primeiros passes e outras 414 no
terceiro (todas as 299 com folga acima de 20 caracteres e as 115 da faixa 11–20).

| Métrica | Original | 2º passe | Agora | Alvo |
|---|---|---|---|---|
| Correta é a mais longa | 80,2% | 69,1% | 26,8% | ~20% |
| Excede a 2ª maior em +40 caracteres | 228 | 79 | 0 | 0 |
| Excede em +20 caracteres | 379 | 299 | 0 | < 100 |

Diferenças de 1 a 10 caracteres são ruído, não pista — não vale gastar esforço nelas.
As 228 questões que ainda têm a correta como mais longa estão **todas** nessa faixa
de ruído; é por isso que o indicador parou em 26,8% e não em 20%. Fechar essa
diferença exigiria mexer justamente nas folgas de 1 a 10 caracteres.

O que importa de verdade é se dá para acertar chutando na alternativa mais longa.
Considerando "visivelmente mais longa" como exceder a segunda em mais de 10 caracteres:

| | Original | Agora |
|---|---|---|
| Questões em que a pista existe | 436 (51,2%) | 56 (6,6%) |
| Acerto ao chutar na mais longa | 95,0% | 0,0% |
| Fração do banco entregue de graça | 48,6% | 0,0% |

Resíduo conhecido: naquelas 56 questões a mais longa é sempre um distrator, o que
em tese premia quem *evita* a mais longa. O ganho é desprezível (6,6% do banco,
de 20% para 25% de chance) e some ao equilibrar essas 56 num próximo passe.

**Como corrigir uma questão enviesada:** reescrever os *distratores*, não encurtar
a resposta certa. Distratores devem ser condutas plausíveis que alguém adotaria
por engano — não frases curtas do tipo "Apenas X" ou "Somente Y". Em boa parte
dos casos, escrever pelo menos um distrator **mais longo** que a correta.

Fluxo recomendado: gerar o JSON do banco, editar estruturalmente, regravar o
array em `index.html`. Ver `equilibra2.py` como modelo — ele carrega o JSON,
aplica um dicionário `{índice: (novas_opções, novo_índice_correto)}` e regrava.

Nas máquinas sem Python e sem Node, `validar.py` e `equilibra2.py` não rodam. O
terceiro passe foi feito com scripts equivalentes em GDScript, executados pelo
Godot em modo headless (extrair banco → aplicar patch JSON → medir → validar).

**Viés de letra — resolvido.** As alternativas são embaralhadas em tempo de
execução (`embaralhaOrdem`), no estudo e no simulado. Não reintroduzir ordem fixa.

## Metodologia dos cartões

O padrão está em **`METODOLOGIA.md`**: recordação ativa, um fato por cartão,
distratores plausíveis, explicação que ensina. Ler antes de escrever ou
reescrever questão.

`auditar-banco.ps1` mede o banco contra esse padrão — e, diferente do
`validar.ps1`, **não reprova nada**: qualidade é gradiente, não regra. A saída
serve para escolher o que corrigir primeiro.

Estado da última auditoria: **92,8% das questões sem nenhum apontamento**. O
banco já estava em boa forma, o que descartou a ideia inicial de reescrever
tudo — reescrever 876 questões teria custo alto e ganho perto de zero. Foram
corrigidas as 6 que tinham enunciado não respondível sem as alternativas.

Restam, sem urgência: 48 casos de distrator curto demais (gravidade média) e
3 de explicação curta sem raciocínio explícito.

**Prioridade de conteúdo é declarada, não inventada.** Não existe dado de
incidência de provas anteriores neste projeto — o banco veio de fontes
primárias (manuais, leis), não de provas passadas. Enquanto ninguém juntar as
provas da FEVRE/CIAGA, a priorização usa três sinais honestos: peso do bloco
no edital, cobertura do conteúdo programático e onde a pessoa erra mais.

## Motor de repetição espaçada

Leitner de 5 caixas, intervalos 1, 3, 7 e 14 dias, com **teto dinâmico**: nenhum
intervalo pode passar de ⅓ dos dias restantes até a prova, e a partir de D-10
tudo vira revisão diária. Ver `proximaData()`.

Três respostas possíveis: "Sabia" sobe uma caixa; "Chutei" e "Errei" voltam para
a caixa 1. O botão "Chutei" é central — não removê-lo nem transformá-lo em acerto.

**A ordem dentro do que já venceu** é decidida por `prioridade()`: caixa, taxa
de erro da questão e peso do bloco na prova. Os pesos (0.6 e 0.3) são
calibrados para o desconto somado ficar **abaixo de 1**, isto é, abaixo da
distância entre duas caixas — erro e peso ordenam *dentro* da caixa e nunca
atravessam a fronteira dela. Caixa 1 quer dizer "errei na revisão mais
recente", que é o sinal mais forte que existe; nada pode passar na frente.
Isso não adianta revisão nenhuma: o espaçamento continua mandando em *quando*
o cartão volta.

**O dia sempre vira no fuso de Brasília, nunca no fuso do aparelho.** `hoje()`
usa `Intl.DateTimeFormat` com `timeZone:"America/Sao_Paulo"` fixo — não um
offset `-3` na unha, que quebraria se o Brasil reintroduzisse horário de
verão. Qualquer soma ou comparação de data usa `diaUTC()`/`somarDias()`, nunca
`new Date()` puro nem `.setDate()`: misturar hora local do aparelho com
formatação UTC no meio do cálculo foi exatamente o bug que existia antes desta
regra (o dia virava errado dependendo de onde o aparelho estava, inclusive
num navio). O merge de eventos de outro aparelho (`aplicarEventoRemoto`) usa a
mesma formatação de fuso ao decidir em qual dia contar a resposta.

Acurácia por período (hoje/7 dias/30 dias) soma `E.diasCertas`/`E.diasTotal`
numa janela — campos paralelos a `E.dias` (que só conta quantidade), criados
de propósito para não fazer dias de antes desta métrica aparecerem como 0%.

## Publicação

Netlify (arrastar a pasta) ou GitHub Pages (git push + Settings → Pages).
Precisa ir junto: os 6 arquivos originais, `concursos.json`, `supabase.json` e a
pasta `banco/` inteira — sem ela o app cai na tela de erro de boot. Detalhes em
`TUTORIAL.md`. Configurar conta e sincronização (uma vez só, feito pelo
mantenedor) está em `TUTORIAL-SUPABASE.md`.
