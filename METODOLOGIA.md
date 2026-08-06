# Metodologia — como escrever e revisar os cartões

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
| Conhecimentos Específicos | 50 | 71% | 677 | 73% |
| Língua Portuguesa | 10 | 14% | 109 | 12% |
| Legislação do SUS | 10 | 14% | 99 | 11% |

Português e Matemática (a matéria exclusiva do CAAQ-CDM) ganharam reforço
depois da tabela acima ter sido escrita: Matemática saiu de 24 para 39
cartões (densidade de 2,4 para 3,9 cartões por questão da prova — ainda a
mais rala do banco, mas menos do que antes) e Português, de 99 para 109,
focado nos tópicos que tinham só 1 cartão (Ambiguidade, Coerência, Sintaxe,
Tipologia textual, Pronomes, Coordenação, Coordenação e subordinação,
Intertextualidade).

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

## 5. Checklist para escrever um cartão

Antes de dar o cartão por pronto:

- [ ] O enunciado é uma pergunta respondível **sem** ler as alternativas?
- [ ] Testa **um** fato só?
- [ ] Os 4 distratores são erros que alguém cometeria de verdade?
- [ ] Nenhum "todas as anteriores" / "apenas I e III"?
- [ ] A alternativa certa **não** é a mais longa?
- [ ] A explicação diz *por que*, não *qual*?
- [ ] Tem fonte verificável (lei e artigo, ou manual e capítulo)?
- [ ] O tópico e o subtópico já existem no banco (em vez de rótulo novo)?
