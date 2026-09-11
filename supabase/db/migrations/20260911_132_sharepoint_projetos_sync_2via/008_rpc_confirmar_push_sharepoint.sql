-- SPEC-130 — RPC que a Edge Function sharepoint-projetos-push chama depois de gravar com
-- sucesso no Graph, pra fechar o ciclo: guarda o sharepoint_item_id (se era criação), o hash
-- do que foi enviado e quem originou a mudança (changed_by_usuario_id, capturado pela
-- trigger de push a partir de auth.uid() da escrita original — service role não tem esse
-- contexto, por isso repassa em vez de tentar redescobrir).
--
-- Liga app.sync_em_andamento antes do UPDATE pra trigger 007 não sobrescrever
-- last_sync_source/last_synced_by com o que ela assumiria por padrão (auth.uid() da própria
-- Edge Function, que é NULL — perderia a atribuição).

create or replace function public.confirmar_push_sharepoint(
  p_projeto_id uuid,
  p_sharepoint_item_id text,
  p_sync_hash text,
  p_changed_by_usuario_id uuid
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  perform set_config('app.sync_em_andamento', 'on', true);

  update public.projetos
  set
    sharepoint_item_id = p_sharepoint_item_id,
    sync_hash = p_sync_hash,
    last_synced_at = now(),
    last_sync_source = 'sistema',
    last_synced_by = p_changed_by_usuario_id
  where id = p_projeto_id;
end;
$$;

comment on function public.confirmar_push_sharepoint(uuid, text, text, uuid) is
  'Fecha o ciclo de um push bem-sucedido: grava sharepoint_item_id/sync_hash/last_synced_at e preserva a atribuição correta (last_sync_source=sistema, last_synced_by). Chamada só pela Edge Function sharepoint-projetos-push (service role). SPEC-130.';

revoke all on function public.confirmar_push_sharepoint(uuid, text, text, uuid) from public;
grant execute on function public.confirmar_push_sharepoint(uuid, text, text, uuid) to service_role;
