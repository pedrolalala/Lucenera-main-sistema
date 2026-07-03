-- Migration 20260630_012 — Parte 4
-- Trigger que vincula equipe_id automaticamente ao gravar responsavel_nome.
--
-- Toda vez que um projeto for inserido ou tiver responsavel_nome atualizado,
-- o trigger busca em equipes_projetos o registro cujo nome bata e preenche
-- equipe_id automaticamente — sem intervenção manual.
--
-- Se o nome não bater com nenhuma equipe, equipe_id fica NULL sem erro.

CREATE OR REPLACE FUNCTION public.fn_sync_equipe_por_responsavel()
RETURNS trigger
LANGUAGE plpgsql
SET search_path TO 'public'
AS $$
BEGIN
  IF NEW.responsavel_nome IS NULL THEN
    NEW.equipe_id := NULL;
    RETURN NEW;
  END IF;

  SELECT id
    INTO NEW.equipe_id
  FROM public.equipes_projetos
  WHERE lower(trim(equipes)) = lower(trim(NEW.responsavel_nome))
  LIMIT 1;

  RETURN NEW;
END;
$$;

-- Dispara BEFORE INSERT e BEFORE UPDATE quando responsavel_nome muda.
-- BEFORE garante que equipe_id já está correto antes de gravar no banco.
CREATE OR REPLACE TRIGGER trg_sync_equipe_por_responsavel
  BEFORE INSERT OR UPDATE OF responsavel_nome
  ON public.projetos
  FOR EACH ROW
  EXECUTE FUNCTION public.fn_sync_equipe_por_responsavel();
