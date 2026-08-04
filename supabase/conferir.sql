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

rollback;

-- ============================================================================
-- Depois de rodar: procure por "FALHOU" e por "warning" na saída.
-- Se não houver nenhum, a fundação está de pé.
-- ============================================================================
