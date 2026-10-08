-- SPEC-184 (08/10/2026): tirar peça da vitrine do Showroom pelo /admin, de forma reversível.
-- Produto, foto e estoque ficam intactos; a peça oculta não volta sozinha quando o Connect
-- traz estoque de novo. Sem BEGIN/COMMIT no texto (aplicar com dry-run + rollback antes).

CREATE TABLE IF NOT EXISTS public.showroom_ocultos (
  codigo_produto integer PRIMARY KEY REFERENCES public.produtos (codigo_produto) ON DELETE CASCADE,
  ocultado_em timestamptz NOT NULL DEFAULT now()
);
-- Só as RPCs SECURITY DEFINER abaixo mexem nela (a view é do postgres, lê normalmente).
ALTER TABLE public.showroom_ocultos ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.showroom_ocultos FROM anon, authenticated;

-- Mesma view de antes (mesmas colunas, mesma ordem) + "não está oculta".
CREATE OR REPLACE VIEW public.vw_showroom_publico AS
 WITH avulsas AS (
         SELECT p.codigo_produto,
            p.nome,
            m.nome AS marca,
            COALESCE(cp.nome, NULLIF(p.categoria, ''::text)) AS categoria,
            p.estoque_showroom,
            COALESCE(p.valor_venda, 0::numeric) AS valor_venda,
            NULLIF(p.descricao_tecnica, ''::text) AS descricao_tecnica,
            p.imagem_showroom_url,
            p.updated_at AS atualizado_em
           FROM produtos p
             LEFT JOIN marcas m ON m.id = p.marca_id
             LEFT JOIN categorias_produto cp ON cp.id = p.categoria_id
          WHERE p.ativo AND p.imagem_showroom_url IS NOT NULL AND p.imagem_showroom_url <> ''::text AND COALESCE(p.estoque_showroom, 0) > 0
            AND NOT (EXISTS ( SELECT 1 FROM showroom_grupo_itens g WHERE g.codigo_produto_membro = p.codigo_produto))
            AND NOT (EXISTS ( SELECT 1 FROM showroom_grupo_itens g WHERE g.codigo_produto_principal = p.codigo_produto))
            AND NOT (EXISTS ( SELECT 1 FROM showroom_ocultos o WHERE o.codigo_produto = p.codigo_produto))
        ), conjuntos_agregado AS (
         SELECT g.codigo_produto_principal,
            sum(COALESCE(pm.valor_venda, 0::numeric) * g.quantidade::numeric) AS valor_membros,
            min(floor(
                CASE
                    WHEN pm.ativo THEN COALESCE(pm.estoque_showroom, 0)
                    ELSE 0
                END::numeric / g.quantidade::numeric))::integer AS min_conjuntos_membros
           FROM showroom_grupo_itens g
             JOIN produtos pm ON pm.codigo_produto = g.codigo_produto_membro
          GROUP BY g.codigo_produto_principal
        ), conjuntos AS (
         SELECT pr.codigo_produto,
            pr.nome,
            mpr.nome AS marca,
            COALESCE(cppr.nome, NULLIF(pr.categoria, ''::text)) AS categoria,
            LEAST(COALESCE(pr.estoque_showroom, 0), COALESCE(ca.min_conjuntos_membros, 0)) AS estoque_showroom,
            COALESCE(pr.valor_venda, 0::numeric) + COALESCE(ca.valor_membros, 0::numeric) AS valor_venda,
            NULLIF(pr.descricao_tecnica, ''::text) AS descricao_tecnica,
            pr.imagem_showroom_url,
            pr.updated_at AS atualizado_em
           FROM conjuntos_agregado ca
             JOIN produtos pr ON pr.codigo_produto = ca.codigo_produto_principal
             LEFT JOIN marcas mpr ON mpr.id = pr.marca_id
             LEFT JOIN categorias_produto cppr ON cppr.id = pr.categoria_id
          WHERE pr.ativo AND pr.imagem_showroom_url IS NOT NULL AND pr.imagem_showroom_url <> ''::text
            AND NOT (EXISTS ( SELECT 1 FROM showroom_ocultos o WHERE o.codigo_produto = pr.codigo_produto))
        )
 SELECT avulsas.codigo_produto, avulsas.nome, avulsas.marca, avulsas.categoria, avulsas.estoque_showroom,
        avulsas.valor_venda, avulsas.descricao_tecnica, avulsas.imagem_showroom_url, avulsas.atualizado_em
   FROM avulsas
UNION ALL
 SELECT conjuntos.codigo_produto, conjuntos.nome, conjuntos.marca, conjuntos.categoria, conjuntos.estoque_showroom,
        conjuntos.valor_venda, conjuntos.descricao_tecnica, conjuntos.imagem_showroom_url, conjuntos.atualizado_em
   FROM conjuntos
  WHERE conjuntos.estoque_showroom > 0;

CREATE OR REPLACE FUNCTION public.showroom_ocultar_peca(p_user text, p_senha text, p_codigo_produto integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if not public.showroom_cred_ok(p_user, p_senha) then
    raise exception 'usuario ou senha invalidos' using errcode = '28000';
  end if;
  if not exists (select 1 from public.produtos where codigo_produto = p_codigo_produto) then
    raise exception 'produto % nao encontrado', p_codigo_produto;
  end if;
  insert into public.showroom_ocultos (codigo_produto) values (p_codigo_produto)
  on conflict (codigo_produto) do nothing;
  return jsonb_build_object('ok', true, 'codigo_produto', p_codigo_produto);
end;
$function$;

CREATE OR REPLACE FUNCTION public.showroom_reexibir_peca(p_user text, p_senha text, p_codigo_produto integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if not public.showroom_cred_ok(p_user, p_senha) then
    raise exception 'usuario ou senha invalidos' using errcode = '28000';
  end if;
  delete from public.showroom_ocultos where codigo_produto = p_codigo_produto;
  return jsonb_build_object('ok', true, 'codigo_produto', p_codigo_produto);
end;
$function$;

CREATE OR REPLACE FUNCTION public.showroom_listar_ocultas(p_user text, p_senha text)
 RETURNS TABLE (
   codigo_produto integer,
   nome text,
   marca text,
   referencia text,
   estoque_showroom integer,
   imagem_showroom_url text,
   ocultado_em timestamptz
 )
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if not public.showroom_cred_ok(p_user, p_senha) then
    raise exception 'usuario ou senha invalidos' using errcode = '28000';
  end if;
  return query
    select p.codigo_produto, p.nome, m.nome, p.referencia, coalesce(p.estoque_showroom, 0)::integer,
           p.imagem_showroom_url, o.ocultado_em
      from public.showroom_ocultos o
      join public.produtos p on p.codigo_produto = o.codigo_produto
      left join public.marcas m on m.id = p.marca_id
     order by o.ocultado_em desc;
end;
$function$;

GRANT EXECUTE ON FUNCTION public.showroom_ocultar_peca(text, text, integer) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.showroom_reexibir_peca(text, text, integer) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.showroom_listar_ocultas(text, text) TO anon, authenticated;

NOTIFY pgrst, 'reload schema';
