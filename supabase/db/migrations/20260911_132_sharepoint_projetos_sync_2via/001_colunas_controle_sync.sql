-- SPEC-130 — Sincronização em duas vias Projetos <-> Lista SharePoint "Organização Projetos".
-- Colunas de controle em public.projetos: amarram cada projeto ao item correspondente do
-- SharePoint (sharepoint_item_id) e evitam loop de eco entre push e pull (sync_hash +
-- last_sync_source). Não mexe em regra de negócio nem em coluna existente.

alter table public.projetos
  add column if not exists sharepoint_item_id text,
  add column if not exists sync_hash text,
  add column if not exists last_synced_at timestamptz,
  add column if not exists last_sync_source text,
  add column if not exists last_synced_by uuid;

alter table public.projetos
  add constraint chk_projetos_last_sync_source
  check (last_sync_source is null or last_sync_source in ('sistema', 'sharepoint'));

alter table public.projetos
  add constraint fk_projetos_last_synced_by
  foreign key (last_synced_by) references public.usuarios(id);

create unique index uq_projetos_sharepoint_item_id
  on public.projetos (sharepoint_item_id)
  where sharepoint_item_id is not null;

comment on column public.projetos.sharepoint_item_id is
  'ID do item correspondente na lista SharePoint "Organização Projetos" (Graph). NULL = ainda não sincronizado. SPEC-130.';
comment on column public.projetos.sync_hash is
  'Hash dos campos sincronizados na última gravação (push ou pull) — só otimização (evita reenvio quando nada mudou). O anti-eco de verdade é last_sync_source, garantido pela trigger 007. SPEC-130.';
comment on column public.projetos.last_synced_at is
  'Timestamp da última sincronização (push ou pull) bem-sucedida. SPEC-130.';
comment on column public.projetos.last_sync_source is
  'Origem da última gravação sincronizada: ''sistema'' ou ''sharepoint''. SPEC-130.';
comment on column public.projetos.last_synced_by is
  'Usuário do CRM responsável pela última alteração sincronizada (NULL quando a origem foi o SharePoint). SPEC-130.';
