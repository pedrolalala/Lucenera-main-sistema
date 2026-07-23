-- Migration 20260723_062 - vendas: colunas para historico legado (planilha "venda", 22.171 linhas)
-- Parte 1/2: adiciona colunas de item + CFOP + flag de origem, sem tocar nas 263 linhas existentes.

ALTER TABLE public.vendas
  ADD COLUMN IF NOT EXISTS grupo_cfop text,
  ADD COLUMN IF NOT EXISTS produto_id uuid REFERENCES public.produtos(id),
  ADD COLUMN IF NOT EXISTS descricao_produto text,
  ADD COLUMN IF NOT EXISTS vl_unitario numeric(15,2),
  ADD COLUMN IF NOT EXISTS qtd_produto numeric(10,2),
  ADD COLUMN IF NOT EXISTS historico_legado boolean NOT NULL DEFAULT false;

COMMENT ON COLUMN public.vendas.historico_legado IS 'true = linha importada do historico do Connect (planilha venda, item por item). Excluida das somas de vendas.valor_total nas views financeiras para nao duplicar com orcamentos/projeto_parcelas quando o mesmo CodVenda vira orcamento aprovado.';
COMMENT ON COLUMN public.vendas.grupo_cfop IS 'Classificacao fiscal da venda no sistema legado (VENDAS, TROCA DEV, GARANTIA, etc). Sempre unica por cod_venda.';

-- vendas_cod_venda_key assumia 1 linha por cod_venda (desenho de cabecalho). O historico legado
-- precisa de 1 linha por item (media ~5,8 itens por cod_venda), entao a unicidade precisa cair.
ALTER TABLE public.vendas DROP CONSTRAINT IF EXISTS vendas_cod_venda_key;
