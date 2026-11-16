-- Rollback SPEC-287: volta ao estado da SPEC-228 (código PROV-NNNN + pull de 5 em 5 min).
-- Depois deste rollback, republicar sharepoint-projetos-push na versão anterior (main antes da SPEC-287).

begin;

create or replace function public.trg_projetos_codigo_provisorio_fn()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.codigo is null or btrim(new.codigo) = '' then
    new.codigo := public.gerar_codigo_provisorio_projeto();
  end if;
  return new;
end;
$$;

drop function if exists public.gerar_codigo_projeto();

select cron.unschedule('sharepoint-projetos-conferencia')
where exists (select 1 from cron.job where jobname = 'sharepoint-projetos-conferencia');
drop function if exists public.disparar_conferencia_sharepoint();

select cron.schedule('sharepoint-projetos-pull', '*/5 * * * *', 'select public.disparar_pull_sharepoint();')
where not exists (select 1 from cron.job where jobname = 'sharepoint-projetos-pull');

delete from public.sharepoint_sync_log where direction = 'conferencia';

alter table public.sharepoint_sync_log drop constraint if exists sharepoint_sync_log_direction_check;
alter table public.sharepoint_sync_log
  add constraint sharepoint_sync_log_direction_check check (direction = any (array['push', 'pull']));

alter table public.sharepoint_sync_log drop constraint if exists sharepoint_sync_log_action_check;
alter table public.sharepoint_sync_log
  add constraint sharepoint_sync_log_action_check
  check (action = any (array['create', 'update', 'skip', 'conflict', 'error']));

commit;
