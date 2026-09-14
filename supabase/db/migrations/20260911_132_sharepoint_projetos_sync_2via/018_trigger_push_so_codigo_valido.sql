-- SPEC-130 — achado de risco real (2026-09-14): uma limpeza em massa de `cidade`/`estado`
-- disparou push pra ~800 projetos de uma vez, e entre eles estavam registros internos que
-- NUNCA deveriam sincronizar com o SharePoint — "Projeto Comissão N" (código `COM-N`),
-- "PRJ-TESTE", etc. Só não viraram itens de verdade na lista real porque o Graph limitou
-- (throttling) as ~800 chamadas simultâneas e todas essas tentativas específicas falharam
-- por sorte, não por proteção. Corrige adicionando uma guarda: só dispara push quando
-- `codigo` bate com o formato real de projeto (`AA.NNN...`, ex. "26.267", "24.020").
-- Registros com outro formato de código (COM-N, PRJ-TESTE, etc.) nunca mais disparam push.

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

  -- guarda de segurança: só projetos com código no formato real da lista SharePoint
  -- (ex. "26.267") disparam push. Registros internos (COM-N, PRJ-TESTE etc.) nunca vão.
  if new.codigo !~ '^\d{2}\.\d+$' then
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
