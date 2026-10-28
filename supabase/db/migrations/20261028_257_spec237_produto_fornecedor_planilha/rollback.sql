-- Rollback da 257 (SPEC-237): tira o gatilho, os vínculos desta carga e o principal que ela preencheu.
BEGIN;
DROP TRIGGER IF EXISTS trg_produto_fornecedor_principal_vinculo ON public.produtos;
DROP FUNCTION IF EXISTS public.trg_produto_fornecedor_principal_vinculo();

UPDATE public.produtos p
   SET fornecedor_principal_id = NULL
  FROM public.produto_fornecedores pf
 WHERE pf.produto_id = p.id AND pf.observacao = 'SPEC-237: planilha Produtos da Connect (14/10/2026), nmFornecedor'
   AND p.fornecedor_principal_id = pf.fornecedor_id;

DELETE FROM public.produto_fornecedores WHERE observacao = 'SPEC-237: planilha Produtos da Connect (14/10/2026), nmFornecedor';
COMMIT;
