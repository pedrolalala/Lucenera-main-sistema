-- Rollback da 253 (SPEC-235): tira a trava de situação da peça e volta a vw_consulta_estoque sem as colunas novas.
BEGIN;
DROP TRIGGER IF EXISTS trg_orcamento_itens_situacao_peca ON public.orcamento_itens;
DROP FUNCTION IF EXISTS public.trg_orcamento_itens_situacao_peca();
DROP VIEW public.vw_consulta_estoque;
CREATE VIEW public.vw_consulta_estoque WITH (security_invoker = true) AS
WITH itens AS (
         SELECT ei.produto_id,
            sum(ei.quantidade) FILTER (WHERE (ei.local <> ALL (ARRAY['Showroom'::estoque_local, 'Estoque Garantia'::estoque_local, 'Estoque Casa Cor'::estoque_local]))) AS geral,
            sum(COALESCE(ei.quantidade_reservada, (0)::numeric)) FILTER (WHERE (ei.local <> ALL (ARRAY['Showroom'::estoque_local, 'Estoque Garantia'::estoque_local, 'Estoque Casa Cor'::estoque_local]))) AS reservado_connect,
            count(*) FILTER (WHERE (ei.local <> ALL (ARRAY['Estoque Garantia'::estoque_local, 'Estoque Casa Cor'::estoque_local]))) AS n_itens_geral,
            bool_or((COALESCE(ei.quantidade, (0)::numeric) <> (0)::numeric)) AS algum_local_com_saldo
           FROM estoque_itens ei
          GROUP BY ei.produto_id
        ), base AS (
         SELECT p.id AS produto_id,
            p.codigo_produto,
            p.referencia,
            p.nome,
            p.ativo,
            p.preco_venda,
            p.valor_venda,
            p.marca_id,
            m.nome AS marca_nome,
            p.categoria_id,
            cp.nome AS categoria_nome,
            COALESCE(i.geral, (0)::numeric) AS estoque_total,
            COALESCE(s.q_reserva, (0)::numeric) AS q_reserva,
            COALESCE(s.q_separacao, (0)::numeric) AS q_separacao,
            COALESCE(s.q_entrega_futura, (0)::numeric) AS q_entrega_futura,
            COALESCE(i.reservado_connect, (0)::numeric) AS reservado_connect,
            GREATEST((COALESCE(s.q_reserva, (0)::numeric) + COALESCE(s.q_separacao, (0)::numeric)), COALESCE(i.reservado_connect, (0)::numeric)) AS estoque_reservado,
            COALESCE(p.estoque_showroom, 0) AS estoque_showroom,
            (COALESCE(i.n_itens_geral, (0)::bigint) > 0) AS has_estoque,
            COALESCE(i.algum_local_com_saldo, false) AS algum_local_com_saldo
           FROM ((((produtos p
             LEFT JOIN marcas m ON ((m.id = p.marca_id)))
             LEFT JOIN categorias_produto cp ON ((cp.id = p.categoria_id)))
             LEFT JOIN itens i ON ((i.produto_id = p.id)))
             LEFT JOIN vw_cadastro_produto_setores s ON ((s.produto_id = p.id)))
        )
 SELECT produto_id,
    codigo_produto,
    referencia,
    nome,
    ativo,
    preco_venda,
    valor_venda,
    marca_id,
    marca_nome,
    categoria_id,
    categoria_nome,
    estoque_total,
    q_reserva,
    q_separacao,
    q_entrega_futura,
    reservado_connect,
    estoque_reservado,
    (estoque_total - estoque_reservado) AS estoque_disponivel,
    estoque_showroom,
    has_estoque,
    ((estoque_total <> (0)::numeric) OR ((estoque_total - estoque_reservado) <> (0)::numeric) OR (estoque_showroom <> 0) OR algum_local_com_saldo) AS tem_saldo
   FROM base b;
GRANT SELECT, INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER ON public.vw_consulta_estoque TO authenticated, service_role;
COMMIT;
