# Padrão dos cartões — como escrever, revisar e aposentar

Este documento define o padrão do banco. Ele existe porque a qualidade do
estudo é decidida na hora de **escrever** a questão, não na hora de estudá-la:
um cartão mal feito é decorado sem ser entendido, e o Leitner só faz repetir
esse erro em intervalos cada vez maiores.

Vale para questão nova e para reescrita de questão antiga. O `validar.py`
confere a parte mecânica (formato, id, fonte, viés de comprimento); o que está
aqui é o que ele **não** consegue medir sozinho.

---

## 1. Os quatro princípios

### 1.1 Recordação ativa, não reconhecimento

O cartão precisa forçar a pessoa a **produzir** a resposta antes de ver as
alternativas. Se dá para acertar só reconhecendo a alternativa familiar, o
cartão está medindo memória de leitura, não conhecimento.

Na prática: o enunciado sozinho, sem as alternativas, tem que fazer sentido
como pergunta.

- ✅ "Qual é o intervalo mínimo entre a 1ª e a 2ª dose da vacina contra
  hepatite B em adultos?" — dá para responder de cabeça.
- ❌ "Sobre a vacina contra hepatite B, assinale a alternativa correta." — não
  é pergunta nenhuma; a tarefa real só aparece nas alternativas.

### 1.2 Um fato por cartão

Um cartão testa **uma** coisa. Quando ele testa cinco, errar não diz qual das
cinco a pessoa não sabia — e o Leitner devolve o cartão inteiro para a caixa 1,
fazendo repetir os quatro fatos que ela já dominava.

Assunto grande vira **vários cartões pequenos**, não um cartão grande.

- ❌ Um cartão sobre "calendário vacinal da criança".
- ✅ Um cartão por vacina/idade/intervalo que importa.

### 1.3 Distratores plausíveis

O distrator precisa ser uma resposta que alguém daria **por engano de
verdade** — a conduta errada que se vê na prática, o valor parecido, a
confusão clássica entre dois conceitos.

Distrator absurdo não ensina nada e ainda entrega a resposta por eliminação.

- ✅ Para "intervalo entre doses", distratores com outros intervalos reais que
  existem em outras vacinas (é exatamente a confusão que a prova cobra).
- ❌ "Apenas quando o paciente solicitar", "Nunca", "Somente aos domingos".

**Regra prática que já vale no projeto:** ao corrigir uma questão enviesada,
reescreva os *distratores*, nunca encurte a correta. Em boa parte dos casos,
escreva pelo menos um distrator **mais longo** que a alternativa certa.

### 1.4 A explicação ensina, não repete

A explicação existe para o momento em que a pessoa **errou**. Ela precisa dizer
*por que* a correta está certa — e, quando o erro é previsível, por que o
distrator mais tentador está errado.

- ✅ "Metonímia: o continente (enfermaria) aparece no lugar do conteúdo (as
  pessoas que estavam nela)."
- ❌ "A alternativa correta é a letra B."

### 1.4.1 Explicação por alternativa — campo `eo`, opcional

O campo `e` é a explicação da questão como um todo, sempre obrigatório. O
app também aceita um campo opcional, `eo`, que é uma explicação **por
alternativa**: um array com o mesmo tamanho de `o`, cada posição dizendo por
que aquela alternativa específica está certa ou errada. Ao responder, o app
mostra essa nota junto da própria alternativa, destacando uma a uma — não
só embaixo da questão como o `e` já faz.

```json
"o": ["Rifampicina", "Isoniazida", "Etambutol", "Pirazinamida", "Estreptomicina"],
"c": 0,
"eo": [
  "Correta: é a droga usada tanto na profilaxia da meningocócica quanto no esquema da TB — mesmo fármaco, indicações diferentes.",
  "Também trata TB, mas não é a profilaxia padrão para contato de meningocócica.",
  "",
  "",
  ""
]
```

Posição vazia (`""`) é válida e significa "sem nota para esta alternativa"
— não precisa justificar a que é obviamente absurda. O `validar` só reprova
duas coisas: array de tamanho diferente de `o`, e array presente mas vazio
em **todas** as posições (nesse caso é melhor tirar o campo).

