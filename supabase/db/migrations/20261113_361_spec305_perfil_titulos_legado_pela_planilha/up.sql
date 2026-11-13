-- SPEC-305 (13/11/2026): perfil dos titulos do legado da Connect.
-- As planilhas ContaReceber/ContaPagar de 05/11 trazem desc_perfil_empresa = 'RIBEIRAO PRETO' em todas as linhas (3 empresas), mas
-- 10.396 titulos legado_connect estavam com perfil NULL; o filtro Perfil das telas Contas a Receber/Pagar nao achava nada neles.
-- So preenche perfil NULL (nao toca nos 6 titulos 'sao_paulo' nem no 1 'ribeirao' ja gravados). Backup dos ids no schema backup.
BEGIN;

CREATE TABLE backup._bkp_spec305_perfil_titulos AS
SELECT id, perfil AS perfil_antes, now() AS salvo_em
  FROM public.financeiro_titulos
 WHERE origem_tipo = 'legado_connect' AND perfil IS NULL;
REVOKE ALL ON backup._bkp_spec305_perfil_titulos FROM PUBLIC, anon, authenticated;

UPDATE public.financeiro_titulos t
   SET perfil = 'ribeirao'
  FROM backup._bkp_spec305_perfil_titulos b
 WHERE b.id = t.id AND t.perfil IS NULL;

DO $$ BEGIN
  IF (SELECT count(*) FROM public.financeiro_titulos WHERE origem_tipo = 'legado_connect' AND perfil IS NULL) <> 0 THEN
    RAISE EXCEPTION 'SPEC-305: ficou titulo legado sem perfil';
  END IF;
  IF (SELECT count(*) FROM public.financeiro_titulos WHERE perfil = 'sao_paulo') <> 6 THEN
    RAISE EXCEPTION 'SPEC-305: titulos sao_paulo mudaram';
  END IF;
END $$;
COMMIT;
