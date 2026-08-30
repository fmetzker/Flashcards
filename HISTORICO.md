# Histórico — por que as coisas ficaram assim

**Para que serve:** guardar a narrativa que não cabe no código. Bug que custou
caro para achar, decisão que foi revista, coisa que existiu e foi removida. É
o *como chegamos aqui*.

**Não é regra.** Regra viva mora no `CLAUDE.md`, e é lá que se procura o que
não pode ser quebrado. Aqui é memória: serve para entender por que uma regra
existe, e para não repetir um erro já pago. Se um fato aparecer nos dois, o
`CLAUDE.md` manda.

**Critério do que vem parar aqui.** No código fica o comentário que explica a
linha PRESENTE — "não remova isto, senão vaza RLS", "este número é o mesmo de
`proximaData()`". Vem para cá o que narra o PASSADO — "antes era assim",
"existiu e foi removido porque", "descoberto em setembro". O que só repetia o
que o código já diz não vem: some.

---

## Painel de desempenho

**Três números errados, um de cada vez, todos por confundir perguntas
parecidas.** O painel nasceu em agosto/2026 e os três primeiros bugs foram do
mesmo tipo: dois números certos respondendo a perguntas diferentes, sem nada
dizendo qual valia.

- **336 "cartões estudados" para uma conta com 69 cartões.** A primeira versão
  usou `respostas_total` de `resumo_desempenho`, que conta toda REVISÃO
  repetida do mesmo cartão. "Quantos cartões diferentes" é `estado_cartao`,
  que já é `DISTINCT ON (usuario_id, questao_id)`.
- **95 revisões atrasadas para uma conta cuja tela Estatísticas mostrava 0.**
  `eventos_resposta` é *append-only* e nunca esquece matéria abandonada: um
  cartão de matéria que a conta seguiu há meses ficava "atrasado" para sempre.
  Resolvido com `perfis.materias_ativas`, sincronizado pelo cliente. Conta que
  nunca sincronizou passou a mostrar "–", não 0 — 0 diria "está em dia" quando
  a verdade é "não sei".
- **74 atrasadas numa conta que tinha acabado de zerar o progresso.** O
  `zerar()` limpa o `E` local, mas não tem como apagar o log no servidor. Daí
  `progresso_zerado_em`: o reset virou um MARCO no tempo, e tudo antes dele
  deixa de contar. O log continua inteiro — é corte, não delete.

**O PATCH que apagava o próprio marco.** A correção acima pareceu não
funcionar por um detalhe: `null` num PATCH do PostgREST não é "não mexe", é
**apaga**. Quem zerou antes da versão existir tinha `E.progressoZeradoEm`
vazio, e a sincronização derrubava o marco do servidor a cada chamada —
inclusive um marco posto à mão por SQL, segundos depois de criado. O campo
passou a só entrar no corpo quando há instante de verdade para gravar.

**Lista de matérias apagada por um PATCH com `[]`.** Mesma armadilha do
`progresso_zerado_em: null`, um campo ao lado: `materias_ativas: []` num PATCH
não é "não mexe", é **apaga**. Estado local vazio acontece de verdade — conta
recém-logada ainda na tela de escolher concurso, ou aparelho novo — e o
listener de `online` chama `sincronizar()` de qualquer tela, então bastava a
rede voltar naquele instante para a lista boa do servidor cair. O painel
passava a mostrar "–" em revisões atrasadas, que é como ele diz "não sei o que
essa conta estuda". Hoje lista vazia não é enviada.

**Um script de diagnóstico que mentiu com cara de dado.** Enquanto se
investigava as 95 atrasadas, um script leu `banco/*.json` linha a linha com
`json.loads` — mas os arquivos são ARRAY JSON — e engoliu o erro num
`except: continue`. Reportou "95 de 95 ids ausentes" quando os 95 existiam
todos. A defesa contra id órfão que nasceu daí é correta e ficou; a lição é
outra: script de diagnóstico com `except: continue` inventa resultado.
Confira o total encontrado contra o esperado antes de concluir qualquer coisa.

**PostgREST corta resposta sem avisar.** As consultas do painel não erram
quando passam do teto de linhas — devolvem menos do que existe, caladas.
Perigoso em `estado_cartao`/`eventos_resposta` sem filtro de conta, que somam
o log de todo mundo e crescem sozinhos. Daí `buscarTudo()`, que pagina até a
página vir menor que a pedida, sempre com `order=` explícito: sem ordem
declarada o Postgres não garante a mesma sequência entre duas páginas, e uma
linha some no meio.

