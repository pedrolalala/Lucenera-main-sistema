-- SPEC-130 — tabelas de apoio da sincronização de duas vias Projetos <-> SharePoint.
-- sharepoint_sync_log: auditoria de cada push/pull/conflito/erro (quem alterou dos dois lados).
-- sharepoint_status_map: de-para projeto_status <-> valor de status da lista (sem seed —
--   aguarda o Vinícius preencher, ver SPEC-130 seção "Pendências").
-- sharepoint_sync_state: pequeno key-value de controle (deltaLink do pull, cache de site/list id).
-- projeto_codigo_sequencia: contador por ano usado por gerar_codigo_projeto() (003).

create table public.sharepoint_sync_log (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  projeto_id uuid references public.projetos(id) on delete set null,
  sharepoint_item_id text,
  direction text not null check (direction in ('push', 'pull')),
  action text not null check (action in ('create', 'update', 'skip', 'conflict', 'error')),
  source text,
  changed_by_usuario_id uuid references public.usuarios(id),
  changed_by_sharepoint text,
  campos_alterados jsonb,
  payload_hash text,
  resultado text,
  erro text
);

create index idx_sharepoint_sync_log_projeto_id on public.sharepoint_sync_log (projeto_id);
create index idx_sharepoint_sync_log_created_at on public.sharepoint_sync_log (created_at desc);

comment on table public.sharepoint_sync_log is
  'Auditoria de cada tentativa de sincronização (push/pull) entre projetos e a lista SharePoint "Organização Projetos". SPEC-130.';

create table public.sharepoint_status_map (
  projeto_status public.projeto_status primary key,
  sharepoint_valor text not null
);

comment on table public.sharepoint_status_map is
  'De-para entre o enum projeto_status e o texto de status usado na lista SharePoint. Sem seed até o Vinícius aprovar o mapeamento (SPEC-130, pendência). Status sem linha aqui não sincroniza.';

create table public.sharepoint_sync_state (
  chave text primary key,
  valor text,
  updated_at timestamptz not null default now()
);

comment on table public.sharepoint_sync_state is
  'Key-value de controle da sincronização: deltaLink do pull, cache de site-id/list-id do Graph. SPEC-130.';

create table public.projeto_codigo_sequencia (
  ano text primary key,
  ultimo_numero integer not null default 0
);

comment on table public.projeto_codigo_sequencia is
  'Contador do sufixo numérico do código de projeto (formato AA.NNN), por ano. Usado só por gerar_codigo_projeto(). SPEC-130.';