**"Sempre que possível", não obrigatório.** Vale o esforço quando o
distrator representa um erro conceitual real (a pessoa que errou vai querer
saber por que pensou certo e escolheu errado) — é o mesmo critério de
plausibilidade da seção 1.3. Não vale a pena para "Apenas quando o paciente
solicitar" ou outro distrator óbvio: aí o `e` sozinho já basta, e forçar uma
nota por posição só encheria o cartão de texto sem ensinar nada a mais.

**Dois casos concretos de "não vale a pena", vindos de uma calibração de 20
cartões (7 Enfermagem, 7 SUS, 6 Matemática):**

- **Fato de memorização pura, sem raciocínio a explicar.** Tabuada
  (`banco/matematica.json`) tem 56 cartões do tipo "quanto é 3×7?", com
  distratores que são só outros números — não há erro conceitual por trás
  de "24" estar errado para "3×7", é só um número diferente de 21. `eo` ali
  vira enchimento repetitivo. Vale para qualquer cartão do mesmo padrão:
  se o distrator não representa um jeito específico de errar o raciocínio,
  não escreva nota nenhuma.
- **Distrator que já narra o próprio erro no texto.** Parte do banco de
  Matemática (ex.: `"36, multiplicando 12 pela soma dos termos da razão"`)
  já inclui a explicação do erro dentro da própria alternativa. `eo`
  duplicaria o que a pessoa já lê ao errar — só vale a pena em alternativas
  "cruas", com números ou termos soltos, sem a razão do erro embutida.

Exemplo real do que vale a pena — vacina BCG (`banco/enfermagem.json`,
id `7d3eda0f1d`), onde cada distrator é a via/local de OUTRA vacina real,
uma confusão que quem estuda comete de verdade:

```json
"o": ["Intramuscular profunda, no músculo vasto lateral da coxa",
      "Subcutânea, no deltoide",
      "Intradérmica, na inserção inferior do deltoide direito",
      "Intradérmica, no antebraço esquerdo",
      "Oral, em duas gotas"],
"c": 2,
"eo": [
  "Errada: essa é a via de outras vacinas do calendário infantil (ex.: pentavalente, hepatite B), não da BCG.",
  "Errada: via subcutânea é usada por outras vacinas (ex.: tríplice viral), não pela BCG, que é intradérmica.",
  "Correta: BCG é intradérmica, na inserção inferior do deltoide direito.",
  "Errada: a via está certa, mas o local está errado — é no deltoide DIREITO, não no antebraço esquerdo.",
  "Errada: essa é a via da vacina de rotavírus, não da BCG."
]
```

Note que cada nota é verificável contra a fonte do próprio cartão — nenhuma
inventa um fato novo, só nomeia de qual outra vacina/situação real vem a
confusão. Quando não dá pra verificar de onde vem um número errado (um
cartão de juros compostos da calibração foi descartado por esse motivo),
**não escreva a nota** — explicação plausível mas não confirmada é pior que
nenhuma (mesmo princípio da regra 11 do `CLAUDE.md`).

As 1244 questões já escritas não precisam ser retrofitadas — regra 9 do
`CLAUDE.md` proíbe script de gravação em lote no banco, e preencher `eo`
retroativamente é trabalho de conteúdo, revisado um cartão de cada vez,
não de automação. `eo` é para cartão novo ou em reescrita. A produção segue
em lotes por matéria — Enfermagem primeiro (maior peso e volume), depois
Português/SUS, depois as menores.

### 1.5 Um fato, um cartão — e só um cartão

O complemento necessário do princípio 1.2. Ali a regra é não juntar cinco
fatos num cartão; aqui é não espalhar **o mesmo fato** por dois. Vale cheia
para **cartão de definição** (`n=1` — "o que é X", "qual é a regra"). Para
**cartão de exercício** (`n≥2` — aplicar uma regra já definida a um caso
novo), existe uma exceção deliberada: ver 1.5.2.

Dois cartões de definição que cobram o mesmo fato não dobram o
aprendizado — competem entre si. É **interferência**: em vez de fixar o
fato, a pessoa passa a decorar a diferença superficial entre as duas
versões ("aquele que começa com 'Segundo a lei...'"), que não vale nada na
prova. E o Leitner agenda os dois, gastando duas revisões para consolidar
uma informação só.

- ✅ "Conduta na dengue grupo A" e "conduta na dengue grupo D" — enunciado
  quase idêntico, fatos diferentes, respostas diferentes. São dois cartões.
