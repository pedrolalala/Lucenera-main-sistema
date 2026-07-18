-- Migration 20260715_042 — Parte 1
-- SPEC-026: prazo de entrega comprometido no orçamento, calculado em dias úteis.
--
-- Correção de grounding: a coluna `prazo_entrega` que já existia no banco
-- pertence a `orcamentos_revenda_ubiqua` (fluxo não relacionado, catálogo
-- Ubiqua) — NÃO à tabela `orcamentos` real usada pelo fluxo de aprovação
-- (gestao-financeira-clone-544cb). Esta migration cria o campo certo.
--
-- Cálculo é em dias úteis (segunda a sexta) apenas — não existe tabela de
-- feriados compartilhada no banco central hoje, então feriados não são
-- excluídos. Ver Pendências da SPEC-026.

ALTER TABLE public.orcamentos
  ADD COLUMN IF NOT EXISTS prazo_entrega_dias integer DEFAULT 27;

COMMENT ON COLUMN public.orcamentos.prazo_entrega_dias IS
  'Prazo de entrega comprometido com o cliente, em dias úteis (default 27, '
  'média entre 25-30 dias úteis citada na reunião de 13/07/2026 — ajustável '
  'por orçamento). Usado para calcular data_prazo_entrega. SPEC-026.';

CREATE OR REPLACE FUNCTION public.fn_add_dias_uteis(data_base date, dias integer)
RETURNS date
LANGUAGE plpgsql
IMMUTABLE
AS $$
DECLARE
  d date := data_base;
  restantes integer := dias;
BEGIN
  IF dias IS NULL OR data_base IS NULL THEN
    RETURN NULL;
  END IF;

  WHILE restantes > 0 LOOP
    d := d + 1;
    IF EXTRACT(ISODOW FROM d) < 6 THEN
      restantes := restantes - 1;
    END IF;
  END LOOP;

  RETURN d;
END;
$$;

COMMENT ON FUNCTION public.fn_add_dias_uteis IS
  'Soma dias úteis (seg-sex) a uma data. Não considera feriados — não há '
  'tabela de feriados compartilhada no banco central. SPEC-026.';

CREATE OR REPLACE VIEW public.vw_orcamentos_prazo_entrega AS
SELECT
  o.id AS orcamento_id,
  o.numero,
  o.projeto_id,
  o.status,
  o.prazo_entrega_dias,
  COALESCE(o.aprovado_cliente_em::date, o.data_emissao::date) AS data_base_prazo,
  public.fn_add_dias_uteis(
    COALESCE(o.aprovado_cliente_em::date, o.data_emissao::date),
    o.prazo_entrega_dias
  ) AS data_prazo_entrega
FROM public.orcamentos o;

COMMENT ON VIEW public.vw_orcamentos_prazo_entrega IS
  'Data de entrega comprometida por orçamento, calculada a partir da data de '
  'aprovação do cliente (ou emissão, se ainda não aprovado) + prazo_entrega_dias '
  'em dias úteis. SPEC-026.';

GRANT SELECT ON public.vw_orcamentos_prazo_entrega TO authenticated;
