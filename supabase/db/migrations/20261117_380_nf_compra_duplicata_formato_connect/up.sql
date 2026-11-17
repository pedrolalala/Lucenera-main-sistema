-- Duplicata da NF de compra no formato da Connect (pedido da Carol, Central a0bc76a8): ordem de lancamento 8425, 8426...
-- Antes: sequencia nativa 900000+ (mesma das vendas). Agora sequencia propria, comecando acima do maior codigo da Connect (8424).
-- As vendas nativas (900000+) nao mudam.
BEGIN;

DO $$
DECLARE v_ini bigint;
BEGIN
  SELECT greatest(coalesce(max(legado_cod_duplicata), 0), 8424) + 1 INTO v_ini FROM public.financeiro_titulos WHERE legado_cod_duplicata < 900000;
  EXECUTE format('CREATE SEQUENCE IF NOT EXISTS public.seq_duplicata_nf_compra START WITH %s MINVALUE %s', v_ini, v_ini);
END $$;

CREATE OR REPLACE FUNCTION public.fn_titulo_nf_numero_duplicata()
RETURNS trigger LANGUAGE plpgsql SET search_path TO 'public' AS $fn$
DECLARE v integer;
BEGIN
  IF NEW.origem_tipo = 'nota_fiscal_compra' AND NEW.numero_duplicata IS NULL THEN
    LOOP
      v := nextval('public.seq_duplicata_nf_compra');
      EXIT WHEN NOT EXISTS (SELECT 1 FROM public.financeiro_titulos x WHERE x.legado_cod_duplicata = v OR x.numero_duplicata = v);
    END LOOP;
    NEW.numero_duplicata := v;
  END IF;
  RETURN NEW;
END $fn$;
REVOKE ALL ON FUNCTION public.fn_titulo_nf_numero_duplicata() FROM PUBLIC, anon;

-- Renumera as NFs ja lancadas (900026..900058), na ordem do lancamento, e acerta o boleto espelho.
CREATE TEMP TABLE _novo_num ON COMMIT DROP AS
SELECT id, nextval('public.seq_duplicata_nf_compra')::integer AS novo
  FROM public.financeiro_titulos WHERE origem_tipo = 'nota_fiscal_compra' AND numero_duplicata >= 900000 ORDER BY criado_em, id;

UPDATE public.financeiro_titulos t SET numero_duplicata = n.novo FROM _novo_num n WHERE t.id = n.id;

UPDATE public.boletos bo SET numero_documento = t.numero_duplicata::text
  FROM public.financeiro_titulos t
 WHERE t.origem_tipo = 'nota_fiscal_compra' AND bo.conta_grupo_id = t.nota_fiscal_compra_id
   AND bo.tipo_operacao = 'CP' AND bo.nosso_numero LIKE 'NFC-%' AND bo.numero_documento IS DISTINCT FROM t.numero_duplicata::text;

COMMIT;
