-- ============================================================================
-- Fase 3a — conferência
--
-- Rode DEPOIS do schema.sql, no SQL Editor do Supabase. Cada bloco imprime
-- "OK" ou "FALHOU". Uma RLS mal configurada não aparece em teste feliz: o app
-- funciona, e o progresso de uma pessoa simplesmente vaza para outra. Por isso
-- aqui a gente testa o que **deve ser negado**, não o que deve funcionar.
--
-- Nada aqui altera dados de verdade: tudo roda dentro de uma transação que
-- termina em rollback.
-- ============================================================================

begin;

-- Os testes abaixo simulam pessoas (Ana, Bruno, autor, revisor...) com UUIDs
-- fictícios, sem conta de verdade em auth.users — mas várias colunas têm
-- chave estrangeira pra lá. "DEFERRED" adia a checagem dessas chaves para o
-- COMMIT; como este arquivo sempre termina em ROLLBACK, a checagem nunca
-- chega a rodar. Precisa que schema.sql (seção 8.3) já tenha marcado essas
-- chaves como adiáveis — se este comando der erro, rode schema.sql de novo.
set constraints all deferred;

-- ----------------------------------------------------------------------------
-- 1. RLS está ligada em todas as tabelas?
-- ----------------------------------------------------------------------------
select
  case when count(*) = 0 then 'OK — RLS ligada em todas'
       else 'FALHOU — sem RLS: ' || string_agg(tablename, ', ')
  end as teste_1_rls_ligada
from pg_tables
where schemaname = 'public'
  and tablename in ('convidados','perfis','eventos_resposta','simulados')
  and not rowsecurity;


-- ----------------------------------------------------------------------------
-- 2. A allowlist é inacessível pela API?
--    Deve ter ZERO policies: com RLS ligada, isso nega tudo.
-- ----------------------------------------------------------------------------
select
  case when count(*) = 0 then 'OK — convidados sem policy, ninguém lê pela API'
       else 'FALHOU — convidados tem ' || count(*) || ' policy(ies); a lista de e-mails ficou legível'
  end as teste_2_allowlist_fechada
from pg_policies
where schemaname = 'public' and tablename = 'convidados';


-- ----------------------------------------------------------------------------
-- 3. O log é append-only de verdade?
--    Não pode existir policy de UPDATE nem de DELETE em eventos_resposta.
-- ----------------------------------------------------------------------------
select
  case when count(*) = 0 then 'OK — eventos_resposta sem update/delete'
       else 'FALHOU — o log pode ser alterado: ' || string_agg(policyname, ', ')
  end as teste_3_append_only
from pg_policies
where schemaname = 'public' and tablename = 'eventos_resposta'
  and cmd in ('UPDATE','DELETE');


-- ----------------------------------------------------------------------------
-- 4. A view respeita a RLS de quem consulta?
--    Sem security_invoker, a view roda como o dono (postgres) e ignora a RLS
--    da tabela de baixo — vazando o progresso de todo mundo.
-- ----------------------------------------------------------------------------
select
  case when 'security_invoker=true' = any(c.reloptions)
       then 'OK — estado_cartao com security_invoker'
       else 'FALHOU — estado_cartao IGNORA a RLS; qualquer pessoa logada lê o progresso de todas'
  end as teste_4_view_invoker
from pg_class c
join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public' and c.relname = 'estado_cartao';


-- ----------------------------------------------------------------------------
-- 5. Isolamento real entre duas pessoas
--
-- Simula dois usuários e confirma que um não enxerga o progresso do outro.
-- Este é o teste que importa: os anteriores conferem a configuração, este
-- confere o comportamento.
-- ----------------------------------------------------------------------------
do $$
declare
  ana   uuid := '11111111-1111-1111-1111-111111111111';
  bruno uuid := '22222222-2222-2222-2222-222222222222';
  visto int;
begin
  -- entra o dado das duas pessoas contornando a RLS (aqui somos postgres)
  insert into public.eventos_resposta (id, usuario_id, questao_id, ts, resultado, caixa_depois, prox)
  values
    (gen_random_uuid(), ana,   'aaaaaaaaaa', now(), 'sabia',  2, current_date),
    (gen_random_uuid(), bruno, 'bbbbbbbbbb', now(), 'errei',  1, current_date);

  -- agora passa a responder como a Ana, com a RLS valendo
  set local role authenticated;
  perform set_config('request.jwt.claims', json_build_object('sub', ana, 'role','authenticated')::text, true);

  select count(*) into visto from public.eventos_resposta;
  if visto = 1 then
    raise notice 'OK — Ana vê só o próprio evento (% linha)', visto;
  else
    raise warning 'FALHOU — Ana enxerga % linhas; deveria ver 1', visto;
  end if;

  select count(*) into visto from public.eventos_resposta where usuario_id = bruno;
  if visto = 0 then
    raise notice 'OK — Ana não alcança o progresso do Bruno';
  else
    raise warning 'FALHOU — Ana lê % evento(s) do Bruno', visto;
  end if;

  select count(*) into visto from public.estado_cartao;
  if visto = 1 then
    raise notice 'OK — a view estado_cartao também isola';
  else
    raise warning 'FALHOU — estado_cartao devolve % linhas para a Ana; deveria devolver 1', visto;
  end if;

  -- forjar evento em nome do Bruno tem que ser recusado
  begin
    insert into public.eventos_resposta (id, usuario_id, questao_id, ts, resultado, caixa_depois, prox)
    values (gen_random_uuid(), bruno, 'cccccccccc', now(), 'sabia', 2, current_date);
    raise warning 'FALHOU — Ana conseguiu gravar evento em nome do Bruno';
  exception when insufficient_privilege or check_violation then
    raise notice 'OK — gravar em nome de outra pessoa foi recusado';
  end;

  -- apagar o próprio log também tem que ser recusado (append-only)
  begin
    delete from public.eventos_resposta where usuario_id = ana;
    if found then
      raise warning 'FALHOU — o log não é append-only: deu para apagar';
    else
      raise notice 'OK — delete não alcançou nenhuma linha (append-only)';
    end if;
  exception when insufficient_privilege then
    raise notice 'OK — delete recusado (append-only)';
  end;

  reset role;
