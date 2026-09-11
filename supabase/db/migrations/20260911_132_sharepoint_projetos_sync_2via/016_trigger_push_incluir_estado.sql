-- SPEC-130 — inclui `estado` na lista de colunas que disparam o push (006 não tinha,
-- porque Estado só entrou no escopo em 2026-09-11). Sem isso, editar só o estado de um
-- projeto nunca chegaria ao SharePoint.

drop trigger if exists trg_projetos_sharepoint_push on public.projetos;

create trigger trg_projetos_sharepoint_push
after insert or update of
  nome, codigo, responsavel_nome, cidade, arquivado, data_entrada,
  nivel_estrategico, status, arquiteto_id, responsavel_obra_id, estado
on public.projetos
for each row
execute function public.trg_projetos_sharepoint_push_fn();
