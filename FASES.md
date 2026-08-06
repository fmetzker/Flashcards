# Plano de evolução — de app de prova única para plataforma de estudo

Documento de rumo. O app hoje é monousuário, offline, com um banco de 852
questões embutido no `index.html` e travado num único concurso
(Enfermeiro / Volta Redonda, 20/09/2026).

O destino é uma plataforma com **contas**, **histórico e preferências por
usuário**, **concurso-alvo escolhido por cada pessoa** e um **banco de questões
compartilhado por matéria** — de modo que quem faz concursos diferentes com
matérias em comum estude o mesmo acervo, cada um com seu progresso.

Cada fase é entregável sozinha e deixa o app funcionando. Dá para parar em
qualquer uma delas.

---

## Decisões tomadas

**Online é aceitável.** A restrição original — funcionar num navio com internet
instável — foi dispensada pelo usuário. O service worker continua no projeto
porque já existe e não custa nada, mas as fases seguintes podem assumir rede.

**Ainda assim existe uma via offline completa.** `gerar-offline.ps1` produz
`offline.html`, o app inteiro num arquivo só, com o banco embutido em
`window.DADOS`. Abre com duplo clique, sem servidor e sem rede. Serve para
testar rápido e para levar num pendrive. Custou uma linha no app: a função
`pega()` consulta `window.DADOS` antes de recorrer ao `fetch`.

**Backend: Supabase** (Postgres + Auth + Row Level Security), free tier.
Acesso por `fetch` direto na API REST, sem SDK e sem CDN — mantém o projeto sem
build e sem dependências.

**Login por e-mail e senha**, com sessão longa. Magic link foi descartado: exige
receber e-mail no momento do login.

**Cadastro por allowlist de e-mails convidados.** O grupo é fechado (família e
amigos próximos). Sem cadastro aberto.

**Escala-alvo: 5 a 10 pessoas.** Nenhuma decisão deve ser tomada pensando em
milhares de usuários.

---

## O que preservar

O ativo do projeto não é o código do app — são as **852 questões**, cada uma com
fonte obrigatória, e o portão de qualidade que impede o banco de degradar:

- viés de comprimento medido e corrigido em três passes (ver `CLAUDE.md`);
- viés de letra resolvido por embaralhamento em tempo de execução;
- `validar.py` barrando questão malformada, duplicada ou com viés piorando.

Toda fase mantém essas garantias. A Fase 4 transforma esse portão no critério de
aceitação de questões contribuídas por outras pessoas.

---

## Fase 0 — Identidade estável das questões · **concluída**

> **Por que vem primeiro:** o progresso é hoje indexado pela *posição no array*
> (`E.cartoes[137]` = "a 138ª questão do BANCO"). Num banco compartilhado, que
> várias pessoas ampliam e corrigem, inserir uma questão no meio embaralha o
> histórico de todo mundo em silêncio. Sincronizar índices de array entre
> aparelhos é um erro irrecuperável. Esta fase é obrigatória.

- [x] `id` estável em cada questão — SHA-1 do enunciado truncado em 10
      hexadecimais, reproduzível em qualquer linguagem
- [x] banco extraído do `index.html` para JSON por área em `banco/`
      (`extrair-banco.ps1`)
- [x] `index.html` carrega o banco por `fetch`; boot assíncrono, com tela de
      falha explicando o erro em vez de página em branco
- [x] `E.cartoes` migra de índice para id, com mapa `banco/indice-legado.json`
      convertendo o progresso já existente
- [x] `validar.py` lê os JSON e confere `id == sha1(enunciado)`; `validar.ps1`
      equivalente para máquinas sem Python
- [x] `VERSAO` do `sw.js` em `v12-852q-ids`, com os arquivos do banco no cache
- [x] `servidor.ps1` para rodar localmente — `file://` deixou de funcionar

Para o usuário, nada muda. O app fica migrável.

**Verificação.** As métricas de viés reproduzem exatamente os números anteriores
(228/852 = 26,8% · 0 acima de 20 chars · 56 com pista · 0,0% de acerto ao chutar
na mais longa), o que prova que a extração não corrompeu nenhuma questão.
Testado no navegador: migração de progresso antigo, fila, Leitner, simulado de
70 questões, estatísticas, caderno de erros e tela de falha.

**Consequência a lembrar:** o `id` deriva do enunciado. Editar um enunciado muda
o id e apaga o histórico daquela questão. Corrigir alternativas, explicação e
fonte é seguro.

---

## Fase 1 — Matéria e concurso viram dados · **concluída**

`a:"esp"` não era uma matéria: era "o resto da prova do cargo Enfermeiro" — não
se compartilha "Conhecimentos Específicos" entre concursos, é justamente a parte
que muda. Mas o campo `t` já trazia a taxonomia real, e os maiores tópicos são
matérias de verdade que reaparecem em qualquer concurso de enfermagem.

- [x] 85 tópicos reagrupados em **20 matérias** (`fase1-materias.ps1`); o campo
      `a` saiu e entrou `m`
- [x] um arquivo por matéria; o app carrega **só as matérias que o concurso
      escolhido cobra**
- [x] `concursos.json`: cargo, órgão, banca, edital, data, duração, blocos e
      regra de aprovação
- [x] Volta Redonda 2026 é a primeira receita
- [x] data da prova, 35 pontos, regra de bloco zerado, composição 10/10/50,
      duração de 3 h e critério de desempate saíram do código
- [x] estatísticas ganharam o nível de matéria, além do de tópico
- [x] `sw.js` monta o cache a partir do `materias.json`, para não desatualizar
      quando uma matéria for acrescentada

### As 20 matérias

| Matéria | Questões | | Matéria | Questões |
|---|--:|---|---|--:|
| Urgência, Emergência e Terapia Intensiva | 118 | | Vigilância em Saúde | 28 |
| Língua Portuguesa | 99 | | Farmacologia e Medicamentos | 25 |
| Doenças Transmissíveis | 75 | | Centro Cirúrgico e CME | 23 |
| Imunização | 66 | | Saúde Mental | 22 |
| Políticas Nacionais de Saúde | 58 | | Ética e Exercício Profissional | 20 |
| Fundamentos e Procedimentos de Enfermagem | 52 | | Anatomia e Fisiologia | 15 |
| Saúde da Mulher | 51 | | Processo de Enfermagem e Registros | 10 |
| Saúde do Adulto e do Idoso | 50 | | Saúde do Trabalhador | 8 |
| Saúde da Criança e do Adolescente | 42 | | Atenção Domiciliar | 7 |
| Controle de Infecção e Segurança do Paciente | 42 | | Legislação do SUS | 41 |

