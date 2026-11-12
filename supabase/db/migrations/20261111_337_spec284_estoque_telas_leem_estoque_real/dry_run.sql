-- SPEC-284 dry-run: aplica o up dentro de uma transação, confere e desfaz (ROLLBACK). Nada fica gravado.
-- Rodar o conteúdo do up.sql SEM o BEGIN/COMMIT entre o BEGIN e as conferências abaixo.
BEGIN;

-- (colar aqui o corpo do up.sql, sem BEGIN/COMMIT)

-- Conferência 1: Dashboard = estoque real (esperado 0 diferenças)
SELECT 'v_estoque_produtos' AS view, count(*) AS linhas,
       count(*) FILTER (WHERE v.estoque_total      <> COALESCE(e.quantidade, 0)) AS total_diferente,
       count(*) FILTER (WHERE v.estoque_disponivel <> COALESCE(e.quantidade - e.quantidade_reservada, 0)) AS disponivel_diferente
  FROM public.v_estoque_produtos v
  LEFT JOIN public.estoque_itens e ON e.produto_id = v.produto_id AND e.local = 'Estoque';

-- Conferência 2: Pedido Avulso = estoque real (esperado 0 diferenças)
SELECT 'vw_estoque_produtos' AS view, count(*) AS linhas,
       count(*) FILTER (WHERE v.estoque_total      <> COALESCE(e.quantidade, 0)) AS total_diferente,
       count(*) FILTER (WHERE v.estoque_disponivel <> COALESCE(e.quantidade - e.quantidade_reservada, 0)) AS disponivel_diferente
  FROM public.vw_estoque_produtos v
  LEFT JOIN public.estoque_itens e ON e.produto_id = v.produto_id AND e.local = 'Estoque';

-- Conferência 3: exemplos citados na SPEC
SELECT produto_codigo, estoque_total, estoque_disponivel FROM public.vw_estoque_produtos
 WHERE produto_codigo IN ('13587', '12395', '12135', '8952') ORDER BY 1;

-- Conferência 4: security_invoker mantido na view do Compras
SELECT relname, reloptions FROM pg_class WHERE relname IN ('v_estoque_produtos', 'vw_estoque_produtos');

ROLLBACK;
