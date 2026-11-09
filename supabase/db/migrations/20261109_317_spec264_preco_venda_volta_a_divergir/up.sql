-- SPEC-264: o importador da Connect grava valor_venda com os triggers de preço desligados, então preco_venda
-- (lido pelo Orçamento) ficou diferente do valor_venda (lido pela Consulta). Reacerta as peças divergentes.
-- O importador também foi corrigido (grava preco_venda = valor_venda na mesma UPDATE).
BEGIN;

CREATE TABLE IF NOT EXISTS backup._bkp_spec264_produtos_preco_venda AS
  SELECT id, codigo_produto, preco_venda, valor_venda, now() AS copiado_em
    FROM public.produtos
   WHERE coalesce(valor_venda, 0) > 0 AND preco_venda IS DISTINCT FROM valor_venda;

UPDATE public.produtos
   SET preco_venda = valor_venda
 WHERE coalesce(valor_venda, 0) > 0
   AND preco_venda IS DISTINCT FROM valor_venda;

COMMIT;