Português e as duas matérias de SUS são as que reaparecem em quase todo concurso
da área da saúde — é por elas que o compartilhamento começa a valer.

**Verificação.** Métricas de viés inalteradas (228/852 = 26,8% · 0 · 0 · 56 com
pista · 0,0%). Testado no navegador: composição, duração e regra de aprovação
lidas da receita; alerta de bloco fraco; estatísticas nos dois níveis; fluxo de
estudo e caderno de erros. E, principalmente, **uma segunda receita fictícia
rodou sem uma linha de código nova** — outro cargo, outra data, blocos 15+25,
150 minutos, aprovação sem cláusula de bloco zerado, carregando só as 4 matérias
daquela prova (242 questões em vez de 852).

**Armadilha encontrada no caminho:** incrementar a `VERSAO` do `sw.js` não basta
para ver a mudança. O service worker antigo continua servindo o `index.html` em
cache; para testar é preciso desregistrá-lo e apagar os caches.

---

## Fase 1b — Tópicos dentro das matérias · **concluída**

A Fase 1 criou as matérias, mas 10 das 20 ficaram com um único tópico, de mesmo
nome: "Imunização > Imunização", 66 questões. A árvore existia e não dividia
nada. Esta fase deu o segundo nível de verdade.

- [x] `fase1b-topicos.ps1` reclassifica o campo `t` a partir da **fonte e do
      enunciado**, que já carregavam o assunto; regras por matéria, primeira que
      casa vence, com um destino explícito para o que não casa
- [x] roda em simulação por padrão, imprimindo contagens e duas questões de
      amostra por tópico — foi assim que os erros de classificação apareceram e
      foram corrigidos antes de gravar
- [x] **85 → 149 tópicos**; 506 questões mudaram de `t`
- [x] tela **Matérias**: árvore completa, cada matéria abre e mostra seus
      tópicos com progresso (`vistas/total` e acurácia), e botão para estudar só
      aquela matéria ou só aquele tópico
- [x] `iniciarSessao("filtro", …)` respeita a mesma ordem do estudo normal: o
      vencido primeiro, depois o nunca visto; se não há nada devido, revisa
      adiantado em vez de não fazer nada
- [x] cabeçalho da questão mostra matéria e tópico
- [x] Estatísticas deixou de duplicar a árvore e voltou ao seu papel: ranquear
      do mais fraco para o mais forte, agora com a matéria embaixo do tópico

O `t` não faz parte do `id` (que é o SHA-1 do enunciado), então reclassificar não
custou nenhum progresso salvo.

**Duas armadilhas encontradas, ambas anotadas nos scripts:**

- `$regras = $REGRAS[...]` **apagava** o dicionário de regras: nomes de variável
  no PowerShell não diferenciam maiúsculas, então as duas são a mesma variável.
  O efeito era silencioso — só a primeira matéria era processada;
- `Select-Object -First` dentro de um `ForEach-Object` interrompe também o laço
  externo.

**Pendência conhecida:** a questão sobre a teoria de Wanda Horta está em
*Anatomia e Fisiologia* e pertence a *Processo de Enfermagem e Registros* — é
um erro de matéria, herdado da Fase 1, não de tópico.

---

## Fase 1c — As matérias são as três do edital · **concluída**

Correção de rumo pedida pelo usuário. As Fases 1 e 1b trataram "Imunização",
"Saúde da Mulher" etc. como matérias. Pela leitura do edital, matéria é o **bloco
da prova**. O que era matéria virou tópico; o que era tópico virou subtópico.

- [x] `fase1c-tres-materias.ps1` converte os 20 arquivos em três
- [x] `m` = 3 matérias · `t` = 50 tópicos · `s` = 114 subtópicos (opcional)
- [x] Português (23 tópicos) e SUS (10) param no segundo nível: os assuntos deles
      já são específicos o bastante, e um subtópico seria cópia do tópico
- [x] tela Matérias vira árvore de três níveis, com estudo em qualquer um deles
- [x] Estatísticas ranqueia pelo nível mais fino de cada questão, mostrando o
      nível de cima embaixo do nome
- [x] cabeçalho da questão mostra tópico e subtópico
- [x] `concursos.json`: cada bloco aponta agora para uma única matéria
- [x] validadores conferem que o subtópico nunca repete o nome do tópico

**Trade-off assumido.** A separação "questão pertence a matéria, nunca a
concurso" era o que permitiria compartilhar o acervo entre concursos de cargos
diferentes. Com "Conhecimentos Específicos de Enfermagem" como matéria única, o
compartilhamento do acervo de enfermagem vale entre concursos **de enfermagem**.
Português e Legislação do SUS — as que caem em quase toda prova da área da saúde
— continuam compartilháveis com qualquer cargo. Para o grupo a que o app se
destina, o custo é pequeno e o modelo fica mais próximo de como o edital se lê.

**Armadilha, a mesma de sempre:** `($qs | Group-Object t).Count` devolve o
tamanho do grupo quando há **um** grupo só, em vez de 1. Isso deu subtópico
redundante a Saúde do Trabalhador e Atenção Domiciliar. Sempre `@(...)` em volta.

---

## Fase 2 — Perfis locais múltiplos · **concluída**

**Modelo usado:** Sonnet 5, esforço medium.

Ainda sem backend. Vários perfis no mesmo aparelho, cada um com seu progresso e
seu concurso-alvo.

- [x] índice `vr:perfis` (`{atual, lista:[{id,nome}]}`) + chave por perfil
      `vr:perfil:<id>`, mesmo formato de estado de sempre
- [x] migração automática da chave antiga `vr-enf-2026` para o perfil `p1` na
      primeira execução — a chave antiga **não é apagada**, fica como rede de
      segurança
- [x] seletor de perfil em Ajustes: trocar, criar, renomear, apagar
- [x] trocar/criar/apagar recarrega a página de propósito — o app já faz boot
      completo do zero, reaproveitar isso é mais simples e mais seguro do que
      reinicializar cada variável de estado à mão
- [x] apagar é bloqueado se só existir um perfil (função e UI, os dois);
      apagar o perfil ativo troca automaticamente para outro da lista
- [x] `zerar()` (Ajustes → Zona de risco) deixou claro que apaga só o perfil
      atual, não todos

Resolve boa parte do pedido original — duas pessoas estudando no mesmo iPad —
a um custo baixo, sem depender de nada da Fase 3.

**Verificação.** Testado no navegador: migração de progresso salvo no formato
antigo (chave preservada, perfil `p1` criado com o conteúdo certo); criar
perfil novo sem herdar cartões do outro; progresso isolado entre dois perfis
depois de trocar; renomear repinta sem recarregar; apagar o perfil ativo troca
para o restante e remove a chave dele; bloqueio de apagar o último perfil tanto
pela UI (botão escondido) quanto chamando a função direto. Suite de regressão
completa (árvore de matérias, estudo, Leitner, simulado) sem quebra.
`offline.html` regenerado; `validar.ps1` sem erros, métricas de viés
inalteradas.

