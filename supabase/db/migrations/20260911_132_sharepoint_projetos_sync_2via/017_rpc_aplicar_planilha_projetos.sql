-- SPEC-130 — RPC de reconciliação a partir de um export/planilha da lista "Organização
-- Projetos" (2026-09-14: `01-Documento/01 - Planilhas/Planilha de projetos.xlsx`, sem
-- ID de item do Graph, só código). Casa SÓ por `codigo` (nunca por sharepoint_item_id,
-- que essa fonte não tem) e nunca mexe no vínculo já existente — só atualiza os campos de
-- negócio. Mesma regra de COALESCE das outras RPCs de pull (nunca apaga com NULL).

create or replace function public.aplicar_planilha_projetos(
  p_codigo text,
  p_nome text,
  p_responsavel_nome text,
  p_cidade text,
  p_arquivado boolean,
  p_data_entrada date,
  p_nivel_estrategico public.projeto_nivel,
  p_status public.projeto_status,
  p_arquiteto_id uuid,
  p_responsavel_obra_id uuid,
  p_estado varchar(2)
)
returns table (projeto_id uuid, acao text)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_id uuid;
  v_acao text;
begin
  perform set_config('app.sync_em_andamento', 'on', true);

  select id into v_id from public.projetos where codigo = p_codigo;

  if v_id is not null then
    update public.projetos set
      nome = coalesce(p_nome, nome),
      responsavel_nome = coalesce(p_responsavel_nome, responsavel_nome),
      cidade = coalesce(p_cidade, cidade),
      arquivado = coalesce(p_arquivado, arquivado),
      data_entrada = coalesce(p_data_entrada, data_entrada),
      nivel_estrategico = coalesce(p_nivel_estrategico, nivel_estrategico),
      status = coalesce(p_status, status),
      arquiteto_id = coalesce(p_arquiteto_id, arquiteto_id),
      responsavel_obra_id = coalesce(p_responsavel_obra_id, responsavel_obra_id),
      estado = coalesce(p_estado, estado),
      last_synced_at = now(),
      last_sync_source = 'sharepoint',
      last_synced_by = null
    where id = v_id;
    v_acao := 'update';
  else
    insert into public.projetos (
      nome, codigo, responsavel_nome, cidade, arquivado, data_entrada,
      nivel_estrategico, status, arquiteto_id, responsavel_obra_id, estado,
      last_synced_at, last_sync_source, last_synced_by
    ) values (
      coalesce(p_nome, 'Projeto sem nome'), p_codigo,
      p_responsavel_nome, p_cidade, coalesce(p_arquivado, false), p_data_entrada,
      p_nivel_estrategico, p_status, p_arquiteto_id, p_responsavel_obra_id, p_estado,
      now(), 'sharepoint', null
    )
    returning id into v_id;
    v_acao := 'create';
  end if;

  return query select v_id, v_acao;
end;
$$;

comment on function public.aplicar_planilha_projetos(text, text, text, text, boolean, date, public.projeto_nivel, public.projeto_status, uuid, uuid, varchar) is
  'Reconcilia projetos a partir de um export/planilha da lista SharePoint sem ID de item — casa só por codigo, nunca mexe em sharepoint_item_id. SPEC-130, 2026-09-14.';

revoke all on function public.aplicar_planilha_projetos(text, text, text, text, boolean, date, public.projeto_nivel, public.projeto_status, uuid, uuid, varchar) from public;
grant execute on function public.aplicar_planilha_projetos(text, text, text, text, boolean, date, public.projeto_nivel, public.projeto_status, uuid, uuid, varchar) to service_role;
