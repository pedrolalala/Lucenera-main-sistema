-- SPEC-130 — agenda o pull (SharePoint → sistema) a cada 5 minutos via pg_cron.
-- `cron.schedule` recebe uma string fixa de comando, então não dá pra ler o Vault direto
-- nela — por isso existe esta função wrapper, que lê o Vault em tempo de execução (mesmo
-- padrão da trigger de push, 006) e o cron só chama a função.
--
-- Precisa, fora desta migration (não commitar segredo em .sql versionado):
--   select vault.create_secret('https://<project-ref>.supabase.co/functions/v1/sharepoint-projetos-pull', 'sharepoint_pull_url');
-- (reaproveita o secret 'sharepoint_sync_secret' já criado pro push, 006)
--
-- Enquanto 'sharepoint_pull_url' não existir no Vault, o cron roda a cada 5 min sem fazer
-- nada (mesma guarda de segurança da trigger de push).

create or replace function public.disparar_pull_sharepoint()
returns void
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_pull_url text;
  v_sync_secret text;
begin
  select decrypted_secret into v_pull_url
  from vault.decrypted_secrets where name = 'sharepoint_pull_url';

  if v_pull_url is null then
    return;
  end if;

  select decrypted_secret into v_sync_secret
  from vault.decrypted_secrets where name = 'sharepoint_sync_secret';

  perform net.http_post(
    url := v_pull_url,
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-sync-secret', coalesce(v_sync_secret, '')
    ),
    body := '{}'::jsonb
  );
end;
$$;

comment on function public.disparar_pull_sharepoint() is
  'Wrapper chamado pelo pg_cron a cada 5 min pra disparar a Edge Function sharepoint-projetos-pull. Inerte até o secret sharepoint_pull_url existir no Vault. SPEC-130.';

select cron.schedule(
  'sharepoint-projetos-pull',
  '*/5 * * * *',
  $$select public.disparar_pull_sharepoint();$$
);
