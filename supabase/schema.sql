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

drop trigger if exists exigir_convite on auth.users;
create trigger exigir_convite
  before insert on auth.users
  for each row execute function public.exigir_convite();


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
create or replace function public.criar_perfil()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.perfis (id, nome)
  values (
    new.id,
    coalesce(nullif(new.raw_user_meta_data->>'nome', ''), split_part(new.email, '@', 1))
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
  caixa_depois smallint not null check (caixa_depois between 1 and 5),
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

create policy "eventos próprios: ler"
  on public.eventos_resposta for select using (usuario_id = auth.uid());
create policy "eventos próprios: criar"
  on public.eventos_resposta for insert with check (usuario_id = auth.uid());
-- Sem policy de update nem de delete, de propósito: é a AUSÊNCIA delas que
-- torna o log append-only de verdade, no banco, e não só por convenção do app.


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
  on public.simulados for select using (usuario_id = auth.uid());
create policy "simulados próprios: criar"
  on public.simulados for insert with check (usuario_id = auth.uid());


-- ----------------------------------------------------------------------------
-- 5. Estado derivado
--
-- Documenta em SQL a regra de derivação: o estado de um cartão é o evento mais
-- recente daquela questão.
--
-- ATENÇÃO ao `security_invoker = true`: sem isso, uma view roda com as
-- permissões de quem a criou (postgres) e IGNORA a RLS da tabela de baixo —
-- ou seja, vazaria o progresso de todo mundo para qualquer pessoa logada.
-- Não remover.
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

-- autor só cria como pendente — não dá pra já nascer aprovada
create policy "autor: propor"
  on public.propostas for insert
  with check (autor_id = auth.uid() and status = 'pendente');

-- autor vê o que propôs, em qualquer status (pra acompanhar se foi aceito)
create policy "autor: ver as próprias"
  on public.propostas for select
  using (autor_id = auth.uid());

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
-- 8.2 Chaves estrangeiras adiáveis — só para permitir a conferência
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
-- Descobre as FKs sozinho em vez de nomear cada uma na mão — não quebra se
-- uma tabela nova ganhar uma referência pra auth.users no futuro.
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
-- 9. Convide as pessoas do grupo
--
-- Edite e execute. Só quem estiver aqui consegue criar conta.
-- ----------------------------------------------------------------------------
-- insert into public.convidados (email, nome) values
--   ('franciscometzker@gmail.com', 'Francisco'),
--   ('esposa@exemplo.com',         'Esposa')
-- on conflict (email) do nothing;


-- ----------------------------------------------------------------------------
-- 10. Vire revisor
--
-- Rode depois de já ter feito login pelo menos uma vez pelo app (a conta
-- precisa existir em auth.users primeiro). Busca pelo e-mail — não precisa
-- copiar UUID de Authentication → Users na mão.
-- ----------------------------------------------------------------------------
-- insert into public.revisores (user_id)
-- select id from auth.users where email = 'franciscometzker@gmail.com'
-- on conflict (user_id) do nothing;
