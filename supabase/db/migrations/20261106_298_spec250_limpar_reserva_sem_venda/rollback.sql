-- SPEC-250: remove a função. (Não desfaz baixas já aplicadas: cada uma ficou registrada em movimentacoes_peca, origem "Reserva sem venda (herança Connect)".)
DROP FUNCTION IF EXISTS public.limpar_reserva_sem_venda_connect(jsonb, boolean, text);
