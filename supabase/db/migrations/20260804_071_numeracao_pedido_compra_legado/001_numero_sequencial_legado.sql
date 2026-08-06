-- Reuniao 04/08/2026 (Filippo + Debora, "necessidade de compra"): o numero
-- do pedido ja era gerado automaticamente quando NEW.numero vinha vazio,
-- mas no formato "PC-<ano>-NNNN" -- nunca usado de fato em producao (0
-- pedidos criados pelo app ate hoje, so os 51 importados do legado como
-- "PC-LEGADO-NNNN", max 1725). O sistema legado (Connect) seguiu numerando
-- em paralelo -- os PDFs de referencia mostram pedidos 1743 (23/07) e 1765
-- (03/08), e o usuario confirmou 1767 como o ultimo numero realmente usado.
--
-- Troca o formato para numero sequencial simples (sem prefixo), igual ao
-- legado, via sequence dedicada iniciada em 1768 (proximo apos 1767) --
-- evita colisao com qualquer numero legado, mesmo os que nao foram
-- importados (gap entre 1725 e 1767).

CREATE SEQUENCE public.pedidos_compra_numero_seq START WITH 1768;

CREATE OR REPLACE FUNCTION public.set_pedido_compra_numero()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
  IF NEW.numero IS NULL OR trim(NEW.numero) = '' THEN
    NEW.numero := nextval('public.pedidos_compra_numero_seq')::text;
  END IF;
  RETURN NEW;
END;
$function$;

COMMENT ON SEQUENCE public.pedidos_compra_numero_seq IS
  'Numeracao de pedidos_compra.numero criados pelo app (sem prefixo), continuando a sequencia do sistema legado Connect. Iniciada em 1768 (usuario confirmou 1767 como ultimo numero legado real em 2026-08-04, acima do max importado de 1725).';
