-- Pedido do usuário (26/10): no Hub, Contas a Pagar e Contas a Receber lado a lado (a Separação Parcial ficava no
-- meio porque havia empate de display_order 6/7). Renumera sem empate, mantendo o resto da ordem. Sem BEGIN/COMMIT.

UPDATE public.systems SET display_order = 6 WHERE slug = 'financeiro';
UPDATE public.systems SET display_order = 7 WHERE slug = 'contas-pagar';
UPDATE public.systems SET display_order = 8 WHERE slug = 'contas-receber';
UPDATE public.systems SET display_order = 9 WHERE slug = 'separacao-parcial';
UPDATE public.systems SET display_order = 10 WHERE slug = 'logistica';
UPDATE public.systems SET display_order = 11 WHERE slug = 'ubiqua';
UPDATE public.systems SET display_order = 12 WHERE slug = 'dashboard-financeiro';
UPDATE public.systems SET display_order = 13 WHERE slug = 'memoria';
UPDATE public.systems SET display_order = 14 WHERE slug = 'showroom';
UPDATE public.systems SET display_order = 15 WHERE slug = 'vendas';
UPDATE public.systems SET display_order = 16 WHERE slug = 'movimentacao-pecas';
UPDATE public.systems SET display_order = 17 WHERE slug = 'controle-producao';
UPDATE public.systems SET display_order = 18 WHERE slug = 'controle-garantia';
