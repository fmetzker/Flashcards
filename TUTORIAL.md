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
- Internet apenas para a publicação e a primeira abertura — depois disso o app roda offline

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
| `supabase.json` | Endereço da conta (opcional — sem ele, conta fica indisponível) |
| `banco/` | **A pasta inteira**, com as 852 questões — sem ela o app cai numa tela de erro |

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

**5.** Abra esse endereço no navegador. Você deve ver a tela inicial do app, com a contagem de dias e a cartela de quadradinhos.

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

**4.** Confirme o nome (vem "Prova 20/09") e toque em **Adicionar**.

**5.** Feche o Safari. Abra o app pelo ícone novo na tela de início.
Ele abre em tela cheia, sem barra de navegador — como um aplicativo normal.

**6.** **Passo mais importante:** ainda **com internet**, navegue um pouco pelo app. Toque em Estatísticas, em Simulado, volte ao início. É nesse momento que o service worker termina de guardar tudo no aparelho.

**7.** Confira em **Ajustes → Uso offline**. Deve estar escrito: *"App guardado no aparelho: funciona sem internet."*

---

## Parte 3 — Testar se está mesmo funcionando

Faça este teste antes de confiar no app. Leva 1 minuto e evita descobrir o problema no meio do mar.

**1.** Ative o **Modo Avião** no iPhone.

**2.** Abra o app pelo ícone da tela de início.

**3.** Verifique:
- [ ] A tela inicial carrega normalmente
- [ ] Em "Questões no app" aparece **852**
- [ ] O botão "Estudar agora" abre uma questão
- [ ] Responder a questão mostra a explicação e a fonte
- [ ] Voltar ao início e a meta do dia subiu

**4.** Feche o app completamente (deslize para cima na tela de apps abertos), abra de novo e veja se o progresso continua lá.

Se tudo passou, está pronto. Pode desligar o modo avião.

---

## Parte 4 — Primeiro uso

**1.** Vá em **Ajustes** e confirme a **meta diária**. Está em 35, que corresponde a cerca de 45 minutos por dia. Se você tiver menos tempo em algum período, reduza — meta batida com constância vale mais que meta grande abandonada.

**2.** Volte ao início e toque em **Estudar agora**.

**3.** Ao responder cada questão, use os botões com honestidade:
- **Sabia** — você tinha certeza. A questão vai para a caixa seguinte e volta mais tarde.
- **Chutei** — acertou por sorte ou por eliminação. A questão volta para a caixa 1, como se tivesse errado. **Este botão é o que faz o app funcionar.** Se você marcar "Sabia" no que chutou, vai chegar na prova achando que domina o que não domina.

**4.** Uma vez por semana, faça um **Simulado**: 70 questões, 3 horas, sem gabarito até o fim. Ele aplica a regra do edital — mínimo de 35 pontos e nenhuma área zerada.

**5.** Em **Estatísticas**, os tópicos aparecem do mais fraco para o mais forte. É a sua lista de prioridades, atualizada sozinha.

---

## Parte 5 — Backup (não pule esta parte)

O progresso fica salvo **só no seu iPhone**. Se você trocar de aparelho, reinstalar o app ou limpar os dados do Safari, ele some.

**Rotina semanal, 5 segundos:**

1. Abra **Ajustes → Backup**
2. Toque em **Baixar arquivo** (salva um `.json` no app Arquivos)
   ou em **Copiar texto** (copia o progresso, para você colar nas Notas ou mandar por e-mail para si mesmo)

O app avisa sozinho na tela inicial quando passam 7 dias sem backup.

**Para restaurar** (celular novo, ou depois de reinstalar):
Instale o app de novo pelos passos da Parte 2, vá em **Ajustes → Backup** e use **Restaurar de arquivo** ou **Restaurar de texto**.

---

## Parte 6 — Atualizar quando houver questões novas

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
| O app não abre sem internet | O service worker não terminou de guardar | Abra com internet e navegue por 30 segundos; confira em Ajustes → Uso offline |
| Continua mostrando o número antigo de questões | Cache com a mesma versão | Troque o `VERSAO` no `sw.js`, publique de novo, feche e abra o app duas vezes |
| O progresso sumiu | Dados limpos ou app reinstalado | Restaure pelo backup em Ajustes |
| A página abre com uma tela de erro em vez do app | Faltou a pasta `banco/`, o `concursos.json`, ou eles ficaram fora da raiz do site | Confira a lista de arquivos e pastas no início deste tutorial |
| O site do Netlify sumiu | Foi publicado sem conta e expirou | Refaça a publicação já logado |
| Ajustes diz que não consegue salvar | O app está aberto como arquivo local | Use o endereço publicado, não o arquivo |

---

## Resumo em 7 linhas

1. Criar conta no Netlify
2. Arrastar o zip em `app.netlify.com/drop`
3. Abrir o endereço no Safari do iPhone
4. Compartilhar → Adicionar à Tela de Início
5. Navegar 30 segundos com internet
6. Testar no modo avião
7. Estudar 35 questões por dia e fazer backup toda semana