---

## Fase 3 — Contas e sincronização

Grande demais para um passo só; dividida em três, como foi com 1/1b/1c.

### Duas premissas que mudaram desde o esboço original

**O banco de questões continua estático.** O esboço previa `questoes`,
`materias` e `concursos` como tabelas. Hoje são arquivos JSON versionados e
conferidos pelo `validar.ps1`, idênticos para todo mundo. Pôr no Postgres seria
pagar consulta para ler conteúdo que nunca varia por usuário, e ainda exigiria
uma tela de administração — que é a Fase 4. **Só conta, preferências e
progresso vão para o banco.**

**O Leitner não é replayável puro.** O esboço dizia "estado derivado dos
eventos". Mas `proximaData()` depende de `diasAte()`, que muda todo dia:
reprocessar hoje um evento de duas semanas atrás daria um `prox` diferente do
que foi calculado na hora. Por isso o evento **carrega o resultado**
(`caixa_depois`, `prox`), e derivar vira "pegar o evento mais recente de cada
questão" — fiel e simples.

---

### Fase 3a — Fundação · **concluída**

**Modelo usado:** Opus 5, esforço high — RLS errada não aparece em teste feliz;
o app funciona e o progresso de uma pessoa vaza para outra.

- [x] `supabase/schema.sql`: `convidados` (allowlist), `perfis`,
      `eventos_resposta` (append-only), `simulados`, view `estado_cartao`
- [x] gatilho `exigir_convite` em `auth.users` — falha fechado: e-mail fora da
      lista não cria conta
- [x] gatilho `criar_perfil` — o perfil nasce junto com a conta
- [x] `convidados` com RLS ligada e **zero policies**: a lista de e-mails do
      grupo não é enumerável por quem tiver a chave anon (que é pública e vai
      no cliente)
- [x] `eventos_resposta` sem policy de update nem de delete — é a ausência
      delas que torna o log append-only no banco, não só por convenção do app
- [x] `id` do evento gerado no cliente, o que torna o reenvio idempotente
- [x] `estado_cartao` com `security_invoker = true` — sem isso a view rodaria
      como o dono e ignoraria a RLS, vazando o progresso de todos
- [x] `supabase/conferir.sql`: testa o que **deve ser negado** — isolamento
      entre dois usuários, forjar evento em nome de outro, apagar o log
- [x] `validar.ps1` barra a chave `service_role` no repositório (decodifica o
      JWT; as duas chaves começam iguais e ficam lado a lado no painel)

**Pendente para você:** criar o projeto no Supabase (sugestão: região São
Paulo), rodar `schema.sql` e depois `conferir.sql`, preencher a tabela
`convidados` e me passar a URL e a chave **anon**.

---

### Fase 3b — Login opcional · **concluída**

**Modelo usado:** Sonnet 5, esforço medium.

- [x] `supabase.json` (URL + chave anon) na raiz, lido por `pega()` como
      `concursos.json`; com valores de exemplo até o usuário colar os reais
- [x] wrapper REST com `fetch` contra o GoTrue do Supabase, sem SDK e sem CDN:
      `entrar`, `criarConta`, `sair`, `renovarSessao`
- [x] **sessão guardada por perfil local** (`vr:sessao:<perfilId>`), não numa
      chave global — trocar de perfil recarrega a página (padrão da Fase 2), e
      a sessão nova é lida do zero para o perfil certo
- [x] renovação silenciosa no boot (`verificarSessao`) quando o token está a
      menos de 5 min de expirar; refresh_token revogado desloga sem travar a
      abertura do app
- [x] seção "Conta" em Ajustes: formulário quando deslogado, e-mail + Sair
      quando logado, aviso de "não configurada" com o `supabase.json` de
      exemplo
- [x] **login opcional**: sem conta, o app é idêntico ao da Fase 2
- [x] `offline.html` declara a seção indisponível (reusa o `window.DADOS` que
      já existia) em vez de tentar falar com uma rede que não tem
- [x] `gerar-offline.ps1` embute `supabase.json`; `validar.ps1`/`validar.py`
      conferem a existência e o formato do arquivo, e o cache do `sw.js`

**Fora do escopo, de propósito:** recuperação de senha e qualquer
sincronização de dado — isso é a 3c.

**Verificação.** Sem projeto Supabase real ainda, a lógica foi testada com
`fetch` simulado no navegador: login com senha errada (erro do servidor
aparece cru na tela, sessão não criada) e certa (sessão salva na chave do
perfil certo); **isolamento real entre dois perfis** — logar como "Perfil 1",
trocar para "Esposa" com reload de verdade, sessão não vaza, voltar para
"Perfil 1" e a sessão dele continua lá; renovação de sessão (sucesso e
refresh_token revogado); `sair()`; cadastro nos três cenários (login imediato,
"confirme seu e-mail", e-mail não convidado recusado pelo servidor); validação
de campos vazios; estado "não configurada" com o `supabase.json` de exemplo
(nenhuma tentativa de rede); estado indisponível em `offline.html` real, com
`supabase.json` confirmadamente embutido. Suíte de regressão completa (árvore,
estudo, Leitner, simulado) sem quebra. `validar.ps1` sem erros.

**Teste de integração real — feito.** Projeto criado (região São Paulo),
`schema.sql` e `conferir.sql` rodados sem "FALHOU", `supabase.json` preenchido
com a URL e a chave `sb_publishable_...` real. Confirmado contra o projeto de
verdade, por `curl` e depois pela UI: `perfis` devolve `[]` para leitura
anônima (RLS bloqueando, não vazando); cadastro de e-mail fora da allowlist é
recusado pelo gatilho `exigir_convite` (Postgres aborta a transação inteira —
nenhum resíduo fica em `auth.users`); a mensagem real de erro do GoTrue nesse
caso é `"Database error saving new user"` — genérica, não nomeia o motivo, mas
o comportamento de segurança é o que importa e está correto.

**Quase entrou uma chave secreta no repositório.** Ao pedir a chave `anon`
para fechar este teste, a primeira colada foi a secreta, no formato novo do
Supabase (`sb_secret_...`, equivalente à antiga `service_role`) — os dois
formatos de chave ficam lado a lado no painel, igual o par antigo. Ela nunca
chegou a um arquivo. Os guardas-corpo do `validar.ps1`/`validar.py` só
reconheciam o formato antigo (JWT); corrigidos para os dois formatos antes de
usar a chave certa.

---

