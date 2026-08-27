-- SPEC-058 — Pedido 1: Férias sem bloqueio duro
--
-- Permite lançar férias sem um período aquisitivo associado (ex.: funcionário
-- novo, sem período aquisitivo completo/cadastrado ainda). O front-end
-- (VacationForm.tsx) passa a enviar `periodo_aquisitivo_id: null` quando não
-- houver período selecionado.
--
-- Consequência aceita (ver SPEC-058, Pendência P-04): registros de `ferias`
-- com `periodo_aquisitivo_id IS NULL` ficam de fora de `vw_controle_ferias_clt`
-- (que usa INNER JOIN com `periodos_aquisitivos`), ou seja, não entram no
-- cálculo de saldo de férias nem aparecem em VacationBalances.tsx. Isso é
-- esperado e não será corrigido nesta SPEC.

ALTER TABLE public.ferias ALTER COLUMN periodo_aquisitivo_id DROP NOT NULL;
