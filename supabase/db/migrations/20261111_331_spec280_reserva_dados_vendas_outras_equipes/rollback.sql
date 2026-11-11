-- SPEC-280: remove a função nova (a tela volta a completar os dados lendo `orcamentos`, como antes).
DROP FUNCTION IF EXISTS public.reserva_dados_vendas(uuid[]);
