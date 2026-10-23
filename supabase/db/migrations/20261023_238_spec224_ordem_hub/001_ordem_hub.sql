-- SPEC-224 (pedido do usuário 23/10): no Hub, Movimentação de Peças logo depois de Vendas e antes do Controle de
-- Produção. Só a ordem (systems.display_order). Sem BEGIN/COMMIT.

UPDATE public.systems SET display_order = 16 WHERE slug = 'controle-garantia';
UPDATE public.systems SET display_order = 15 WHERE slug = 'controle-producao';
UPDATE public.systems SET display_order = 14 WHERE slug = 'movimentacao-pecas';
