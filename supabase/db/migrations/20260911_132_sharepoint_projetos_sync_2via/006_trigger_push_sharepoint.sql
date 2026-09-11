-- SPEC-130 — trigger de push: qualquer INSERT/UPDATE dos campos sincronizados em `projetos`
-- chama a Edge Function `sharepoint-projetos-push` via pg_net (assíncrono).
--
-- Anti-eco: NÃO usa hash pra decidir se propaga. Usa `last_sync_source`, que a trigger
-- BEFORE `trg_projetos_stamp_sync_meta` (007) garante estar sempre correto em toda escrita
-- normal — só fica 'sharepoint' quando é literalmente a RPC de pull (009) escrevendo, porque
-- só ela liga a flag de sessão `app.sync_em_andamento`. Then: se `last_sync_source =
-- 'sharepoint'`, a escrita veio do próprio pull — não faz sentido reenviar pro SharePoint.
-- `sync_hash` aqui é só otimização (evita HTTP à toa quando o conteúdo sincronizado não
-- mudou de fato), não é o mecanismo de segurança contra loop.
--
-- Segurança: URL da function e o segredo compartilhado (x-sync-secret) ficam no Vault
-- (supabase_vault, já habilitado neste projeto), nunca hardcoded aqui. Precisa rodar, fora
-- desta migration (não commitar segredo em .sql versionado):
--   select vault.create_secret('https://<project-ref>.supabase.co/functions/v1/sharepoint-projetos-push', 'sharepoint_push_url');
--   select vault.create_secret('<um segredo aleatório>', 'sharepoint_sync_secret');
-- (a mesma Edge Function deve exigir esse header e recusar chamadas sem ele — ver
-- supabase/functions/sharepoint-projetos-push/index.ts).
--
-- Enquanto o secret 'sharepoint_push_url' não existir no Vault, a trigger não falha o
-- INSERT/UPDATE — só não dispara nada (guarda de segurança pra não quebrar o CRM antes do
-- pipeline estar pronto).

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
begin
  -- escrita originada do próprio pull (ver 007/009) — não repropaga pro SharePoint
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

  -- otimização: mesmo conteúdo já sincronizado como 'sistema' antes, não reenvia à toa
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

  -- auth.uid() só resolve algo aqui porque a trigger roda na mesma transação da escrita
  -- original feita via PostgREST/supabase-js como usuário autenticado. Repassa pro payload
  -- pra Edge Function (que roda com service role, sem esse contexto) gravar a atribuição
  -- certa via confirmar_push_sharepoint() (008).
  perform net.http_post(
    url := v_push_url,
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
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

comment on function public.trg_projetos_sharepoint_push_fn() is
  'Dispara a Edge Function sharepoint-projetos-push via pg_net a cada criação/edição relevante de projeto. Inerte até o secret sharepoint_push_url existir no Vault. SPEC-130.';

create trigger trg_projetos_sharepoint_push
after insert or update of
  nome, codigo, responsavel_nome, cidade, arquivado, data_entrada,
  nivel_estrategico, status, arquiteto_id, responsavel_obra_id
on public.projetos
for each row
execute function public.trg_projetos_sharepoint_push_fn();
