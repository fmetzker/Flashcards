-- ============================================================================
-- Fase 3a — fundação do backend
--
-- Cole este arquivo inteiro no SQL Editor do Supabase e execute. É idempotente:
-- rodar de novo não quebra nada.
--
-- O QUE **NÃO** ESTÁ AQUI, DE PROPÓSITO: as questões, as matérias e os
-- concursos. Eles continuam em banco/*.json e concursos.json, versionados no
-- repositório e conferidos por validar.ps1. São idênticos para todo mundo e
-- nunca variam por usuário — pôr no Postgres seria pagar consulta para ler
-- conteúdo estático e ainda exigir uma tela de administração (isso é a Fase 4).
--
-- Aqui mora só o que é de cada pessoa: conta, preferências e progresso.
-- ============================================================================


-- ----------------------------------------------------------------------------
-- 1. Allowlist de convidados
--
-- O grupo é fechado (família e amigos). Sem isto, qualquer um com a chave anon
-- — que é pública por design e vai dentro do cliente — poderia se cadastrar.
-- ----------------------------------------------------------------------------
create table if not exists public.convidados (
  email        text primary key,
  nome         text,
  convidado_em timestamptz not null default now()
);

alter table public.convidados enable row level security;

-- Nenhuma policy é criada para esta tabela, e isso é intencional: com RLS
-- ligada e zero policies, a API nega tudo. A lista de e-mails do grupo não
-- pode ser enumerável por quem tiver a chave anon. Só o gatilho abaixo lê,
-- e ele roda como security definer.
revoke all on public.convidados from anon, authenticated;


-- Gatilho que barra cadastro de quem não foi convidado.
-- Falha FECHADO: se o e-mail não estiver na lista, o cadastro é recusado.
create or replace function public.exigir_convite()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if not exists (
    select 1 from public.convidados c
    where lower(c.email) = lower(new.email)
  ) then
    raise exception 'E-mail não convidado: %', new.email
      using errcode = 'insufficient_privilege';
  end if;
  return new;
end;
$$;

-- DESLIGADO: o cadastro deixou de ser fechado. Qualquer pessoa pode criar
-- conta; o controle passou a ser DEPOIS do cadastro, via perfis.status
-- (seção 2.1) — a conta nasce 'pendente' e não enxerga nada até um aprovador
-- liberar. A função e a tabela `convidados` ficam de pé, sem uso, para o caso
-- de você querer voltar ao modelo fechado: basta recriar o gatilho abaixo.
drop trigger if exists exigir_convite on auth.users;


-- ----------------------------------------------------------------------------
-- 2. Perfis
--
-- Uma linha por conta. Guarda nome, concurso escolhido e meta diária — as
-- mesmas preferências que hoje vivem no localStorage de cada perfil local.
-- Tabela única em vez de perfis + preferencias separadas: para 5 a 10 pessoas,
-- separar só multiplica policies para manter certas.
-- ----------------------------------------------------------------------------
create table if not exists public.perfis (
  id            uuid primary key references auth.users(id) on delete cascade,
  nome          text not null default '',
  concurso      text,                       -- id de um concurso de concursos.json
  meta          smallint not null default 35 check (meta between 5 and 200),
  ultimo_backup date,
  atualizado_em timestamptz not null default now()
);

alter table public.perfis enable row level security;

drop policy if exists "perfil próprio: ler"       on public.perfis;
drop policy if exists "perfil próprio: criar"     on public.perfis;
drop policy if exists "perfil próprio: atualizar" on public.perfis;

create policy "perfil próprio: ler"
  on public.perfis for select using (id = auth.uid());
create policy "perfil próprio: criar"
  on public.perfis for insert with check (id = auth.uid());
create policy "perfil próprio: atualizar"
  on public.perfis for update using (id = auth.uid()) with check (id = auth.uid());
-- Sem policy de delete: apagar conta é operação de painel, não de aplicativo.


-- Cria o perfil sozinho quando a conta nasce, para não depender de o cliente
-- lembrar de fazer isso logo depois do cadastro.
-- O e-mail é copiado para cá porque auth.users não é legível pela API, e a
-- tela de aprovação precisa mostrar QUEM está pedindo acesso. Não vaza nada:
-- a RLS de perfis só deixa ver a própria linha, ou todas se for aprovador.
create or replace function public.criar_perfil()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.perfis (id, nome, email)
  values (
    new.id,
    coalesce(nullif(new.raw_user_meta_data->>'nome', ''), split_part(new.email, '@', 1)),
    new.email
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists criar_perfil on auth.users;
create trigger criar_perfil
  after insert on auth.users
  for each row execute function public.criar_perfil();


-- ----------------------------------------------------------------------------
-- 2.1 Aprovação de contas
--
-- O cadastro é aberto (o gatilho exigir_convite foi desligado na seção 1),
-- mas a conta nasce 'pendente' e não enxerga NADA até um aprovador liberar.
-- O portão fica no servidor, não na tela: cada tabela de dados exige
-- conta_aprovada() na policy. Esconder o botão no app não protegeria nada.
--
-- Precisa vir ANTES das seções 3, 4 e 8: as policies de lá chamam
-- conta_aprovada(), e o Postgres exige que a função já exista na hora de
-- criar a policy. Mesma lição que a seção 7.1 aprendeu com sou_revisor().
-- ----------------------------------------------------------------------------

-- e-mail para a tela de aprovação (ver comentário em criar_perfil, acima)
alter table public.perfis add column if not exists email text;

-- Guardado assim, em bloco, e não com um simples "add column ... default":
-- adicionar a coluna preenche TODAS as linhas existentes com 'pendente', o
-- que trancaria pra fora quem já usava o app. O backfill para 'aprovado'
-- precisa rodar junto, e só na primeira vez — este arquivo é idempotente e
-- feito para ser reexecutado, e um update solto aprovaria, a cada execução,
-- todo mundo que estivesse esperando na fila naquele momento.
do $$
begin
  if not exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'perfis' and column_name = 'status'
  ) then
    alter table public.perfis
      add column status text not null default 'pendente'
        check (status in ('pendente','aprovado','rejeitado')),
      add column aprovado_por uuid references auth.users(id),
      add column aprovado_em  timestamptz;
    -- quem já tinha conta antes desta mudança entrou quando o cadastro era
    -- fechado por convite: já estava autorizado, não faz sentido barrar agora
    update public.perfis set status = 'aprovado';
  end if;
end $$;

-- backfill de e-mail para as contas criadas antes desta coluna existir
update public.perfis p
   set email = u.email
  from auth.users u
 where u.id = p.id and p.email is null;

create index if not exists perfis_por_status on public.perfis (status, atualizado_em);


-- Quem pode aprovar contas. Mesmo desenho de `revisores`: RLS ligada, zero
-- policies, revoke all — ninguém lê a lista pela API, nem as policies que
-- dependem dela (por isso sou_aprovador() é security definer).
create table if not exists public.aprovadores (
  user_id   uuid primary key references auth.users(id) on delete cascade,
  criado_em timestamptz not null default now()
);

alter table public.aprovadores enable row level security;
revoke all on public.aprovadores from anon, authenticated;

create or replace function public.sou_aprovador()
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (select 1 from public.aprovadores where user_id = auth.uid());
$$;

grant execute on function public.sou_aprovador() to authenticated;

-- "Minha conta já foi liberada?" — security definer pelo mesmo motivo de
-- sou_revisor(): uma policy que consultasse perfis direto rodaria com o
-- privilégio de quem está consultando e cairia na RLS da própria perfis,
-- criando recursão. Aqui a função lê com privilégio elevado e devolve só um
-- booleano.
create or replace function public.conta_aprovada()
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1 from public.perfis where id = auth.uid() and status = 'aprovado'
  );
$$;

grant execute on function public.conta_aprovada() to authenticated;


-- Só aprovador muda status — e a assinatura de quem decidiu vem do servidor.
-- Sem isto, qualquer pessoa poderia se auto-aprovar com um PATCH direto na
-- API: a policy "perfil próprio: atualizar" existe justamente para deixar a
-- pessoa editar o próprio perfil (nome, meta), e status mora na mesma linha.
create or replace function public.proteger_status_perfil()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.status is distinct from old.status then
    if not public.sou_aprovador() then
      raise exception 'Só um aprovador pode mudar o status de uma conta'
        using errcode = 'insufficient_privilege';
    end if;
    new.aprovado_por := auth.uid();
    new.aprovado_em  := now();
  end if;
  -- e-mail é identidade, não campo editável: é por ele que o aprovador
  -- reconhece quem está pedindo acesso, então não pode ser forjado pelo
  -- cliente. Só congela quando já tem valor — senão bloquearia o próprio
  -- backfill das contas criadas antes desta coluna existir (acima), que
  -- preenche justamente de null para o e-mail de verdade.
  if old.email is not null then new.email := old.email; end if;
  return new;
end;
$$;

drop trigger if exists proteger_status_perfil on public.perfis;
create trigger proteger_status_perfil
  before update on public.perfis
  for each row execute function public.proteger_status_perfil();


-- policies de perfis para o aprovador (as do próprio dono ficam na seção 2)
drop policy if exists "aprovador: ver todos" on public.perfis;
drop policy if exists "aprovador: decidir"   on public.perfis;

create policy "aprovador: ver todos"
  on public.perfis for select using (public.sou_aprovador());
create policy "aprovador: decidir"
  on public.perfis for update using (public.sou_aprovador()) with check (public.sou_aprovador());

-- Recriada aqui, e não na seção 2, porque cita a coluna `status` — que só
-- passa a existir logo acima. Na prática quem cria a linha é o gatilho
-- criar_perfil (security definer, ignora RLS); esta policy é a rede de
-- segurança para o caso de alguém tentar inserir o próprio perfil pela API
-- já nascendo aprovado.
drop policy if exists "perfil próprio: criar" on public.perfis;
create policy "perfil próprio: criar"
  on public.perfis for insert with check (id = auth.uid() and status = 'pendente');


-- ----------------------------------------------------------------------------
-- 2.2 Matérias ativas — Painel de desempenho
--
-- Quais matérias esta conta estuda AGORA: materiasInscritas() no cliente
-- (união das matérias dos concursos inscritos + matérias avulsas marcadas),
-- sincronizado sempre que muda (sincronizarMateriasAtivas() em index.html).
--
-- eventos_resposta é append-only e nunca esquece matéria abandonada: sem
-- isto, o Painel de desempenho não tinha como distinguir "revisão atrasada
-- de verdade" de "cartão de matéria que a conta nem estuda mais" — essa
-- distinção só existia no localStorage de cada aparelho. Escrita já cai na
-- policy "perfil próprio: atualizar" (seção 2) — não precisa de policy
-- nova, só a coluna.
-- ----------------------------------------------------------------------------
alter table public.perfis add column if not exists materias_ativas jsonb not null default '[]'::jsonb;


-- ----------------------------------------------------------------------------
-- 2.3 Marco de reset de progresso — Painel de desempenho
--
-- Instante do último zerar() da conta (null = nunca zerou). eventos_resposta
-- é append-only: o reset limpa o `E` do aparelho, mas NÃO tem como apagar o
-- log aqui (sem policy de update/delete, seção 3 — e um delete apagaria o
-- histórico de todos os aparelhos da conta, não só de quem clicou).
--
-- Este marco é o que faz "zerei meu progresso" valer para a conta inteira, e
-- não só para a tela do aparelho que zerou: o painel e resumo_desempenho
-- (abaixo) ignoram todo evento anterior a ele. Sem isso, uma conta que zerou
-- via 0 atrasadas na própria tela Estatísticas (lê o `E` local, zerado) e 74
-- no painel (lê o servidor, intacto) — dois números certos respondendo a
-- perguntas diferentes, sem nada dizendo qual valia.
--
-- Escrita cai na policy "perfil próprio: atualizar" (seção 2) — não precisa
-- de policy nova. Sincronizado por sincronizarMateriasAtivas() (index.html),
-- junto de materias_ativas.
-- ----------------------------------------------------------------------------
alter table public.perfis add column if not exists progresso_zerado_em timestamptz;


-- ----------------------------------------------------------------------------
-- 3. Eventos de resposta — o log append-only
--
-- Cada resposta vira um evento. Duas decisões que valem explicação:
--
-- `id` é gerado no CLIENTE (uuid). É isso que torna o envio idempotente: se a
-- rede cair no meio e o app reenviar, o insert colide na chave primária em vez
-- de duplicar a resposta.
--
-- `caixa_depois` e `prox` são GRAVADOS, não recalculados. O motor Leitner tem
-- teto dinâmico — proximaData() depende de diasAte(), que muda todo dia. Um
-- "replay" do log daqui a duas semanas produziria um prox diferente do que foi
-- calculado na hora da resposta. Com o resultado gravado no evento, derivar o
-- estado vira "pegar o evento mais recente de cada questão": fiel e simples.
-- ----------------------------------------------------------------------------
create table if not exists public.eventos_resposta (
  id           uuid primary key,
  usuario_id   uuid not null default auth.uid() references auth.users(id) on delete cascade,
  questao_id   text not null check (questao_id ~ '^[0-9a-f]{10}$'),  -- regra 5 do CLAUDE.md
  ts           timestamptz not null,        -- quando a pessoa respondeu (relógio do aparelho)
  resultado    text not null check (resultado in ('sabia','chutei','errei')),
  caixa_depois smallint not null check (caixa_depois between 1 and 8),
  prox         date not null,
  criado_em    timestamptz not null default now()  -- relógio do servidor: cursor do pull
);

-- pull incremental: "me dê o que chegou depois deste instante"
create index if not exists eventos_por_usuario_tempo
  on public.eventos_resposta (usuario_id, criado_em);
-- estado atual: o evento mais recente de cada questão
create index if not exists eventos_por_questao
  on public.eventos_resposta (usuario_id, questao_id, ts desc);

alter table public.eventos_resposta enable row level security;

drop policy if exists "eventos próprios: ler"   on public.eventos_resposta;
drop policy if exists "eventos próprios: criar" on public.eventos_resposta;

-- conta_aprovada() (seção 2.1): conta pendente não lê nem grava nada. É aqui
-- que a aprovação vira portão de verdade — no servidor, não na tela.
create policy "eventos próprios: ler"
  on public.eventos_resposta for select using (usuario_id = auth.uid() and public.conta_aprovada());
create policy "eventos próprios: criar"
  on public.eventos_resposta for insert with check (usuario_id = auth.uid() and public.conta_aprovada());
-- Sem policy de update nem de delete, de propósito: é a AUSÊNCIA delas que
-- torna o log append-only de verdade, no banco, e não só por convenção do app.

-- Painel de desempenho dos alunos: aprovador lê o log de QUALQUER conta, não
-- só o próprio — é o que permite reconstruir o estado de cada aluno (replay
-- do log, mesma lógica de aplicarEventoRemoto() no cliente) sem um blob de
-- estado por conta no servidor. Mesmo molde de "aprovador: ver todos" em
-- perfis (seção 2.1): papel já existente, RLS de policy extra, sem tabela
-- nova. RLS é permissiva por padrão dentro do mesmo comando (select) — esta
-- policy só ACRESCENTA quem mais pode ler, nunca tira o que "eventos
-- próprios: ler" já garante para o dono da conta.
drop policy if exists "eventos: aprovador lê tudo" on public.eventos_resposta;
create policy "eventos: aprovador lê tudo"
  on public.eventos_resposta for select using (public.sou_aprovador());

-- 3.1 Leitner de 8 caixas (eram 5) — index.html:CAIXA_MAX é a outra metade
-- desta constante; os dois lados têm de concordar, e nada os liga automa-
-- ticamente. `create table if not exists`, acima, não altera uma constraint
-- que já existe num banco publicado — precisa deste ALTER explícito, e ele
-- roda de novo sem erro a cada reexecução do arquivo (mesmo nome de sempre
-- para o check sem nome: <tabela>_<coluna>_check).
alter table public.eventos_resposta
  drop constraint if exists eventos_resposta_caixa_depois_check;
alter table public.eventos_resposta
  add constraint eventos_resposta_caixa_depois_check check (caixa_depois between 1 and 8);


-- ----------------------------------------------------------------------------
-- 4. Simulados
--
-- Histórico de simulados. Hoje vive num array local e se perde se o aparelho
-- morrer; é progresso de verdade e merece sincronizar.
-- ----------------------------------------------------------------------------
create table if not exists public.simulados (
  id         uuid primary key,
  usuario_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  data       date not null,
  acertos    smallint not null check (acertos >= 0),
  total      smallint not null check (total > 0),
  concurso   text,
  criado_em  timestamptz not null default now()
);

create index if not exists simulados_por_usuario
  on public.simulados (usuario_id, data desc);

alter table public.simulados enable row level security;

drop policy if exists "simulados próprios: ler"   on public.simulados;
drop policy if exists "simulados próprios: criar" on public.simulados;

create policy "simulados próprios: ler"
  on public.simulados for select using (usuario_id = auth.uid() and public.conta_aprovada());
create policy "simulados próprios: criar"
  on public.simulados for insert with check (usuario_id = auth.uid() and public.conta_aprovada());

-- Painel de desempenho — mesmo motivo e mesmo molde da policy equivalente em
-- eventos_resposta (seção 3), logo acima.
drop policy if exists "simulados: aprovador lê tudo" on public.simulados;
create policy "simulados: aprovador lê tudo"
  on public.simulados for select using (public.sou_aprovador());


-- ----------------------------------------------------------------------------
-- 5. Estado derivado
--
-- Documenta em SQL a regra de derivação: o estado de um cartão é o evento mais
-- recente daquela questão.
--
-- ATENÇÃO ao `security_invoker = true`: sem isso, uma view roda com as
-- permissões de quem a criou (postgres) e IGNORA a RLS da tabela de baixo —
-- ou seja, vazaria o progresso de todo mundo para qualquer pessoa logada.
-- Não remover. Com ele, esta view respeita a RLS de eventos_resposta (seção
-- 3) automaticamente — inclusive a policy "eventos: aprovador lê tudo": um
-- aprovador que consultar estado_cartao já recebe o de qualquer conta, sem
-- a view precisar saber nada sobre papel nenhum.
-- ----------------------------------------------------------------------------
create or replace view public.estado_cartao
with (security_invoker = true) as
select distinct on (usuario_id, questao_id)
  usuario_id,
  questao_id,
  resultado,
  caixa_depois as caixa,
  prox,
  ts
from public.eventos_resposta
order by usuario_id, questao_id, ts desc, id desc;


-- ----------------------------------------------------------------------------
-- 5.1 Resumo agregado por conta — Painel de desempenho
--
-- Acurácia geral e última atividade dependem do histórico INTEIRO (meses ou
-- anos de eventos), não só de uma janela recente — somar isso no cliente
-- puxando cada evento pra sempre seria pesado à toa quando o Postgres já
-- faz a soma na consulta. `hoje`/`últimos 7 dias`, ao contrário, são janela
-- pequena e não entram aqui: pintarPainel() (index.html) busca eventos
-- recentes direto e agrega no cliente, sem precisar de view pra isso.
--
-- security_invoker = true, mesmo motivo de estado_cartao: herda a RLS de
-- eventos_resposta sem repetir a regra de quem pode ver o quê — aprovador
-- lê a linha de qualquer conta, conta comum só a própria.
--
-- O join com perfis aplica o corte de progresso_zerado_em (seção 2.3): o
-- agregado ignora tudo que veio antes do último zerar() daquela conta. É o
-- único lugar onde esse corte PRECISA ser feito em SQL — o painel filtra os
-- outros números no cliente (tem o `ts` de cada linha em mãos), mas uma
-- soma agregada já chega pronta, sem como descontar depois.
-- ----------------------------------------------------------------------------
create or replace view public.resumo_desempenho
with (security_invoker = true) as
select
  e.usuario_id,
  count(*) as respostas_total,
  count(*) filter (where e.resultado = 'sabia') as acertos_total,
  max(e.criado_em) as ultima_atividade
from public.eventos_resposta e
join public.perfis p on p.id = e.usuario_id
where p.progresso_zerado_em is null or e.ts > p.progresso_zerado_em
group by e.usuario_id;


-- ----------------------------------------------------------------------------
-- 7. Revisores — Fase 4
--
-- Quem pode ver e aprovar propostas de questão de qualquer pessoa. Mesma
-- lógica da allowlist de convidados: RLS ligada, zero policies, ninguém lê
-- pela API — nem mesmo as policies de `propostas`, que por isso consultam
-- esta tabela através de sou_revisor() (seção 7.1), não direto.
-- ----------------------------------------------------------------------------
create table if not exists public.revisores (
  user_id    uuid primary key references auth.users(id) on delete cascade,
  criado_em  timestamptz not null default now()
);

alter table public.revisores enable row level security;
revoke all on public.revisores from anon, authenticated;


-- ----------------------------------------------------------------------------
-- 7.1 "Sou revisor?"
--
-- `revisores` nega toda leitura pela API (revoke all, logo acima) — de
-- propósito, pra lista de quem revisa não ficar enumerável. Mas então
-- precisa de um jeito de perguntar "eu, especificamente, sou revisor?" sem
-- poder listar quem mais é. Uma function security definer que só devolve
-- true/false resolve: ela lê a tabela com privilégio elevado, e o único dado
-- que sai dela é o booleano.
--
-- Precisa vir ANTES das policies de `propostas`, duas seções abaixo: elas
-- chamam esta function, e o Postgres exige que ela já exista na hora de
-- criar a policy. Também é por isso que ela existe: uma policy de RLS roda
-- com o privilégio de quem está consultando, não do dono da tabela — uma
-- policy que fizesse `exists (select ... from revisores ...)` direto bateria
-- no mesmo "permission denied" que motivou o revoke all, e travaria a
-- leitura de `propostas` pra QUALQUER pessoa, revisor ou não (o Postgres
-- avalia todas as policies de uma tabela, mesmo as que não se aplicam).
-- ----------------------------------------------------------------------------
create or replace function public.sou_revisor()
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (select 1 from public.revisores where user_id = auth.uid());
$$;

grant execute on function public.sou_revisor() to authenticated;


-- ----------------------------------------------------------------------------
-- 8. Propostas de questão — Fase 4
--
-- O banco de questões continua estático, versionado em banco/*.json e
-- validado por validar.py — isso NÃO muda. Esta tabela é só a caixa de
-- entrada: alguém propõe, um revisor aprova ou rejeita, e só DEPOIS uma
-- pessoa com a chave secreta roda incorporar-propostas.ps1 localmente para
-- transformar o aprovado num arquivo de matéria de verdade, pelo mesmo
-- caminho — commit, validar.py — que qualquer outra questão sempre seguiu.
-- Aprovar aqui nunca escreve direto no banco que o app lê.
--
-- `id` é gerado no cliente, igual a eventos_resposta: mesmo motivo (reenvio
-- depois de queda de rede não duplica, colide na chave primária).
-- ----------------------------------------------------------------------------
create table if not exists public.propostas (
  id             uuid primary key,
  autor_id       uuid not null default auth.uid() references auth.users(id) on delete cascade,
  materia        text not null check (materia in ('portugues','sus','enfermagem')),
  topico         text not null,
  subtopico      text,
  enunciado      text not null,
  alternativas   jsonb not null check (jsonb_array_length(alternativas) = 5),
  correta        smallint not null check (correta between 0 and 4),
  explicacao     text not null,
  fonte          text not null,
  status         text not null default 'pendente' check (status in ('pendente','aprovada','rejeitada')),
  motivo_rejeicao text,
  revisado_por   uuid references auth.users(id),
  revisado_em    timestamptz,
  criado_em      timestamptz not null default now()
);

create index if not exists propostas_por_status on public.propostas (status, criado_em);

alter table public.propostas enable row level security;

drop policy if exists "autor: propor"          on public.propostas;
drop policy if exists "autor: ver as próprias" on public.propostas;
drop policy if exists "revisor: ver todas"     on public.propostas;
drop policy if exists "revisor: decidir"       on public.propostas;

-- autor só cria como pendente — não dá pra já nascer aprovada.
-- conta_aprovada(): quem ainda não foi liberado não propõe questão.
create policy "autor: propor"
  on public.propostas for insert
  with check (autor_id = auth.uid() and status = 'pendente' and public.conta_aprovada());

-- autor vê o que propôs, em qualquer status (pra acompanhar se foi aceito)
create policy "autor: ver as próprias"
  on public.propostas for select
  using (autor_id = auth.uid() and public.conta_aprovada());

-- revisor vê tudo (as políticas de SELECT se combinam com OR: quem for
-- autor E revisor ao mesmo tempo continua vendo tudo normalmente).
-- sou_revisor(), não a subquery direta em revisores — ver o comentário na
-- seção 7.1 do porquê isso não é só estilo, é o que faz a policy funcionar.
create policy "revisor: ver todas"
  on public.propostas for select
  using (public.sou_revisor());

-- só revisor muda status — o autor não pode auto-aprovar a própria proposta
create policy "revisor: decidir"
  on public.propostas for update
  using (public.sou_revisor())
  with check (public.sou_revisor());

-- sem policy de delete: rejeitada fica registrada, não some


-- ----------------------------------------------------------------------------
-- 8.1 Quem decidiu e quando — Fase 4b
--
-- `revisado_por`/`revisado_em` não têm DEFAULT porque DEFAULT só se aplica em
-- INSERT, e essas colunas só fazem sentido preenchidas num UPDATE (quando a
-- decisão acontece). Um gatilho resolve, e tem uma vantagem sobre confiar no
-- cliente pra mandar esses campos: quem decidiu vem de auth.uid() no servidor,
-- não do que o app disser — não dá pra um revisor assinar a decisão de outro.
-- ----------------------------------------------------------------------------
create or replace function public.marcar_revisor()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if old.status = 'pendente' and new.status <> 'pendente' then
    new.revisado_por := auth.uid();
    new.revisado_em := now();
  end if;
  return new;
end;
$$;

drop trigger if exists marcar_revisor on public.propostas;
create trigger marcar_revisor
  before update on public.propostas
  for each row execute function public.marcar_revisor();


-- ----------------------------------------------------------------------------
-- 8.3 Marca de incorporada — Fase 4c
--
-- `status = 'aprovada'` diz que um revisor decidiu aceitar; não diz se
-- `incorporar-propostas.ps1` já transformou isso numa questão de verdade em
-- banco/<matéria>.json. Sem esta coluna o script não teria como saber o que
-- já processou e reincorporaria a mesma proposta a cada execução.
--
-- Preenchida pelo próprio script (com a chave secreta, que ignora RLS — não
-- precisa de policy de update aqui). Fica nula enquanto pendente ou recusada.
-- ----------------------------------------------------------------------------
alter table public.propostas add column if not exists incorporada_em timestamptz;


-- ----------------------------------------------------------------------------
-- 8.4 Reportar problema em questão
--
-- Canal simples pra quem estuda avisar "isso aqui está errado" — enunciado,
-- alternativa, explicação ou fonte. Não vira uma fila de revisão paralela:
-- usa os mesmos revisores de `propostas` (`sou_revisor()`), porque julgar se
-- uma questão está certa é o mesmo tipo de trabalho que aprovar uma nova.
--
-- `id` gerado no cliente, mesmo motivo de sempre (reenvio depois de queda de
-- rede não duplica, colide na chave primária).
-- ----------------------------------------------------------------------------
create table if not exists public.reportes (
  id            uuid primary key,
  autor_id      uuid not null default auth.uid() references auth.users(id) on delete cascade,
  questao_id    text not null check (questao_id ~ '^[0-9a-f]{10}$'),  -- regra 5 do CLAUDE.md
  motivo        text not null,
  status        text not null default 'pendente' check (status in ('pendente','resolvido','descartado')),
  resolvido_por uuid references auth.users(id),
  resolvido_em  timestamptz,
  criado_em     timestamptz not null default now()
);

create index if not exists reportes_por_status on public.reportes (status, criado_em);

alter table public.reportes enable row level security;

drop policy if exists "autor: reportar"        on public.reportes;
drop policy if exists "autor: ver os próprios" on public.reportes;
drop policy if exists "revisor: ver todos"     on public.reportes;
drop policy if exists "revisor: decidir"       on public.reportes;

-- conta_aprovada() (seção 2.1): quem ainda não foi liberado não reporta nada
create policy "autor: reportar"
  on public.reportes for insert
  with check (autor_id = auth.uid() and status = 'pendente' and public.conta_aprovada());

create policy "autor: ver os próprios"
  on public.reportes for select
  using (autor_id = auth.uid() and public.conta_aprovada());

-- sou_revisor(), não subquery direta em revisores — mesmo motivo do
-- comentário na seção 7.1: uma subquery direta rodaria com o privilégio de
-- quem consulta e bateria no revoke all de `revisores`.
create policy "revisor: ver todos"
  on public.reportes for select
  using (public.sou_revisor());

create policy "revisor: decidir"
  on public.reportes for update
  using (public.sou_revisor())
  with check (public.sou_revisor());

-- sem policy de delete: reporte descartado fica registrado, não some

-- resolvido_por/resolvido_em vêm do servidor, nunca do cliente — mesmo
-- desenho de marcar_revisor() (seção 8.1) pra propostas.
create or replace function public.marcar_revisor_reporte()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if old.status = 'pendente' and new.status <> 'pendente' then
    new.resolvido_por := auth.uid();
    new.resolvido_em := now();
  end if;
  return new;
end;
$$;

drop trigger if exists marcar_revisor_reporte on public.reportes;
create trigger marcar_revisor_reporte
  before update on public.reportes
  for each row execute function public.marcar_revisor_reporte();


-- ----------------------------------------------------------------------------
-- 8.5 Chaves estrangeiras adiáveis — só para permitir a conferência
--
-- Por padrão, uma chave estrangeira é checada no exato momento do INSERT/
-- UPDATE. "Adiável" (DEFERRABLE) permite pedir pra checagem só rodar no
-- COMMIT — e como conferir.sql sempre termina em ROLLBACK, a checagem nunca
-- chega a rodar para o dado de teste que ele insere (Ana, Bruno, autor,
-- revisor... UUIDs fictícios, sem conta de verdade em auth.users).
--
-- Não muda o comportamento normal do app: sem pedir explicitamente (é isso
-- que conferir.sql faz, com SET CONSTRAINTS ALL DEFERRED), continua checando
-- na hora, exatamente como antes. A alternativa que tentei primeiro —
-- desligar o gatilho que aplica a FK — esbarra numa proteção do Postgres:
-- só superusuário de verdade pode desligar esse gatilho específico, e o
-- papel do SQL Editor do Supabase não é superusuário de verdade.
--
-- Descobre as FKs sozinho em vez de nomear cada uma na mão — mas só encontra
-- as que JÁ EXISTEM no momento em que este bloco roda. Por isso esta seção
-- **precisa ficar depois de toda CREATE TABLE deste arquivo** — é o próprio
-- bug que aconteceu com `reportes` (seção 8.4): a tabela nasceu depois deste
-- bloco rodar antes, na posição antiga, e a FK dela nunca foi marcada
-- adiável, quebrando `conferir.sql` com "violates foreign key constraint".
-- Ao acrescentar tabela nova que referencia auth.users, ou este bloco
-- continua sendo a ÚLTIMA coisa do arquivo (exceto os inserts comentados,
-- que não rodam sozinhos), ou a tabela nova quebra do mesmo jeito.
-- ----------------------------------------------------------------------------
do $$
declare r record;
begin
  for r in
    select conname, conrelid::regclass as tabela
    from pg_constraint
    where contype = 'f'
      and confrelid = 'auth.users'::regclass
      and connamespace = 'public'::regnamespace
  loop
    execute format('alter table %s alter constraint %I deferrable initially immediate', r.tabela, r.conname);
  end loop;
end $$;


-- ----------------------------------------------------------------------------
-- 9. Convidados — NÃO É MAIS USADO
--
-- O cadastro virou aberto (ver seção 1): qualquer pessoa cria conta, e o
-- controle acontece depois, na aprovação. Esta tabela fica de pé, vazia ou
-- não, caso você queira voltar ao modelo fechado — para isso, recrie o
-- gatilho exigir_convite e mantenha a lista em dia.
-- ----------------------------------------------------------------------------
-- insert into public.convidados (email, nome) values
--   ('franciscometzker@gmail.com', 'Francisco'),
--   ('esposa@exemplo.com',         'Esposa')
-- on conflict (email) do nothing;


-- ----------------------------------------------------------------------------
-- 10. Vire revisor de questões
--
-- Rode depois de já ter feito login pelo menos uma vez pelo app (a conta
-- precisa existir em auth.users primeiro). Busca pelo e-mail — não precisa
-- copiar UUID de Authentication → Users na mão.
-- ----------------------------------------------------------------------------
-- insert into public.revisores (user_id)
-- select id from auth.users where email = 'franciscometzker@gmail.com'
-- on conflict (user_id) do nothing;


-- ----------------------------------------------------------------------------
-- 11. Vire aprovador de contas
--
-- OBRIGATÓRIO rodar pelo menos uma vez, para pelo menos uma pessoa: sem
-- nenhum aprovador cadastrado, ninguém consegue liberar ninguém, e toda conta
-- nova fica presa em 'pendente' para sempre.
-- ----------------------------------------------------------------------------
-- insert into public.aprovadores (user_id)
-- select id from auth.users where email = 'franciscometzker@gmail.com'
-- on conflict (user_id) do nothing;
