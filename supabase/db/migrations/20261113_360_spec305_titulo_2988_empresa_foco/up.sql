-- SPEC-305 (13/11/2026): titulo legado da duplicata 2988 (CAIO MEDICI, acordo 578, 1 parcela de R$ 0,00, venc. 01/04/2026)
-- esta como ISLIGHT no banco e como FOCO ILUMINACAO na planilha da Connect (conferencia de 13/11). Valor zero: nenhum total muda, so a contagem por empresa.
BEGIN;
UPDATE public.financeiro_titulos t
   SET empresa_id = (SELECT id FROM public.empresas WHERE nome = 'FOCO ILUMINACAO')
 WHERE t.legado_cod_duplicata = 2988 AND t.natureza = 'receber'
   AND t.empresa_id = (SELECT id FROM public.empresas WHERE nome = 'ISLIGHT');
DO $$ BEGIN
  IF (SELECT count(*) FROM public.financeiro_titulos t JOIN public.empresas e ON e.id = t.empresa_id
       WHERE t.legado_cod_duplicata = 2988 AND t.natureza = 'receber' AND e.nome = 'FOCO ILUMINACAO') <> 1 THEN
    RAISE EXCEPTION 'SPEC-305: titulo 2988 nao ficou em FOCO ILUMINACAO';
  END IF;
END $$;
COMMIT;