- ✅ "Regência do verbo assistir", "de visar", "de aspirar" — a fórmula do
  enunciado se repete de propósito; cada um cobra uma regência distinta.
- ❌ O mesmo intervalo entre doses perguntado uma vez de forma direta e
  outra "segundo o manual do MS". Mesma resposta, mesmo fato: é um cartão.
- ❌ Duas versões do MESMO exercício com os números idênticos e só o rótulo
  trocado (trocar "maçãs" por "laranjas" sem mudar nenhum valor do
  problema). Isso não é uma aplicação nova — é cosmético, e continua
  proibido mesmo em `n≥2` (ver 1.5.2).

Note que **enunciado parecido não é o problema** — fórmula repetida de
enunciado costuma ser bom sinal, não ruim: mantém o formato previsível e
deixa a diferença de conteúdo em evidência. O problema é fato repetido.

### 1.5.1 Por que não existe atalho mecânico aqui

A primeira versão desta seção afirmava um teste rápido: *"se a resposta certa
dos dois cartões é a mesma frase, provavelmente sobra um"*. **Isso está
errado, e a medição no banco mostrou.** Dos 946 cartões, 10 pares dividem a
resposta certa dentro do mesmo tópico — e os 10 são legítimos:

| Par | Resposta comum | Por que são dois cartões |
|---|---|---|
| `sen(30°)` e `cos(60°)` | 1/2 | ângulos complementares, fatos distintos |
| antídoto do organofosforado e droga da bradicardia | Atropina | mesma droga, indicações diferentes |
| profilaxia da meningocócica e efeito adverso na TB | Rifampicina | mesma droga, contextos diferentes |
| área do triângulo e área do trapézio | 30 cm² | coincidência dos números do enunciado |

Resposta igual, portanto, é ruído puro como regra automática. E enunciado
parecido sozinho também não serve, pelo motivo do quadro acima. O que
realmente indica redundância é a **combinação** — enunciado quase idêntico
*somado a* mesma resposta — e ela hoje não acontece nenhuma vez no banco.

É por isso que o `validar` trata redundância como **aviso, nunca erro**:
decidir se dois cartões cobram o mesmo fato é julgamento, e nenhum limiar
substitui a leitura dos dois. O aviso serve para trazer o par até seus olhos,
não para decidir por você.

### 1.5.2 Exercício não é definição

A 1.5 barra repetir **o mesmo fato**. Mas "aplicar uma regra de novo, com
dado diferente" não é repetir o fato — é treinar a aplicação dele, que é
uma habilidade própria, separada de saber a regra. Cartão de definição
("o que é MMC?") e cartão de exercício ("ache o MMC de 18 e 24") medem
coisas diferentes, e quem já sabe a definição pode, ainda assim, errar a
conta.

Por isso, a partir de agora, o teste 1.5 se aplica **cheio a cartão de
definição** (`n=1`, ou o tópico ainda sem nenhum cartão de nível 2+) e **de
forma mais frouxa a cartão de exercício** (`n≥2`): dois exercícios do mesmo
método, com números ou cenário genuinamente diferentes, são dois cartões
legítimos — cada resolução é uma repetição de verdade, não uma decoreba de
qual pergunta é qual.

- ✅ Dois cartões de regra de três direta, um sobre litros de tinta por m²
  de casco pintado, outro sobre horas-homem por container carregado —
  método igual, dado e contexto diferentes. São dois cartões de exercício.
- ✅ Três cartões de comparação de fração (encontrar a maior entre quatro),
  cada um com um conjunto de frações diferente. Mesma habilidade, três
  treinos.
- ❌ Um cartão de definição de MMC e outro perguntando "o que é MMC?" de
  novo com sinônimos. Isso ainda é o 1.5 cheio — dois cartões de definição
  do mesmo fato continuam proibidos.
- ❌ Encher um tópico de exercício até ele passar muito do peso do edital
  (3.2) só porque "ainda cabe mais um". Exercício tem teto — é a saturação
  da seção 3.5, calibrada agora para contar prática como valor real, não
  só fato novo.

Na prática, isso muda o corolário da 3.5 (ver lá) e libera exatamente o
padrão que antes o 1.5 barrava: "o mesmo cálculo com os números trocados"
deixa de ser automaticamente descarte — é descarte quando o tópico já tem
exercício suficiente pro peso que carrega na prova, não porque o método se
repete.

---

## 2. O que não fazer

