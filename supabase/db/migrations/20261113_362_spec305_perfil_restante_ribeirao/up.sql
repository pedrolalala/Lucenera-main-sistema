-- SPEC-305 (13/11/2026, decisao do usuario): "o que tiver sem perfil joga para Ribeirao".
-- Restam sem perfil 39 titulos nativos (pedido/NF/adiantamento/devolucao/orcamento) e 44 boletos. Backup dos ids no schema backup.
BEGIN;

CREATE TABLE backup._bkp_spec305_perfil_restante AS
SELECT 'titulo'::text AS tabela, id::text AS id, now() AS salvo_em FROM public.financeiro_titulos WHERE perfil IS NULL
UNION ALL
SELECT 'boleto', id::text, now() FROM public.boletos WHERE perfil IS NULL;
REVOKE ALL ON backup._bkp_spec305_perfil_restante FROM PUBLIC, anon, authenticated;

UPDATE public.financeiro_titulos SET perfil = 'ribeirao' WHERE perfil IS NULL;
UPDATE public.boletos SET perfil = 'ribeirao' WHERE perfil IS NULL;

DO $$ BEGIN
  IF (SELECT count(*) FROM public.financeiro_titulos WHERE perfil IS NULL) <> 0
     OR (SELECT count(*) FROM public.boletos WHERE perfil IS NULL) <> 0 THEN
    RAISE EXCEPTION 'SPEC-305: ficou registro sem perfil';
  END IF;
  IF (SELECT count(*) FROM public.financeiro_titulos WHERE perfil = 'sao_paulo') <> 6 THEN
    RAISE EXCEPTION 'SPEC-305: titulos sao_paulo mudaram';
  END IF;
END $$;
COMMIT;
