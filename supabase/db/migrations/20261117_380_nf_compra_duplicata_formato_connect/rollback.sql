-- Rollback 380: NFs voltam para a faixa 900000+ (sequencia nativa) e o gatilho volta a usar seq_cod_duplicata_nativa.
BEGIN;
CREATE OR REPLACE FUNCTION public.fn_titulo_nf_numero_duplicata()
RETURNS trigger LANGUAGE plpgsql SET search_path TO 'public' AS $fn$
BEGIN
  IF NEW.origem_tipo = 'nota_fiscal_compra' AND NEW.numero_duplicata IS NULL THEN
    NEW.numero_duplicata := nextval('public.seq_cod_duplicata_nativa');
  END IF;
  RETURN NEW;
END $fn$;
REVOKE ALL ON FUNCTION public.fn_titulo_nf_numero_duplicata() FROM PUBLIC, anon;
CREATE TEMP TABLE _velho_num ON COMMIT DROP AS
SELECT id, nextval('public.seq_cod_duplicata_nativa')::integer AS velho
  FROM public.financeiro_titulos WHERE origem_tipo = 'nota_fiscal_compra' AND numero_duplicata < 900000 ORDER BY criado_em, id;
UPDATE public.financeiro_titulos t SET numero_duplicata = n.velho FROM _velho_num n WHERE t.id = n.id;
UPDATE public.boletos bo SET numero_documento = t.numero_duplicata::text
  FROM public.financeiro_titulos t
 WHERE t.origem_tipo = 'nota_fiscal_compra' AND bo.conta_grupo_id = t.nota_fiscal_compra_id AND bo.tipo_operacao = 'CP' AND bo.nosso_numero LIKE 'NFC-%';
DROP SEQUENCE IF EXISTS public.seq_duplicata_nf_compra;
COMMIT;
