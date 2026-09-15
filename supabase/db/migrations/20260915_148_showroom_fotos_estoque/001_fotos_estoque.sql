-- SPEC-148 — Showroom /admin: fotos do estoque (Fluxo A).
--
-- RASCUNHO — não aplicar sem aprovação. DDL: 1 tabela nova + 1 função helper +
-- 3 policies de storage.objects + 2 RPCs de upload.
--
-- Objetivo: permitir subir/trocar a foto de um produto já em estoque
-- (`produtos.estoque_showroom > 0`) direto por upload de arquivo, sem depender
-- do PowerPoint importado (fluxo já existente das migrations 125/127/128).
--
-- Mecanismo (Opção B, escolhida com o usuário em 2026-09-15 — ver SPEC-148 §8):
-- o client nunca tem sessão `authenticated` (chave sempre anônima), então uma
-- policy de storage.objects não enxerga usuário/senha. Por isso o upload passa
-- por uma "liberação temporária" (`showroom_upload_grants`, TTL 15 min) criada
-- só por RPC que exige credencial válida (`showroom_cred_ok`, migration 128).
-- A policy de storage.objects só libera INSERT/UPDATE/DELETE para o path exato
-- liberado. Nunca toca a pasta `import/` do fluxo PPT (ver SPEC-148 §9).

begin;

-- 1. Tabela de liberação temporária de upload -----------------------------------
create table if not exists public.showroom_upload_grants (
  codigo_produto  int primary key references public.produtos(codigo_produto),
  path            text not null,       -- caminho novo liberado p/ INSERT/UPDATE (produtos/...)
  old_path        text,                -- caminho antigo liberado p/ DELETE (só se também for produtos/...)
  criado_por      text not null,       -- admin_user que gerou a liberação
  criado_em       timestamptz not null default now(),
  expira_em       timestamptz not null default now() + interval '15 minutes'
);
alter table public.showroom_upload_grants enable row level security;
-- RLS on, SEM policy de select/insert/update/delete p/ anon/authenticated:
-- só é lida pela função SECURITY DEFINER usada nas policies de storage.objects.

-- Nota: `showroom_listar_produtos_estoque` (RPC de leitura sem credencial, whitelist não
-- sensível, mesmo padrão de `showroom_buscar_produto`) é criada só na migration seguinte
-- (002_peca_composta.sql), já com as 2 colunas de composição (`eh_principal_de_grupo`,
-- `membro_de_codigo_produto`) — a SPEC-148 desenhou as duas capacidades juntas e a versão
-- final da função (§6 da SPEC) já nasce com essas colunas; não faz sentido criar aqui uma
-- versão intermediária sem elas para já dropar/recriar 3 minutos depois.

-- 2. RPCs de escrita — credencial obrigatória (reaproveita showroom_cred_ok, migration 128) ---
create or replace function public.showroom_liberar_upload_produto(
  p_user text, p_senha text, p_codigo_produto int, p_extensao text
) returns jsonb
language plpgsql security definer set search_path = public
as $$
declare
  v_ext text := lower(p_extensao);
  v_old_url text;
  v_path text;
  v_old_path text;
begin
  if not public.showroom_cred_ok(p_user, p_senha) then
    raise exception 'usuario ou senha invalidos' using errcode = '28000';
  end if;
  if v_ext not in ('jpg','jpeg','png','webp') then
    raise exception 'extensao nao suportada: %', p_extensao using errcode = '22000';
  end if;

  select imagem_showroom_url into v_old_url
  from public.produtos where codigo_produto = p_codigo_produto and ativo;
  if not found then
    raise exception 'produto codigo % nao encontrado/ativo', p_codigo_produto using errcode = 'P0002';
  end if;

  v_path := 'produtos/' || p_codigo_produto || '_' || extract(epoch from now())::bigint || '.' || v_ext;

  -- Só libera DELETE do arquivo antigo se ele for desta MESMA pasta (produtos/).
  -- Nunca libera delete de algo em import/ — ver SPEC-148 §9.
  if v_old_url like '%/storage/v1/object/public/showroom-lucenera/produtos/%' then
    v_old_path := split_part(v_old_url, '/storage/v1/object/public/showroom-lucenera/', 2);
  end if;

  insert into public.showroom_upload_grants (codigo_produto, path, old_path, criado_por)
  values (p_codigo_produto, v_path, v_old_path, p_user)
  on conflict (codigo_produto) do update
    set path = excluded.path, old_path = excluded.old_path,
        criado_por = excluded.criado_por, criado_em = now(),
        expira_em = now() + interval '15 minutes';

  return jsonb_build_object('path', v_path, 'old_path', v_old_path);
