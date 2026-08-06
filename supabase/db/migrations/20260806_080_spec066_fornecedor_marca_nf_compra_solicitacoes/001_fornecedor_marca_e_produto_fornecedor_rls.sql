-- SPEC-066 Frente B: inverte a direção da relação fornecedor<->marca.
--
-- ACHADO CRÍTICO (verificado direto no Supabase real antes de escrever
-- esta migration): "fornecedor" neste sistema NÃO é a tabela
-- public.fornecedores (que existe mas está com 0 linhas, não usada em
-- nenhum lugar real). O fornecedor de verdade é
-- public.contatos WHERE tipo = 'fornecedor' (357 linhas) — é essa tabela
-- que marcas.fornecedor_id, pedidos_compra.fornecedor_id,
-- produto_fornecedores.fornecedor_id e cotacoes_compra.fornecedor_id
-- referenciam de fato (confirmado via pg_constraint). Por isso a coluna
-- nova vai em contatos, não em fornecedores.
--
-- Hoje marcas.fornecedor_id (marca -> 1 contato-fornecedor). O caso real
-- (reunião Débora 06/08/2026): uma marca pode vir de vários
-- fornecedores/CNPJs diferentes (ex. "Metal Spot" via "Metal
-- Estrangemar", "Metal Benaluti" etc.), mas cada fornecedor representa
-- exatamente uma marca. marcas.fornecedor_id é MANTIDA por ora (P-B1)
-- até confirmar todos os usos no frontend antes de removê-la.

ALTER TABLE public.contatos
  ADD COLUMN IF NOT EXISTS marca_id uuid REFERENCES public.marcas(id);

COMMENT ON COLUMN public.contatos.marca_id IS
  'SPEC-066: só relevante para contatos.tipo = ''fornecedor''. Marca que este fornecedor representa (1 fornecedor = 1 marca; 1 marca pode ter vários fornecedores/CNPJs). Opcional (P-B2).';

CREATE INDEX IF NOT EXISTS idx_contatos_marca_id ON public.contatos USING btree (marca_id) WHERE marca_id IS NOT NULL;

-- Migra os vínculos existentes de marcas.fornecedor_id (66 marcas hoje)
-- para a direção nova, invertendo: para cada marca com fornecedor_id
-- preenchido, o contato-fornecedor correspondente passa a apontar pra
-- essa marca. Não sobrescreve contatos.marca_id já preenchido (não
-- deveria haver nenhum ainda, mas por segurança).
UPDATE public.contatos c
SET marca_id = m.id
FROM public.marcas m
WHERE m.fornecedor_id = c.id
  AND c.tipo = 'fornecedor'
  AND c.marca_id IS NULL;

-- SPEC-066 Frente C: produto_fornecedores hoje só tem policy de SELECT.
-- A observação de "caixa fechada" (coluna observacao, já existente e
-- vazia) e qtd_minima precisam ser editáveis pela tela de cadastro
-- produto×fornecedor — sem RPC dedicada, mesmo padrão de escrita direta
-- já usado em contatos/marcas.
CREATE POLICY produto_fornecedores_insert_policy ON public.produto_fornecedores
  FOR INSERT TO authenticated WITH CHECK (true);

CREATE POLICY produto_fornecedores_update_policy ON public.produto_fornecedores
  FOR UPDATE TO authenticated USING (true);

CREATE POLICY produto_fornecedores_delete_policy ON public.produto_fornecedores
  FOR DELETE TO authenticated USING (true);
