BEGIN;
UPDATE public.financeiro_titulos SET empresa_id = (SELECT id FROM public.empresas WHERE nome = 'ISLIGHT')
 WHERE legado_cod_duplicata = 2988 AND natureza = 'receber';
COMMIT;
