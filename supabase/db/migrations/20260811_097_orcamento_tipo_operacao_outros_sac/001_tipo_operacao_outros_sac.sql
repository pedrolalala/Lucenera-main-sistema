-- Tela de Orcamento: 2 novos tipos de operacao ("Outros" e "SAC") + campo
-- "Tipo" (subgrupo). Pedido do usuario 2026-08-11.
--
-- Achado antes de aplicar: natureza_operacao ja existia (SPEC-071), mas o
-- CHECK so permitia 'venda'/'devolucao'; nao havia coluna nenhuma pra
-- guardar o subgrupo escolhido. Reportado ao usuario; autorizou ampliar o
-- CHECK e criar a coluna nova (ambas aditivas, nao quebram nada existente).
--
-- aprovar_orcamento_financeiro() so tem ramo explicito pra
-- natureza_operacao = 'devolucao' (o resto cai no ramo "venda" por
-- default) -- 'outros'/'sac' vao se comportar como venda na aprovacao
-- financeira ate que uma regra de negocio especifica seja definida.
-- Fora de escopo desta alteracao (so interface), sinalizado na SPEC.

ALTER TABLE public.orcamentos
  DROP CONSTRAINT orcamentos_natureza_operacao_check;

ALTER TABLE public.orcamentos
  ADD CONSTRAINT orcamentos_natureza_operacao_check
  CHECK (natureza_operacao = ANY (ARRAY['venda'::text, 'devolucao'::text, 'outros'::text, 'sac'::text]));

ALTER TABLE public.orcamentos
  ADD COLUMN IF NOT EXISTS subgrupo text;

COMMENT ON COLUMN public.orcamentos.subgrupo IS
  'Subgrupo do orcamento (campo "Tipo" na tela), dependente de natureza_operacao. Lista fixa no frontend, nao normalizada em tabela.';
