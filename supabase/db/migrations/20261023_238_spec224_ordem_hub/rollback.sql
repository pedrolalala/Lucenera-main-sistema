-- Rollback da 238: ordem anterior. Sem BEGIN/COMMIT.

UPDATE public.systems SET display_order = 101 WHERE slug = 'movimentacao-pecas';
UPDATE public.systems SET display_order = 14 WHERE slug = 'controle-producao';
UPDATE public.systems SET display_order = 15 WHERE slug = 'controle-garantia';
