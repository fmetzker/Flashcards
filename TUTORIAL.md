# Tutorial — publicar e instalar o app

## O que precisa ir junto na publicação

| Arquivo / pasta | Para que serve |
|---|---|
| `index.html` | O app: HTML, CSS e JS |
| `sw.js` | Guarda o app no aparelho para funcionar offline |
| `manifest.json` | Nome, cores e ícone do app |
| `icone-192.png`, `icone-512.png`, `apple-touch-icon.png` | Ícones |
| `concursos.json` | Data da prova, composição, regra de aprovação |
| `supabase.json` | Endereço da conta — obrigatório, sem ele ninguém consegue logar |
| `banco/` | **A pasta inteira**, com as questões — sem ela o app cai numa tela de erro |

Não precisa ir: `.ps1`, `.py`, `.md`, a pasta `supabase/` (SQL) nem o
`offline.html`. Não quebra nada se forem, só sobram arquivos que ninguém usa
por ali.

---

## Parte 1 — Publicar

### Netlify (mais rápido)

**1.** Crie conta em `app.netlify.com/signup` (e-mail ou GitHub, sem
cartão) — **antes** de subir os arquivos, senão o site expira em 1 hora.

**2.** Já logado, vá em `app.netlify.com/drop` e arraste a **pasta do
projeto inteira** (confira que `banco/` está visível antes de arrastar).

**3.** Aparece um endereço tipo `https://palavra-aleatoria.netlify.app`.
Se quiser um nome melhor: **Site configuration → Change site name**.

### GitHub Pages (mais durável)

Vale a pena se você já tem conta no GitHub — mais confiável que arrastar
pasta, já que `banco/` tem várias dezenas de arquivos.

**1.** Crie um repositório vazio em `github.com/new` (sem README/.gitignore).

**2.** No computador, dentro da pasta do projeto:

```bash
git remote add origin git@github.com:SEU-USUARIO/NOME-DO-REPOSITORIO.git
git branch -M main
git push -u origin main
```

**3.** **Settings → Pages** → Source: **Deploy from a branch** → Branch:
**main**, pasta **/ (root)** → **Save**. Em 1-3 minutos o endereço aparece:
`https://seu-usuario.github.io/nome-do-repositorio/`.

**Para atualizar depois:** `git add -A`, `git commit`, `git push` — republica
sozinho. Lembre de subir a `VERSAO` em `sw.js` quando mexer no `index.html`,
senão o aparelho pode continuar servindo a versão antiga.

---

## Parte 2 — Instalar no iPhone

**1.** Abra o endereço no **Safari** (precisa ser o Safari — outros
navegadores do iPhone não oferecem "Adicionar à Tela de Início" do mesmo
jeito).

**2.** Toque em **Compartilhar** → **Adicionar à Tela de Início** →
confirme o nome ("Flashcard") → **Adicionar**.

**3.** Abra o app pelo ícone novo. Ele abre em tela cheia, como um
aplicativo normal.

**4.** **Importante:** ainda **com internet**, navegue um pouco (Estatísticas,
Simulado, volta ao início). É nesse momento que o app termina de se guardar
no aparelho para funcionar offline depois.

---

## Parte 3 — Criar conta

Login é obrigatório para entrar. O cadastro é aberto (qualquer e-mail), mas
a conta **precisa ser aprovada** por quem administra antes de liberar.

**1.** Na tela de entrar, toque em **Criar conta** — e-mail e senha.

**2.** Você cai numa tela de espera. Avise quem administra o app (o e-mail
que você usou) para que te aprove.

**3.** Aprovado, toque em **"Verificar de novo"** (ou reabra o app).

**4.** Na primeira entrada de verdade, o app pergunta qual concurso você
estuda (dá para marcar mais de um — e mudar depois em Ajustes → Concursos).

Depois disso a sessão fica salva no aparelho — não precisa logar de novo, a
não ser que saia da conta.

---

## Parte 4 — Testar e usar

**Antes de confiar no app:** ative o modo avião, abra pelo ícone, confira
que a tela inicial carrega, responda uma questão, feche e reabra o app e
veja se o progresso continua lá.

**No dia a dia:**
- **Estudar agora** abre a fila do dia. Responda com honestidade: **Sabia**
  se tinha certeza, **Chutei** se acertou por sorte ou eliminação — esse
  botão é o que faz a repetição espaçada funcionar de verdade.
- A meta diária é sempre o total de questões da prova (não dá para
  configurar) e só conta o que é do concurso em foco.
- **Estatísticas** mostra seus tópicos mais fracos primeiro — é a lista de
  prioridades, atualizada sozinha.
- **Simulado** aplica a composição e a regra de aprovação do edital.
- Se encontrar um cartão com erro, use **"Reportar problema"** na explicação
  da questão.

**Backup:** a conta já sincroniza sozinha. Em Ajustes → Backup dá para
baixar uma cópia extra a qualquer momento — não é obrigatório, é só rede de
segurança para quando o servidor ficar fora do ar.

---

## Problemas comuns

| Sintoma | Causa provável | Solução |
|---|---|---|
| Não aparece "Adicionar à Tela de Início" | Não está no Safari | Abra o endereço no Safari |
| O app não abre sem internet | O primeiro login com internet nunca aconteceu | Abra com internet, faça login e navegue 30 segundos |
| Preso na tela "Conta aguardando aprovação" | Ninguém aprovou ainda | Avise quem administra; depois toque em "Verificar de novo" |
| Continua mostrando questões antigas | Cache com a mesma versão | Quem publicou precisa subir a `VERSAO` em `sw.js` |
| A página abre com tela de erro | Faltou a pasta `banco/` ou o `concursos.json` na publicação | Confira a lista de arquivos no início deste tutorial |
| Ajustes diz que não consegue salvar | O app foi aberto como arquivo local, não pelo endereço publicado | Use o endereço publicado |
