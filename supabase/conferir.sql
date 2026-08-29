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
-- chega a rodar. Precisa que schema.sql (seção 8.5, a última do arquivo)
-- já tenha marcado essas chaves como adiáveis — se este comando der erro,
-- rode schema.sql de novo.
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
  -- as duas precisam de perfil APROVADO: desde a aprovação de contas
  -- (schema.sql 2.1), a policy de eventos_resposta exige conta_aprovada(),
  -- e sem isto este teste falharia por motivo errado — não por vazamento de
  -- dado entre elas, que é o que ele existe para pegar
  insert into public.perfis (id, nome, email, status) values
    (ana,   'Ana',   'ana@exemplo.com',   'aprovado'),
    (bruno, 'Bruno', 'bruno@exemplo.com', 'aprovado');

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
-- 5.1 Painel de desempenho — aprovador lê o log de QUALQUER conta
--
-- eventos_resposta e simulados ganharam uma policy extra ("... : aprovador
-- lê tudo"), no mesmo molde de perfis. Confirma que ela faz exatamente o
-- que deve: aprovador enxerga o log de duas contas diferentes, e uma conta
-- comum (aprovada, mas NÃO aprovadora) continua barrada do log alheio
-- mesmo com a policy nova existindo — ela só ACRESCENTA quem lê, nunca
-- afrouxa o isolamento de quem não é aprovador.
-- ----------------------------------------------------------------------------
do $$
declare
  aluno1    uuid := 'a0a0a0a0-a0a0-a0a0-a0a0-a0a0a0a0a0a0';
  aluno2    uuid := 'b0b0b0b0-b0b0-b0b0-b0b0-b0b0b0b0b0b0';
  aprovador uuid := 'c0c0c0c0-c0c0-c0c0-c0c0-c0c0c0c0c0c0';
  comum     uuid := 'd0d0d0d0-d0d0-d0d0-d0d0-d0d0d0d0d0d0';
  visto int;
begin
  insert into public.perfis (id, nome, email, status) values
    (aluno1,    'Aluno Um',    'aluno1@exemplo.com',    'aprovado'),
    (aluno2,    'Aluno Dois',  'aluno2@exemplo.com',    'aprovado'),
    (aprovador, 'Aprovador',   'aprovador2@exemplo.com','aprovado'),
    (comum,     'Conta Comum', 'comum@exemplo.com',     'aprovado');
  insert into public.aprovadores (user_id) values (aprovador);

  insert into public.eventos_resposta (id, usuario_id, questao_id, ts, resultado, caixa_depois, prox)
  values
    (gen_random_uuid(), aluno1, '1111111111', now(), 'sabia', 2, current_date),
    (gen_random_uuid(), aluno2, '2222222222', now(), 'errei', 1, current_date);
  insert into public.simulados (id, usuario_id, data, acertos, total, concurso)
  values
    (gen_random_uuid(), aluno1, current_date, 30, 40, 'teste'),
    (gen_random_uuid(), aluno2, current_date, 20, 40, 'teste');

  -- como aprovador: vê o log das DUAS contas
  set local role authenticated;
  perform set_config('request.jwt.claims', json_build_object('sub', aprovador, 'role','authenticated')::text, true);

  select count(*) into visto from public.eventos_resposta where usuario_id in (aluno1, aluno2);
  if visto = 2 then raise notice 'OK — aprovador vê o log das duas contas em eventos_resposta';
  else raise warning 'FALHOU — aprovador vê % evento(s) de aluno1/aluno2; deveria ver 2', visto; end if;

  select count(*) into visto from public.simulados where usuario_id in (aluno1, aluno2);
  if visto = 2 then raise notice 'OK — aprovador vê o log das duas contas em simulados';
  else raise warning 'FALHOU — aprovador vê % simulado(s) de aluno1/aluno2; deveria ver 2', visto; end if;

  select count(*) into visto from public.estado_cartao where usuario_id in (aluno1, aluno2);
  if visto = 2 then raise notice 'OK — estado_cartao também abre pro aprovador (herda a RLS de baixo)';
  else raise warning 'FALHOU — estado_cartao devolve % linha(s) pro aprovador; deveria ver 2', visto; end if;

  -- como conta comum (aprovada, mas NÃO aprovadora): continua vendo só o
  -- próprio log — a policy nova não pode ter afrouxado isto
  perform set_config('request.jwt.claims', json_build_object('sub', comum, 'role','authenticated')::text, true);
  select count(*) into visto from public.eventos_resposta where usuario_id in (aluno1, aluno2);
  if visto = 0 then raise notice 'OK — conta comum continua sem alcançar o log de outra conta';
  else raise warning 'FALHOU — conta comum (não aprovadora) lê % evento(s) alheio(s) — a policy nova vazou', visto; end if;

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
  -- perfis aprovados pelo mesmo motivo da seção 5: a policy "autor: ver as
  -- próprias" exige conta_aprovada() desde a aprovação de contas
  insert into public.perfis (id, nome, email, status) values
    (autor,   'Autor',   'autor@exemplo.com',   'aprovado'),
    (outro,   'Outro',   'outro@exemplo.com',   'aprovado'),
    (revisor, 'Revisor', 'revisor@exemplo.com', 'aprovado');

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

-- ----------------------------------------------------------------------------
-- 8. Aprovação de contas
--
-- O cadastro é aberto, então este é o portão que substitui a allowlist: uma
-- conta 'pendente' não pode ler nem gravar nada, e — o que mais importa — não
-- pode se auto-aprovar, mesmo mandando um PATCH direto na API. A policy
-- "perfil próprio: atualizar" existe para a pessoa editar nome e meta, e o
-- status mora na mesma linha; é o gatilho que separa as duas coisas.
-- ----------------------------------------------------------------------------
do $$
declare
  pendente  uuid := '88888888-8888-8888-8888-888888888888';
  aprovador uuid := '99999999-9999-9999-9999-999999999999';
  visto     int;
  status_lido text;
  quem      uuid;
begin
  insert into public.perfis (id, nome, email, status) values
    (pendente,  'Quem Espera', 'espera@exemplo.com',  'pendente'),
    (aprovador, 'Quem Aprova', 'aprova@exemplo.com',  'aprovado');
  insert into public.aprovadores (user_id) values (aprovador);

  -- ---- como a conta pendente ----
  set local role authenticated;
  perform set_config('request.jwt.claims', json_build_object('sub', pendente, 'role','authenticated')::text, true);

  -- precisa enxergar o PRÓPRIO perfil, senão não tem como o app saber que
  -- está pendente e mostrar a tela de espera
  select count(*) into visto from public.perfis where id = pendente;
  if visto = 1 then raise notice 'OK — conta pendente vê o próprio perfil (precisa, pra saber que está pendente)';
  else raise warning 'FALHOU — conta pendente não vê o próprio perfil; o app não teria como mostrar a tela de espera'; end if;

  -- mas não pode gravar resposta nenhuma
  begin
    insert into public.eventos_resposta (id, usuario_id, questao_id, ts, resultado, caixa_depois, prox)
    values (gen_random_uuid(), pendente, 'dddddddddd', now(), 'sabia', 2, current_date);
    raise warning 'FALHOU — conta pendente conseguiu gravar evento de resposta';
  exception when insufficient_privilege or check_violation then
    raise notice 'OK — conta pendente não grava evento (conta_aprovada barra)';
  end;

  -- nem propor questão
  begin
    insert into public.propostas (id, autor_id, materia, topico, enunciado, alternativas, correta, explicacao, fonte)
    values (gen_random_uuid(), pendente, 'sus', 'T', 'enunciado de pendente', '["A","B","C","D","E"]'::jsonb, 0, 'e', 'f');
    raise warning 'FALHOU — conta pendente conseguiu propor questão';
  exception when insufficient_privilege or check_violation then
    raise notice 'OK — conta pendente não propõe questão';
  end;

  -- e NÃO pode se auto-aprovar: este é o teste central desta seção
  begin
    update public.perfis set status = 'aprovado' where id = pendente;
    select status into status_lido from public.perfis where id = pendente;
    if status_lido = 'aprovado' then
      raise warning 'FALHOU — a conta se auto-aprovou; o portão de aprovação não vale nada';
    else
      raise notice 'OK — auto-aprovação não teve efeito (status seguiu %)', status_lido;
    end if;
  exception when insufficient_privilege then
    raise notice 'OK — auto-aprovação recusada pelo gatilho';
  end;

  -- nem pode trocar o próprio e-mail: é por ele que o aprovador reconhece
  -- quem está pedindo acesso. Sem esta trava dava para se passar por outro.
  update public.perfis set nome = 'Nome Novo', email = 'chefe@exemplo.com' where id = pendente;
  select email into status_lido from public.perfis where id = pendente;
  if status_lido = 'espera@exemplo.com' then
    raise notice 'OK — e-mail do perfil não pode ser trocado pelo cliente';
  else
    raise warning 'FALHOU — e-mail virou %; dá para se passar por outra pessoa na fila de aprovação', status_lido;
  end if;

  -- ---- como o aprovador ----
  perform set_config('request.jwt.claims', json_build_object('sub', aprovador, 'role','authenticated')::text, true);

  select count(*) into visto from public.perfis where status = 'pendente';
  if visto >= 1 then raise notice 'OK — aprovador enxerga a fila de pendentes (% conta[s])', visto;
  else raise warning 'FALHOU — aprovador não vê nenhuma conta pendente; a tela de aprovação ficaria vazia'; end if;

  update public.perfis set status = 'aprovado' where id = pendente;
  select status, aprovado_por into status_lido, quem from public.perfis where id = pendente;
  if status_lido = 'aprovado' then raise notice 'OK — aprovador consegue aprovar';
  else raise warning 'FALHOU — aprovador não conseguiu aprovar (status ficou %)', status_lido; end if;
  if quem = aprovador then raise notice 'OK — aprovado_por vem do servidor (auth.uid())';
  else raise warning 'FALHOU — aprovado_por = %, deveria ser o aprovador (%)', quem, aprovador; end if;

  -- sou_aprovador() responde certo, e a lista continua ilegível
  if public.sou_aprovador() then raise notice 'OK — sou_aprovador() diz true pra quem aprova';
  else raise warning 'FALHOU — sou_aprovador() deveria ser true'; end if;

  begin
    perform count(*) from public.aprovadores;
    raise warning 'FALHOU — a tabela aprovadores foi lida diretamente pela API';
  exception when insufficient_privilege then
    raise notice 'OK — aprovadores continua ilegível direto, só via sou_aprovador()';
  end;

  -- ---- depois de aprovada, a conta passa a funcionar ----
  perform set_config('request.jwt.claims', json_build_object('sub', pendente, 'role','authenticated')::text, true);
  begin
    insert into public.eventos_resposta (id, usuario_id, questao_id, ts, resultado, caixa_depois, prox)
    values (gen_random_uuid(), pendente, 'eeeeeeeeee', now(), 'sabia', 2, current_date);
    raise notice 'OK — depois de aprovada, a conta grava normalmente';
  exception when others then
    raise warning 'FALHOU — conta aprovada continua sem conseguir gravar: %', sqlerrm;
  end;

  reset role;
end $$;


-- ----------------------------------------------------------------------------
-- 9. O cadastro está mesmo aberto?
--    O gatilho de convite tem que estar DESLIGADO — se continuar de pé,
--    ninguém de fora consegue criar conta e a aprovação nunca acontece.
-- ----------------------------------------------------------------------------
select
  case when count(*) = 0 then 'OK — exigir_convite desligado, cadastro aberto'
       else 'FALHOU — o gatilho exigir_convite ainda está ativo; o cadastro continua fechado por convite'
  end as teste_9_cadastro_aberto
from pg_trigger
where tgname = 'exigir_convite' and not tgisinternal;


-- ----------------------------------------------------------------------------
-- 10. Reportar problema em questão
--
-- Mesmo padrão de propostas (seção 6): autor vê e cria só o que é seu,
-- revisor vê e decide tudo, autor não pode se auto-resolver, resolvido_por
-- não pode ser forjado pelo cliente.
-- ----------------------------------------------------------------------------
do $$
declare
  autor    uuid := '10101010-1010-1010-1010-101010101010';
  outro    uuid := '20202020-2020-2020-2020-202020202020';
  revisor  uuid := '30303030-3030-3030-3030-303030303030';
  rep_id   uuid := gen_random_uuid();
  visto    int;
  visto_uuid uuid;
  visto_ts   timestamptz;
begin
  insert into public.perfis (id, nome, email, status) values
    (autor,   'Autor Reporte',   'autor-reporte@exemplo.com',   'aprovado'),
    (outro,   'Outro Reporte',   'outro-reporte@exemplo.com',   'aprovado'),
    (revisor, 'Revisor Reporte', 'revisor-reporte@exemplo.com', 'aprovado');
  insert into public.revisores (user_id) values (revisor) on conflict do nothing;

  set local role authenticated;
  perform set_config('request.jwt.claims', json_build_object('sub', autor, 'role','authenticated')::text, true);
  insert into public.reportes (id, questao_id, motivo)
  values (rep_id, 'ffffffffff', 'enunciado com erro de digitação');

  select count(*) into visto from public.reportes;
  if visto = 1 then raise notice 'OK — autor vê o próprio reporte';
  else raise warning 'FALHOU — autor vê % reportes; deveria ver 1', visto; end if;

  perform set_config('request.jwt.claims', json_build_object('sub', outro, 'role','authenticated')::text, true);
  select count(*) into visto from public.reportes;
  if visto = 0 then raise notice 'OK — outra pessoa não vê o reporte alheio';
  else raise warning 'FALHOU — outra pessoa vê % reporte(s) que não são dela', visto; end if;

  -- autor não pode se auto-resolver
  perform set_config('request.jwt.claims', json_build_object('sub', autor, 'role','authenticated')::text, true);
  update public.reportes set status = 'resolvido' where id = rep_id;
  if found then
    raise warning 'FALHOU — o autor conseguiu resolver o próprio reporte';
  else
    raise notice 'OK — autor não consegue resolver o próprio reporte';
  end if;

  -- revisor vê e resolve; resolvido_por vem do servidor
  perform set_config('request.jwt.claims', json_build_object('sub', revisor, 'role','authenticated')::text, true);
  select count(*) into visto from public.reportes;
  if visto = 1 then raise notice 'OK — revisor vê o reporte de outra pessoa';
  else raise warning 'FALHOU — revisor vê % reportes; deveria ver 1', visto; end if;

  update public.reportes set status = 'resolvido', resolvido_por = autor where id = rep_id;
  select resolvido_por, resolvido_em into visto_uuid, visto_ts from public.reportes where id = rep_id;
  if visto_uuid = revisor then raise notice 'OK — resolvido_por vem do servidor, não do que o cliente mandou';
  else raise warning 'FALHOU — resolvido_por = %, deveria ser o revisor (%)', visto_uuid, revisor; end if;
  if visto_ts is not null then raise notice 'OK — resolvido_em foi preenchido pelo gatilho';
  else raise warning 'FALHOU — resolvido_em ficou nulo'; end if;

  reset role;
end $$;


rollback;

-- ============================================================================
-- Depois de rodar: procure por "FALHOU" e por "warning" na saída.
-- Se não houver nenhum, a fundação está de pé.
-- ============================================================================
