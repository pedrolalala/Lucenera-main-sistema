-- SPEC-310 (16/11/2026): o estoque deve ser lido do local certo (estoque_itens), nao da coluna antiga produtos.estoque_total/disponivel.
-- 1) ubiqua_estoque_atual() passa a ler estoque_itens (geral + showroom - reservado = mesma conta da Connect).
-- 2) A coluna antiga dos produtos que ficaram desatualizados (entrada de NF/venda atualizam estoque_itens e nao ela) e realinhada. Backup em schema backup.
BEGIN;

CREATE TABLE backup._bkp_spec310_produtos_estoque_antigo AS
SELECT p.id AS produto_id, p.codigo_produto, p.estoque_total, p.estoque_disponivel, now() AS salvo_em
FROM public.produtos p
JOIN public.estoque_itens e ON e.produto_id = p.id AND e.local::text = 'Estoque'
WHERE COALESCE(p.estoque_total,0) IS DISTINCT FROM COALESCE(e.quantidade,0);
REVOKE ALL ON backup._bkp_spec310_produtos_estoque_antigo FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.ubiqua_estoque_atual()
RETURNS TABLE(referencia text, disponivel integer)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public'
AS $$
  SELECT r.referencia,
         GREATEST(0, FLOOR(COALESCE(e.quantidade,0) + COALESCE(p.estoque_showroom,0) - COALESCE(e.quantidade_reservada,0)))::integer
    FROM public.revenda_ubiqua r
    JOIN public.produtos p ON upper(trim(p.referencia)) = upper(trim(r.referencia))
    LEFT JOIN public.estoque_itens e ON e.produto_id = p.id AND e.local::text = 'Estoque';
$$;

UPDATE public.produtos p
SET estoque_total = e.quantidade,
    estoque_disponivel = e.quantidade + COALESCE(p.estoque_showroom,0) - COALESCE(e.quantidade_reservada,0)
FROM public.estoque_itens e
WHERE e.produto_id = p.id AND e.local::text = 'Estoque'
  AND p.id IN (SELECT produto_id FROM backup._bkp_spec310_produtos_estoque_antigo);

DO $$ BEGIN
  IF (SELECT count(*) FROM public.produtos p JOIN public.estoque_itens e ON e.produto_id=p.id AND e.local::text='Estoque'
      WHERE COALESCE(p.estoque_total,0) IS DISTINCT FROM COALESCE(e.quantidade,0)) <> 0 THEN
    RAISE EXCEPTION 'SPEC-310: ainda ha produto com estoque_total diferente de estoque_itens';
  END IF;
END $$;
NOTIFY pgrst, 'reload schema';
COMMIT;