### Fase 3c — Sincronização · **concluída**

**Modelo usado:** Opus 5, esforço high (motor) + Sonnet 5, esforço medium
(interface), na mesma sessão de trabalho.

Lacuna encontrada ao abrir o código: `registrar()` era booleano — "Chutei" e
"Entendi, seguir" (erro) caíam no mesmo `else`, então o app nunca soube
distinguir chutei de errei internamente, só na tela. Corrigido antes de mexer
em sincronização, já que o schema da 3a guarda os três resultados.

- [x] `uuidv4()` local (portátil, sem depender de `crypto.randomUUID`) para
      gerar o id de cada evento e simulado no cliente
- [x] fila de envio por perfil (`vr:fila:<id>`, `vr:fila-sim:<id>`); push
      idempotente — 409 (id duplicado) é tratado como sucesso, não erro
- [x] `registrar()` grava o motivo real (sabia/chutei/errei) e enfileira
- [x] pull incremental por cursor (`criado_em`, paginado de 500 em 500),
      separado para eventos e simulados
- [x] **duas regras de merge, documentadas em comentário no código:**
      `caixa`/`prox` são estado atual e só trocam se o evento for **mais novo
      por `ts`** que o que já existe local — um evento atrasado de outro
      aparelho não pode sobrescrever uma resposta mais recente daqui; já
      `acertos`/`erros`/`dias` são contagem acumulada e só somam para eventos
      que **não estão em `E.eventosProprios`** — sem isso, o que este mesmo
      aparelho empurrou voltaria no próximo pull e contaria duas vezes
      (`E.simulados` dedupe simplesmente por `id` já presente, sem essa
      complicação — não é contagem acumulada)
- [x] recuperação de token expirado: 401 no meio de uma chamada dispara
      `renovarSessao()` e repete a chamada uma vez
- [x] falha de rede no meio do envio deixa o evento na fila — não perde nem
      trava; tenta de novo na próxima chamada de `sincronizar()`
- [x] disparo automático depois de cada resposta e de cada simulado (se
      logado), no boot depois de `verificarSessao`, e ao reconectar
      (`window.addEventListener("online", ...)`)
- [x] indicador de status em Ajustes → Conta ("sincronizado" / "N pendentes" /
      "sincronizando…") + botão "Sincronizar agora"

**Verificação.** Sem projeto Supabase real ainda: simulei um servidor Postgres
completo em memória no navegador (tabelas, `criado_em` crescente, 409 em id
duplicado) e testei ponta a ponta — estudar 3 questões com os três resultados
e ver a fila esvaziar; reprocessar o pull do zero (cursor resetado) sem
duplicar contadores; evento de "outro aparelho" somando corretamente e
atualizando `caixa`/`prox`; evento atrasado de outro aparelho somando
contadores **sem** sobrescrever o estado mais recente; simulado sincronizando
e resistindo a reprocesso duplicado; renovação automática em 401 com retentativa;
**queda de rede no meio do envio sem perder o evento nem travar o app**, e
recuperação ao restaurar a rede. Suíte de regressão completa sem conta
configurada (idêntico à Fase 2). `offline.html` regenerado, `validar.ps1` sem
erros, métricas de viés inalteradas.

**Teste de integração real pendente**, igual à 3b: RLS em uso de fato contra
duas sessões reais da mesma conta, e o formato real das respostas do
PostgREST — o servidor simulado aqui aproxima o contrato, não garante.

---

## Fase 4 — Banco colaborativo

O banco continua **estático**: `banco/*.json`, versionado, validado por
`validar.py`. O Supabase entra só como caixa de entrada — proposta e revisão
acontecem lá, mas a questão só existe de verdade no app depois de um script
local incorporar o aprovado ao arquivo de matéria e o `validar.py` rodar,
igual sempre rodou. Aprovar no app nunca escreve direto no banco que o app lê.

```
app (logado) → propõe → tabela `propostas` (pendente)
                                ↓
                    revisor aprova/rejeita no app
                                ↓
     script local puxa as aprovadas → banco/<matéria>.json → validar.py → commit
```

### Fase 4a — Schema e formulário de proposta · **concluída**

**Modelo usado:** Opus 5, esforço high (schema/RLS) + Sonnet 5 (formulário).

- [x] tabela `propostas` (matéria/tópico/subtópico/enunciado/alternativas/
      correta/explicação/fonte/status), `id` gerado no cliente — mesmo motivo
      de idempotência dos eventos de resposta
- [x] tabela `revisores` (allowlist de quem pode aprovar, mesmo padrão de
      `convidados`: RLS ligada, zero policies, ninguém lê pela API)
- [x] RLS de `propostas`: autor lê/escreve só as próprias; revisor lê e
      decide todas; **autor não consegue aprovar a própria proposta** mesmo
      chamando a API direto — testado em `conferir.sql`
- [x] tela "Propor questão" no app, item de menu que só aparece logado
- [x] validações no formulário espelham as exigências mínimas do
      `validar.py` (5 alternativas distintas, todos os campos obrigatórios)
      — não o substituem; o validador de verdade roda na hora de incorporar

**Dois bugs reais encontrados e corrigidos no caminho, nenhum deles novo
desta fase:**

- `chamarRest` fazia `Object.assign({headers:...}, opcoes)` — quando
  `opcoes` também tinha `headers` (todo POST com `Prefer`), o de cima
  sobrescrevia o de baixo por inteiro, e a chamada saía **sem `apikey` nem
  `Authorization`**. Isso datava da Fase 3c: `empurrarUm()` (push de
  eventos e simulados) tinha esse defeito desde que foi escrito. Os testes
  da 3c "passaram" porque o servidor simulado da época não conferia
  cabeçalho — só quando testei a proposta com mais cuidado (conferindo o
  cabeçalho recebido) o defeito apareceu. Ou seja: **a sincronização
  provavelmente nunca funcionou de verdade contra o projeto real**, apesar
  de "verificada" na 3c. Corrigido para as duas funções de uma vez.
- a tela de proposta chamava `pintarPropor()` depois de enviar com sucesso,
  pra limpar os campos — só que `pintarPropor()` também apaga a mensagem de
  erro/sucesso como parte de reconstruir o formulário, então a confirmação
  desaparecia na hora. Troquei por limpar os campos um a um, sem repintar.

**Verificação.** Formulário testado com servidor simulado, inclusive
inspecionando o cabeçalho de verdade da requisição (é assim que os dois bugs
acima apareceram): validação de campo vazio, validação de alternativas
repetidas, envio com sucesso mostrando a mensagem certa, formato exato do
payload. Botão do menu escondido sem login, visível logado. `conferir.sql`
com blocos novos: autor vê só a própria proposta, terceiro não vê nada,
revisor vê e decide, autor não consegue aprovar a própria. Regressão completa
sem quebra, `offline.html` regenerado, `validar.ps1` sem erros.

