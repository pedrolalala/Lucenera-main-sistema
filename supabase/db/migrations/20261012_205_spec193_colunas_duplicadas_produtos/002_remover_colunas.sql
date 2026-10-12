-- SPEC-193 B3 etapa 2, parte 2: colunas duplicadas saem de `produtos`.
-- Cópia de segurança antes (para o rollback): _bkp_spec193_produtos_colunas (só admin/postgres).
-- `sku` NÃO some de vez: vira coluna GERADA = referencia (só leitura). Motivo: o PDF do orçamento
-- (Edge Function generate-report, com cópia em 9 sistemas) e a emissão de NF-e pedem `sku` à tabela;
-- assim continuam funcionando, e ninguém mais consegue gravar um valor diferente da referência.
-- fornecedor_principal_id fica (o campo "Fornecedor" do Cadastro ainda grava nele — ver B2).

CREATE TABLE public._bkp_spec193_produtos_colunas AS
  SELECT id, sku, codigo_legado, percentual_lucro, categoria FROM public.produtos;
ALTER TABLE public._bkp_spec193_produtos_colunas ADD PRIMARY KEY (id);
ALTER TABLE public._bkp_spec193_produtos_colunas ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public._bkp_spec193_produtos_colunas FROM anon, authenticated;
COMMENT ON TABLE public._bkp_spec193_produtos_colunas IS
  'SPEC-193 B3: cópia de produtos.sku/codigo_legado/percentual_lucro/categoria antes do DROP (rollback da migration 205).';

ALTER TABLE public.produtos
  DROP COLUMN codigo_legado,
  DROP COLUMN percentual_lucro,
  DROP COLUMN categoria,
  DROP COLUMN sku;

ALTER TABLE public.produtos
  ADD COLUMN sku text GENERATED ALWAYS AS (referencia) STORED;
COMMENT ON COLUMN public.produtos.sku IS
  'SPEC-193 B3: igual a referencia (coluna gerada, só leitura). Mantida só para leitores antigos (PDF do orçamento, NF-e). Usar referencia.';
GRANT SELECT (sku) ON public.produtos TO authenticated;

NOTIFY pgrst, 'reload schema';