| Padrão | Por quê |
|---|---|
| "Todas as anteriores" / "Nenhuma das anteriores" | Testa lógica de prova, não conteúdo. E quebra o embaralhamento de alternativas do app. |
| "Assinale a INCORRETA" sem necessidade | Dobra a carga cognitiva sem medir mais conhecimento. Use só quando a própria prova cobra assim. |
| Alternativas do tipo "Apenas I e III" | Vira quebra-cabeça de combinação. Se o assunto tem 4 afirmativas, são 4 cartões. |
| Enunciado que cita formatação ("o trecho **destacado**") | O app mostra texto puro — o `validar.py` já barra isso. |
| Alternativa certa visivelmente mais longa | Deixa acertar sem saber. Já resolvido no banco; não reintroduzir. |
| Pegadinha de leitura ("não é incorreto afirmar que não...") | Mede desatenção, não preparo. |
| Dois cartões de definição com a mesma resposta certa para o mesmo fato | Interferência: gasta duas revisões para fixar uma informação. Ver 1.5. (Exercício aplicando o mesmo método a dado novo é exceção — ver 1.5.2.) |

---

## 3. Prioridade: quantos cartões cada assunto merece

### 3.1 O que temos, e o que não temos

O ideal seria **incidência real**: contar quantas vezes cada assunto caiu nas
provas anteriores da banca e distribuir os cartões proporcionalmente.

**Esse dado não existe neste projeto.** O banco foi escrito a partir de fontes
primárias (manuais do MS, leis, resoluções COFEN, diretrizes AHA), não de
provas passadas. Enquanto ninguém juntar as provas anteriores da FEVRE e do
CIAGA, qualquer número de "incidência" que este documento afirmasse seria
inventado — e pior que não ter prioridade nenhuma, porque pareceria fundamentado.

Então usamos dois sinais **honestos**, que existem hoje:

### 3.2 Sinal 1 — o peso do próprio edital

A composição da prova é dado público e está em `concursos.json`. Para o
concurso de Enfermeiro (003/2026-SMA):

| Bloco | Questões na prova | % da prova | Cartões hoje | % do banco |
|---|--:|--:|--:|--:|
| Conhecimentos Específicos | 50 | 71% | 677 | 72% |
| Língua Portuguesa | 10 | 14% | 127 | 13% |
| Legislação do SUS | 10 | 14% | 103 | 11% |

Português e Matemática (a matéria exclusiva do CAAQ-CDM) ganharam reforço
depois da tabela acima ter sido escrita: Matemática saiu de 24 para 39
cartões (densidade de 2,4 para 3,9 cartões por questão da prova — ainda a
mais rala do banco, mas menos do que antes) e Português, de 99 para 127,
em duas rodadas — a primeira levou de 1 para 2 cartões os tópicos
Ambiguidade, Coerência, Sintaxe, Tipologia textual, Pronomes, Coordenação,
Coordenação e subordinação e Intertextualidade; a segunda levou os mesmos
oito de 2 para 4, mais 1 cartão cada em Colocação pronominal e Reescrita.
SUS ganhou 4 cartões em Controle social (de 1 para 5), o tópico mais raro
do banco até então.

A distribuição atual já está **próxima do peso do edital**. Não há
desequilíbrio grave a corrigir aqui — o que existe são lacunas pontuais
(seção 3.3).

### 3.3 Sinal 2 — cobertura do conteúdo programático

Todo item do conteúdo programático precisa ter pelo menos alguns cartões.
Item do edital com zero cartão é o pior caso possível: a pessoa estuda com
sensação de cobertura completa e chega na prova sem ter visto o assunto.

Conferido contra o edital 003/2026-SMA: nenhum item do conteúdo
programático de Conhecimentos Específicos está mais com zero cartões. As
duas lacunas encontradas na primeira conferência (3.6 Saúde do Homem; 3.18
Feridas, Estomias e Reabilitação) já foram fechadas, 10 e 13 cartões
respectivamente. Ao acrescentar concurso novo, repetir esta conferência —
comparar o Anexo do edital com os tópicos de `banco/<matéria>.json`.

### 3.4 Sinal 3 — onde a pessoa erra

Este o app já calcula: a tela **Estatísticas** ranqueia do assunto mais fraco
para o mais forte, pelo nível mais fino de cada questão. Assunto com acurácia
baixa e poucos cartões merece mais cartões — a pessoa está errando e não tem
material suficiente para consertar.

