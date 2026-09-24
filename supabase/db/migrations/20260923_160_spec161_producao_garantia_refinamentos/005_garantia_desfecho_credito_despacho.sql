-- SPEC-161 Prioridade 10 — Controle de Garantia: desfecho "Crédito gerado
-- em despacho" + data do desfecho.
--
-- Os 6 status do protocolo (garantia_protocolo_status) NÃO mudam
-- (confirmado pelo usuário: "aqui não precisa mudar nada, aqui é isso aqui
-- mesmo"). Só o desfecho (preenchido junto com o status 'finalizado')
-- ganha uma opção nova.
--
-- desfecho_em: data do que aconteceu (não necessariamente "agora"), mesmo
-- padrão de producao_pedidos.data_ficou_pronto (data digitada pelo
-- usuário, não now()) — permite calcular a duração do protocolo
-- (desfecho_em - created_at) para relatório futuro.

BEGIN;

ALTER TABLE public.garantia_protocolos
  DROP CONSTRAINT garantia_protocolos_desfecho_check;

ALTER TABLE public.garantia_protocolos
  ADD CONSTRAINT garantia_protocolos_desfecho_check
  CHECK (desfecho IN ('peca_nova', 'conserto', 'nao_acatado', 'credito_gerado_despacho'));

ALTER TABLE public.garantia_protocolos
  ADD COLUMN IF NOT EXISTS desfecho_em date;

COMMENT ON COLUMN public.garantia_protocolos.desfecho_em IS
  'SPEC-161 Prioridade 10: data em que o desfecho de fato aconteceu (preenchida pelo usuário ao finalizar o protocolo, não necessariamente a data de hoje). Junto com created_at, permite medir a duração total do protocolo.';

COMMIT;
