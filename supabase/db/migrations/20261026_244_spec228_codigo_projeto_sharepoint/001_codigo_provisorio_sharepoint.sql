-- SPEC-228 — código do projeto gerado só pelo SharePoint (fluxo do Power Automate).
-- O fluxo só numera e cria o grupo/pasta no Teams quando o item chega na lista com o Código
-- vazio. O sistema passa a criar o projeto com código provisório PROV-NNNN, envia o item sem
-- Código (Edge Function sharepoint-projetos-push) e recebe o oficial pelo pull.
--
-- ORDEM: publicar sharepoint-projetos-push (sem field_0) ANTES desta migration — com a função
-- antiga, o push mandaria "PROV-0001" como Código e o fluxo não rodaria.

begin;

-- 1) código provisório
create sequence if not exists public.projeto_codigo_provisorio_seq;
revoke all on sequence public.projeto_codigo_provisorio_seq from anon, authenticated;

create or replace function public.gerar_codigo_provisorio_projeto()
returns text
language sql
security definer
set search_path = public
as $$
  select 'PROV-' || lpad(nextval('public.projeto_codigo_provisorio_seq')::text, 4, '0');
$$;
revoke all on function public.gerar_codigo_provisorio_projeto() from public, anon, authenticated;

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

drop trigger if exists trg_projetos_codigo_provisorio on public.projetos;
create trigger trg_projetos_codigo_provisorio
  before insert on public.projetos
  for each row execute function public.trg_projetos_codigo_provisorio_fn();

-- 2) push: dispara também para código provisório (demais formatos — COM-N, PRJ-TESTE — seguem barrados)
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

  -- guarda de segurança: só código oficial da lista (ex. "26.267") ou provisório do sistema
  -- (SPEC-228, "PROV-0001") disparam push. Registros internos (COM-N, PRJ-TESTE etc.) nunca vão.
  if new.codigo !~ '^\d{2}\.\d+$' and new.codigo !~ '^PROV-\d+$' then
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

-- 3) pull: item da lista ainda sem Código nasce com provisório (antes: gerar_codigo_projeto,
--    que deu 26.1621 no teste de 26/10); quando o Código chega, coalesce troca o provisório.
create or replace function public.aplicar_pull_sharepoint(
  p_sharepoint_item_id text, p_nome text, p_codigo text, p_responsavel_nome text, p_cidade text,
  p_arquivado boolean, p_data_entrada date, p_nivel_estrategico projeto_nivel,
  p_status projeto_status, p_arquiteto_id uuid, p_responsavel_obra_id uuid,
  p_estado character varying, p_sync_hash text)
returns table(projeto_id uuid, acao text)
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
      coalesce(p_codigo, public.gerar_codigo_provisorio_projeto()),
      p_responsavel_nome, p_cidade, coalesce(p_arquivado, false), p_data_entrada,
      p_nivel_estrategico, p_status, p_arquiteto_id, p_responsavel_obra_id, p_estado,
      p_sharepoint_item_id, p_sync_hash, now(), 'sharepoint', null
    )
    returning id into v_id;
    v_acao := 'create';
  end if;

  return query select v_id, v_acao;
end;
$$;

-- 4) troca provisório -> oficial chega também nas entregas (ligadas pela separação)
create or replace function public.propagate_projeto_codigo()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if old.codigo is not distinct from new.codigo then
    return new;
  end if;

  update separacoes
  set codigo_obra = new.codigo,
      updated_at  = now()
  where projeto_id = new.id;

  update entregas_pendentes e
  set codigo_obra = new.codigo
  from separacoes s
  where s.id = e.separacao_id and s.projeto_id = new.id;

  update entregas_finalizadas e
  set codigo_obra = new.codigo
  from separacoes s
  where s.id = e.separacao_id and s.projeto_id = new.id;

  return new;
end;
$$;

-- 5) aposentar o gerador de código do sistema (contador estava em 1621, sem uso real)
drop function if exists public.gerar_codigo_projeto();
drop table if exists public.projeto_codigo_sequencia;

commit;