**Pendente para você:** rodar `schema.sql` de novo no SQL Editor (é
idempotente, adiciona só o que falta), depois logar pelo app uma vez e rodar
o bloco 10 do schema pra virar revisor.

---

### Fase 4b — Revisão · **concluída**

**Modelo usado:** Sonnet 5, esforço medium.

- [x] tela de revisão: lista pendentes por matéria/tópico/subtópico,
      enunciado, alternativas com a correta marcada, explicação, fonte
- [x] aprovar (confirmação) / rejeitar (motivo opcional, cancelável sem
      efeito) — atualiza só o status, nunca escreve no banco que o app lê
- [x] visível só pra quem `sou_revisor()` confirma — ver os dois ajustes de
      schema abaixo, que a 4a tinha deixado faltando

**Dois complementos de schema que a 4a não previu, achados ao desenhar esta
tela:**

- `revisores` nega toda leitura pela API (RLS sem policy, de propósito). Isso
  significa que **não dava pra perguntar "sou revisor?" com um SELECT** — a
  própria proteção que impede listar quem revisa também impede um revisor
  descobrir que é revisor. Resolvido com `sou_revisor()`, uma function
  `security definer` que só devolve booleano, nunca a lista.
- `revisado_por`/`revisado_em` não tinham como se preencher sozinhos: DEFAULT
  só atua em INSERT, e essas colunas só fazem sentido num UPDATE (quando a
  decisão acontece). Resolvido com o gatilho `marcar_revisor`, que também
  fecha uma brecha que existiria se o cliente preenchesse esses campos
  direto: sem o gatilho, um revisor poderia assinar a decisão em nome de
  outro. Com ele, quem decidiu vem sempre de `auth.uid()` no servidor.

**Verificação.** `conferir.sql` ganhou blocos para os dois: `sou_revisor()`
devolve true/false certo e a tabela continua ilegível mesmo sendo revisor;
tentar forjar `revisado_por` é ignorado, o gatilho usa o `auth.uid()` real.
No app, testado com servidor simulado: botão escondido deslogado, escondido
logado-mas-não-revisor, visível e funcional como revisor — listar pendentes,
aprovar, rejeitar com motivo, cancelar rejeição sem chamar o servidor,
`revisado_por` nunca enviado pelo cliente. Deslogar reresetta `SOU_REVISOR` e
esconde o botão. Regressão completa sem quebra, `offline.html` regenerado,
`validar.ps1` sem erros.

**Correção posterior, achada só ao rodar contra o projeto real, em duas
tentativas:** o `conferir.sql` simula pessoas (Ana, Bruno, autor, revisor) com
UUIDs fictícios, mas `usuario_id`/`autor_id`/`user_id`/`revisado_por` têm
chave estrangeira de verdade para `auth.users` — a primeira execução real
quebrou com `violates foreign key constraint`. Nunca tinha rodado de verdade
antes desta correção; "testado" nas seções anteriores queria dizer analisado
com cuidado, não executado.

- **1ª tentativa:** uma function auxiliar (`pg_temp.desliga_fk`) que desligava
  só o gatilho **interno** de FK de uma tabela, sem tocar em gatilhos nomeados
  como `marcar_revisor`. Esbarrou numa proteção do Postgres: só superusuário
  de verdade pode desligar um `RI_ConstraintTrigger`, e o papel do SQL Editor
  do Supabase não é superusuário de verdade — `permission denied ... is a
  system trigger`.
- **2ª tentativa:** em vez de desligar o gatilho, tornar as chaves
  estrangeiras para `auth.users` **adiáveis** (`schema.sql`, descobrindo-as
  sozinho via `pg_constraint` em vez de nomear cada uma na mão) e, em
  `conferir.sql`, `set constraints all deferred` logo depois do `begin`. A
  checagem passa a rodar só no `COMMIT`; como o arquivo sempre termina em
  `ROLLBACK`, ela nunca chega a rodar para o dado de teste. Não precisa de
  nenhum privilégio especial — bem mais robusto que brigar com gatilho.
- **Um terceiro problema, de desenho, não de teste:** rodando de novo, veio
  `permission denied for table revisores` numa consulta comum a `propostas`
  (não uma tentativa de burlar nada). Causa: as policies "revisor: ver
  todas"/"revisor: decidir" faziam `exists (select ... from revisores ...)`
  direto — e essa subquery roda com o privilégio de quem está consultando,
  não do dono da tabela. Como `revisores` nega tudo (`revoke all`), **e o
  Postgres avalia todas as policies de uma tabela, mesmo as que não se
  aplicam**, isso travaria a leitura de `propostas` para qualquer pessoa,
  revisor ou não — não só no teste, no app de verdade também, e eu não tinha
  percebido porque nunca tinha rodado contra um projeto real. É exatamente o
  problema que `sou_revisor()` (uma function `security definer`) foi criada
  pra resolver — só que eu não tinha usado ela dentro das próprias policies,
  só no app. Corrigido: as duas policies agora chamam `sou_revisor()`, que
  precisou subir de posição no arquivo (seção 7.1, antes de `propostas`) —
  o Postgres exige que a function já exista na hora de criar a policy.

**Confirmado contra o projeto real.** `schema.sql` rodado ("sucesso"),
`conferir.sql` rodado depois e conferido linha a linha: nenhum `FALHOU` nem
`WARNING` em nenhuma seção. Fluxo completo de convite → criar conta → virar
revisor → relogar (pra `verificarRevisor()` rodar de novo) testado e
confirmado pelo usuário.

---

### Fase 4c — Incorporação ao banco · **concluída**

**Modelo usado:** Sonnet 5, esforço medium.

- [x] `schema.sql` (8.3): coluna `incorporada_em` em `propostas` — sem ela o
      script não teria como distinguir "aprovada" de "aprovada e já
      incorporada", e reincorporaria a mesma proposta a cada execução
- [x] `incorporar-propostas.ps1`: puxa as aprovadas com `incorporada_em is
      null` (chave secreta — pedida por variável de ambiente ou colada na
      hora, sem eco no terminal, nunca gravada em arquivo; roda só
      localmente, nunca no app); calcula o id (mesma função sha1 truncada de
      sempre); pula duplicata (id já existe no banco); grava a linha nova em
      `banco/<matéria>.json` **sem reescrever o arquivo inteiro** — só insere
      antes do `]` final, pra manter o diff pequeno e não arriscar
      reformatar as 852 questões existentes; marca `incorporada_em` de volta
      no Supabase depois de gravar cada matéria; para aí — commit e
      `validar.py`/`validar.ps1` continuam manuais, igual a acrescentar
      qualquer outra questão
