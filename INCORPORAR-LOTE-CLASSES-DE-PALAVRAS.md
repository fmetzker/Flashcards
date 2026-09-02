# Incorporar o lote de Classes de palavras — passo a passo local

> Nota de sessão, não documentação permanente. Existe só para você aplicar
> com o Claude Code local (ou à mão) o que foi escrito nesta sessão remota,
> que não tem PowerShell para rodar o passo final. **Pode apagar este
> arquivo depois de aplicado** — ele não é um dos quatro arquivos de
> referência do projeto (ver `CLAUDE.md`).

## O que já está pronto

`rascunho.json` tem **75 cartões candidatos** de "Classes de palavras"
(`banco/portugues.json`), escritos em dois lotes, ainda **não gravados no
banco** — só a incorporação local grava de verdade (regra 9 do
`CLAUDE.md`: só os três scripts sancionados escrevem em `banco/*.json`, e
`incorporar-rascunho.ps1` só pode rodar onde há PowerShell).

A técnica pedida: cada cartão vem de uma frase compartilhada com outros
cartões do mesmo lote, cada um destacando uma palavra diferente e
perguntando a classe gramatical dela — 18 frases ao todo, 3 a 6 cartões
por frase. Toda explicação (`e`) reabre com a definição canônica da classe
(a mesma já gravada no cartão de definição `n=1` correspondente) antes de
justificar o caso concreto, e o `eo` nomeia por que os distratores daquela
frase especificamente não se encaixam.

Distribuição por classe (banco atual → depois dos dois lotes):

| Classe | Hoje | Lote 1 | Lote 2 | Depois |
|---|--:|--:|--:|--:|
| Artigo | 3 | +5 | +3 | 11 |
| Interjeição | 2 | +4 | +2 | 8 |
| Verbo | 8 | +4 | +2 | 14 |
| Numeral | 8 | +4 | +3 | 15 |
| Conjunção | 8 | +5 | +3 | 16 |
| Preposição | 10 | +3 | +3 | 16 |
| Pronome | 14 | +5 | +5 | 24 |
| Substantivo | 15 | +5 | +5 | 25 |
| Advérbio | 15 | +4 | +2 | 21 |
| Adjetivo | 16 | +4 | +4 | 24 |

Tópico "Classes de palavras" inteiro: 101 → **176 cartões**.

## Validação já rodada nesta sessão

`python3 validar.py --rascunho` (com os 75 juntos): **"Sem erros. Pode
publicar."**

Conferido explicitamente, não só o "sem erros":

- **Viés de comprimento**: 23.2% → 23.1% no banco inteiro; em Português
  especificamente, 34.5% → 34.5% (nenhuma alternativa nova é a "mais
  longa" com folga — o número não mexeu nadinha, porque toda alternativa
  é só o nome de uma classe, e a posição da correta foi variada de
  propósito).
- **"Redundância provável" (mesmo enunciado + mesma resposta certa)**: o
  banco já tinha 25 pares antes de eu mexer em nada (confirmado rodando
  `validar.py` sem `--rascunho` e comparando a lista, byte a byte). Meus
  75 cartões introduzem **4 pares novos**, e são intencionais, não
  descuido — quatro frases do lote usam a MESMA classe duas vezes de
  propósito, para contrastar dois subtipos dela lado a lado na mesma
  frase:
  - `"Um"` (artigo indefinido) × `"os"` (artigo definido), na frase do
    edital publicado.
  - `"Cada"` (pronome indefinido distributivo) × `"nenhum"` (pronome
    indefinido negativo), na frase dos técnicos.
  - `"Nossa"` (pronome possessivo) × `"alguns"` (pronome indefinido), na
    frase da esquadra — e "Nossa" cruza com o Lote 1, onde a MESMA
    palavra aparece como interjeição ("Nossa! A tripulação concluiu...").
    A explicação de cada cartão já nomeia esse contraste.
  - `"Segundo"` (preposição, "de acordo com") × `"sob"` (preposição, "sob
    controle"), na frase do boletim — e "Segundo" cruza com "segunda" do
    Lote 1 (numeral ordinal, "segunda etapa"), mesma raiz, classe
    diferente por contexto.

  O `validar.py` sinaliza isso como aviso porque "mesma resposta certa"
  sozinho não decide nada (princípio 1.5.1 do `PADRAO-DOS-CARTOES.md`) —
  aqui os dois lados de cada par testam reconhecer um subtipo diferente
  da mesma classe, não o mesmo fato duas vezes. Já veio revisado; não
  precisa reabrir esse julgamento, só saber que o aviso vai aparecer e
  por quê.
- Todos os outros avisos de "enunciados parecidos" (dezenas) são o
  esperado: pares de cartões da MESMA frase, resposta certa diferente —
  é a técnica pedida funcionando, não redundância.

## Passo a passo para gravar de verdade

Rodar na raiz do repositório, localmente (onde há PowerShell):

```powershell
# 1. Confira o que o script faria, sem gravar nada:
.\incorporar-rascunho.ps1 -DryRun

# 2. Se a prévia bater com os 75 cartões esperados, grave:
.\incorporar-rascunho.ps1
# — grava em banco/portugues.json, esvazia rascunho.json.
# Antes de gravar, ele já roda o validador de verdade e falha fechado se
# reprovar (regra 9) — mas como já validamos --rascunho nesta sessão,
# não deve haver surpresa.

# 3. Validador completo, banco já alterado (inclui testar.js):
.\validar.ps1
# Confira que ainda termina em "Sem erros. Pode publicar." e que os
# avisos de redundância batem com os quatro pares intencionais acima
# (mais os 25 que já existiam).

# 4. (Opcional) Só se você usa/distribui o offline.html:
.\gerar-offline.ps1

# 5. Commit — não precisa bump de VERSAO em sw.js (regra 2 só vale para
#    mudança em index.html/motor.js; isso aqui é só banco/portugues.json):
git add banco/portugues.json rascunho.json
git commit -m "Classes de palavras: +75 cartões (mesma frase, palavras diferentes)"
git push
```

Se o `-DryRun` mostrar um número diferente de 75, ou o `validar.ps1` do
passo 3 reprovar, pare e me avise antes de prosseguir — não force o
commit por cima de um validador vermelho.
