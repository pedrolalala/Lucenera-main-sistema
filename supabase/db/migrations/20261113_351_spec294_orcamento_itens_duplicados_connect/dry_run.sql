-- SPEC-294: apaga linha duplicada de orcamento_itens criada pelo passo (b2) da migration 273
-- (item do XML da Connect sem cod_produto reinserido como "avulso") e recalcula desconto_global.
-- Regra: por (orcamento, custom_id, descricao, quantidade, preco) em orcamento Connect, se ha mais linhas
-- do que no XML (connect_xml_item), apaga o excesso, so entre linhas SEM vinculo em projeto_itens
-- (preferindo produto_id nulo e a mais recente). Nao mexe em projeto_itens, estoque, reserva, financeiro.
BEGIN;

CREATE SCHEMA IF NOT EXISTS backup;
CREATE TABLE IF NOT EXISTS backup.spec294_orcamento_itens_apagados AS SELECT * FROM public.orcamento_itens WHERE false;
CREATE TABLE IF NOT EXISTS backup.spec294_orcamentos_desconto (orcamento_id uuid PRIMARY KEY, desconto_global_antigo numeric, desconto_tipo_antigo text);
REVOKE ALL ON backup.spec294_orcamento_itens_apagados, backup.spec294_orcamentos_desconto FROM PUBLIC, anon, authenticated;

CREATE TEMP TABLE _a AS
SELECT i.*, o.numero AS _numero,
       row_number() OVER (PARTITION BY i.orcamento_id, i.custom_id, i.descricao, i.quantidade, i.preco_unitario
                          ORDER BY (i.produto_id IS NULL) DESC, i.created_at DESC, i.id) AS _rn,
       count(*) OVER (PARTITION BY i.orcamento_id, i.custom_id, i.descricao, i.quantidade, i.preco_unitario) AS _n_oi,
       NOT EXISTS (SELECT 1 FROM public.projeto_itens p WHERE p.orcamento_item_id = i.id) AS _livre
FROM public.orcamento_itens i JOIN public.orcamentos o ON o.id = i.orcamento_id
WHERE o.origem = 'connect';

-- quantas linhas o XML tem para a mesma combinacao (qtd + preco) naquele orcamento, por classificacao (L01...)
CREATE TEMP TABLE _x AS
SELECT regexp_replace(o.numero, '[^0-9]', '', 'g')::int AS cod, x.qtd_produto AS q, x.vl_unitario AS p, count(*) AS n_xml
FROM public.connect_xml_item x JOIN public.orcamentos o ON regexp_replace(o.numero, '[^0-9]', '', 'g')::int = x.cod_orcamento
WHERE o.origem = 'connect' GROUP BY 1, 2, 3;

CREATE TEMP TABLE _del AS
WITH g AS (
  SELECT orcamento_id, _numero, quantidade, preco_unitario, count(*) AS n_oi_total
  FROM _a GROUP BY 1, 2, 3, 4
)
SELECT a.* FROM _a a
JOIN g ON g.orcamento_id = a.orcamento_id AND g.quantidade = a.quantidade AND g.preco_unitario = a.preco_unitario
JOIN _x x ON x.cod = regexp_replace(a._numero, '[^0-9]', '', 'g')::int AND x.q = a.quantidade AND x.p = a.preco_unitario
WHERE a._n_oi > 1 AND a._livre
  AND a._rn <= (g.n_oi_total - x.n_xml);

-- So corrige o orcamento cuja base (sem a duplicata) bate com a soma dos itens do XML; os demais vao para a D1 da SPEC-294.
DELETE FROM _del d WHERE NOT EXISTS (
  SELECT 1 FROM public.orcamentos o
  WHERE o.id = d.orcamento_id
    AND round((SELECT sum(i.quantidade * i.preco_unitario) FROM public.orcamento_itens i WHERE i.orcamento_id = o.id)
              - (SELECT coalesce(sum(dd.quantidade * dd.preco_unitario), 0) FROM _del dd WHERE dd.orcamento_id = o.id), 2)
      = (SELECT round(sum(x.qtd_produto * x.vl_unitario), 2) FROM public.connect_xml_item x WHERE x.cod_orcamento = regexp_replace(o.numero, '[^0-9]', '', 'g')::int));

INSERT INTO backup.spec294_orcamentos_desconto
SELECT o.id, o.desconto_global, o.desconto_tipo FROM public.orcamentos o
WHERE o.id IN (SELECT orcamento_id FROM _del) ON CONFLICT DO NOTHING;

INSERT INTO backup.spec294_orcamento_itens_apagados
SELECT i.* FROM public.orcamento_itens i WHERE i.id IN (SELECT id FROM _del);

DELETE FROM public.orcamento_itens WHERE id IN (SELECT id FROM _del);

UPDATE public.orcamentos o SET
  desconto_global = greatest(0, round((SELECT coalesce(sum(i.quantidade * i.preco_unitario), 0) FROM public.orcamento_itens i WHERE i.orcamento_id = o.id) - o.valor_total, 2)),
  desconto_tipo = 'valor'
WHERE o.id IN (SELECT DISTINCT orcamento_id FROM _del);

DO $$ BEGIN
  RAISE NOTICE 'SPEC-294: % linhas apagadas em % orcamentos', (SELECT count(*) FROM _del), (SELECT count(DISTINCT orcamento_id) FROM _del);
END $$;

-- conferencias (antes do ROLLBACK)
DO $$ DECLARE r record; BEGIN
  FOR r IN SELECT o.numero, o.valor_total, o.desconto_global,
      (SELECT count(*) FROM public.orcamento_itens i WHERE i.orcamento_id=o.id) n_oi,
      (SELECT round(sum(quantidade*preco_unitario),2) FROM public.orcamento_itens i WHERE i.orcamento_id=o.id) base_oi,
      (SELECT round(sum(x.qtd_produto*x.vl_unitario),2) FROM public.connect_xml_item x WHERE x.cod_orcamento=regexp_replace(o.numero,'[^0-9]','','g')::int) base_xml
    FROM public.orcamentos o WHERE o.id IN (SELECT DISTINCT orcamento_id FROM _del) ORDER BY 1 LOOP
    RAISE NOTICE '% valor_total=% desc=% n_oi=% base_oi=% base_xml=%', r.numero, r.valor_total, r.desconto_global, r.n_oi, r.base_oi, r.base_xml;
  END LOOP;
  RAISE NOTICE 'apagadas com vinculo em projeto_itens: %', (SELECT count(*) FROM _del d JOIN public.projeto_itens p ON p.orcamento_item_id=d.id);
END $$;
ROLLBACK;