- [x] `-DryRun`: mostra o que seria incorporado sem gravar nada nem marcar
      nada no Supabase

**Por que a chave secreta é segura aqui, mesmo sendo a que ignora RLS:** o
script é uma ferramenta de manutenção, roda só na máquina de quem mantém o
projeto, nunca dentro do app. É o mesmo motivo pelo qual dá pra usar
`git push` sem commitar a chave SSH — a chave existe fora do repositório, só
na hora de rodar.

**Verificação.** Sintaxe conferida com o parser do PowerShell. A lógica de
inserção testada isolada contra uma cópia de `banco/portugues.json` num
diretório temporário: duas questões novas inseridas, arquivo resultante
continua JSON válido (101 questões, as 99 originais + 2), e a linha
pré-existente mais próxima da inserção comparada byte a byte com o original —
UTF-8 idêntico, sem corrupção de acento. `validar.ps1` rodado contra o
repositório de verdade depois do `schema.sql` (8.3) e do script novo: sem
erros, 852 questões, mesmos vieses de antes (nada mudou no banco em si, só a
ferramenta foi acrescentada).

---

## Múltiplos concursos por perfil · **concluída**

Pedido fora da numeração das fases — o perfil escolhe um ou mais concursos.

**Modelo usado:** Opus 5, esforço high (modelo/migração/teto) + Sonnet 5,
esforço medium (interface).

A separação que sustenta tudo, e que é o ponto onde um erro sai caro:

| | define | muda quando |
|---|---|---|
| `INSCRITOS` / `E.concursos` | banco carregado (união das matérias) e teto do Leitner (`diasAteMaisProxima`) | marcar/desmarcar em Ajustes — **recarrega** |
| `CONCURSO` / `E.concursoAtivo` | cabeçalho, contagem, cartela, simulado, alerta de bloco | seletor na tela inicial — **só repinta** |

- [x] `E.concurso` (singular) migra para `E.concursos` + `E.concursoAtivo` na
      primeira execução, sem perder a escolha de quem já usava; id que sumiu
      do `concursos.json` é descartado em vez de travar o perfil
- [x] banco = união das matérias de todos os inscritos — é isso que faz
      "seguir dois" significar estudar o conteúdo dos dois, e não só trocar
      o cabeçalho
- [x] teto do Leitner usa a prova **mais próxima** entre os inscritos
- [x] seletor de foco no cabeçalho (só aparece com mais de um)
- [x] seção "Concursos" em Ajustes; não dá pra ficar sem nenhum; se o foco
      sair da lista, migra sozinho para o que restou

**Verificação.** Com um segundo concurso simulado em memória (Barra Mansa,
prova 21 dias antes de Volta Redonda, sem SUS no edital): migração do formato
antigo preservando meta e cartões; união trazendo as 852 questões; **teto do
Leitner apertando de 15 para 8 dias por causa da prova mais próxima** —
conferido no número, não só na lógica: caixa 5 marcou revisão para 13/08 em
vez de 19/08, que cairia depois da prova de Barra Mansa; troca de foco
mudando cabeçalho/contagem/blocos sem recarregar banco; simulado seguindo a
receita do foco (15+25, 150 min, mínimo 20 sem cláusula de bloco zerado);
questões de SUS ainda estudáveis com foco no concurso que não tem SUS;
proteção do último concurso e migração automática do foco. Regressão completa
sem quebra, `offline.html` regenerado, `validar.ps1` sem erros.

---

## Login obrigatório · **concluída**

**Modelo usado:** Sonnet 5, esforço high.

Conta deixou de ser opcional: sem sessão válida, o boot mostra a tela de
login em vez da tela inicial (`exigeLogin()`/`pintarLogin()`). O
`offline.html` é a exceção deliberada — nunca fala com o servidor.
`validar.py`/`validar.ps1` passaram a tratar `supabase.json` de exemplo como
**erro**, não aviso: publicar assim tranca todo mundo pra fora.

---

## Fim do perfil local · **concluída**

**Modelo usado:** Sonnet 5, esforço high.

Com login obrigatório, o id local (`p1`, `p2`...) virou redundante — e
perigoso: o mesmo `p1` podia guardar o progresso de duas pessoas diferentes
no mesmo aparelho. O progresso passou a ser chaveado pelo id real da conta
(`sub` do token). Ver regra 1 do `CLAUDE.md`.

Migração automática de três esquemas anteriores (`vr:perfis`/`vr:perfil:<id>`,
`vr:sessao:<id>`, e a chave pré-Fase 2 `vr-enf-2026` — que era resgatada por
`carregarPerfis()`, função que deixou de existir). Nada antigo é apagado.

**Verificação.** Testado no navegador: migração preservando meta, cartões,
dias, fila e cursores; duas contas no mesmo aparelho lendo/escrevendo sob
chaves distintas, com o estado de uma **intacto** depois de a outra usar o
app; `offline.html` entrando sem login e persistindo entre aberturas.

**Bug achado no próprio teste:** no `offline.html` não existe sessão, então
`CONTA_ID` ficava null, `CHAVE` null e `salvar()` só guardava em memória — o
progresso sumiria ao fechar o arquivo. Corrigido com a chave fixa
`vr:conta:local`. Não teria aparecido sem rodar o offline de verdade.

---

## Cadastro aberto com aprovação · **concluída**

**Modelo usado:** Opus 5, esforço high (schema/RLS) + Sonnet 5 (telas).

A allowlist de convidados deu lugar a um portão **depois** do cadastro:
qualquer pessoa cria conta, ela nasce `pendente` e não enxerga nada até um
aprovador liberar.

- `exigir_convite` desligado; `convidados` fica de pé, sem uso
- `perfis` ganha `status`/`aprovado_por`/`aprovado_em`/`email`
- `aprovadores` + `sou_aprovador()`, no padrão de `revisores`/`sou_revisor()`
- `conta_aprovada()` exigido nas policies de `eventos_resposta`, `simulados`
  e `propostas`. `perfis` é a exceção deliberada: a pessoa precisa ler a
  própria linha para o app saber que está pendente
- gatilho `proteger_status_perfil` impede auto-aprovação (o `status` mora na
  mesma linha que nome e meta, que a pessoa pode editar), assina
  `aprovado_por` com `auth.uid()` do servidor e congela o `email`

**Dois problemas achados na revisão, antes de rodar:**

- O backfill que marca contas antigas como aprovadas rodaria **toda vez**.
  Como o `schema.sql` é idempotente por contrato e feito para ser
  reexecutado, isso aprovaria em massa quem estivesse na fila naquele
  momento. Agora vive dentro de um guard que checa se a coluna já existe.
