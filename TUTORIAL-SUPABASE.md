# Tutorial — configurar conta e sincronização (Supabase)

Este tutorial é diferente do `TUTORIAL.md`: aquele é para qualquer pessoa da
família instalar o app pronto. Este é para **você**, configurando a
infraestrutura uma vez só. Ninguém mais vai precisar repetir isto — quem só
usa o app faz login normalmente, sem tocar em nada aqui.

**Login passou a ser obrigatório para entrar no app** — sem `supabase.json`
preenchido com um projeto de verdade, ninguém consegue nem abrir a tela
inicial (a tela de login aparece, mas sem servidor pra falar com ela). Não
dá para pular este tutorial se o app vai ser usado por mais alguém além de
você. A única exceção é o `offline.html` (arquivo único, sem rede), que
nunca exigiu conta e continua sem exigir.

Tempo: uns 15 minutos, feito uma vez.

---

## Parte 1 — Criar o projeto

**1.** Acesse **[supabase.com](https://supabase.com)** e crie uma conta —
e-mail ou GitHub, sem cartão.

**2.** Clique em **New project**.

**3.** Preencha:
- **Name**: algo como `flashcards-enf`
- **Database Password**: gere uma senha forte e guarde num lugar seguro
  (gerenciador de senhas, por exemplo). Não é a mesma coisa que as chaves da
  Parte 5 — essa senha é para acesso direto ao banco, raramente usada
- **Region**: **South America (São Paulo)** — é a que dá menor latência

**4.** Clique em **Create new project**. Leva alguns minutos para provisionar.

---

## Parte 2 — Rodar o schema

O schema cria as tabelas, as regras de acesso (RLS) e as funções que o app
usa. Está pronto no repositório — você só cola e roda.

**1.** No menu lateral do projeto, abra **SQL Editor**.

**2.** Clique em **New query**.

**3.** Abra o arquivo [supabase/schema.sql](supabase/schema.sql) deste
repositório, copie o conteúdo **inteiro** (do primeiro comentário até a
última linha), cole no editor.

**4.** Clique em **Run** (ou `Ctrl+Enter` / `Cmd+Enter`).

**5.** Confira o resultado: deve aparecer algo como "Success. No rows
returned" na parte de baixo. Se aparecer erro em vermelho, pare aqui e me
mande a mensagem antes de continuar.

> O arquivo é **idempotente** — rodar de novo no futuro (depois de uma
> atualização) não quebra nada, só adiciona o que for novo.

---

## Parte 3 — Conferir que a segurança está de pé

Este passo não muda nada no banco — ele só testa e desfaz tudo no final
(`rollback`). É seguro rodar quantas vezes quiser.

**1.** Ainda no SQL Editor, abra outra **New query**.

**2.** Copie o conteúdo inteiro de
[supabase/conferir.sql](supabase/conferir.sql), cole, clique em **Run**.

**3.** O resultado aparece como uma lista de mensagens `NOTICE` (na aba
**Messages**, não na aba de resultado em tabela). Leia procurando por duas
palavras:

- **`OK`** — o esperado, é a maioria das linhas
- **`FALHOU`** ou **`WARNING`** — problema. Se aparecer qualquer uma, copie a
  mensagem inteira e me mande antes de seguir para a próxima parte

Se só houver `OK`, a fundação de segurança está correta: cada pessoa só
enxerga o próprio progresso, o log de respostas não pode ser apagado nem
forjado em nome de outra pessoa, e a lista de quem pode revisar propostas não
é visível por ninguém de fora.

---

## Parte 4 — Convidar as pessoas do grupo

O cadastro é fechado: só quem estiver nesta lista consegue criar conta.

**1.** No SQL Editor, nova query:

```sql
insert into public.convidados (email, nome) values
  ('franciscometzker@gmail.com', 'Francisco'),
  ('email-da-sua-esposa@exemplo.com', 'Esposa')
on conflict (email) do nothing;
```

**2.** Troque pelos e-mails de verdade e rode. `on conflict do nothing`
significa que rodar de novo (para adicionar mais alguém depois) não duplica
quem já está na lista — só acrescenta o novo.

---

## Parte 5 — Pegar a URL e a chave pública

**Aqui é fácil confundir duas chaves parecidas — leia com atenção.**

**1.** No menu lateral, **Project Settings** (ícone de engrenagem) → **API Keys**.

**2.** Você vai ver a **Project URL** (algo como
`https://xxxxxxxxxxxx.supabase.co`) e duas chaves:

| Chave | Nome atual | Nome antigo (projetos mais velhos) | Pode ficar pública? |
|---|---|---|---|
| A que você quer | `sb_publishable_...` | `anon` `public` (formato JWT, começa com `eyJ`) | **Sim** — é feita para ir no cliente |
| A que NUNCA deve sair daqui | `sb_secret_...` | `service_role` (formato JWT) | **Não** — ignora toda a proteção (RLS) |

As duas ficam uma do lado da outra no painel, com nomes parecidos. Se colar a
errada em qualquer arquivo do projeto ou aqui no chat, o `validar.ps1` acusa
— mas o mais seguro é simplesmente conferir o prefixo (`sb_publishable_` ou
`anon`) antes de copiar.

**3.** Copie a **Project URL** e a chave **pública** (`sb_publishable_...` ou
`anon`).

---

## Parte 6 — Preencher supabase.json

**1.** Abra [supabase.json](supabase.json) neste repositório.

**2.** Troque os dois valores de exemplo pelos que você copiou:

```json
{
  "url": "https://xxxxxxxxxxxx.supabase.co",
  "anonKey": "sb_publishable_...."
}
```

**3.** Salve, rode `validar.ps1` para conferir que não sobrou nenhuma chave
errada em lugar nenhum, e publique (commit + push, ou peça para eu fazer).

---

## Parte 7 — Virar revisor

Só quem está na tabela `revisores` vê a tela "Revisar propostas" no app.
Normalmente é só você.

**1.** Primeiro, crie sua conta pelo próprio app — abra o app publicado, ele
já vai te mostrar a tela de login direto (é obrigatória desde que o login
passou a ser exigido para entrar). Toque em "Criar conta" com um dos e-mails
convidados na Parte 4.

**2.** De volta ao SQL Editor:

```sql
insert into public.revisores (user_id)
select id from auth.users where email = 'seu-email-aqui@exemplo.com'
on conflict (user_id) do nothing;
```

Troque pelo e-mail que você usou para logar. A busca por e-mail evita ter que
ir em Authentication → Users copiar UUID na mão.

**3.** Se quiser conferir que funcionou, rode:

```sql
select u.email from public.revisores r join auth.users u on u.id = r.user_id;
```

Deve listar seu e-mail.

---

## Parte 8 — Testar pelo app

**1.** Abra o app publicado. Deve aparecer a tela de login direto — entre com
o e-mail e senha que você criou na Parte 7.

**2.** Depois de entrar, vá em **Ajustes → Conta**: deve aparecer "Conectado
como [seu e-mail]" e o status de sincronização.

**3.** Volte à tela inicial. Devem aparecer dois itens novos no menu:
**"Propor questão"** e **"Revisar propostas"** (o segundo só porque você é
revisor).

**4.** Teste proposta e revisão:
- Em "Propor questão", preencha um exemplo qualquer e envie
- Em "Revisar propostas", ela deve aparecer na lista — aprove ou rejeite

Se tudo isso funcionar, a configuração está completa.

---

## Problemas comuns

| Sintoma | Causa provável | Solução |
|---|---|---|
| `conferir.sql` mostra `FALHOU` | Alguma policy do schema não ficou como esperado | Copie a mensagem e peça ajuda antes de usar o app com conta |
| "Database error saving new user" ao criar conta | E-mail não está em `convidados`, ou a Parte 4 não rodou | Confira a Parte 4; o e-mail precisa bater exatamente |
| Login funciona mas "Revisar propostas" não aparece | A Parte 7 não rodou, ou rodou antes de o login existir | Repita a Parte 7 depois de ter feito login pelo menos uma vez |
| Ajustes → Conta diz "Sincronização ainda não configurada" | `supabase.json` ainda tem os valores de exemplo | Repita a Parte 6 |
| Tela de login diz "sincronização ainda não configurada" e não tem formulário | `supabase.json` ainda tem os valores de exemplo — sem ele, ninguém consegue entrar no app | Repita a Parte 6 |
| Colei a chave errada em algum lugar | Confundiu `sb_secret_` com `sb_publishable_` | Rode `validar.ps1` — ele acusa; troque pela pública e considere regenerar a secreta no painel |
