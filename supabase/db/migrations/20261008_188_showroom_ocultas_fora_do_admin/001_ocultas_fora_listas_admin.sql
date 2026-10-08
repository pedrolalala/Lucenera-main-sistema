-- SPEC-184 (ampliação, 08/10/2026): peça tirada do showroom (LED, lâmpada etc.) some também
-- das listas do /admin — aba "Peças e fotos" e busca de produto ao vincular peça do PPT.
-- A montagem de conjuntos continua achando a peça (p_incluir_ocultos = true), para
-- poder compor luminária + lâmpada.
-- showroom_buscar_produto ganha parâmetro: DROP da assinatura antiga antes (CREATE OR
-- REPLACE com parâmetro novo criaria overload). Sem BEGIN/COMMIT no texto.

CREATE OR REPLACE FUNCTION public.showroom_listar_produtos_estoque(p_termo text DEFAULT NULL::text)
 RETURNS TABLE(codigo_produto integer, nome text, codigo_legado integer, referencia text, estoque_showroom integer, imagem_showroom_url text, marca text, eh_principal_de_grupo boolean, membro_de_codigo_produto integer)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select p.codigo_produto, p.nome, p.codigo_legado, p.referencia,
         coalesce(p.estoque_showroom,0), p.imagem_showroom_url, m.nome,
         exists(select 1 from public.showroom_grupo_itens g1 where g1.codigo_produto_principal = p.codigo_produto),
         (select g2.codigo_produto_principal from public.showroom_grupo_itens g2 where g2.codigo_produto_membro = p.codigo_produto)
  from public.produtos p
  left join public.marcas m on m.id = p.marca_id
  where p.ativo
    and coalesce(p.estoque_showroom,0) > 0
    and not exists (select 1 from public.showroom_ocultos o where o.codigo_produto = p.codigo_produto)
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

DROP FUNCTION IF EXISTS public.showroom_buscar_produto(text);

CREATE FUNCTION public.showroom_buscar_produto(p_termo text, p_incluir_ocultos boolean DEFAULT false)
 RETURNS TABLE(codigo_produto integer, nome text, marca text, estoque_showroom integer, valor_venda numeric, eh_principal_de_grupo boolean, membro_de_codigo_produto integer)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select p.codigo_produto, p.nome, m.nome, coalesce(p.estoque_showroom,0), coalesce(p.valor_venda,0),
         exists(select 1 from public.showroom_grupo_itens g1 where g1.codigo_produto_principal = p.codigo_produto),
         (select g2.codigo_produto_principal from public.showroom_grupo_itens g2 where g2.codigo_produto_membro = p.codigo_produto)
  from public.produtos p
  left join public.marcas m on m.id = p.marca_id
  where p.ativo
    and (p_incluir_ocultos or not exists (select 1 from public.showroom_ocultos o where o.codigo_produto = p.codigo_produto))
    and (
      p.codigo_produto::text = p_termo
      or p.nome ilike '%' || p_termo || '%'
      or p.codigo_legado::text ilike '%' || p_termo || '%'
      or p.referencia ilike '%' || p_termo || '%'
    )
  order by (p.codigo_produto::text = p_termo) desc, p.nome
  limit 20;
$function$;

GRANT EXECUTE ON FUNCTION public.showroom_buscar_produto(text, boolean) TO anon, authenticated;

NOTIFY pgrst, 'reload schema';
