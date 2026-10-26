-- Rollback SPEC-228 (migration 244): volta as funções como estavam em 26/10/2026 (dump do banco real).
-- Atenção: projetos já criados com PROV-NNNN continuam assim; o contador antigo recomeça do maior AA.NNN existente.
begin;
drop trigger if exists trg_projetos_codigo_provisorio on public.projetos;
drop function if exists public.trg_projetos_codigo_provisorio_fn();
create table if not exists public.projeto_codigo_sequencia (ano text primary key, ultimo_numero integer not null default 0);
alter table public.projeto_codigo_sequencia enable row level security;
revoke all on public.projeto_codigo_sequencia from anon, authenticated;
CREATE OR REPLACE FUNCTION public.aplicar_pull_sharepoint(p_sharepoint_item_id text, p_nome text, p_codigo text, p_responsavel_nome text, p_cidade text, p_arquivado boolean, p_data_entrada date, p_nivel_estrategico projeto_nivel, p_status projeto_status, p_arquiteto_id uuid, p_responsavel_obra_id uuid, p_estado character varying, p_sync_hash text)
 RETURNS TABLE(projeto_id uuid, acao text)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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
      estado = coalesce(p_estado, estado),
      sync_hash = p_sync_hash,
      last_synced_at = now(),
      last_sync_source = 'sharepoint',
      last_synced_by = null
    where id = v_id;
    v_acao := 'update';
  else
    insert into public.projetos (
      nome, codigo, responsavel_nome, cidade, arquivado, data_entrada,
      nivel_estrategico, status, arquiteto_id, responsavel_obra_id, estado,
      sharepoint_item_id, sync_hash, last_synced_at, last_sync_source, last_synced_by
    ) values (
      coalesce(p_nome, 'Projeto sem nome'),
      coalesce(p_codigo, public.gerar_codigo_projeto()),
      p_responsavel_nome, p_cidade, coalesce(p_arquivado, false), p_data_entrada,
      p_nivel_estrategico, p_status, p_arquiteto_id, p_responsavel_obra_id, p_estado,
      p_sharepoint_item_id, p_sync_hash, now(), 'sharepoint', null
    )
    returning id into v_id;
    v_acao := 'create';
  end if;

  return query select v_id, v_acao;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.gerar_codigo_projeto()
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_ano text := to_char(now(), 'FMYY');
  v_max_existente integer;
  v_numero integer;
begin
  select coalesce(max(nullif(split_part(codigo, '.', 2), '')::integer), 0)
    into v_max_existente
  from public.projetos
  where codigo like v_ano || '.%';

  insert into public.projeto_codigo_sequencia (ano, ultimo_numero)
  values (v_ano, greatest(v_max_existente, 0) + 1)
  on conflict (ano) do update
    set ultimo_numero = greatest(
      public.projeto_codigo_sequencia.ultimo_numero,
      v_max_existente
    ) + 1
  returning ultimo_numero into v_numero;

  return v_ano || '.' || v_numero;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.propagate_projeto_codigo()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
BEGIN
  IF OLD.codigo IS NOT DISTINCT FROM NEW.codigo THEN
    RETURN NEW;
  END IF;

  UPDATE separacoes
  SET codigo_obra = NEW.codigo,
      updated_at  = NOW()
  WHERE projeto_id = NEW.id;

  RETURN NEW;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.trg_projetos_sharepoint_push_fn()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
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
$function$
;
drop function if exists public.gerar_codigo_provisorio_projeto();
drop sequence if exists public.projeto_codigo_provisorio_seq;
commit;