---

## Cache e versão

**Um bump de VERSAO derrubava 3,6 MB de banco.** `CACHE` e `CACHE_BANCO`
viviam juntos num nome só, com versão. Como a regra 2 manda subir a `VERSAO` a
cada mudança no `index.html` (~3x/dia neste repositório), o banco inteiro era
rebaixado do zero a cada deploy de CÓDIGO, sem nenhuma questão ter mudado.

**E a separação quebrou dois lugares em silêncio.** Os dois caches começam com
`"prova-enf-"`, e o código que varria `caches.keys()` procurando "o cache do
app" passou a poder pegar o do banco por acaso, mostrando "banco" no lugar da
versão. Isso atrasou o diagnóstico de um bug real no painel, porque a tela não
dizia se o aparelho já tinha o código novo.

**Rede-primeiro, e o furo do "lento".** Até a v14 o service worker era
cache-primeiro, e trocar a `VERSAO` não bastava: o worker velho respondia
antes. Virou rede-primeiro — mas `fetch()` só cai no catch quando a rede
FALHA, nunca quando ela só está LENTA, e o app travava para sempre na tela de
carregando numa internet ruim. Daí o prazo: a rede corre contra um relógio e o
cache assume se ela demorar.

---

## Ordem de aprendizado

**O grafo abria em leque; virou fila.** Até agosto/2026 `requisitos` era o
próprio grafo de dependência de conceito, e "abrir um por vez" só valia entre
os tópicos-raiz — uma cadeia de ordem acrescentada pouco antes, que enfileirava
a largada e deixava o resto da árvore intacto. O relato que abriu o caso foi
"Português libera Classes de palavras e Flexão verbal ao concluir Gramática".
Era verdade, e medido no motor matéria por matéria o problema era maior do que
o relato: Classes de palavras destrava 9 tópicos de Português (5 no mesmo
instante), Anatomia e Fisiologia abria 7 de Enfermagem com 11 cartões
estudados, Aritmética abria 5 de Matemática. O piso era pior que o leque —
Flexão verbal, 51 cartões, dependia de `{Classes de palavras, Verbo}`, e esse
subtópico tem UM cartão de nível 1: um acerto e o tópico inteiro abria, um
cartão depois de Gramática.

A correção não foi no motor. `requisitos` virou uma corrente linear — cada
tópico exige exatamente o anterior — e o grafo de dependência real mudou de
casa para `requisitos_conceituais`, que ninguém lê em tempo de execução. Com
uma corrente, `profundidadeTopico()` devolve 0,1,2,3… e `porDesbloqueio()` já
pintava a tela Matérias na ordem certa: nenhuma linha de `motor.js` ou
`index.html` mudou. O máximo que abre ao mesmo tempo caiu de 7 para 1 nas nove
matérias com fila, e o menor elo do banco inteiro subiu de 1 para 10 cartões.

O grafo não foi apagado porque ele virou a PROVA: `validar.py` confere que a
fila nunca contraria a dependência declarada. Sem isso a fila seria uma lista
de opinião que ninguém consegue auditar depois; com isso, é uma ordem de
ensino que se pode conferir contra o que o próprio arquivo afirma sobre o
conteúdo. Duas matérias (`enfermagem-trabalho`, `maritimo-maquinas`) não têm
grafo nenhum — a fila delas sempre foi ordem de ensino pura, e já dizia isso
por escrito antes da mudança.

**As ondas de subtópico viraram fila junto.** Elas abriam vários irmãos ao
mesmo tempo (Classes de palavras soltava Substantivo, Verbo e Interjeição de
uma vez). Serializar não inventou pedagogia nova: conferido antes de mexer,
não havia no banco inteiro um só tópico com mais de um subtópico que já não
declarasse ordem — a fila só desempata dentro de cada onda, e as ondas
originais ficaram registradas em `requisitos_conceituais_subtopicos`.

**Camadas entre tópicos, removidas.** Existiram rótulos agrupando os tópicos
em "a palavra / a relação entre palavras / o texto". Eram decorativos e
contradiziam o motor: ao dominar Classes de palavras abriam ao mesmo tempo um
tópico de camada 1 e outro de camada 3, porque quem decide o que abre é o
grafo de pré-requisitos. A tela anunciava uma hierarquia que não existia.

