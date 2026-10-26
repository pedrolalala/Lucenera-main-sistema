-- Rollback da 239: ordem anterior (com os empates 6/7). Sem BEGIN/COMMIT.

UPDATE public.systems SET display_order = 6 WHERE slug = 'financeiro';
UPDATE public.systems SET display_order = 6 WHERE slug = 'contas-pagar';
UPDATE public.systems SET display_order = 7 WHERE slug = 'contas-receber';
UPDATE public.systems SET display_order = 7 WHERE slug = 'separacao-parcial';
UPDATE public.systems SET display_order = 8 WHERE slug = 'logistica';
UPDATE public.systems SET display_order = 9 WHERE slug = 'ubiqua';
UPDATE public.systems SET display_order = 10 WHERE slug = 'dashboard-financeiro';
UPDATE public.systems SET display_order = 11 WHERE slug = 'memoria';
UPDATE public.systems SET display_order = 12 WHERE slug = 'showroom';
UPDATE public.systems SET display_order = 13 WHERE slug = 'vendas';
UPDATE public.systems SET display_order = 14 WHERE slug = 'movimentacao-pecas';
UPDATE public.systems SET display_order = 15 WHERE slug = 'controle-producao';
UPDATE public.systems SET display_order = 16 WHERE slug = 'controle-garantia';