Este sinal é individual, não serve para decidir o banco inteiro, mas serve
para decidir **o que escrever a seguir** quando o tempo é limitado.

### 3.5 Quando parar: a regra de saturação

Os três sinais acima dizem *onde* escrever. Falta o critério de parada — sem
ele, "faça mais cartões" não tem fim e o banco cresce torto, engordando o
assunto que é fácil de escrever em vez do que precisa.

Um tópico está **saturado** quando todos os fatos que o edital cobra já têm
cartão. Não é número: é cobertura. Na prática, três perguntas resolvem:

1. **Sobrou fato sem cartão?** Se sim, escreva — é o sinal mais forte,
   independente de quantos cartões o tópico já tenha.
2. **O cartão novo passaria no teste 1.5** (fato próprio se for definição;
   dado/cenário genuinamente novo se for exercício — ver 1.5.2)? Se não, o
   tópico está saturado: o que parece lacuna é repetição.
3. **A densidade está muito fora do peso do edital** (seção 3.2)? Se o
   tópico já está acima do peso e os dois testes acima não pediram cartão
   novo, escreva em outro lugar.

Corolário prático: **para definição, é melhor um tópico com 4 cartões
cobrindo 4 fatos do que um com 10 cobrindo os mesmos 4** — quantidade só
conta quando cada unidade carrega fato novo. **Para exercício, quantidade
conta como prática de verdade**, mas ainda tem teto: o peso do edital
(3.2) decide quantos treinos daquele método cabem, não "sobrou mais um
fato pra cobrir".

### 3.6 Sinal 4 — o que o erro coletivo revela sobre o cartão

Os sinais 1 a 3 dizem o que escrever. Este diz o que **consertar**, e é
diferente dos outros porque não fala do assunto: fala do cartão.

Cartão que quase todo mundo erra costuma estar **mal escrito**, não difícil.
Suspeite quando a taxa de erro é muito alta e persiste depois de várias
revisões — as causas de longe mais comuns são:

- **Distrator igualmente defensável.** Existe mais de uma resposta certa, ou
  a "errada" só está errada num detalhe que o enunciado não cobrou.
- **Enunciado ambíguo.** A pessoa entende outra pergunta e responde certo
  para a pergunta errada.
- **Fato desatualizado.** A fonte mudou (protocolo revisado, lei alterada) e
  o cartão ficou para trás — este é o pior caso, porque ensina errado.

A distinção prática: assunto difícil dá erro alto **e disperso** entre vários
cartões do tópico; cartão defeituoso dá erro alto **concentrado** em um só,
enquanto os vizinhos vão bem. O primeiro caso pede mais cartões (seção 3.4);
o segundo pede conserto (seção 5).

---

## 4. Metodologia de revisão

A repetição espaçada já está implementada (Leitner de 5 caixas, intervalos 1,
3, 7 e 14 dias, com teto dinâmico conforme a proximidade da prova). O que este
documento acrescenta é **como escolher a ordem** dentro do que está vencido.

### 4.1 O que já vale

- **Três respostas, não duas.** "Sabia", "Chutei" e "Errei". O botão "Chutei"
  é o que faz o sistema funcionar: acerto por sorte volta para a caixa 1, como
  erro. Marcar "Sabia" no que se chutou é a forma mais rápida de chegar na
  prova achando que domina o que não domina.
- **Teto dinâmico.** Nenhum intervalo passa de ⅓ dos dias restantes até a
  prova; a partir de D-10, tudo vira revisão diária.
- **Cota por área.** A sessão diária respeita a composição da prova (ver
  `progressoDoDia`/`iniciarSessao`): não adianta fechar a meta só na matéria
  preferida.

### 4.2 O que muda agora

Dentro do que está vencido, a ordem passa a considerar, além da caixa:

1. **Caixa** (o que está mais atrasado no Leitner vem primeiro) — já valia.
2. **Taxa de erro da questão** — o que a pessoa erra mais volta antes.
3. **Peso do bloco na prova** — empate resolve pelo que vale mais pontos.

O objetivo é que o tempo escasso vá para o que muda mais a nota, sem quebrar
a lógica do espaçamento (nada é adiantado além do que já venceu).

---

## 5. Manter o que já existe

