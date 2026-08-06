-- Pedido do usuario (06/08/2026): a tela "Consultar Duplicatas" ja tem
-- tipo_operacao (CR/CP) funcional e boletos.perfil (ribeirao/sao_paulo,
-- SPEC-064) ja existe no schema. Mas o formulario de Notas Fiscais nao
-- tem NENHUM dos dois campos, e o formulario de "Novo Boleto"/"Editar
-- Boleto" (Boletos.tsx) tambem nao expoe tipo_operacao nem perfil --
-- ou seja, hoje e literalmente impossivel criar um boleto de Contas a
-- Pagar pela UI, porque o campo nao existe na criacao.
--
-- notas_fiscais nao tinha nenhuma coluna de direcao (CR/CP) nem perfil
-- ate agora -- adiciona os dois, mesma convencao ja usada em
-- boletos/pedidos_compra/solicitacoes_aprovacao_compra etc.

ALTER TABLE public.notas_fiscais
  ADD COLUMN IF NOT EXISTS tipo_operacao text,
  ADD COLUMN IF NOT EXISTS perfil text;

ALTER TABLE public.notas_fiscais
  ADD CONSTRAINT notas_fiscais_tipo_operacao_check
    CHECK (tipo_operacao IS NULL OR tipo_operacao IN ('CR', 'CP')),
  ADD CONSTRAINT notas_fiscais_perfil_check
    CHECK (perfil IS NULL OR perfil = ANY (ARRAY['ribeirao', 'sao_paulo']));

COMMENT ON COLUMN public.notas_fiscais.tipo_operacao IS
  'CR = Contas a Receber (nota fiscal de venda ao cliente), CP = Contas a Pagar (nota fiscal de fornecedor). Mesma convencao de boletos.tipo_operacao.';
COMMENT ON COLUMN public.notas_fiscais.perfil IS
  'Ribeirao/Sao Paulo, rotulo informativo (SPEC-064) -- mesma convencao de boletos.perfil.';
