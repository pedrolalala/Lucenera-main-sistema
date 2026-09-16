-- SPEC-148 — Showroom /admin: troca SKU por codigo_legado nas RPCs de estoque/composição.
--
-- RASCUNHO — não aplicar sem aprovação. Ajuste pontual pós-implementação: testando a aba
-- "Fotos do estoque" ao vivo, o Pedro pediu pra trocar o campo `sku` (text) pelo
-- `codigo_legado` (int) — é o identificador que o time reconhece nessas telas. Troca a coluna
-- retornada e o campo pesquisado nas 3 RPCs de leitura desta SPEC. Nenhuma mudança de
-- escrita/RLS/Storage.

begin;

drop function if exists public.showroom_listar_produtos_estoque(text);
create or replace function public.showroom_listar_produtos_estoque(p_termo text default null)
returns table (
  codigo_produto int, nome text, codigo_legado int, referencia text,
  estoque_showroom int, imagem_showroom_url text, marca text,
  eh_principal_de_grupo boolean, membro_de_codigo_produto int
)
language sql stable security definer set search_path = public
as $$
  select p.codigo_produto, p.nome, p.codigo_legado, p.referencia,
         coalesce(p.estoque_showroom,0), p.imagem_showroom_url, m.nome,
         exists(select 1 from public.showroom_grupo_itens g1 where g1.codigo_produto_principal = p.codigo_produto),
         (select g2.codigo_produto_principal from public.showroom_grupo_itens g2 where g2.codigo_produto_membro = p.codigo_produto)
  from public.produtos p
  left join public.marcas m on m.id = p.marca_id
  where p.ativo
    and coalesce(p.estoque_showroom,0) > 0
    and (
      p_termo is null or p_termo = ''
      or p.nome ilike '%'||p_termo||'%'
      or p.codigo_legado::text ilike '%'||p_termo||'%'
      or p.referencia ilike '%'||p_termo||'%'
      or p.codigo_produto::text = p_termo
    )
  order by (p.imagem_showroom_url is null) desc, p.nome
  limit 1000;
$$;
grant execute on function public.showroom_listar_produtos_estoque(text) to anon, authenticated;

drop function if exists public.showroom_buscar_produto(text);
create or replace function public.showroom_buscar_produto(p_termo text)
returns table (
  codigo_produto int, nome text, marca text, estoque_showroom int, valor_venda numeric,
  eh_principal_de_grupo boolean, membro_de_codigo_produto int
)
language sql stable security definer set search_path = public
as $$
  select p.codigo_produto, p.nome, m.nome, coalesce(p.estoque_showroom,0), coalesce(p.valor_venda,0),
         exists(select 1 from public.showroom_grupo_itens g1 where g1.codigo_produto_principal = p.codigo_produto),
         (select g2.codigo_produto_principal from public.showroom_grupo_itens g2 where g2.codigo_produto_membro = p.codigo_produto)
  from public.produtos p
  left join public.marcas m on m.id = p.marca_id
  where p.ativo
    and (
      p.codigo_produto::text = p_termo
      or p.nome ilike '%' || p_termo || '%'
      or p.codigo_legado::text ilike '%' || p_termo || '%'
      or p.referencia ilike '%' || p_termo || '%'
    )
  order by (p.codigo_produto::text = p_termo) desc, p.nome
  limit 20;
$$;
grant execute on function public.showroom_buscar_produto(text) to anon, authenticated;

drop function if exists public.showroom_obter_composicao(int);
create or replace function public.showroom_obter_composicao(p_codigo_produto_principal int)
returns table (codigo_produto int, nome text, codigo_legado int, estoque_showroom int, valor_venda numeric, quantidade int)
language sql stable security definer set search_path = public
as $$
  select p.codigo_produto, p.nome, p.codigo_legado, coalesce(p.estoque_showroom,0), coalesce(p.valor_venda,0), g.quantidade
  from public.showroom_grupo_itens g
  join public.produtos p on p.codigo_produto = g.codigo_produto_membro
  where g.codigo_produto_principal = p_codigo_produto_principal
  order by p.nome;
$$;
grant execute on function public.showroom_obter_composicao(int) to anon, authenticated;

commit;
