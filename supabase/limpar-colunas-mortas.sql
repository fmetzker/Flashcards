-- ============================================================================
-- Limpeza de colunas mortas em public.perfis — RODAR À MÃO, UMA VEZ
--
-- ESTE ARQUIVO NÃO É IDEMPOTENTE POR ACIDENTE: ele é, mas o efeito é
-- IRREVERSÍVEL. `drop column` apaga o dado junto com a coluna, e num banco
-- publicado não há como voltar atrás sem restaurar backup. Por isso ele vive
-- separado do schema.sql, que é feito para ser colado e reexecutado sem
-- pensar — misturar um DROP ali seria pedir para alguém apagar dado numa
-- reexecução de rotina.
--
-- LEIA ANTES DE RODAR. Confira que as três colunas estão mesmo vazias na SUA
-- instalação (a consulta abaixo faz isso). Se alguma tiver dado que você
-- queira guardar, salve antes — depois do drop, acabou.
--
-- POR QUE SAEM. Nenhuma das três é lida ou escrita pelo app. O cliente toca
-- perfis em exatamente três lugares (index.html):
--   PATCH  perfis?id=eq.<conta>            -> materias_ativas, progresso_zerado_em
--   GET    perfis?select=status,progresso_zerado_em&id=eq.<conta>
--   GET    perfis?status=eq....&select=id,nome,email,materias_ativas,...   (painel)
--
--   concurso      A conta passou a seguir VÁRIOS concursos ao mesmo tempo
--                 (E.concursos, no localStorage). Esta coluna é do tempo em
--                 que era um só, e nunca chegou a ser sincronizada.
--   meta          A meta diária deixou de ser configurável: hoje é a soma das
--                 cotas dos blocos, recalculada no cliente (CLAUDE.md, "Meta e
--                 progresso do dia"). A coluna ainda contradizia essa regra,
--                 com default 35 e check de 5 a 200.
--   ultimo_backup Do tempo em que o backup era manual, por arquivo. A
--                 sincronização por eventos substituiu isso inteiro.
--
-- COMO RODAR: cole no SQL Editor do Supabase e execute. Depois disso, o
-- schema.sql (que já não cria essas colunas) continua reexecutável normalmente.
-- ============================================================================


-- ----------------------------------------------------------------------------
-- 1. Confira primeiro — quantas linhas têm dado em cada uma?
--    Espere 0 nas três. Se vier diferente de 0, PARE e decida o que fazer com
--    esse dado antes de seguir para a parte 2.
-- ----------------------------------------------------------------------------
select
  count(*) filter (where concurso is not null)               as com_concurso,
  count(*) filter (where meta is distinct from 35)           as com_meta_alterada,
  count(*) filter (where ultimo_backup is not null)          as com_ultimo_backup,
  count(*)                                                   as total_de_perfis
from public.perfis;


-- ----------------------------------------------------------------------------
-- 2. A remoção. Só rode depois de conferir a parte 1.
--
--    `if exists` para poder rodar de novo sem erro numa instalação que já
--    limpou (ou que nasceu depois do schema.sql parar de criar as colunas).
-- ----------------------------------------------------------------------------
alter table public.perfis drop column if exists concurso;
alter table public.perfis drop column if exists meta;
alter table public.perfis drop column if exists ultimo_backup;


-- ----------------------------------------------------------------------------
-- 3. Confira depois — a tabela deve ficar só com o que o servidor usa.
--    Esperado: id, nome, atualizado_em, email, status, aprovado_por,
--    aprovado_em, materias_ativas, progresso_zerado_em.
-- ----------------------------------------------------------------------------
select column_name, data_type
from information_schema.columns
where table_schema = 'public' and table_name = 'perfis'
order by ordinal_position;
