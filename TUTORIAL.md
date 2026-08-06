# Tutorial — colocar o app para funcionar no iPhone

App de estudo para o concurso da Secretaria Municipal de Saúde de Volta Redonda
Cargo: Enfermeiro · Edital 003/2026-SMA · Prova em 20/09/2026

---

## Antes de começar

**O que você precisa:**
- A pasta do projeto inteira (não um zip — desde que o banco de questões
  passou a viver em arquivos separados, publicar exige levar a pasta `banco/`
  junto, e um zip preparado à mão é fácil de deixar algo de fora)
- Um computador (recomendado) ou o iPhone com o app Arquivos
- Internet para a publicação e para logar da primeira vez em cada aparelho/perfil — login é obrigatório para entrar no app (exceto na versão `offline.html`); depois de logado, continua funcionando offline

**Por que precisa publicar num endereço na internet:**
O Safari do iPhone não permite adicionar um arquivo local à tela de início, e o armazenamento do progresso não funciona de forma confiável em arquivo aberto direto do aparelho. Publicar uma vez resolve os dois problemas de uma vez, e depois o app funciona sem rede.

**O que precisa ir junto:**

| Arquivo / pasta | Para que serve |
|---|---|
| `index.html` | O app: HTML, CSS e JS |
| `sw.js` | Guarda o app no aparelho para funcionar offline |
| `manifest.json` | Define nome, cores e ícone do app |
| `icone-192.png`, `icone-512.png`, `apple-touch-icon.png` | Ícones |
| `concursos.json` | Data da prova, composição, regra de aprovação |
| `supabase.json` | Endereço da conta — **obrigatório**: sem ele, ninguém consegue logar, e login é exigido para entrar no app |
| `banco/` | **A pasta inteira**, com as questões — sem ela o app cai numa tela de erro |

Não precisa ir: os arquivos `.ps1`, `.py`, `FASES.md`, `CLAUDE.md`, a pasta
`supabase/` (SQL) nem o `offline.html`. São ferramentas de desenvolvimento —
publicá-los junto não quebra nada, só deixa o site com arquivos que ninguém vai
usar por ali.

Se algum dos itens da tabela ficar de fora, o app abre, mas não funciona —
ou não funciona offline.

---

## Parte 1 — Publicar (10 minutos, uma vez só)

### Caminho A — Netlify (mais rápido)

**1.** Crie a conta gratuita primeiro, em `app.netlify.com/signup`.
Pode ser com e-mail ou com conta do GitHub. Não precisa cartão.

> ⚠️ **Faça isso antes de subir os arquivos.** Sites publicados sem conta expiram em 1 hora e somem. Já logado, o site é seu e fica no ar por tempo indeterminado.

**2.** Já logado, vá em `app.netlify.com/drop`.

**3.** Arraste a **pasta do projeto inteira** para a área indicada na página
(o Netlify Drop aceita pasta, não precisa compactar). Confira que a pasta
`banco/` está visível dentro dela antes de arrastar.

**4.** Aguarde alguns segundos. Vai aparecer um endereço tipo:
`https://palavra-aleatoria-12345.netlify.app`

**5.** Abra esse endereço no navegador. Você deve ver a tela de **entrar/criar conta** — não a tela inicial ainda. Isso é esperado: login é obrigatório, e a Parte 3 explica o resto.

**6.** Se quiser um nome melhor: no painel do Netlify, vá em **Site configuration → Change site name** e escolha algo como `prova-enfermagem-vr`. O endereço vira `https://prova-enfermagem-vr.netlify.app`.

**7.** Anote o endereço num lugar seguro. Ele é a chave de tudo.

### Caminho B — GitHub Pages (mais durável)

Vale a pena se você já tem conta no GitHub ou quer algo que dure anos. Com a
pasta `banco/` tendo várias dezenas de arquivos, é mais confiável publicar por
`git push` do que arrastando pastas pela interface do site.

**1.** Crie um repositório novo em `github.com/new`. Pode ser público ou
privado — nada no repositório é secreto (a chave em `supabase.json` é pública
por design), mas privado evita que gente de fora encontre por acaso. **Não**
marque as opções de criar `README`, `.gitignore` ou licença — um repositório
vazio evita conflito na hora de enviar os arquivos.

**2.** No computador, dentro da pasta do projeto:

```bash
git remote add origin git@github.com:SEU-USUARIO/NOME-DO-REPOSITORIO.git
git branch -M main
git push -u origin main
```

