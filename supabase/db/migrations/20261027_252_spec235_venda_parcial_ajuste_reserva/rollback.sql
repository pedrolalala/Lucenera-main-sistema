-- Rollback da 252 (SPEC-235): volta o nome, reativa o grupo e tira o ajuste do Matheus.
BEGIN;
DROP FUNCTION IF EXISTS public.ajustar_reserva_venda(uuid, text, numeric, text);
DROP FUNCTION IF EXISTS public.pode_ajustar_reserva_venda();
DELETE FROM public.usuario_permissao_excecoes e
 USING public.modulos m
 WHERE e.modulo_id = m.id AND m.chave = 'ajuste_reserva_venda';
DELETE FROM public.modulos WHERE chave = 'ajuste_reserva_venda';
UPDATE public.categorias_produto SET ativo = true WHERE nome = 'GRUPO CONVERSAO';
UPDATE public.systems SET name = 'Separação Parcial' WHERE slug = 'separacao-parcial';
COMMIT;