**A escada que nunca destravava.** Quando a escada de subtópico nasceu
(agosto/2026), o nível `n` continuou sendo medido pelo TÓPICO inteiro. Isso
somava cartão de nível 1 de todo subtópico — inclusive os ainda fechados, que
são inacessíveis e portanto impossíveis de dominar. O nível 1 do tópico nunca
"vencia", e nível 2 de subtópico NENHUM abria, até a cadeia inteira ser
percorrida. Escalar por subtópico resolveu.

**Análise combinatória abrindo com 1 de 17 subtópicos vistos.** Ela exigia
`{Aritmética, Multiplicação}` — a raiz de uma escada de 8 ondas. Era razoável
quando Aritmética era pequena, e virou desproporcional quando a escada
cresceu. Daí o limite de 2 ondas puladas, hoje conferido pelo `validar.py`. O
limite não é arbitrário: é o maior valor que já existia entre os casos
considerados corretos.

**Multiplicação era um tópico separado.** Virou subtópico de Aritmética, e a
escada da matéria foi reorganizada em volta disso.

**Ordem de exibição por tamanho.** Os subtópicos saíam ordenados por
quantidade de cartões enquanto os tópicos já saíam por profundidade de
desbloqueio. A tela mostrava uma ordem e a escada seguia outra.

---

## Sessão de estudo

