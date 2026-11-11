-- SPEC-275 (06/11/2026): preço da herança Connect em projeto_itens.
-- A carga da SPEC-243 gravou preco_unitario = 0 e desconto = 0 nos projeto_itens das vendas CNX-xxxx (valor ficou só em
-- orcamento_itens). A devolução calcula o valor a partir de projeto_itens, então saía R$ 0,00.
-- Esta migration copia preco_unitario e desconto do orcamento_itens (ligado por projeto_itens.orcamento_item_id) SÓ onde o preço é 0.
-- NÃO mexe em quantidade, saldos, estoque, financeiro, descrição, nem em projetos.valor_total (trigger desligado só na transação,
-- e conferido ao final). Sem BEGIN/COMMIT no texto (aplicar com dry-run + rollback antes).

ALTER TABLE public.projeto_itens DISABLE TRIGGER trg_sync_valor_total;
ALTER TABLE public.projeto_itens DISABLE TRIGGER trg_set_projeto_itens_descricao;

CREATE TEMP TABLE _spec275_antes ON COMMIT DROP AS
SELECT (SELECT coalesce(sum(valor_total), 0) FROM public.projetos) AS soma_valor_total_projetos,
       (SELECT coalesce(sum(quantidade), 0) FROM public.projeto_itens) AS soma_quantidade,
       (SELECT md5(string_agg(id::text || coalesce(descricao, ''), '|' ORDER BY id)) FROM public.projeto_itens) AS hash_descricao;

UPDATE public.projeto_itens pi
   SET preco_unitario = oi.preco_unitario,
       desconto = coalesce(oi.desconto, 0)
  FROM public.orcamento_itens oi, public.orcamentos o
 WHERE oi.id = pi.orcamento_item_id
   AND o.id = pi.orcamento_id
   AND o.origem = 'connect'
   AND coalesce(pi.preco_unitario, 0) = 0
   AND coalesce(oi.preco_unitario, 0) > 0;

DO $$
DECLARE a record;
BEGIN
  SELECT * INTO a FROM _spec275_antes;
  IF a.soma_valor_total_projetos IS DISTINCT FROM (SELECT coalesce(sum(valor_total), 0) FROM public.projetos) THEN
    RAISE EXCEPTION 'SPEC-275: projetos.valor_total mudou — abortando.';
  END IF;
  IF a.soma_quantidade IS DISTINCT FROM (SELECT coalesce(sum(quantidade), 0) FROM public.projeto_itens) THEN
    RAISE EXCEPTION 'SPEC-275: quantidade mudou — abortando.';
  END IF;
  IF a.hash_descricao IS DISTINCT FROM (SELECT md5(string_agg(id::text || coalesce(descricao, ''), '|' ORDER BY id)) FROM public.projeto_itens) THEN
    RAISE EXCEPTION 'SPEC-275: descrição mudou — abortando.';
  END IF;
END $$;

ALTER TABLE public.projeto_itens ENABLE TRIGGER trg_sync_valor_total;
ALTER TABLE public.projeto_itens ENABLE TRIGGER trg_set_projeto_itens_descricao;
