-- SPEC-058 — Pedido 2 (Opção A): Lançamento de folga compensatória
--
-- Adiciona o valor 'folga' à lista de status permitidos em
-- public.controle_falta, para permitir registrar dias de folga compensatória
-- (ex.: atuação como mesário nas eleições). O motivo/justificativa é
-- registrado no campo `justificativa` (texto livre, já existente) — não é
-- criado nenhum catálogo estruturado de motivos.
--
-- 'folga' não deve, por padrão, reduzir dias trabalhados nem desconto de
-- VR/VT em Folha.tsx (a tela só trata explicitamente 4 status específicos;
-- um status novo não tratado não afeta pagamento por padrão).

ALTER TABLE public.controle_falta DROP CONSTRAINT controle_ponto_status_check;

ALTER TABLE public.controle_falta
  ADD CONSTRAINT controle_ponto_status_check CHECK (
    status = ANY (
      ARRAY[
        'presente'::text,
        'ausente'::text,
        'atraso'::text,
        'meio_periodo'::text,
        'atestado'::text,
        'licenca_maternidade'::text,
        'falta_injustificada'::text,
        'licenca_paternidade'::text,
        'licenca_obito'::text,
        'licenca_casamento'::text,
        'licenca_militar'::text,
        'licenca_medica'::text,
        'folga'::text
      ]
    )
  );