**3.** Vá em **Settings → Pages**. Em "Source", escolha **Deploy from a
branch**; em "Branch", escolha **main** e a pasta **/ (root)**. Clique em
**Save**.

**4.** Espere de 1 a 3 minutos e recarregue a página. Vai aparecer o endereço:
`https://seu-usuario.github.io/nome-do-repositorio/`

**Para atualizar depois** (nova versão do app ou questões novas): `git add -A`, `git commit` e `git push` — o GitHub Pages republica sozinho em 1 a 3 minutos.

---

## Parte 2 — Instalar no iPhone (2 minutos)

**1.** Abra o endereço no **Safari**.
Precisa ser o Safari. Chrome, Firefox e outros navegadores do iPhone não oferecem "Adicionar à Tela de Início" da mesma forma.

**2.** Toque no botão **Compartilhar** (o quadrado com a seta para cima, na barra inferior).

**3.** Role a lista e toque em **Adicionar à Tela de Início**.

**4.** Confirme o nome (vem "Flashcard") e toque em **Adicionar**.

**5.** Feche o Safari. Abra o app pelo ícone novo na tela de início.
Ele abre em tela cheia, sem barra de navegador — como um aplicativo normal.

**6.** **Passo mais importante:** ainda **com internet**, navegue um pouco pelo app. Toque em Estatísticas, em Simulado, volte ao início. É nesse momento que o service worker termina de guardar tudo no aparelho.

**7.** Confira em **Ajustes → Uso offline**. Deve estar escrito: *"App guardado no aparelho: funciona sem internet."*

---

## Parte 3 — Criar conta e esperar liberação

**Login é obrigatório para entrar no app.** Sem ele, nem a tela inicial aparece. E o cadastro, mesmo sendo aberto pra qualquer e-mail, não libera sozinho — alguém precisa aprovar você depois.

**1.** Na tela de entrar/criar conta, toque em **Criar conta**. Preencha e-mail e uma senha seguem — não precisa ser convidado antes, qualquer e-mail funciona.

**2.** Depois de criar, você cai numa tela **"Conta aguardando aprovação"**. Isso é normal, não é erro. Avise quem administra o app (mande o e-mail que você usou) para que ele te libere.

**3.** Quando avisarem que liberaram, toque em **"Verificar de novo"** na própria tela de espera — ou feche e abra o app de novo.

**4.** Na primeira vez que entra de verdade, o app pergunta **qual concurso você estuda** (dá pra marcar mais de um). Só depois disso ele carrega o banco de questões e mostra a tela inicial. Se marcar errado ou quiser mudar depois, é só ir em Ajustes → Concursos.

> Depois desse primeiro login, o app guarda a sessão no aparelho e continua abrindo offline normalmente — você não vai precisar repetir isso, a não ser que saia da conta ou apague os dados do Safari.

---

## Parte 4 — Testar se está mesmo funcionando

Faça este teste antes de confiar no app. Leva 1 minuto e evita descobrir o problema no meio do mar. **Faça isto depois da Parte 3** — sem ter logado pelo menos uma vez com internet, o app não abre nem em modo avião.

**1.** Ative o **Modo Avião** no iPhone.

**2.** Abra o app pelo ícone da tela de início.

**3.** Verifique:
- [ ] A tela inicial carrega normalmente (não a tela de login, de espera nem a de escolher concurso)
- [ ] Em "Questões no app" aparece um número (876, ou mais se o banco cresceu)
- [ ] O botão "Estudar agora" abre uma questão
- [ ] Responder a questão mostra a explicação e a fonte
- [ ] Voltar ao início e a meta do dia subiu

**4.** Feche o app completamente (deslize para cima na tela de apps abertos), abra de novo e veja se o progresso continua lá.

Se tudo passou, está pronto. Pode desligar o modo avião.

---

## Parte 5 — Primeiro uso

**1.** A meta diária não se configura mais — ela é sempre o total de questões da prova do concurso em foco (por exemplo, 70 no vestibular de Enfermeiro). Aparece pronta na tela inicial, em "Meta de hoje".

**2.** Toque em **Estudar agora**.

**3.** Ao responder cada questão, use os botões com honestidade:
- **Sabia** — você tinha certeza. A questão vai para a caixa seguinte e volta mais tarde.
- **Chutei** — acertou por sorte ou por eliminação. A questão volta para a caixa 1, como se tivesse errado. **Este botão é o que faz o app funcionar.** Se você marcar "Sabia" no que chutou, vai chegar na prova achando que domina o que não domina.