**A tabuada saía em ordem — e a revisão também.** Relatado em uso: "em
Multiplicação, a tabuada vem em ordem". Vinha mesmo — 3×2, 3×3, 3×4… —, e
estudar assim deixa responder somando o anterior em vez de lembrar, o oposto
da recordação ativa que o `PADRAO-DOS-CARTOES.md` pede. Cartão novo saía na
ordem do arquivo, e isso estava até documentado como decisão ("`novas` NÃO é
reordenada"). O que ninguém sabia é que a **revisão** saía igual:
`prioridade()` devolve exatamente o mesmo número para todo cartão de mesma
caixa, sem histórico de erro, do mesmo bloco — e `sort` estável devolvia a
ordem do arquivo de volta. A tabuada voltava em sequência nas duas filas.

A correção não precisou de gerador de aleatório: o `id` do cartão já é o
SHA-1 do enunciado truncado (regra 5), ou seja, um valor uniformemente
aleatório e sem relação nenhuma com o conteúdo ou com a posição no arquivo.
Ordenar por `id` É embaralhar, de graça e sem estado. Virou regra geral — *a
ordem do arquivo nunca decide nada* — aplicada nos quatro pontos em que uma
ordem acidental mandava: `novas` e o desempate de `revisar` em `fila()`, e os
modos `"filtro"` e `"erros"` de `montarLoteSessao()` (neste último a ordem
acidental era outra, a de inserção em `E.cartoes`).

Determinístico de propósito: `fila()` roda de novo a cada reabastecimento da
sessão, então `Math.random()` mudaria a ordem no meio dela e nenhum teste
conseguiria travar o comportamento. O simulado continua sorteando de verdade
(`sorteia()`), porque ali cada prova precisa ser diferente.

**A sessão fechava ao fim do lote.** Era uma lista fixa: acabou, voltou para o
Início. Virou contínua em agosto/2026 — reabastece com o mesmo motor e só
termina quando não há mais nada para estudar hoje.

**Revisão adiantada, criada e removida.** Existiu um preenchimento que puxava
cartão ainda não vencido quando a cota do bloco não fechava. Fazia sentido
enquanto a sessão tinha tamanho fixo; com a sessão contínua o problema que ela
resolvia deixou de existir, e estudar antes da hora só enfraquece o
espaçamento. Removida.

**Fila de revisão engolindo a sessão.** Antes de `intercalar()`, revisão e
novas eram concatenadas: um backlog grande consumia a meta inteira e cartão
novo não aparecia enquanto o atrasado não zerasse.

**Cartela de 100 dias.** Havia uma grade 10×10 colorida por meta batida no
lugar da contagem de dias seguidos. Era cara de carregar e pintar e não dizia
nada que a contagem simples não dissesse.

**Acurácia em 7 e 30 dias.** Saiu da tela Estatísticas: diluía rápido demais
para servir de sinal — um mês de acerto quase não se move com um erro isolado.
No lugar entraram as revisões pendentes, que são contagem do que vem por aí,
não média do que passou.

---

## Datas

**`hoje()` usava `toISOString()`**, que é sempre UTC — coincidência, não fuso
correto, e diferente tanto do horário local quanto do de Brasília. O app foi
pensado para funcionar num navio; o dia tem que virar à meia-noite de
Brasília, onde é a prova.

---

## Banco de questões

**Um script de gravação em lote corrompeu o banco.** Por encoding, e passando
por cima de regra que o validador reprova. É a origem da regra 9 do
`CLAUDE.md` — só três scripts escrevem em `banco/*.json`, e todos rodam o
validador de verdade antes.

**Mapear o edital ao pé da letra cortou 67 de 127 questões de Português.** O
mapeamento item-do-edital → tópico-do-banco é interpretação, não transcrição:
os itens são categorias largas. Na dúvida, inclui.

**Perseguir o viés agregado estragou três matérias saudáveis.** Português
estava em 25%, Matemática em 20%, SUS em 12,5% — todas dentro do aceitável.
Uma correção mirando o número do banco inteiro zerou as três. 0% também é
viés: "a mais longa nunca é a correta" elimina uma alternativa de graça. O
alvo é o acaso, ~20%, não o zero.

**O número agregado mente.** Já esteve em 18% — dentro do acaso — com TODA
matéria ativa em 0% e as duas inativas em 59%. Quem estuda vê uma matéria, não
o banco.

---

## Contas e sincronização

**O link de confirmação de cadastro parecia não fazer nada.** O GoTrue não
abre página do Supabase: ele confere o token e redireciona de volta para o app
com a sessão pronta no fragmento da URL. O app ignorava o fragmento inteiro e
mostrava a tela de login comum.

**Ficar sem internet deslogava a conta.** `renovarSessao()` tratava
QUALQUER erro como "a credencial não presta" e apagava a sessão do aparelho —
inclusive falha de rede. Num PWA feito para funcionar offline, abrir o app sem
internet a menos de 5 minutos do token vencer bastava: a pessoa voltava à tela
de login sem entender por quê, e o papel de aprovador sumia junto. Descoberto
em agosto/2026 numa conta real, ao testar justamente o modo offline. Hoje só
4xx do GoTrue desloga; rede e 5xx mantêm a sessão e tentam de novo depois.

**"Sincronizado" mentindo.** O status olhava só se a fila de saída estava
vazia — e puxar eventos não enfileira nada, então uma tentativa que falhou de
ponta a ponta (sem internet) deixava a fila vazia do mesmo jeito e a tela
dizia "sincronizado".

**`materias_ativas` desatualizado por falta de retentativa.** Uma versão
chamava a sincronização à parte, tentava uma vez e desistia em silêncio. Foi o
que causou as 95 atrasadas fantasma. Passou a rodar dentro de `sincronizar()`,
reaproveitando a malha de retentativa que já existia.

---

## Auditoria de código — agosto/2026

**Não havia teste nenhum da conduta do motor.** Leitner, pré-requisitos,
escada de nível, meta e fuso eram verificados à mão, no navegador, uma vez. A
rede de testes (`testar.js`) nasceu daí, e a mutação — quebrar o código de
propósito para ver se o teste acusa — encontrou dois furos nela mesma,
justamente nos dois bugs que mais custaram a achar.

**Dois validadores divergentes.** `validar.py` tinha 76 checagens e
`validar.ps1` 25, e o `.ps1` não conferia `requisitos.json` nem `topicos.json`
de jeito nenhum — enquanto os scripts de gravação gateavam justamente nele.
Virou invólucro.

**`propostas.materia` recusava 7 das 10 matérias.** A coluna nasceu com um
`check` de lista fixa com as três matérias da época; a tela passou a oferecer
todas as dez. Lista fixa em `check` obriga migração de schema para uma coisa
que devia ser só uma linha em `materias.json`.

**`salvar()` engolia falha de gravação.** Cair para memória significa que o
progresso parou de ser persistido — e ninguém ficava sabendo.

**Três colunas mortas em `perfis`.** `concurso` (de quando a conta seguia um
concurso só), `meta` (a meta deixou de ser configurável, e a coluna ainda
contradizia a regra) e `ultimo_backup` (do backup manual por arquivo).
