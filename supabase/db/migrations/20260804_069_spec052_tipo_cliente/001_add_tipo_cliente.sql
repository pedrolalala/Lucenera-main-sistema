-- SPEC-052 (achado adicional, 2026-08-04): print de referência enviado pelo
-- usuário do sistema legado do Vinicius (Cadastro de Clientes) mostra um
-- campo "Tipo Cliente" com 4 opções fixas, distinto de "Regime Apuração"
-- (que já existe em `contatos.regime_apuracao` como texto livre).
--
-- Segue o mesmo padrão já usado em `contatos.tipo_pessoa`: varchar + CHECK
-- com os valores fixos, em vez de um tipo ENUM novo. Nullable e sem
-- DEFAULT — os ~360+ contatos existentes não têm esse dado hoje.

ALTER TABLE public.contatos
  ADD COLUMN tipo_cliente varchar;

ALTER TABLE public.contatos
  ADD CONSTRAINT contatos_tipo_cliente_check
  CHECK (
    tipo_cliente IS NULL
    OR tipo_cliente = ANY (ARRAY['consumidor', 'nao_contribuinte', 'industria', 'revendedor']::text[])
  );

COMMENT ON COLUMN public.contatos.tipo_cliente IS
  'Classificação comercial/fiscal do cliente (SPEC-052): consumidor, nao_contribuinte, industria ou revendedor. Distinto de regime_apuracao (regime tributário). Opções confirmadas por print do sistema de referência do usuário em 2026-08-04.';
