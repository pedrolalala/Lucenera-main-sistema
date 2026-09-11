-- SPEC-130 — fix pós-teste (2026-09-11): mesmo o pull incremental (com deltaLink já
-- estabelecido pelo backfill) estourou o timeout padrão do pg_net (5000ms) — o trabalho de
-- fundo da function (token do Graph, carregar contatos/usuários, consultar a lista) já
-- consome perto disso, independente de quantos itens mudaram. Confirmado em
-- net._http_response (timed_out=true na execução das 17:25).
--
-- Aumenta o timeout nas duas chamadas (push e pull). Seguro: net.http_post é assíncrono —
-- o timeout controla só quanto o pg_net espera a resposta antes de desistir, não trava a
-- trigger nem o cron.

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
    ),
    timeout_milliseconds := 20000
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
    body := '{}'::jsonb,
    timeout_milliseconds := 60000
  );
end;
$$;
