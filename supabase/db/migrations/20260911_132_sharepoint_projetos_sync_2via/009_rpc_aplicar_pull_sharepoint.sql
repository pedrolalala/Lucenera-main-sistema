-- SPEC-130 — RPC que a Edge Function sharepoint-projetos-pull chama pra cada item alterado
-- na lista SharePoint. Casa por sharepoint_item_id; se não achar, cai pro fallback por
-- codigo (só em projeto ainda sem sharepoint_item_id, pra não roubar o vínculo de outro).
-- Sem correspondência nenhuma, cria um projeto novo (se vier sem código, gera um — mesma
-- regra de fonte única do push).
--
-- COALESCE em cada campo: um valor NULO vindo do SharePoint nunca apaga o que já existe no
-- sistema (proteção v1 contra perda de dado por campo mal lido/transformado). Se um dia for
-- necessário permitir limpar um campo de verdade, isso precisa virar uma decisão explícita,
-- não um efeito colateral desta RPC.
--
-- Liga app.sync_em_andamento antes de escrever, pela mesma razão da 008: sem isso, a trigger
-- 007 sobrescreveria last_sync_source/last_synced_by com os valores default de escrita
-- "normal" (auth.uid() da service role, que é NULL, e 'sistema' em vez de 'sharepoint').

create or replace function public.aplicar_pull_sharepoint(
  p_sharepoint_item_id text,
  p_nome text,
  p_codigo text,
  p_responsavel_nome text,
  p_cidade text,
  p_arquivado boolean,
  p_data_entrada date,
  p_nivel_estrategico public.projeto_nivel,
  p_status public.projeto_status,
  p_arquiteto_id uuid,
  p_responsavel_obra_id uuid,
  p_sync_hash text
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

  select id into v_id from public.projetos where sharepoint_item_id = p_sharepoint_item_id;

  if v_id is null and p_codigo is not null then
    select id into v_id from public.projetos
    where codigo = p_codigo and sharepoint_item_id is null;
  end if;

  if v_id is not null then
    update public.projetos set
      sharepoint_item_id = p_sharepoint_item_id,
      nome = coalesce(p_nome, nome),
      codigo = coalesce(p_codigo, codigo),
      responsavel_nome = coalesce(p_responsavel_nome, responsavel_nome),
      cidade = coalesce(p_cidade, cidade),
      arquivado = coalesce(p_arquivado, arquivado),
      data_entrada = coalesce(p_data_entrada, data_entrada),
      nivel_estrategico = coalesce(p_nivel_estrategico, nivel_estrategico),
      status = coalesce(p_status, status),
      arquiteto_id = coalesce(p_arquiteto_id, arquiteto_id),
      responsavel_obra_id = coalesce(p_responsavel_obra_id, responsavel_obra_id),
      sync_hash = p_sync_hash,
      last_synced_at = now(),
      last_sync_source = 'sharepoint',
      last_synced_by = null
    where id = v_id;
    v_acao := 'update';
  else
    insert into public.projetos (
      nome, codigo, responsavel_nome, cidade, arquivado, data_entrada,
      nivel_estrategico, status, arquiteto_id, responsavel_obra_id,
      sharepoint_item_id, sync_hash, last_synced_at, last_sync_source, last_synced_by
    ) values (
      coalesce(p_nome, 'Projeto sem nome'),
      coalesce(p_codigo, public.gerar_codigo_projeto()),
      p_responsavel_nome, p_cidade, coalesce(p_arquivado, false), p_data_entrada,
      p_nivel_estrategico, p_status, p_arquiteto_id, p_responsavel_obra_id,
      p_sharepoint_item_id, p_sync_hash, now(), 'sharepoint', null
    )
    returning id into v_id;
    v_acao := 'create';
  end if;

  return query select v_id, v_acao;
end;
$$;

comment on function public.aplicar_pull_sharepoint(text, text, text, text, text, boolean, date, public.projeto_nivel, public.projeto_status, uuid, uuid, text) is
  'Aplica no banco um item da lista SharePoint (criado ou alterado lá), casando por sharepoint_item_id (fallback codigo). Chamada só pela Edge Function sharepoint-projetos-pull (service role). SPEC-130.';

revoke all on function public.aplicar_pull_sharepoint(text, text, text, text, text, boolean, date, public.projeto_nivel, public.projeto_status, uuid, uuid, text) from public;
grant execute on function public.aplicar_pull_sharepoint(text, text, text, text, text, boolean, date, public.projeto_nivel, public.projeto_status, uuid, uuid, text) to service_role;
