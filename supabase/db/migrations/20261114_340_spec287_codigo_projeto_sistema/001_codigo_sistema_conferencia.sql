-- SPEC-287 — código do projeto gerado pelo sistema; sincronização só sistema -> SharePoint.
-- Decisão do Filippo (14/11/2026): projeto novo nasce só no sistema, com o próximo número
-- livre (último + 1). O item vai para a lista sem Código (Edge Function sharepoint-projetos-push,
-- sem mudança nesse ponto), o fluxo do Power Automate numera igual e cria pasta/Teams.
-- O pull de 5 em 5 min é desligado; fica uma conferência só de leitura, dias úteis às 8h.
--
-- ORDEM: publicar sharepoint-projetos-conferencia ANTES desta migration (o cron chama a função).

begin;

-- 1) gerador do código oficial: AA.NNN, AA = ano em São Paulo, NNN = maior do ano + 1
create or replace function public.gerar_codigo_projeto()
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_ano text := to_char(now() at time zone 'America/Sao_Paulo', 'YY');
  v_ultimo int;
begin
  -- dois cadastros ao mesmo tempo não pegam o mesmo número (trava até o fim da transação)
  perform pg_advisory_xact_lock(hashtext('public.gerar_codigo_projeto'));

  select max(split_part(codigo, '.', 2)::int) into v_ultimo
  from public.projetos
  where codigo ~ ('^' || v_ano || '\.\d+$');

  return v_ano || '.' || lpad((coalesce(v_ultimo, 0) + 1)::text, 3, '0');
end;
$$;
revoke all on function public.gerar_codigo_projeto() from public, anon, authenticated;

-- 2) projeto criado sem código nasce com o código oficial (antes: PROV-NNNN, SPEC-228)
create or replace function public.trg_projetos_codigo_provisorio_fn()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.codigo is null or btrim(new.codigo) = '' then
    new.codigo := public.gerar_codigo_projeto();
  end if;
  return new;
end;
$$;

-- 3) desliga o pull SharePoint -> sistema (a função e a Edge Function ficam, sem agendamento)
select cron.unschedule('sharepoint-projetos-pull')
where exists (select 1 from cron.job where jobname = 'sharepoint-projetos-pull');

-- 4) conferência só leitura, dias úteis às 8h de São Paulo (11h UTC)
create or replace function public.disparar_conferencia_sharepoint()
returns void
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_pull_url text;
  v_sync_secret text;
  v_anon_key text;
begin
  select decrypted_secret into v_pull_url
  from vault.decrypted_secrets where name = 'sharepoint_pull_url';

  if v_pull_url is null then
    return;
  end if;

  select decrypted_secret into v_sync_secret
  from vault.decrypted_secrets where name = 'sharepoint_sync_secret';
  select decrypted_secret into v_anon_key
  from vault.decrypted_secrets where name = 'supabase_anon_key';

  perform net.http_post(
    url := replace(v_pull_url, 'sharepoint-projetos-pull', 'sharepoint-projetos-conferencia'),
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || coalesce(v_anon_key, ''),
      'x-sync-secret', coalesce(v_sync_secret, '')
    ),
    body := '{}'::jsonb,
    timeout_milliseconds := 120000
  );
end;
$$;
revoke all on function public.disparar_conferencia_sharepoint() from public, anon, authenticated;

select cron.unschedule('sharepoint-projetos-conferencia')
where exists (select 1 from cron.job where jobname = 'sharepoint-projetos-conferencia');
select cron.schedule('sharepoint-projetos-conferencia', '0 11 * * 1-5',
                     'select public.disparar_conferencia_sharepoint();');

-- 5) log aceita a conferência
alter table public.sharepoint_sync_log drop constraint if exists sharepoint_sync_log_direction_check;
alter table public.sharepoint_sync_log
  add constraint sharepoint_sync_log_direction_check
  check (direction = any (array['push', 'pull', 'conferencia']));

alter table public.sharepoint_sync_log drop constraint if exists sharepoint_sync_log_action_check;
alter table public.sharepoint_sync_log
  add constraint sharepoint_sync_log_action_check
  check (action = any (array['create', 'update', 'skip', 'conflict', 'error', 'ok', 'divergencia']));

commit;
