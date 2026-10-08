 WITH avulsas AS (
         SELECT p.codigo_produto,
            p.nome,
            m.nome AS marca,
            COALESCE(cp.nome, NULLIF(p.categoria, ''::text)) AS categoria,
            p.estoque_showroom,
            COALESCE(p.valor_venda, (0)::numeric) AS valor_venda,
            NULLIF(p.descricao_tecnica, ''::text) AS descricao_tecnica,
            p.imagem_showroom_url,
            p.updated_at AS atualizado_em
           FROM ((produtos p
             LEFT JOIN marcas m ON ((m.id = p.marca_id)))
             LEFT JOIN categorias_produto cp ON ((cp.id = p.categoria_id)))
          WHERE (p.ativo AND (p.imagem_showroom_url IS NOT NULL) AND (p.imagem_showroom_url <> ''::text) AND (COALESCE(p.estoque_showroom, 0) > 0) AND (NOT (EXISTS ( SELECT 1
                   FROM showroom_grupo_itens g
                  WHERE (g.codigo_produto_membro = p.codigo_produto)))) AND (NOT (EXISTS ( SELECT 1
                   FROM showroom_grupo_itens g
                  WHERE (g.codigo_produto_principal = p.codigo_produto)))))
        ), conjuntos_agregado AS (
         SELECT g.codigo_produto_principal,
            sum((COALESCE(pm.valor_venda, (0)::numeric) * (g.quantidade)::numeric)) AS valor_membros,
            (min(floor(((
                CASE
                    WHEN pm.ativo THEN COALESCE(pm.estoque_showroom, 0)
                    ELSE 0
                END)::numeric / (g.quantidade)::numeric))))::integer AS min_conjuntos_membros
           FROM (showroom_grupo_itens g
             JOIN produtos pm ON ((pm.codigo_produto = g.codigo_produto_membro)))
          GROUP BY g.codigo_produto_principal
        ), conjuntos AS (
         SELECT pr.codigo_produto,
            pr.nome,
            mpr.nome AS marca,
            COALESCE(cppr.nome, NULLIF(pr.categoria, ''::text)) AS categoria,
            LEAST(COALESCE(pr.estoque_showroom, 0), COALESCE(ca.min_conjuntos_membros, 0)) AS estoque_showroom,
            (COALESCE(pr.valor_venda, (0)::numeric) + COALESCE(ca.valor_membros, (0)::numeric)) AS valor_venda,
            NULLIF(pr.descricao_tecnica, ''::text) AS descricao_tecnica,
            pr.imagem_showroom_url,
            pr.updated_at AS atualizado_em
           FROM (((conjuntos_agregado ca
             JOIN produtos pr ON ((pr.codigo_produto = ca.codigo_produto_principal)))
             LEFT JOIN marcas mpr ON ((mpr.id = pr.marca_id)))
             LEFT JOIN categorias_produto cppr ON ((cppr.id = pr.categoria_id)))
          WHERE (pr.ativo AND (pr.imagem_showroom_url IS NOT NULL) AND (pr.imagem_showroom_url <> ''::text))
        )
 SELECT avulsas.codigo_produto,
    avulsas.nome,
    avulsas.marca,
    avulsas.categoria,
    avulsas.estoque_showroom,
    avulsas.valor_venda,
    avulsas.descricao_tecnica,
    avulsas.imagem_showroom_url,
    avulsas.atualizado_em
   FROM avulsas
UNION ALL
 SELECT conjuntos.codigo_produto,
    conjuntos.nome,
    conjuntos.marca,
    conjuntos.categoria,
    conjuntos.estoque_showroom,
    conjuntos.valor_venda,
    conjuntos.descricao_tecnica,
    conjuntos.imagem_showroom_url,
    conjuntos.atualizado_em
   FROM conjuntos
  WHERE (conjuntos.estoque_showroom > 0);