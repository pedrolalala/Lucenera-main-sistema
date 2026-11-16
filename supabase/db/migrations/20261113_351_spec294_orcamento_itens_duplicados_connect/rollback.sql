BEGIN;
INSERT INTO public.orcamento_itens SELECT * FROM backup.spec294_orcamento_itens_apagados ON CONFLICT (id) DO NOTHING;
UPDATE public.orcamentos o SET desconto_global = b.desconto_global_antigo, desconto_tipo = b.desconto_tipo_antigo
FROM backup.spec294_orcamentos_desconto b WHERE b.orcamento_id = o.id;
COMMIT;
