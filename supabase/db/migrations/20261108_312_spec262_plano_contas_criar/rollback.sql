DROP FUNCTION IF EXISTS public.plano_contas_criar(text, smallint, uuid, text);
-- Itens ja criados ficam (podem estar em uso). Para listar: SELECT * FROM public.plano_de_contas WHERE codigo_connect >= 800000000;
