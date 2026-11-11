-- SPEC-258 Fase 2: desfaz a carga. A carga só COPIOU (nada antigo foi alterado), então desfazer = esvaziar as tabelas novas.
-- SÓ É SEGURO ENQUANTO NÃO HOUVER DADO NATIVO (Fase 4): depois disso, NÃO rodar (apagaria títulos/baixas do sistema novo).
-- TRUNCATE ignora os gatilhos de imutabilidade de propósito; exige papel dono (postgres).
TRUNCATE public.financeiro_eventos, public.financeiro_legado_ids, public.financeiro_pendencias, public.financeiro_renegociacoes,
         public.financeiro_baixas, public.financeiro_cobrancas, public.financeiro_parcelas, public.financeiro_titulos RESTART IDENTITY;