**4.** Uma vez por semana, faça um **Simulado**: 70 questões, 3 horas, sem gabarito até o fim. Ele aplica a regra do edital — mínimo de 35 pontos e nenhuma área zerada.

**5.** Em **Estatísticas**, os tópicos aparecem do mais fraco para o mais forte. É a sua lista de prioridades, atualizada sozinha.

---

## Parte 6 — Backup (opcional, mas bom ter)

Sua conta já sincroniza o progresso com o servidor — trocar de aparelho e logar de novo traz tudo de volta sozinho. Não existe mais aviso nem rotina obrigatória; isto aqui é só uma cópia extra pra quando o servidor ficar fora do ar ou algo sair errado do lado de lá.

**Se quiser fazer, 5 segundos:**

1. Abra **Ajustes → Backup**
2. Toque em **Baixar arquivo** (salva um `.json` no app Arquivos)
   ou em **Copiar texto** (copia o progresso, para você colar nas Notas ou mandar por e-mail para si mesmo)

**Para restaurar** (celular novo, ou depois de reinstalar):
Instale o app de novo pelos passos da Parte 2, faça login com a mesma conta (a sincronização deve trazer o progresso sozinha) e, se algo faltar, use **Ajustes → Backup → Restaurar de arquivo** ou **Restaurar de texto**.

---

## Parte 7 — Atualizar quando houver questões novas

Quando você receber uma versão nova do app:

**1.** Confira se o arquivo `sw.js` já está com um número de versão diferente do anterior. Abra o arquivo num editor de texto e procure a linha:

```javascript
const VERSAO = "v19-sincronizacao";
```

Se estiver igual à versão que já está publicada, troque o número (por exemplo, para `"v20-..."`). **Sem isso, o iPhone continua servindo a versão antiga e as questões novas não aparecem.** (Desde a v14 o service worker já busca a rede primeiro, então isso raramente trava — mas trocar o número continua sendo o hábito certo.)

**2.** Publique os arquivos novos:
- **Netlify:** entre no painel, escolha o site, vá na aba **Deploys** e arraste a pasta do projeto de novo na área de arrastar do rodapé da página. O endereço continua o mesmo.
- **GitHub:** `git add -A`, `git commit -m "..."`, `git push`.

**3.** No iPhone, feche o app completamente e abra de novo **com internet**. Aguarde alguns segundos e feche e abra mais uma vez.

**4.** Confirme na tela inicial que o número em "Questões no app" mudou.

Seu progresso não se perde na atualização — ele fica guardado separado das questões.

---

## Problemas comuns

| Sintoma | Causa provável | Solução |
|---|---|---|
| Não aparece "Adicionar à Tela de Início" | Não está no Safari | Abra o endereço no Safari |
| O app não abre sem internet | O service worker não terminou de guardar, OU você nunca fez o primeiro login | Abra com internet, faça login (Parte 3) e navegue por 30 segundos; confira em Ajustes → Uso offline |
| Fico preso na tela "Conta aguardando aprovação" | Ninguém aprovou sua conta ainda | Avise quem administra o app (seu e-mail de cadastro); depois toque em "Verificar de novo" |
| Criei conta e não aparece nada pra aprovar | Quem administra ainda não olhou a tela "Aprovar contas" | Confirme com ele/ela que o e-mail está certo |
| Continua mostrando o número antigo de questões | Cache com a mesma versão | Troque o `VERSAO` no `sw.js`, publique de novo, feche e abra o app duas vezes |
| O progresso sumiu | Dados limpos ou app reinstalado | Restaure pelo backup em Ajustes |
| A página abre com uma tela de erro em vez do app | Faltou a pasta `banco/`, o `concursos.json`, ou eles ficaram fora da raiz do site | Confira a lista de arquivos e pastas no início deste tutorial |
| O site do Netlify sumiu | Foi publicado sem conta e expirou | Refaça a publicação já logado |
| Ajustes diz que não consegue salvar | O app está aberto como arquivo local | Use o endereço publicado, não o arquivo |

---

## Resumo em 8 linhas

1. Criar conta no Netlify (ou GitHub) e publicar a pasta do projeto
2. Abrir o endereço no Safari do iPhone
3. Compartilhar → Adicionar à Tela de Início
4. Criar sua conta no app e esperar quem administra te aprovar
5. Navegar 30 segundos com internet, já logado
6. Testar no modo avião
7. Estudar suas questões diárias
8. Fazer backup toda semana, mesmo com a sincronização ligada