end;
$$;

create or replace function public.showroom_confirmar_foto_produto(
  p_user text, p_senha text, p_codigo_produto int, p_url_publica text
) returns jsonb
language plpgsql security definer set search_path = public
as $$
declare
  v_grant public.showroom_upload_grants%rowtype;
begin
  if not public.showroom_cred_ok(p_user, p_senha) then
    raise exception 'usuario ou senha invalidos' using errcode = '28000';
  end if;

  select * into v_grant from public.showroom_upload_grants
  where codigo_produto = p_codigo_produto and expira_em > now();
  if not found then
    raise exception 'nenhuma liberacao de upload valida para o produto %', p_codigo_produto using errcode = 'P0002';
  end if;

  if position(('/showroom-lucenera/' || v_grant.path) in p_url_publica) = 0 then
    raise exception 'url nao corresponde ao path liberado' using errcode = '22000';
  end if;

  if not exists (select 1 from storage.objects where bucket_id = 'showroom-lucenera' and name = v_grant.path) then
    raise exception 'arquivo nao encontrado no storage: %', v_grant.path using errcode = 'P0002';
  end if;

  update public.produtos
     set imagem_showroom_url = p_url_publica, updated_at = now()
   where codigo_produto = p_codigo_produto;

  delete from public.showroom_upload_grants where codigo_produto = p_codigo_produto;

  return jsonb_build_object('ok', true, 'url', p_url_publica, 'old_path', v_grant.old_path);
end;
$$;

grant execute on function public.showroom_liberar_upload_produto(text,text,int,text) to anon, authenticated;
grant execute on function public.showroom_confirmar_foto_produto(text,text,int,text) to anon, authenticated;

-- 4. Storage: policies de storage.objects (escrita liberada só pra path com grant válido) ---
create or replace function public.showroom_upload_permitido(p_bucket text, p_name text)
returns boolean
language sql stable security definer set search_path = public
as $$
  select exists (
    select 1 from public.showroom_upload_grants g
    where p_bucket = 'showroom-lucenera'
      and g.expira_em > now()
      and (g.path = p_name or g.old_path = p_name)
  );
$$;
grant execute on function public.showroom_upload_permitido(text,text) to anon, authenticated;

drop policy if exists showroom_produtos_upload on storage.objects;
create policy showroom_produtos_upload
on storage.objects for insert to anon, authenticated
with check (
  bucket_id = 'showroom-lucenera'
  and (storage.foldername(name))[1] = 'produtos'
  and public.showroom_upload_permitido(bucket_id, name)
);

drop policy if exists showroom_produtos_update on storage.objects;
create policy showroom_produtos_update
on storage.objects for update to anon, authenticated
using (
  bucket_id = 'showroom-lucenera'
  and (storage.foldername(name))[1] = 'produtos'
  and public.showroom_upload_permitido(bucket_id, name)
);

drop policy if exists showroom_produtos_delete on storage.objects;
create policy showroom_produtos_delete
on storage.objects for delete to anon, authenticated
using (
  bucket_id = 'showroom-lucenera'
  and (storage.foldername(name))[1] = 'produtos'
  and public.showroom_upload_permitido(bucket_id, name)
);
-- Nada muda na policy de leitura publica existente (showroom_lucenera_public_read)
-- nem nas policies do bucket 'revenda-ubiqua-images'/'orcamentos' (outros sistemas).

commit;