Escrever cartão novo é metade do trabalho. A outra metade é cuidar dos 900 e
tantos que já estão lá — e ela tem uma restrição técnica que mudar a conduta:
**o `id` é o SHA-1 do enunciado**, e é o que amarra o progresso salvo ao
cartão. Isso divide a manutenção em três casos bem diferentes.

### 5.1 Corrigir sem mexer no enunciado — livre

Alternativa, explicação, fonte, tópico e subtópico podem ser editados à mão,
direto no `banco/<matéria>.json`. O id não muda, o histórico de todo mundo
fica intacto. É o caso mais comum: distrator ruim, explicação que não
ensina, fonte imprecisa.

**Faça isso sempre que der.** Boa parte do que a seção 3.6 aponta como
"cartão defeituoso" se resolve aqui, sem tocar no enunciado.

### 5.2 Corrigir o enunciado — só pela ferramenta

Editar o enunciado à mão **zera o histórico daquele cartão para todo mundo**:
o id passa a ser outro, e o progresso salvo fica órfão, apontando para uma
questão que não existe mais.

Use `reescrever-questoes.ps1`. Ele recalcula o id, grava o par antigo→novo em
`banco/reescritas.json` (que o app aplica no boot, transportando o progresso)
e ainda acerta o `indice-legado.json`. Ver regra 5 do `CLAUDE.md`.

### 5.3 Aposentar — o caso que quase nunca é o certo

Apagar um cartão apaga o histórico dele. Como o banco é versionado e o custo
de manter é quase zero, aposentar só se justifica quando o cartão **ensina
errado e não dá para consertar**:

- Fato que deixou de existir (protocolo revogado, artigo de lei suprimido) e
  não há equivalente atual para o qual reescrever.
- Cartão redundante encontrado depois (teste 1.5): aqui, prefira **fundir** —
  reescrever o que tem mais histórico para cobrir o fato melhor, e aposentar
  o outro.

Na dúvida, **reescreva em vez de apagar**: 5.2 preserva o histórico, e um
cartão corrigido vale mais que um buraco.

---

## 6. Como escrever um lote, na prática

O fluxo abaixo existe porque o anterior — escrever um script por lote, gravar
no banco, rodar o validador e desfazer o que ele reprovasse — falhou de quatro
maneiras diferentes numa sessão só: encoding corrompido (`.ps1` sem BOM),
regra do validador que o script não conhecia, viés descoberto tarde, e uma
checagem caseira **mais fraca** que a de verdade (passava, enquanto o contador
"correta é a mais longa" subia de 228 para 245 no banco inteiro).

A correção não foi checar melhor: foi **parar de gravar antes de validar**.

### 6.1 O ciclo

```
1. escreve em rascunho.json          (só conteúdo: m, t, q, o, c, e, f — sem id)
2. validar.ps1 -Rascunho rascunho.json    (regras REAIS, nada gravado)
3. corrige o que apontar, volta ao 2
4. incorporar-rascunho.ps1           (grava só se o passo 2 passar limpo)
5. validar.ps1 · gerar-offline.ps1 · VERSAO no sw.js · commit
```

O passo 2 é o ponto todo: são as regras do `validar`, não uma cópia delas.
Nunca reimplementar checagem num script de lote — foi exatamente isso que
deixou o viés crescer sem ninguém ver.

### 6.2 Escreva os distratores primeiro

O viés de comprimento não é acidente de digitação: é consequência da ordem.
Escrevendo a correta primeiro, ela sai cuidadosa e longa; os distratores vêm
depois, apressados e curtos — e a resposta certa fica entregue pelo tamanho.

Invertendo, o problema não chega a existir: escreva **os quatro distratores
primeiro**, como condutas que alguém adotaria por engano de verdade, e só
então a correta. Ela nasce do tamanho do grupo em vez de destoar dele.

**Alongar não é anexar a razão da rejeição dentro do distrator.** Descoberto
tarde, numa leva inteira de Inglês: para alongar sem enviesar, cada distrator
ganhou um rótulo da categoria certa e uma cláusula dizendo por que não serve
— "is checking, Present Continuous — usado para ação em curso, não hábito"
para uma pergunta que já dizia "no Simple Present" no enunciado. Some isso a
qualquer rótulo que apareça em outro distrator do mesmo cartão, e dá pra
acertar só por eliminação de palavra-chave, sem ler a frase em inglês nem
saber a regra — o oposto exato do que a recordação ativa (1.1) exige. É a
mesma violação da regra 1.1, só que por um caminho novo, criado tentando
consertar outro problema.

