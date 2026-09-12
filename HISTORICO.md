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
- **8 atrasadas no painel contra 3 na tela Estatísticas da mesma conta —
  o mesmo erro, um nível mais fino.** `zerarMateria()` (o "Apagar progresso
  desta matéria") nasceu só local, de propósito: eu tinha levantado a lacuna
  ao construí-lo e ela foi aceita como risco. O relato de uso veio depois, e
  era exatamente ela. Consertado do mesmo jeito que o reset geral, com
  `materias_zeradas` (`{matéria: instante}`) — a diferença é que aqui o corte
  é por matéria, então evento posterior ao marco volta a contar e o número
  cresce de novo quando a pessoa recomeça aquela matéria.

  **Chegou a ser considerado publicar o número pronto** (o cliente já calcula
  em `revisoesPorDia()`; o painel só exibiria, e a concordância seria exata
  por construção). Descartado: "atrasadas" precisa CRESCER com o tempo mesmo
  sem a pessoa abrir o app — um número publicado congelaria na última
  sincronização e esconderia justamente quem está ficando para trás. Por isso
  o painel continua derivando do log, e o que se dá a ele é a informação que
  faltava, não o resultado.

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

**Fila de revisão engolindo a sessão — e o retorno dela, de propósito.**
Antes de `intercalar()` (criada em 2026), revisão e novas eram concatenadas:
um backlog grande consumia a meta inteira e cartão novo não aparecia
enquanto o atrasado não zerasse. `intercalar()` resolveu espalhando as duas
listas proporcionalmente. Meses depois, voltou a ser pedido exatamente esse
efeito — foco em zerar revisão antes de avançar — e `intercalar()` foi
removida outra vez, desta vez como decisão consciente, não como bug: ver
"Meta e progresso do dia" no `CLAUDE.md`.

**E a primeira versão dessa reversão só valia DENTRO de cada matéria.** O
pedido era "conteúdo novo apenas se não tiver revisão pendente", global; a
implementação concatenava bloco a bloco (`[LP: rev,novo][SUS: rev,novo]…`),
então cartão novo da primeira matéria aparecia antes de revisão pendente da
segunda. A suposição "o corte é por matéria, não global" chegou a ser
escrita no plano e passou batida na aprovação — o relato de uso veio depois:
2 atrasadas, 34 revisões do dia, e cartão novo aparecendo mesmo assim.
Corrigido acumulando revisão e novo em listas separadas e concatenando só no
fim, com as revisões reordenadas por `prioridade()` entre as matérias. A
cota por bloco continua decidindo QUEM entra — mudou só a ordem.

**E essa correção ainda deixava a fronteira do BLOCO valer para revisão —
setembro/2026.** A ordem global (revisão antes de novo) já estava certa; o
defeito era em quem ENTRAVA: cada bloco só trazia revisão até a própria cota
(`falta`), e o excedente — revisão de UMA matéria além da cota dela — não
ficava atrás na fila, ficava de fora do lote inteiro, enquanto um bloco
vizinho com fila de revisão curta preenchia a cota dele com cartão novo à
vontade. Relatado em uso: cartão novo de Português (7/50, revisão
supostamente batida) enquanto ~40 revisões de Português continuavam
atrasadas — a pessoa via conteúdo inédito com a própria matéria em dia só na
aparência. `montarLoteSessao("normal")` passou a somar uma CAPACIDADE DO DIA
só (`Σ falta`, o mesmo número de sempre) e deixar revisão de qualquer bloco
competir por ela inteira antes de cartão novo de qualquer bloco — cartão
novo continua limitado à cota de cada bloco, descontado o que a revisão
daquele bloco específico já tomou. Ver CLAUDE.md, "Meta e progresso do dia".

De quebra, um bug real e independente achado no `reescrever-questoes.ps1`
nessa mesma sessão de trabalho: o rebuild do objeto ao reescrever um cartão
não levava o campo `n` (nível dentro do tópico) — qualquer cartão já
classificado que passasse por reescrita perdia a classificação em silêncio,
mesmo defeito que `eo` já teve um campo acima (regra 5 do CLAUDE.md). Achado
ao reescrever `d9b183b33d` → `afd023d7c0` (cartão que citava "a palavra"
sem trazê-la — formatação de destaque que existia na prova impressa e não
sobrevive à transcrição, mesma classe do `318e2b6619`).

**Cartela de 100 dias.** Havia uma grade 10×10 colorida por meta batida no
lugar da contagem de dias seguidos. Era cara de carregar e pintar e não dizia
nada que a contagem simples não dissesse.

**Acurácia em 7 e 30 dias.** Saiu da tela Estatísticas: diluía rápido demais
para servir de sinal — um mês de acerto quase não se move com um erro isolado.
No lugar entraram as revisões pendentes, que são contagem do que vem por aí,
não média do que passou.

**O teto dinâmico do Leitner — a aceleração de revisão perto da prova.**
Existiu até setembro/2026 e foi removido inteiro. A regra era: nenhum
intervalo passa de ⅓ dos dias restantes até a prova, e a partir de D-10 tudo
vira revisão diária. A ideia parecia óbvia — prova chegando, revisa mais.

O relato veio em 12/09/2026, a oito dias da prova do Enfermeiro/VR: "tem
muitas questões e não daria para estudar tudo". Estava certo, e era pior do
que parecia. Com `d = 8`, o teto era 1 dia **para toda caixa**: caixa 1
("errei ontem") e caixa 8 ("acertei sete vezes seguidas") recebiam a mesma
data. Como `montarLoteSessao()` enche a capacidade do dia com revisão antes de
qualquer cartão novo, e com teto 1 todo cartão já respondido vence todo dia,
bastava ter respondido **51 cartões distintos na vida** para `restante` zerar
e o app parar de mostrar cartão inédito até a prova. O banco do VR tem 1987
cartões; o que não tivesse sido visto até D-10 não seria visto.

O erro de projeto: a regra tratava "falta pouco tempo" como se a solução fosse
mais frequência, quando a restrição real da reta final é **capacidade** — 50
por dia × 8 dias = 400 exposições, e ponto. O teto gastava essas 400
preferencialmente no que a pessoa já sabia e cobrava isso em cartão nunca
visto, que na prova é questão perdida na certa. Comprimir revisão perto do
exame é técnica de quem tem capacidade sobrando; não era o caso.

Foram consideradas três alternativas mais brandas — teto por caixa (comprimir
proporcional ao domínio), reservar cota de cartão novo na reta final, e só
apagar a regra do D-10. A remoção total ganhou porque as três remendam o
sintoma: o que se perde sem teto nenhum é pequeno e dá pra medir. As caixas 1
a 4 (1, 3, 7 e 14 dias) devolvem o cartão dentro de qualquer reta final
sozinhas — quem errou recentemente continua vendo de novo. O que deixa de
voltar é caixa 5+, e para estar na caixa 5 são quatro acertos seguidos ao
longo de no mínimo 11 dias. Como efeito colateral, a alternativa de "reservar
cartão novo" deixou de ser necessária: sem o teto o volume de revisão despenca
sozinho, e a regra *revisão primeiro em TODA a sessão* ficou intacta.

Medido depois, simulando os 8 dias finais contra o banco real do VR (1987
cartões, meta 50/dia, respondendo "sabia" em tudo), em cartões DIFERENTES
alcançados no período:

| histórico ao entrar na reta final | com teto | sem teto |
|---|---|---|
| 800 cartões já estudados | 227 | 227 |
| 400 | 178 | 275 |
| 200 | 131 (0 inéditos) | 256 (57 inéditos) |

Com backlog grande o bastante (800), tanto faz — há fila de caixa baixa
sobrando nos dois casos, e `prioridade()` escolhe os mesmos cartões. A
diferença aparece quando a revisão NÃO satura o dia, que é a situação de
quem ainda não cobriu o edital: aí o teto inventa saturação, repetindo os
mesmos 131 cartões 400 vezes. Inédito foi **zero com teto nos três
cenários**.

Dois ganhos de tabela. O **aviso de backlog** voltou a ser sinal: com o teto,
o atrasado tendia ao total já estudado, então `atrasadas > meta × dias`
acendia por construção a partir de D-10 — um alerta que sempre acende não
avisa nada. E `diasAteMaisProxima()` deixou de ter papel no motor; sobrou
como insumo de tela (contagem regressiva e esse aviso), o que desfez o
acoplamento estranho em que **seguir mais um concurso mudava o ritmo de
revisão de todos os outros**.

O que ficou de dívida: o progresso já gravado tem cartão de caixa alta com
data curta, escrita sob a regra antiga. Não há migração, e não precisa — esses
cartões vencem uma vez mais cedo e daí em diante recebem o intervalo cheio.
É por isso que os baldes de `revisoesPorDia()` contam `prox` e não a caixa
nominal, e o teste que trava isso continua no `testes/motor.js`.

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

**Meta do dia mostrando "224/50" no topo com cada matéria em "0/25" — de
verdade, não caixa registradora do usuário.** Reportado em setembro/2026 por
alguém que não abria o app fazia dois dias. `progressoDoDia()` tem um
fallback documentado — "cai no `E.dias` bruto quando `E.diasMateria[dia]` não
existe" — pensado só para dia LEGADO, anterior ao campo `diasMateria` existir.
O problema: `aplicarEventoRemoto()` e `registrar()` só criavam
`E.diasMateria[dia]` DENTRO do `if(qRemota)`/`if(q0)` — ou seja, só quando a
questão do evento batia com uma matéria carregada no momento. Um pull trazendo
histórico de uma matéria que a conta não segue mais (ex.: trocou de foco,
desseguiu um concurso) incrementava `E.dias[dia]` (correto — é o gráfico bruto
"quanto você estudou", de propósito sem filtro) mas NUNCA criava
`E.diasMateria[dia]`. Se TODOS os eventos de "hoje" fossem dessa matéria
descarregada, `E.diasMateria[hoje]` ficava inteiramente ausente e
`progressoDoDia()` não tinha como distinguir isso de "dia anterior ao recurso
existir" — caía no mesmo fallback, e a meta do topo virava o total bruto do
dia (que não respeita cota de bloco nenhuma), enquanto `progressoPorBloco()`
(usa `E.diasMateria[dia] || {}`, nunca cai em fallback nenhum) mostrava 0 em
cada matéria. Dois números de fontes com premissas diferentes para a mesma
pergunta — a mesma família de bug do painel-vs-estatísticas acima, um nível
mais alto. Correção: as duas funções agora criam `E.diasMateria[dia] = ... ||
{}` incondicionalmente, ANTES de checar se a matéria do evento foi
encontrada — o objeto (mesmo vazio) é o que marca "este dia já é rastreado
pelo sistema novo", e é isso que `progressoDoDia()` precisa para não
confundir "hoje, zero de matéria carregada" com "dia legado, sem o campo".

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
