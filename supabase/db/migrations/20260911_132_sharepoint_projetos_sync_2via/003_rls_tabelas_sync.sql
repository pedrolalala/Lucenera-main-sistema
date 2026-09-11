-- SPEC-130 — RLS das tabelas de apoio da sincronização.
-- São tabelas de controle interno (log, de-para, estado, sequência de código), sem uso
-- direto por usuário final. Habilita RLS sem nenhuma policy: bloqueia anon/authenticated
-- via PostgREST por padrão; as Edge Functions leem/escrevem com a service role, que
-- ignora RLS. Nada aqui deve ser exposto por policy sem necessidade concreta.

alter table public.sharepoint_sync_log enable row level security;
alter table public.sharepoint_status_map enable row level security;
alter table public.sharepoint_sync_state enable row level security;
alter table public.projeto_codigo_sequencia enable row level security;
