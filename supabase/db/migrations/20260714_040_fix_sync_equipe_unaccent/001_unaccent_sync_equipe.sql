-- Migration 20260714_040 — Parte 1
-- Torna fn_sync_equipe_por_responsavel() tolerante a acento, alem do
-- lower(trim()) ja existente (migration 20260630_012/005).
--
-- Contexto (SPEC-024): diagnostico em producao mostrou que os 1.659 projetos
-- sem equipe_id NAO sao causados por diferenca de acento/caixa entre
-- responsavel_nome e equipes_projetos.equipes — sao responsaveis reais
-- (Mariane, Ricardo, Amanda, Angelica, etc.) que simplesmente nao tem
-- equipe cadastrada ainda. Essa migration nao resolve esses 1.659 casos;
-- e uma protecao defensiva para o futuro (ex.: "Tháis" vs "Thais").

CREATE OR REPLACE FUNCTION public.fn_sync_equipe_por_responsavel()
RETURNS trigger
LANGUAGE plpgsql
SET search_path TO 'public'
AS $$
DECLARE
  v_equipe_id uuid;
BEGIN
  IF NEW.responsavel_nome IS NULL THEN
    NEW.equipe_id                  := NULL;
    NEW.equipe_responsavel_obra_id := NULL;
    RETURN NEW;
  END IF;

  SELECT id
    INTO v_equipe_id
  FROM public.equipes_projetos
  WHERE unaccent(lower(trim(equipes))) = unaccent(lower(trim(NEW.responsavel_nome)))
  LIMIT 1;

  NEW.equipe_id                  := v_equipe_id;
  NEW.equipe_responsavel_obra_id := v_equipe_id;

  RETURN NEW;
END;
$$;

-- Reaplica o backfill com a comparacao tolerante a acento, para capturar
-- qualquer caso historico desse tipo especifico (nao resolve os 1.659
-- projetos sem equipe correspondente cadastrada).
UPDATE public.projetos p
SET
  equipe_id                  = ep.id,
  equipe_responsavel_obra_id = ep.id
FROM public.equipes_projetos ep
WHERE unaccent(lower(trim(ep.equipes))) = unaccent(lower(trim(p.responsavel_nome)))
  AND (
    p.equipe_id IS NULL
    OR p.equipe_responsavel_obra_id IS NULL
  );
