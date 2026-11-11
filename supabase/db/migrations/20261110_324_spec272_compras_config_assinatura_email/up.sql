-- SPEC-272: assinatura do e-mail ao fornecedor (pedido da Debora na Central, 09/11). Texto livre, opcional;
-- vazio = o e-mail termina com o remetente e "LUCENERA". Quem altera segue sendo o admin (politica compras_config_update).
BEGIN;

ALTER TABLE public.compras_config ADD COLUMN IF NOT EXISTS assinatura_email text;

COMMIT;
