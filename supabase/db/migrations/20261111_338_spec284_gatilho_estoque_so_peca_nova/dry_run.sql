-- SPEC-284 Parte B dry-run (tudo desfeito no fim):
-- 1) troca o gatilho; 2) muda produtos.estoque_total de uma peça e confere que estoque_itens NÃO mudou;
-- 3) cria uma peça de teste e confere que ganhou a linha 'Estoque'.
BEGIN;
-- (colar o corpo do up.sql, sem BEGIN/COMMIT)
-- UPDATE public.produtos SET estoque_total = estoque_total + 1000 WHERE codigo_produto = 13587;
-- SELECT quantidade FROM public.estoque_itens ei JOIN public.produtos p ON p.id = ei.produto_id
--  WHERE p.codigo_produto = 13587 AND ei.local = 'Estoque';   -- esperado: igual ao de antes (289 em 11/11)
ROLLBACK;
