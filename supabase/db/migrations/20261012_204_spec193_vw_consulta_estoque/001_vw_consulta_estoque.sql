-- SPEC-193 C1/C3/C4: consulta de estoque enxuta, separada do cadastro de produto.
-- Uma linha por peça com só o que a Consulta de Produtos (Cadastro) e a busca do Orçamento mostram:
-- código, referência, descrição, preço de venda, marca/categoria (para filtro) e os saldos já calculados.
-- Nada de custo, imposto ou fiscal. Só ACRESCENTA (nenhuma tabela ou view existente muda).
--
-- Mesma conta da tela (src/lib/estoque-sectors.ts, calcularDisponivel — SPEC-191 B1 + decisão 09/10):
--   estoque_total (Geral) = estoque_itens fora de Showroom, Estoque Garantia e Estoque Casa Cor
--   comprometido          = MAIOR entre (reserva + separação do sistema) e a reserva da Connect
--                           (estoque_itens.quantidade_reservada nos mesmos locais)
--   estoque_disponivel    = estoque_total − comprometido
--   tem_saldo             = alguma quantidade ≠ 0 (geral, disponível, showroom ou qualquer local) —
--                           base do filtro "Só com estoque" (SPEC-195 B1)
-- security_invoker: vale a RLS de produtos (quem não vê produtos não vê a consulta).

CREATE OR REPLACE VIEW public.vw_consulta_estoque
WITH (security_invoker = true) AS
WITH itens AS (
  SELECT
    ei.produto_id,
    sum(ei.quantidade) FILTER (
      WHERE ei.local NOT IN ('Showroom', 'Estoque Garantia', 'Estoque Casa Cor')
    ) AS geral,
    sum(COALESCE(ei.quantidade_reservada, 0)) FILTER (
      WHERE ei.local NOT IN ('Showroom', 'Estoque Garantia', 'Estoque Casa Cor')
    ) AS reservado_connect,
    count(*) FILTER (WHERE ei.local NOT IN ('Estoque Garantia', 'Estoque Casa Cor')) AS n_itens_geral,
    bool_or(COALESCE(ei.quantidade, 0) <> 0) AS algum_local_com_saldo
  FROM public.estoque_itens ei
  GROUP BY ei.produto_id
),
base AS (
  SELECT
    p.id AS produto_id,
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
    COALESCE(i.geral, 0) AS estoque_total,
    COALESCE(s.q_reserva, 0) AS q_reserva,
    COALESCE(s.q_separacao, 0) AS q_separacao,
    COALESCE(s.q_entrega_futura, 0) AS q_entrega_futura,
    COALESCE(i.reservado_connect, 0) AS reservado_connect,
    GREATEST(COALESCE(s.q_reserva, 0) + COALESCE(s.q_separacao, 0), COALESCE(i.reservado_connect, 0))
      AS estoque_reservado,
    COALESCE(p.estoque_showroom, 0) AS estoque_showroom,
    COALESCE(i.n_itens_geral, 0) > 0 AS has_estoque,
    COALESCE(i.algum_local_com_saldo, false) AS algum_local_com_saldo
  FROM public.produtos p
  LEFT JOIN public.marcas m ON m.id = p.marca_id
  LEFT JOIN public.categorias_produto cp ON cp.id = p.categoria_id
  LEFT JOIN itens i ON i.produto_id = p.id
  LEFT JOIN public.vw_cadastro_produto_setores s ON s.produto_id = p.id
)
SELECT
  b.produto_id,
  b.codigo_produto,
  b.referencia,
  b.nome,
  b.ativo,
  b.preco_venda,
  b.valor_venda,
  b.marca_id,
  b.marca_nome,
  b.categoria_id,
  b.categoria_nome,
  b.estoque_total,
  b.q_reserva,
  b.q_separacao,
  b.q_entrega_futura,
  b.reservado_connect,
  b.estoque_reservado,
  b.estoque_total - b.estoque_reservado AS estoque_disponivel,
  b.estoque_showroom,
  b.has_estoque,
  (b.estoque_total <> 0
    OR b.estoque_total - b.estoque_reservado <> 0
    OR b.estoque_showroom <> 0
    OR b.algum_local_com_saldo) AS tem_saldo
FROM base b;

COMMENT ON VIEW public.vw_consulta_estoque IS
  'SPEC-193 C1: consulta de estoque enxuta (sem custo/imposto/fiscal). Disponível = Geral − maior(reserva+separação do sistema, reserva Connect).';

REVOKE ALL ON public.vw_consulta_estoque FROM anon, public;
GRANT SELECT ON public.vw_consulta_estoque TO authenticated, service_role;
