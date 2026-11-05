-- SPEC-243 (RASCUNHO, NÃO APLICADA) — preenche funcionarios.nm_connect para os digitadores da planilha que ainda não tinham.
-- A coluna Funcionario das planilhas ReservaxAmbiente/EntregaFuturaxAmbiente = digitador do orçamento = funcionário (orcamentos.vendedor_id).
-- Hoje só 16 de 39 funcionários têm nm_connect. Estes 6 casam por nome com um único funcionário (conferido em 04/11).
-- Só preenche quando está NULL (nunca sobrescreve). KATIA e RICARDO não têm cadastro em funcionarios: ver SPEC-243 seção 4.5.
BEGIN;

UPDATE public.funcionarios SET nm_connect = 'FILIPPO'
 WHERE nm_connect IS NULL AND nome ILIKE 'Filippo Giorgi%';
UPDATE public.funcionarios SET nm_connect = 'HELENA FOGAÇA'
 WHERE nm_connect IS NULL AND nome ILIKE 'Helena Nascimento Foga%';
UPDATE public.funcionarios SET nm_connect = 'MATHEUS'
 WHERE nm_connect IS NULL AND nome ILIKE 'Matheus Fernando Luzente%';
UPDATE public.funcionarios SET nm_connect = 'RAFAELA NETTO'
 WHERE nm_connect IS NULL AND nome ILIKE 'Rafaela Netto%';
UPDATE public.funcionarios SET nm_connect = 'VITORIA LIDIA'
 WHERE nm_connect IS NULL AND nome ILIKE 'Vitoria Lidia da Silva%';
UPDATE public.funcionarios SET nm_connect = 'TEREZINHA'      -- ex-funcionária (status Inativo, sem usuário)
 WHERE nm_connect IS NULL AND nome ILIKE 'Teresinha do Amaral Figueiredo%';

COMMIT;