- As seções 5 e 6 do `conferir.sql` passariam a falhar por **motivo errado**
  (falta de aprovação, não vazamento entre pessoas), escondendo exatamente o
  que elas existem para pegar. Ganharam perfis aprovados.

**Verificação.** No app: os cinco caminhos do portão (sem sessão → login;
pendente e rejeitado → espera; aprovado → app; servidor sem resposta → app,
porque ficar offline não pode trancar quem já usava). No servidor:
`conferir.sql` rodado contra o projeto real, seção 8 nova incluída, **sem
nenhum FALHOU nem WARNING** — conta pendente não grava, não propõe, não se
auto-aprova e não troca o próprio e-mail; aprovador vê a fila e libera;
`aprovado_por` vem do servidor; `aprovadores` continua ilegível.

Diferente da Fase 4b, aqui o schema foi conferido contra o projeto real
**antes** de ser dado como pronto.

---

## Plano de melhorias — Bloco A (rápidas, sem risco) · **concluído**

**Modelo usado:** Sonnet 5, esforço low/medium conforme o item.

Pedido fora da numeração das fases, em sete itens; o Bloco A é a parte
rápida — os blocos B (menu de navegação, meta por disciplina) e C
(metodologia de criação/revisão dos flashcards) ficaram para depois.

- [x] **Nome "Flashcard" na tela de início** — `apple-mobile-web-app-title`
  e `manifest.json` (`short_name`). `name` do manifest e `<title>` do HTML
  ficaram como estavam, de propósito: só foi pedido o nome do atalho, não um
  rebranding completo.
- [x] **Reportar problema numa questão** — botão na tela de estudo, visível
  só com conta (mesma regra de "Propor questão"). Nova tabela `reportes`
  (`schema.sql` 8.4), reaproveitando os revisores de `propostas`
  (`sou_revisor()`) em vez de criar um papel novo — julgar se uma questão
  está certa é o mesmo tipo de trabalho. Mesmas proteções de sempre: autor
  não se auto-resolve, `resolvido_por` vem do servidor. Nova tela "Reportes
  de questões", que lida com o caso de o revisor não ter aquela matéria
  carregada localmente (mostra o id em vez de travar).
- [x] **Backup deixou de cobrar toda semana** — a sincronização por conta já
  cobre o caso comum (trocar de aparelho); o alerta que aparecia na tela
  inicial depois de 7 dias foi removido. Exportar/restaurar continuam
  disponíveis em Ajustes, só sem a cobrança.

**Item 4 (remover o zoom) não entrou.** Investigado e descartado: desde o
iOS 10 o Safari ignora `user-scalable=no`/`maximum-scale` de propósito, por
acessibilidade — não haveria efeito nenhum no aparelho que o app realmente
mira. Se o incômodo for outro (o zoom automático do Safari ao focar um campo
de texto com fonte pequena), é um problema diferente e pode ser corrigido à
parte.

**Verificação.** `reportarProblema()` testado com sessão simulada: botão
aparece logado, some deslogado. `pintarReportes()` testado com dois cenários
mockados — questão presente no banco local (mostra enunciado) e questão de
matéria fora dos concursos seguidos pelo revisor (mostra aviso em vez de
quebrar). Erro de rede tratado sem travar a tela. `validar.ps1` sem erros.

**Correção posterior, achada só ao rodar contra o projeto real** — mesma
classe de bug da Fase 4b: `reportes_autor_id_fkey` nunca virava adiável,
porque a seção que faz isso (schema.sql, então 8.2) rodava **antes** de
`reportes` (então 8.4) existir — `pg_constraint` só enxerga o que já foi
criado no momento em que a consulta roda. `conferir.sql` quebrava com
`violates foreign key constraint` ao inserir o autor de teste fictício.
Corrigido movendo o bloco para o fim do arquivo (renomeado 8.5), com
comentário deixando explícito que essa seção precisa continuar sendo a
última do arquivo — qualquer tabela nova com FK para `auth.users` que entrar
depois dela quebra do mesmo jeito. Confirmado depois: `conferir.sql` roda
sem nenhum `FALHOU` nem `WARNING`.

---

## Plano de melhorias — Bloco B (estruturais) · **concluído**

**Modelo usado:** Opus 5, esforço high (meta por disciplina) + Sonnet 5,
esforço medium (navegação).

### Item 7 — meta por disciplina

O problema relatado: "a meta é contabilizada mesmo quando o usuário estuda
matérias que pertencem exclusivamente a outro concurso".

A divisão pedida **já existia nos dados** — cada bloco do concurso tem
`questoes` (10 Português + 10 SUS + 50 Específicos). Não precisou de campo
novo em `concursos.json`; precisou de contagem por matéria no estado
(`E.diasMateria`) e de agregação por bloco na leitura (`progressoDoDia`).

Três decisões que valem registro:

- **Por matéria, não por bloco.** Id de bloco é por concurso (`lp` num,
  `port` noutro): guardar por bloco quebraria ao trocar o foco.
- **Filtro na leitura, não na gravação.** Quem alterna o foco precisa do
  histórico certo para os dois concursos; filtrar ao gravar destruiria isso.
- **A sessão de estudo também respeita a cota.** Sem isso o app mandaria
  estudar matéria que depois não conta — pior que não contar, induz ao erro.

**Verificação.** Os três cenários do pedido, medidos no navegador com o
concurso de Enfermeiro em foco: 50 cartões só de Português → **10/70** (antes
50/70); 50 Port + 10 SUS + 50 Esp → **70/70**; 40 cartões de Matemática, que
só cai no CAAQ-CDM → **0/70** (antes 40/70). E a sessão de "Estudar agora"
sai na composição da prova (10/10/50), passando a 60 questões sem Português
quando a cota dele já fechou.

### Item 1 — navegação por abas

Barra fixa no rodapé (Hoje · Matérias · Estatísticas · Ajustes). A tela
inicial ficou só com o que é do dia; gráficos e card "Banco" foram para
Estatísticas. Some nas telas de foco e de portão (`SEM_NAV`).

**Verificação.** Aba certa acesa em cada tela, barra some em estudo/login,
barra de ações sobe para não sobrepor a nav, alvos de toque de 94×50px.

### Confronto com o edital (003/2026-SMA)

O edital de Enfermeiro foi lido e comparado com o banco. Duas conclusões:

- **Todos os tópicos do banco contam para a meta** — decisão do usuário.
  Crase, Lei 8.142/90 e Constituição Federal não aparecem literalmente no
  edital, mas são cobrados escondidos dentro do que ele lista ("sintaxe",
  "princípios e diretrizes do SUS"). Excluí-los seria apostar contra isso.
  Por isso o filtro por tópico **não** foi implementado: seria código
  especulativo sem nenhum caso de uso real hoje.
