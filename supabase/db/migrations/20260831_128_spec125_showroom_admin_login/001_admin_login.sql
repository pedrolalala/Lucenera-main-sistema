-- SPEC-125 — Tela /admin: troca o PIN unico por usuario + senha.
--
-- RASCUNHO — aplicar com autorizacao. Credencial compartilhada (nao ha contas
-- por pessoa): usuario "Lucenera", senha guardada como hash bcrypt em
-- showroom_config. As RPCs de curadoria passam a exigir (p_user, p_senha).

begin;

create extension if not exists pgcrypto with schema extensions;

-- credenciais em showroom_config (RLS on, sem policy -> ninguem le por PostgREST)
delete from public.showroom_config where chave = 'admin_pin';
insert into public.showroom_config (chave, valor) values
  ('admin_user', 'Lucenera'),
  ('admin_pass_hash', extensions.crypt('Lucenera123', extensions.gen_salt('bf')))
on conflict (chave) do update set valor = excluded.valor;

-- helper interno de checagem
create or replace function public.showroom_cred_ok(p_user text, p_senha text)
returns boolean
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_user text;
  v_hash text;
begin
  select valor into v_user from public.showroom_config where chave = 'admin_user';
  select valor into v_hash from public.showroom_config where chave = 'admin_pass_hash';
  return v_user is not null
     and v_hash is not null
     and p_user = v_user
     and extensions.crypt(coalesce(p_senha, ''), v_hash) = v_hash;
end;
$$;

-- RPC de login (valida credencial na hora, pra tela dar feedback)
create or replace function public.showroom_login(p_user text, p_senha text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.showroom_cred_ok(p_user, p_senha) then
    raise exception 'usuario ou senha invalidos' using errcode = '28000';
  end if;
  return jsonb_build_object('ok', true);
end;
$$;

-- Recria as RPCs de curadoria com (p_user, p_senha) no lugar de (p_pin) ---------
drop function if exists public.showroom_vincular_peca(text, int, int);
drop function if exists public.showroom_desvincular_peca(text, int);

create or replace function public.showroom_vincular_peca(
  p_user  text,
  p_senha text,
  p_slide int,
  p_codigo_produto int
) returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_peca public.showroom_import_pecas%rowtype;
  v_prod_id uuid;
  v_sh int;
begin
  if not public.showroom_cred_ok(p_user, p_senha) then
    raise exception 'usuario ou senha invalidos' using errcode = '28000';
  end if;

  select * into v_peca from public.showroom_import_pecas where slide = p_slide;
  if not found then
    raise exception 'peca % nao encontrada', p_slide using errcode = 'P0002';
  end if;

  select id, coalesce(estoque_showroom, 0) into v_prod_id, v_sh
  from public.produtos where codigo_produto = p_codigo_produto and ativo;
  if v_prod_id is null then
    raise exception 'produto codigo % nao encontrado/ativo', p_codigo_produto using errcode = 'P0002';
  end if;

  update public.produtos
     set imagem_showroom_url = v_peca.imagem_url,
         estoque_showroom = case when v_sh > 0 then v_sh else coalesce(v_peca.qtd_ppt, 1) end,
         updated_at = now()
   where id = v_prod_id;

  update public.showroom_import_pecas
     set codigo_produto_vinculado = p_codigo_produto, vinculado_em = now(), vinculado_por = p_user
   where slide = p_slide;

  return jsonb_build_object('ok', true, 'slide', p_slide, 'codigo_produto', p_codigo_produto);
end;
$$;

create or replace function public.showroom_desvincular_peca(
  p_user  text,
  p_senha text,
  p_slide int
) returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_cod int;
begin
  if not public.showroom_cred_ok(p_user, p_senha) then
    raise exception 'usuario ou senha invalidos' using errcode = '28000';
  end if;

  select codigo_produto_vinculado into v_cod
  from public.showroom_import_pecas where slide = p_slide;
  if v_cod is not null then
    update public.produtos set imagem_showroom_url = null, updated_at = now()
     where codigo_produto = v_cod;
  end if;
  update public.showroom_import_pecas
     set codigo_produto_vinculado = null, vinculado_em = null, vinculado_por = null
   where slide = p_slide;
  return jsonb_build_object('ok', true, 'slide', p_slide);
end;
$$;

revoke all on function public.showroom_cred_ok(text, text) from anon, authenticated, public;
grant execute on function public.showroom_login(text, text)                     to anon, authenticated;
grant execute on function public.showroom_vincular_peca(text, text, int, int)   to anon, authenticated;
grant execute on function public.showroom_desvincular_peca(text, text, int)     to anon, authenticated;
-- showroom_buscar_produto(text) continua como esta (migration 127).

commit;
