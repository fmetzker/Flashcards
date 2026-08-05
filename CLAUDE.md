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
| `sw.js` | Service worker — faz o app funcionar offline |
| `manifest.json` | Metadados do PWA |
| `icone-192.png`, `icone-512.png`, `apple-touch-icon.png` | Ícones |
| `validar.py` | Verificação de integridade do banco — **rodar sempre antes de publicar** |
| `validar.ps1` | Mesma verificação, para máquinas sem Python |
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

1. **Nunca usar `localStorage` fora do que já existe.** Desde a Fase 2 há
   múltiplos perfis: `vr:perfis` guarda o índice (`{atual, lista:[{id,nome}]}`)
   e cada perfil vive em `vr:perfil:<id>`, mesmo formato de estado de sempre.
   A chave única de antes, `vr-enf-2026`, continua no aparelho como rede de
   segurança — não é apagada — e é migrada para o perfil `p1` na primeira
   execução desta versão. Fallback em memória por perfil. Desde a Fase 3, cada
   perfil também tem `vr:sessao:<id>` (login), `vr:fila:<id>` e
   `vr:fila-sim:<id>` (eventos e simulados ainda não confirmados no servidor),
   `vr:cursor-eventos:<id>` e `vr:cursor-simulados:<id>` (até onde o pull já
   leu). Não introduzir outra chave sem migração.
2. **Ao alterar `index.html`, incrementar `VERSAO` em `sw.js`.** Formato:
   `v13-852q-materias` → `v14-...`. Desde a v14 o service worker é
   **rede-primeiro**, com o cache só como reserva para quando não há internet —
   antes era o contrário, e o aparelho continuava servindo a versão antiga
   mesmo depois de publicar. Não voltar para cache-primeiro: foi a causa de
   duas rodadas de depuração em que a mudança simplesmente não aparecia.
3. **Rodar `validar.py` (ou `validar.ps1`) antes de qualquer commit.** Falha se
   houver questão malformada, duplicada ou com viés estatístico piorando.
4. **Não adicionar dependências externas nem CDN.**
5. **O `id` da questão nunca muda.** Ele é o SHA-1 do enunciado truncado em 10
   hexadecimais, e é o que amarra o progresso salvo à questão. Mudar o
   enunciado muda o id e **zera o histórico daquela questão** para todo mundo —
   corrija alternativas e explicação à vontade, mas pense duas vezes antes de
   mexer no enunciado. O validador confere que `id == sha1(q)`.
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

**Um perfil pode seguir mais de um concurso ao mesmo tempo.** Duas noções que
não podem ser confundidas — é o erro fácil de cometer ao mexer nesta parte:

- `INSCRITOS` / `E.concursos` — todos os que o perfil estuda. Definem o
  **banco carregado** (união das matérias de todos, via `materiasInscritas()`)
  e o **teto do Leitner**, que usa `diasAteMaisProxima()`: seguir um concurso
  distante não pode afrouxar a revisão por causa de outro que é semana que
  vem.
- `CONCURSO` / `E.concursoAtivo` — apenas o que está **em foco na tela**:
  cabeçalho, contagem regressiva (`diasAte()`), cartela, simulado e alerta de
  bloco fraco. Trocar o foco (`aplicarFoco()`) só repinta; **mudar a lista de
  inscritos recarrega**, porque a união de matérias muda.

Perfis de antes desta versão guardavam `E.concurso` (singular); `carregarConfig()`
migra para lista na primeira execução, sem perder a escolha.

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

Banco com **876 questões** (99 lp, 99 sus, 654 esp, 24 matemática).

**Fases 0 a 4c concluídas**, mais o suporte a múltiplos concursos por perfil. O
projeto migrou de app de prova única para plataforma com contas, banco
compartilhado por matéria e concurso escolhido por cada pessoa. O plano
completo está em `FASES.md`. A Fase 0 deu id estável a cada questão, tirou o
banco do `index.html` e converteu o progresso de índice de array para id; a
Fase 1 reagrupou os 85 tópicos em matérias e transformou o concurso em dado; a
Fase 1b subdividiu essas matérias em tópicos reais; a Fase 1c reduziu as
matérias às três do edital, virando uma árvore de três níveis; a Fase 2 deu
suporte a múltiplos perfis no mesmo aparelho; a Fase 3a criou o schema do
Supabase (RLS, allowlist, log append-only); a Fase 3b deu login opcional por
e-mail e senha, com sessão presa ao perfil local; a Fase 3c deu o motor de
sincronização — fila local, push idempotente, pull incremental com merge por
evento mais recente; a Fase 4a deu o formulário de proposta de questão; a Fase
4b deu a tela de revisão (aprovar/rejeitar); a Fase 4c fechou o ciclo com
`incorporar-propostas.ps1`, que grava a proposta aprovada em
`banco/<matéria>.json` — commit e `validar.py` continuam manuais depois. O
banco em si continua estático o tempo todo: a proposta nunca escreve direto
nele. Depois disso, o perfil ganhou suporte a mais de um concurso ao mesmo
tempo, com um em foco e os demais só inscritos.

Projeto Supabase real criado, `supabase.json` preenchido, e o `schema.sql`
inteiro (Fases 3a a 4c: RLS, allowlist, `propostas`/`revisores`,
`sou_revisor`, `marcar_revisor`, `incorporada_em`) confirmado contra o projeto
— `conferir.sql` roda sem nenhum `FALHOU` nem `WARNING`. Sem o `supabase.json`
preenchido, a conta fica indisponível e o app funciona exatamente como na
Fase 2.

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

## Motor de repetição espaçada

Leitner de 5 caixas, intervalos 1, 3, 7 e 14 dias, com **teto dinâmico**: nenhum
intervalo pode passar de ⅓ dos dias restantes até a prova, e a partir de D-10
tudo vira revisão diária. Ver `proximaData()`.

Três respostas possíveis: "Sabia" sobe uma caixa; "Chutei" e "Errei" voltam para
a caixa 1. O botão "Chutei" é central — não removê-lo nem transformá-lo em acerto.

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
