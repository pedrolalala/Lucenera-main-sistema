BEGIN;
ALTER TABLE public.produtos DISABLE TRIGGER trg_calculo_preco_venda;
ALTER TABLE public.produtos DISABLE TRIGGER trg_atualizar_preco_venda;
UPDATE public.produtos p SET preco_venda = b.preco_venda
  FROM backup._bkp_spec264_produtos_preco_venda b
 WHERE b.id = p.id AND p.preco_venda IS DISTINCT FROM b.preco_venda;
ALTER TABLE public.produtos ENABLE TRIGGER trg_calculo_preco_venda;
ALTER TABLE public.produtos ENABLE TRIGGER trg_atualizar_preco_venda;
COMMIT;