end $$;


-- ----------------------------------------------------------------------------
-- 6. Propostas de questão — Fase 4
--
-- Autor vê e propõe só o que é seu; revisor vê tudo e decide; autor NÃO pode
-- aprovar a própria proposta mesmo tentando via API direta.
-- ----------------------------------------------------------------------------
do $$
declare
  autor   uuid := '33333333-3333-3333-3333-333333333333';
  outro   uuid := '44444444-4444-4444-4444-444444444444';
  revisor uuid := '55555555-5555-5555-5555-555555555555';
  prop_id uuid := gen_random_uuid();
  alt     jsonb := '["A","B","C","D","E"]'::jsonb;
  visto   int;
  visto_uuid uuid;
  visto_ts   timestamptz;
begin
  insert into public.revisores (user_id) values (revisor);
  insert into public.propostas (id, autor_id, materia, topico, enunciado, alternativas, correta, explicacao, fonte)
  values (prop_id, autor, 'sus', 'Lei 8.080/90', 'enunciado de teste', alt, 1, 'explicação', 'fonte de teste');

  -- autor vê a própria proposta
  set local role authenticated;
  perform set_config('request.jwt.claims', json_build_object('sub', autor, 'role','authenticated')::text, true);
  select count(*) into visto from public.propostas;
  if visto = 1 then raise notice 'OK — autor vê a própria proposta';
  else raise warning 'FALHOU — autor vê % propostas; deveria ver 1', visto; end if;

  -- outra pessoa (nem autor, nem revisor) não vê nada
  perform set_config('request.jwt.claims', json_build_object('sub', outro, 'role','authenticated')::text, true);
  select count(*) into visto from public.propostas;
  if visto = 0 then raise notice 'OK — outra pessoa não vê a proposta alheia';
  else raise warning 'FALHOU — outra pessoa vê % proposta(s) que não são dela', visto; end if;

  -- autor tenta aprovar a própria proposta: tem que ser recusado
  perform set_config('request.jwt.claims', json_build_object('sub', autor, 'role','authenticated')::text, true);
  update public.propostas set status = 'aprovada' where id = prop_id;
  if found then
    raise warning 'FALHOU — o autor conseguiu aprovar a própria proposta';
  else
    raise notice 'OK — autor não consegue aprovar a própria proposta';
  end if;

  -- revisor vê e aprova normalmente
  perform set_config('request.jwt.claims', json_build_object('sub', revisor, 'role','authenticated')::text, true);
  select count(*) into visto from public.propostas;
  if visto = 1 then raise notice 'OK — revisor vê a proposta de outra pessoa';
  else raise warning 'FALHOU — revisor vê % propostas; deveria ver 1', visto; end if;

  -- tenta assinar a decisão em nome de outra pessoa (spoof) — o gatilho tem
  -- que ignorar isso e usar auth.uid() de verdade, não o que o cliente mandou
  update public.propostas set status = 'aprovada', revisado_por = autor where id = prop_id;
  select revisado_por, revisado_em into visto_uuid, visto_ts from public.propostas where id = prop_id;
  if visto_uuid = revisor then
    raise notice 'OK — revisado_por vem do servidor (auth.uid()), não do que o cliente mandou';
  else
    raise warning 'FALHOU — revisado_por = %, deveria ser o revisor (%), não % — dá pra forjar quem decidiu', visto_uuid, revisor, autor;
  end if;
  if visto_ts is not null then raise notice 'OK — revisado_em foi preenchido pelo gatilho';
  else raise warning 'FALHOU — revisado_em ficou nulo'; end if;

  reset role;
end $$;


-- ----------------------------------------------------------------------------
-- 7. sou_revisor() — só devolve booleano, nunca a lista de quem revisa
-- ----------------------------------------------------------------------------
do $$
declare
  revisor uuid := '66666666-6666-6666-6666-666666666666';
  ninguem uuid := '77777777-7777-7777-7777-777777777777';
  resultado boolean;
begin
  insert into public.revisores (user_id) values (revisor);

  set local role authenticated;
  perform set_config('request.jwt.claims', json_build_object('sub', revisor, 'role','authenticated')::text, true);
  select public.sou_revisor() into resultado;
  if resultado then raise notice 'OK — sou_revisor() diz true pra quem é revisor';
  else raise warning 'FALHOU — sou_revisor() deveria ser true'; end if;

  perform set_config('request.jwt.claims', json_build_object('sub', ninguem, 'role','authenticated')::text, true);
  select public.sou_revisor() into resultado;
  if not resultado then raise notice 'OK — sou_revisor() diz false pra quem não é';
  else raise warning 'FALHOU — sou_revisor() deveria ser false'; end if;

  -- e a tabela em si continua ilegível diretamente, mesmo sendo revisor
  perform set_config('request.jwt.claims', json_build_object('sub', revisor, 'role','authenticated')::text, true);
  begin
    perform count(*) from public.revisores;
    raise warning 'FALHOU — a tabela revisores foi lida diretamente pela API';
  exception when insufficient_privilege then
    raise notice 'OK — revisores continua ilegível direto, só via sou_revisor()';
  end;

  reset role;
end $$;

rollback;

-- ============================================================================
-- Depois de rodar: procure por "FALHOU" e por "warning" na saída.
-- Se não houver nenhum, a fundação está de pé.
-- ============================================================================
