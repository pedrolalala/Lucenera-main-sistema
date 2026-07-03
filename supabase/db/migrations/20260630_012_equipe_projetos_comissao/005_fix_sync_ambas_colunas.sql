-- Migration 20260630_012 — Parte 5
-- Corrige fn_sync_equipe_por_responsavel para preencher AMBAS as colunas:
--   equipe_id                  (adicionada na parte 1)
--   equipe_responsavel_obra_id (coluna original já existente)
--
-- O trigger trg_sync_equipe_por_responsavel já existe — basta recriar
-- a função que ele chama.

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
  WHERE lower(trim(equipes)) = lower(trim(NEW.responsavel_nome))
  LIMIT 1;

  NEW.equipe_id                  := v_equipe_id;
  NEW.equipe_responsavel_obra_id := v_equipe_id;

  RETURN NEW;
END;
$$;

-- Sincronizar os projetos que já existem no banco (dados históricos).
-- O trigger cobre apenas inserções e edições futuras; este UPDATE cobre o passado.
UPDATE public.projetos p
SET
  equipe_id                  = ep.id,
  equipe_responsavel_obra_id = ep.id
FROM public.equipes_projetos ep
WHERE lower(trim(ep.equipes)) = lower(trim(p.responsavel_nome))
  AND (
    p.equipe_id IS NULL
    OR p.equipe_responsavel_obra_id IS NULL
  );
