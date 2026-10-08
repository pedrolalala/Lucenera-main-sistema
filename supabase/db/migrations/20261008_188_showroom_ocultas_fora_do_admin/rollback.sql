-- Rollback da 20261008_188: volta as duas funções à definição de antes.
CREATE OR REPLACE FUNCTION public.showroom_listar_produtos_estoque(p_termo text DEFAULT NULL::text)
 RETURNS TABLE(codigo_produto integer, nome text, codigo_legado integer, referencia text, estoque_showroom integer, imagem_showroom_url text, marca text, eh_principal_de_grupo boolean, membro_de_codigo_produto integer)
 LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public'
AS $function$
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
$function$;

DROP FUNCTION IF EXISTS public.showroom_buscar_produto(text, boolean);
CREATE FUNCTION public.showroom_buscar_produto(p_termo text)
 RETURNS TABLE(codigo_produto integer, nome text, marca text, estoque_showroom integer, valor_venda numeric, eh_principal_de_grupo boolean, membro_de_codigo_produto integer)
 LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public'
AS $function$
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
$function$;
GRANT EXECUTE ON FUNCTION public.showroom_buscar_produto(text) TO anon, authenticated;
NOTIFY pgrst, 'reload schema';
