-- Rollback da 273: remove a função e as 2 tabelas do XML. Orçamentos já enriquecidos pelo XML mantêm o valor/itens até serem recarregados
-- (rodar importar_reserva_entrega_futura_connect.py --aplicar refaz tudo a partir das planilhas, sem o XML).
BEGIN;
DROP FUNCTION IF EXISTS public.aplicar_xml_connect_orcamentos();
DROP TABLE IF EXISTS public.connect_xml_item;
DROP TABLE IF EXISTS public.connect_xml_orcamento;
COMMIT;
