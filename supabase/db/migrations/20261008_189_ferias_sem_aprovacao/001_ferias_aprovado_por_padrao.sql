-- SPEC-185 (08/10/2026): férias sem etapa de aprovação no RH. Só a Lana usa o RH e registra o
-- pedido já combinado (e-mail/conversa) -> a solicitação nasce Aprovada. As pendentes viram
-- Aprovado (passam a contar em vw_controle_ferias_clt, que soma só status = 'Aprovado').
-- O CHECK continua aceitando Pendente/Rejeitado/Cancelado (histórico). Sem BEGIN/COMMIT.
ALTER TABLE public.ferias ALTER COLUMN status SET DEFAULT 'Aprovado';
UPDATE public.ferias SET status = 'Aprovado' WHERE status = 'Pendente';
