-- SPEC-125 — Tela de curadoria dentro do site do showroom.
--
-- RASCUNHO — não aplicar sem aprovação. DDL: 1 tabela nova + 2 RPCs + config PIN.
--
-- Objetivo: um "campo" (/admin no site) onde alguém do time vê cada peça do
-- PowerPoint que ainda NÃO está vinculada a um produto, com a foto, e escolhe o
-- produto de estoque correspondente. Ao confirmar, a RPC grava
-- produtos.imagem_showroom_url + estoque_showroom (mesmo efeito do script
-- `aplicar`), e marca a peça como vinculada.
--
-- Acesso: PIN compartilhado (tabela showroom_config). É ferramenta interna de
-- uso pontual — sem contas de usuário. O PIN nunca vai no bundle; é digitado na
-- tela e mandado em cada chamada de RPC. Pode evoluir p/ login real depois.

begin;

-- 1. Staging das peças extraídas do PowerPoint ---------------------------------
create table if not exists public.showroom_import_pecas (
  slide                    int primary key,
  nome_ppt                 text not null,
  qtd_ppt                  int,
  marca_ppt                text,
  observacoes              text,
  imagem_url               text not null,   -- bucket showroom-lucenera, pasta import/
  candidatos               jsonb default '[]'::jsonb,  -- [{codigo,nome,score}]
  codigo_produto_vinculado int,
  vinculado_em             timestamptz,
  vinculado_por            text,
  criado_em                timestamptz not null default now()
);
comment on table public.showroom_import_pecas is
  'SPEC-125: peças do PPT do showroom p/ curadoria manual na tela /admin do site.';

alter table public.showroom_import_pecas enable row level security;
-- lista é só nome + foto + candidatos (nada sensível): leitura anônima liberada.
drop policy if exists showroom_import_sel_anon on public.showroom_import_pecas;
create policy showroom_import_sel_anon on public.showroom_import_pecas
  for select to anon, authenticated using (true);
-- escrita só via RPC SECURITY DEFINER (sem policy de insert/update/delete).

-- 2. Config do PIN -----------------------------------------------------------
create table if not exists public.showroom_config (
  chave text primary key,
  valor text not null
);
insert into public.showroom_config (chave, valor)
values ('admin_pin', 'TROCAR-ESTE-PIN')
on conflict (chave) do nothing;
-- showroom_config NÃO é legível por anon (sem policy + RLS on).
alter table public.showroom_config enable row level security;

-- 3. RPC: vincular uma peça a um produto -------------------------------------
create or replace function public.showroom_vincular_peca(
  p_pin   text,
  p_slide int,
  p_codigo_produto int
) returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_pin  text;
  v_peca public.showroom_import_pecas%rowtype;
  v_prod_id uuid;
  v_sh   int;
begin
  select valor into v_pin from public.showroom_config where chave = 'admin_pin';
  if v_pin is null or p_pin is distinct from v_pin then
    raise exception 'PIN invalido' using errcode = '28000';
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
         estoque_showroom = case when v_sh > 0 then v_sh
                                 else coalesce(v_peca.qtd_ppt, 1) end,
         updated_at = now()
   where id = v_prod_id;

  update public.showroom_import_pecas
     set codigo_produto_vinculado = p_codigo_produto,
         vinculado_em = now()
   where slide = p_slide;

  return jsonb_build_object('ok', true, 'slide', p_slide, 'codigo_produto', p_codigo_produto);
end;
$$;

-- 4. RPC: desvincular (limpa a foto do produto) ----------------------------
create or replace function public.showroom_desvincular_peca(
  p_pin   text,
  p_slide int
) returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_pin text;
  v_cod int;
begin
  select valor into v_pin from public.showroom_config where chave = 'admin_pin';
  if v_pin is null or p_pin is distinct from v_pin then
    raise exception 'PIN invalido' using errcode = '28000';
  end if;

  select codigo_produto_vinculado into v_cod
  from public.showroom_import_pecas where slide = p_slide;

  if v_cod is not null then
    update public.produtos set imagem_showroom_url = null, updated_at = now()
     where codigo_produto = v_cod;
  end if;
  update public.showroom_import_pecas
     set codigo_produto_vinculado = null, vinculado_em = null
   where slide = p_slide;
  return jsonb_build_object('ok', true, 'slide', p_slide);
end;
$$;

-- 5. RPC: busca de produto p/ o autocomplete da tela (por codigo/nome) -----
create or replace function public.showroom_buscar_produto(p_termo text)
returns table (codigo_produto int, nome text, marca text, estoque_showroom int, valor_venda numeric)
language sql
stable
security definer
set search_path = public
as $$
  select p.codigo_produto, p.nome, m.nome, coalesce(p.estoque_showroom,0), coalesce(p.valor_venda,0)
  from public.produtos p
  left join public.marcas m on m.id = p.marca_id
  where p.ativo
    and (
      p.codigo_produto::text = p_termo
      or p.nome ilike '%' || p_termo || '%'
      or p.sku ilike '%' || p_termo || '%'
      or p.referencia ilike '%' || p_termo || '%'
    )
  order by (p.codigo_produto::text = p_termo) desc, p.nome
  limit 20;
$$;

grant execute on function public.showroom_vincular_peca(text, int, int)   to anon, authenticated;
grant execute on function public.showroom_desvincular_peca(text, int)     to anon, authenticated;
grant execute on function public.showroom_buscar_produto(text)            to anon, authenticated;

commit;
