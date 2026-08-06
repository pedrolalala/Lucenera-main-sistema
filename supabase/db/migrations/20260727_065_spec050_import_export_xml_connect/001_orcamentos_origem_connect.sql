-- SPEC-050 — Importação/Exportação de XML (padrão Connect) no Orçamento
--
-- Adiciona rastreabilidade de origem quando um orçamento é criado a partir da
-- importação de um XML exportado pelo ERP concorrente "Connect"
-- (<connect_systems><orcamento><cod_orcamento>...).
--
-- `origem_connect_cod_orcamento` guarda o `cod_orcamento` original do Connect
-- e serve de chave de idempotência: um mesmo XML não pode ser importado duas
-- vezes gerando dois orçamentos Lucenera distintos.
--
-- Não cria tabela nova, não cria trigger, não mexe em RLS — apenas colunas
-- novas em `orcamentos`, que herdam as policies já existentes da tabela.

ALTER TABLE public.orcamentos
  ADD COLUMN origem_connect_cod_orcamento integer,
  ADD COLUMN origem_connect_importado_em timestamptz;

CREATE UNIQUE INDEX orcamentos_origem_connect_cod_orcamento_uidx
  ON public.orcamentos (origem_connect_cod_orcamento)
  WHERE origem_connect_cod_orcamento IS NOT NULL;

COMMENT ON COLUMN public.orcamentos.origem_connect_cod_orcamento IS
  'SPEC-050: cod_orcamento original do XML Connect importado (idempotência do import). NULL para orçamentos criados nativamente no Lucenera.';

COMMENT ON COLUMN public.orcamentos.origem_connect_importado_em IS
  'SPEC-050: quando este orçamento foi criado a partir de um import de XML Connect. NULL para orçamentos criados nativamente no Lucenera.';
