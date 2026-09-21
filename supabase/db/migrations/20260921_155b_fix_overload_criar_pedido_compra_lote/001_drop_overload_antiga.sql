-- SPEC-155 (fix urgente, achado logo após aplicar a migration anterior):
-- `20260921_155_modal_compra_desconto_local_entrega/001_...sql` recriou
-- `criar_pedido_compra_lote` com 2 parâmetros novos no final da assinatura.
-- `CREATE OR REPLACE FUNCTION` só substitui uma função existente quando a
-- lista de TIPOS de parâmetro é idêntica -- mudar a assinatura (mesmo só
-- acrescentando parâmetros com DEFAULT) faz o Postgres criar uma SEGUNDA
-- função sobrecarregada (overload) em vez de substituir a original.
--
-- Confirmado em produção logo após aplicar a migration anterior: passaram a
-- existir 2 versões (8 e 10 argumentos). Uma chamada nomeada com só os 8
-- parâmetros originais (exatamente como ModalPedidoLote.tsx, Fluxo A, já
-- em produção, sempre chamou) virou ambígua:
--
--   ERROR 42725: function criar_pedido_compra_lote(...) is not unique
--
-- Reproduzido com uma chamada de teste antes de escrever este fix.
--
-- Correção: remove a assinatura antiga (8 args) explicitamente -- só a nova
-- (10 args, com os 2 parâmetros novos DEFAULT NULL) continua existindo,
-- exatamente como pretendido desde o início.

BEGIN;

DROP FUNCTION IF EXISTS public.criar_pedido_compra_lote(
  uuid, jsonb, text, date, text, text, uuid, text
);

NOTIFY pgrst, 'reload schema';

COMMIT;
