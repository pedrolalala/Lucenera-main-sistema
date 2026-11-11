-- SPEC-275: volta ao estado da carga (todos os projeto_itens da herança Connect tinham preço 0 e desconto 0).
ALTER TABLE public.projeto_itens DISABLE TRIGGER trg_sync_valor_total;
UPDATE public.projeto_itens pi SET preco_unitario = 0, desconto = 0
  FROM public.orcamentos o WHERE o.id = pi.orcamento_id AND o.origem = 'connect';
ALTER TABLE public.projeto_itens ENABLE TRIGGER trg_sync_valor_total;
