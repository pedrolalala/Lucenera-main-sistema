-- SPEC-072: usuário confirmou que a tela de Separação Parcial deve mostrar
-- os boletos da venda selecionada (não há dado sensível de valor exposto
-- de forma isolada — só contexto operacional, "todos podem ver"). A policy
-- de SELECT de boletos (SPEC-069, migration 085) só liberava para quem tem
-- 'financeiro' — estende com OR para 'separacao-parcial', sem tocar em
-- INSERT/UPDATE/DELETE (continuam exclusivos de financeiro).
DROP POLICY IF EXISTS spec069_boletos_select ON public.boletos;

CREATE POLICY spec069_boletos_select ON public.boletos FOR SELECT
  USING (
    hub_pode_executar(auth.uid(), 'financeiro', NULL, 'visualizar')
    OR hub_pode_executar(auth.uid(), 'separacao-parcial', NULL, 'visualizar')
  );
