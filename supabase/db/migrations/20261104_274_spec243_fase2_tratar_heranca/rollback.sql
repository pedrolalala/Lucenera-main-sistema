-- Rollback da 274: remove a função de tratamento e volta a restrição de ação ao rascunho da 264.
-- ATENÇÃO: tratamentos já feitos mexeram em saldos e estoque; este rollback NÃO os desfaz (isso exigiria devolver saldo e estoque linha a linha).
-- Se já houver tratamento gravado, o ALTER abaixo falha de propósito (as ações novas não existem na restrição antiga).
BEGIN;
DROP FUNCTION IF EXISTS public.tratar_heranca_connect(uuid, text, text, numeric, text);
ALTER TABLE public.connect_reserva_tratamento DROP COLUMN IF EXISTS setor, DROP COLUMN IF EXISTS projeto_item_id;
ALTER TABLE public.connect_reserva_tratamento DROP CONSTRAINT IF EXISTS connect_reserva_tratamento_acao_check;
ALTER TABLE public.connect_reserva_tratamento
  ADD CONSTRAINT connect_reserva_tratamento_acao_check CHECK (acao IN
    ('mantida_confirmada', 'entregue_sem_estoque', 'entregue_voltou_ao_estoque', 'cancelada_volta_ao_estoque', 'observacao'));
COMMIT;