- **Duas seções do edital estão com ZERO questões** — débito conhecido, a
  pagar no Bloco C: **3.6 Saúde do Homem** (PNAISH, rastreamento de câncer de
  próstata, saúde sexual masculina) e **3.18 Feridas, Estomias e
  Reabilitação** (lesão por pressão, coberturas, ostomizados).

---

## Plano de melhorias — Bloco C (metodologia) · **primeira rodada concluída**

**Modelo usado:** Opus 5, esforço high (padrão e prioridade) + Sonnet 5,
esforço medium (auditoria e correções).

### O achado que mudou o plano

O pedido original era escrever a metodologia **e reescrever as 876 questões**
para segui-la. Antes de reescrever, `auditar-banco.ps1` mediu o banco contra o
padrão recém-escrito. Resultado: **91,8% das questões sem nenhum apontamento**,
e apenas 12 de gravidade alta.

Reescrever tudo teria custo enorme e ganho perto de zero — e ainda arriscaria
o histórico de quem já estuda. O esforço foi redirecionado para as 12 reais.

Duas coisas que só apareceram porque a medição veio antes da ação:

- **O próprio script tinha falso positivo.** "15 x 60 = 900 mg" foi marcada
  como explicação fraca por ter menos de 40 caracteres — mas em questão de
  cálculo a explicação curta É a explicação inteira. O critério passou a
  exigir também ausência de sinal de raciocínio (conta ou conectivo causal).
- **Uma questão tinha explicação que explicava outra coisa.** Em
  `fe95f27118` (tuberculose na gestação), a correta falava de piridoxina e a
  explicação, de amamentação. Nenhuma verificação automática pegaria isso;
  apareceu ao ler os casos apontados.

### O que foi feito

- [x] **`METODOLOGIA.md`** — o padrão: recordação ativa, um fato por cartão,
  distratores plausíveis, explicação que ensina, o que não fazer, e como
  priorizar sem inventar dado de incidência.
- [x] **`auditar-banco.ps1`** (e `.py`) — mede o banco contra o padrão. Mede,
  **não reprova**: qualidade é gradiente, não regra, e por isso não vira
  portão de publicação como o `validar`.
- [x] **`reescrever-questoes.ps1` + `banco/reescritas.json` +
  `migrarReescritas()`** — o mecanismo que faltava. O id é o SHA-1 do
  enunciado, então corrigir enunciado zerava o histórico do cartão para todo
  mundo; isso tornava proibitivo consertar questão ruim, que é justamente o
  que a metodologia manda fazer. Agora o progresso é transportado pelo mapa,
  seguindo cadeia (A→B→C) e resolvendo conflito pelo evento mais recente.
- [x] **6 enunciados corrigidos** — os que não eram pergunta respondível sem
  ler as alternativas ("Sobre X, é correto afirmar que:").
- [x] **`prioridade()`** — ordem dentro do que já venceu passa a considerar
  caixa, taxa de erro e peso do bloco, sem adiantar nenhuma revisão.

**Verificação.** Migração testada no navegador: progresso em id antigo
(caixa 4, 7 acertos, data de revisão) chega intacto no id novo; conflito entre
os dois ids resolve pelo `ts` mais recente nos dois sentidos, sem duplicar.
Auditoria depois das correções: `sem-pergunta` de 6 para **0**, banco em
92,8% limpo. `validar.ps1` sem erros — inclusive os dois que ele acusou no
meio do caminho (`reescritas.json` não reconhecido; `indice-legado.json`
apontando para ids que deixaram de existir), ambos corrigidos.

### Segunda rodada — as duas lacunas do edital · **concluída**

23 questões novas, escritas seguindo `METODOLOGIA.md` desde o início (não
auditadas depois — nasceram já dentro do padrão):

- **10** em Saúde do Homem, 3 subtópicos: PNAISH (o que é, faixa etária,
  barreira cultural que justifica a política), rastreamento e prevenção do
  câncer de próstata (decisão compartilhada, não rastreamento populacional —
  posição do INCA), saúde sexual e reprodutiva (vasectomia, Lei 9.263/1996,
  IST).
- **13** em Feridas, Estomias e Reabilitação, 4 subtópicos: classificação de
  lesão por pressão (estágios 1 a 4, não classificável, Escala de Braden),
  avaliação e tratamento de feridas (coberturas por tipo de exsudato,
  desbridamento, definição de ferida crônica), estomias (ileostomia vs.
  colostomia, Polo Regional de Ostomizados, pele periestomal), reabilitação
  (Rede de Cuidados à Pessoa com Deficiência).

**Processo:** as 23 questões foram checadas contra o viés de comprimento
**antes** de entrar no banco — script de geração roda em modo checagem por
padrão, só grava com uma variável de ambiente explícita, e mesmo assim só se
a checagem vier limpa. Encontrou 3 questões com distrator curto demais logo
na primeira passada; corrigidas antes de gravar, não depois.

**Verificação.** `validar.ps1`: sem erros; o indicador "correta é a mais
longa" subiu de 228 para 241 (dentro do ruído documentado — o que importa,
excede-20/excede-40 caracteres, continua em **zero**). `auditar-banco.ps1`:
nenhum apontamento novo nas 23; banco geral sobe de 92,8% para **93,0%**
sem apontamento algum.

### O que falta neste bloco

- [ ] 48 questões com distrator curto demais (gravidade média) e 3 com
  explicação curta sem raciocínio. Sem urgência.
- [ ] Priorização por **incidência real** continua bloqueada por falta das
  provas anteriores da FEVRE/CIAGA.

---

## Fase 5 — Social leve (opcional)

**Modelo sugerido:** Sonnet 5, esforço **low** — telas de leitura sobre dado
que a Fase 3 já modelou; sem decisão de arquitetura nova.

- [ ] ver quem mais estuda o mesmo concurso
- [ ] comparar constância, não nota

---

## O que não fazer

- **Não migrar para framework nem introduzir build.** O app tem ~400 linhas; o
  ganho não paga o custo.
- **Não usar Firebase.** O modelo é relacional e o RLS do Postgres é mais simples
  de auditar num grupo fechado.
- **Não começar pela Fase 3.** É a parte empolgante e é a que quebra tudo se as
  Fases 0 e 1 não vierem antes.

## Avisos operacionais

- O free tier do Supabase pausa o projeto após cerca de uma semana sem uso. Com
  5 a 10 pessoas estudando diariamente isso não acontece.
- Regra do `CLAUDE.md` que continua valendo em toda fase: **ao alterar o
  `index.html`, incrementar `VERSAO` no `sw.js`**.
