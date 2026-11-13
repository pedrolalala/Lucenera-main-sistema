BEGIN;
UPDATE public.financeiro_titulos t SET perfil = b.perfil_antes
  FROM backup._bkp_spec305_perfil_titulos b WHERE b.id = t.id;
COMMIT;
-- depois de conferir, apagar o backup: DROP TABLE backup._bkp_spec305_perfil_titulos;
