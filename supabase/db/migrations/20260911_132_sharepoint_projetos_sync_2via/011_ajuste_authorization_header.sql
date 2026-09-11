-- SPEC-130 — ajuste pós-teste (2026-09-11): as Edge Functions do Supabase exigem, por padrão
-- da plataforma, um header `Authorization` com um JWT válido do projeto (verify_jwt), além de
-- qualquer autenticação própria da function. A trigger de push e o wrapper do cron não
-- mandavam esse header (só o nosso `x-sync-secret`) — a chamada via pg_net voltava 401
-- "Missing authorization header" antes mesmo de chegar no código da function (confirmado em
-- net._http_response no teste do projeto 26.268).
--
-- Fix: manda `Authorization: Bearer <anon key>` junto. O anon key NÃO é segredo (já é
-- público, usado em todos os apps do frontend) — isso só satisfaz a checagem da plataforma,
-- sem abrir mão de nenhuma proteção real (quem protege de verdade continua sendo o
-- x-sync-secret, exigido dentro do código da function). Guardado no Vault como
-- 'supabase_anon_key' só pra manter o padrão (nada sensível sendo versionado aqui).
--
-- Precisa rodar, fora desta migration:
--   select vault.create_secret('<o SUPABASE_ANON_KEY do projeto>', 'supabase_anon_key');

create or replace function public.trg_projetos_sharepoint_push_fn()
returns trigger
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_payload jsonb;
  v_hash text;
  v_push_url text;
  v_sync_secret text;
  v_anon_key text;
begin
  if new.last_sync_source = 'sharepoint' then
    return new;
  end if;

  v_payload := jsonb_build_object(
    'nome', new.nome,
    'codigo', new.codigo,
    'responsavel_nome', new.responsavel_nome,
    'cidade', new.cidade,
    'arquivado', new.arquivado,
    'data_entrada', new.data_entrada,
    'nivel_estrategico', new.nivel_estrategico,
    'status', new.status,
    'arquiteto_id', new.arquiteto_id,
    'responsavel_obra_id', new.responsavel_obra_id
  );
  v_hash := md5(v_payload::text);

  if tg_op = 'UPDATE' and old.sync_hash = v_hash and old.last_sync_source = 'sistema' then
    return new;
  end if;

  select decrypted_secret into v_push_url
  from vault.decrypted_secrets where name = 'sharepoint_push_url';

  if v_push_url is null then
    return new;
  end if;

  select decrypted_secret into v_sync_secret
  from vault.decrypted_secrets where name = 'sharepoint_sync_secret';
  select decrypted_secret into v_anon_key
  from vault.decrypted_secrets where name = 'supabase_anon_key';

  perform net.http_post(
    url := v_push_url,
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || coalesce(v_anon_key, ''),
      'x-sync-secret', coalesce(v_sync_secret, '')
    ),
    body := jsonb_build_object(
      'projeto_id', new.id,
      'changed_by_usuario_id', auth.uid(),
      'sync_hash', v_hash
    )
  );

  return new;
end;
$$;

create or replace function public.disparar_pull_sharepoint()
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
    url := v_pull_url,
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || coalesce(v_anon_key, ''),
      'x-sync-secret', coalesce(v_sync_secret, '')
    ),
    body := '{}'::jsonb
  );
end;
$$;
