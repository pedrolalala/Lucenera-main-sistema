-- SPEC-285 dry-run (tudo desfeito): aplica a trava e testa como usuário logado.
-- 1) inserir parcela sem orçamento -> recusado; 2) alterar uma das 387 antigas -> recusado;
-- 3) alterar parcela com orçamento -> permitido; 4) como service_role -> permitido.
BEGIN;
-- (colar o corpo do up.sql, sem BEGIN/COMMIT)
-- SET LOCAL request.jwt.claims = '{"role":"authenticated"}';  -- simula usuário logado para auth.role()
-- ...testes...
ROLLBACK;