Teste antes de aceitar um distrator alongado: **cobrindo o resto do
cartão, dá pra eliminar essa alternativa só lendo ela?** Se sim — porque
ela nomeia a categoria certa, ou nega com as mesmas palavras do enunciado —
o alongamento vazou a resposta. Alongar é tornar o distrator uma alternativa
completa e plausível por si só (outra lei real, outro valor real, outra
frase que também poderia ser dita), nunca um rótulo seguido do motivo da
rejeição.

### 6.3 Um lote, uma fonte

Prefira "extrair os fatos do art. 1º da Lei 8.142" a "escrever 4 cartões de
Controle social". Partindo da fonte primária, três coisas saem de graça:

- a `fonte` fica correta e igual no lote inteiro;
- "um fato por cartão" (1.2) vira consequência da leitura, não uma regra a
  lembrar;
- a **saturação** (3.5) fica visível: acabaram os fatos do artigo, acabou o
  lote.

### 6.4 Quando o pedido é só "adicione cartões"

Sem tópico indicado, a escolha é automática, não uma pergunta de volta —
perguntar de novo a cada pedido é o próprio desperdício que essa seção existe
para evitar:

1. **Matéria**: a de menor contagem no banco, entre as que algum concurso
   ativo usa e que têm fonte real para consultar (`banco/topicos.json` ou
   conteúdo já estabelecido). Duas exclusões, e as duas são inelegibilidade,
   não fraqueza: matéria **sem fonte** — caso de `psicologia` enquanto não
   sai o edital — fica fora pela regra 11 do `CLAUDE.md`; matéria **sem
   concurso ativo** fica fora pela regra 12, porque ninguém consegue estudá-la
   hoje. A segunda o `validar` reprova sozinho, no rascunho, antes de gravar;
   a primeira depende de julgamento, porque "não existe fonte" é coisa que
   nenhum script sabe conferir. Nenhuma das duas é definitiva: cadastrar o
   concurso em `concursos.json`, ou sair o edital, devolve a matéria à fila. Empate se desfaz por menor cobertura
   proporcional (tópicos com cartão ÷ tópicos totais) — quem tem mais chão
   pela frente vence —, e a matéria escolhida na rodada anterior não se
   repete enquanto houver outra tabela.
2. **Tópico**: dentro dela, o de menor contagem — prioridade para os que
   `topicos.json` já lista com 0 cartão (Sinal 2, cobertura).
3. **Uma fonte só por tópico**, igual à 6.3, e escreve-se até saturar (3.5):
   o tamanho de CADA tópico é o que a fonte sustenta, não um número decidido
   antes de ler.
4. **Um tópico de cada vez — sem misturar dois no meio —, mas não um só por
   pedido.** Depois de saturar um tópico, passa para o próximo mais fraco da
   MESMA matéria (sem pular para outra) e repete, até a leva somar uma
   quantidade que valha o pedido (a referência são uns 20 a 50 cartões,
   variando com o que cada fonte realmente sustenta — nunca um número fixo
   perseguido à custa de encher tópico saturado). "Um de cada vez" limita a
   troca de assunto **dentro** da escrita de um cartão, não o número de
   tópicos que uma leva cobre.

---

## 7. Checklist para escrever um cartão

Antes de dar o cartão por pronto:

- [ ] O enunciado é uma pergunta respondível **sem** ler as alternativas?
- [ ] Testa **um** fato só?
- [ ] **Já existe cartão cobrando este mesmo fato?** (Se a resposta certa
      repete a de outro cartão do tópico, provavelmente sim — ver 1.5. Para
      exercício de nível 2+, a pergunta certa é outra: o dado/cenário é
      genuinamente novo, ou só o rótulo mudou? Ver 1.5.2.)
- [ ] Os 4 distratores são erros que alguém cometeria de verdade?
- [ ] Nenhum "todas as anteriores" / "apenas I e III"?
- [ ] A alternativa certa **não** é a mais longa?
- [ ] A explicação diz *por que*, não *qual*?
- [ ] Tem fonte verificável (lei e artigo, ou manual e capítulo)?
- [ ] O tópico e o subtópico já existem no banco (em vez de rótulo novo)?
- [ ] O tópico ainda **pede** este cartão, ou já está saturado (ver 3.5)?
