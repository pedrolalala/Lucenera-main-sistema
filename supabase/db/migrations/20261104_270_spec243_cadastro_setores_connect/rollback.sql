-- Rollback da 270: volta a soma ÚNICA em vw_cadastro_produto_setores (Connect misturado na Reserva/Entrega Futura do sistema, como logo após a carga).
-- As colunas `origem` das outras 3 views e as 2 colunas *_connect ficam (CREATE OR REPLACE não remove coluna; são inofensivas:
-- as colunas *_connect continuam existindo para o código novo não quebrar, mas a Reserva/Entrega Futura voltam a incluir a Connect).
BEGIN;

CREATE OR REPLACE VIEW public.vw_cadastro_produto_setores
WITH (security_invoker = true) AS
 SELECT produto_id,
    COALESCE(sum(q_reserva), (0)::numeric) AS q_reserva,
    (COALESCE(sum(q_ag_separar), (0)::numeric) + COALESCE(sum(q_separado), (0)::numeric)) AS q_separacao,
    COALESCE(sum(q_entrega_futura), (0)::numeric) AS q_entrega_futura,
    COALESCE(sum(q_reserva) FILTER (WHERE origem = 'connect'), (0)::numeric) AS q_reserva_connect,
    COALESCE(sum(q_entrega_futura) FILTER (WHERE origem = 'connect'), (0)::numeric) AS q_entrega_futura_connect
   FROM vw_estoque_por_produto_projeto v
  GROUP BY produto_id;

COMMIT;
