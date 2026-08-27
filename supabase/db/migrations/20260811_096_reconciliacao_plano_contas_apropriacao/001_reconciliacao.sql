-- Reconcilia plano_de_contas (nivel 3 / Apropriacao) com a lista oficial
-- fornecida pelo usuario (116 itens). Ver conversa 2026-08-11.
--
-- Estrategia aprovada pelo usuario ("Sua lista e a oficial"):
--   1) Renomear (UPDATE, id preservado) itens existentes cuja grafia
--      diverge só por acentuacao/pontuacao — nao afeta nenhum lancamento
--      vinculado (negociacoes.plano_contas_id / boletos.apropriacao_id
--      continuam apontando pro mesmo id).
--   2) Inserir (INSERT) os itens genuinamente novos da lista do usuario,
--      com parent_id (Sub Grupo) escolhido por semelhanca com os itens
--      irmaos ja existentes.
--   3) NAO remover nenhum item so-do-banco: todos os 27 tem lancamentos
--      reais vinculados em negociacoes (1 a 2261 registros cada) — apagar
--      quebraria/desvincularia historico financeiro real. Ficam mantidos.
--   4) NAO criar "DECIMO TERCEIRO" como novo item: e sinonimo de
--      "13o SALARIO" (ja renomeado abaixo pra "13º SALARIO"), criar os
--      dois duplicaria a mesma despesa.

-- ============================================================
-- 1) RENOMEACOES (23 itens, cosmetico, id preservado)
-- ============================================================

UPDATE public.plano_de_contas SET nome = 'ÁGUA E ESGOTO' WHERE id = 'd5eab52d-aa24-4550-a1fc-f90c8213fff7';
UPDATE public.plano_de_contas SET nome = 'ASSISTÊNCIA SOFTWARE' WHERE id = '8914f969-861a-4b0c-be85-5b189da4a302';
UPDATE public.plano_de_contas SET nome = 'ASSISTÊNCIA TÉCNICA' WHERE id = '51ac2d53-7b4c-4925-9c5c-9617533d4108';
UPDATE public.plano_de_contas SET nome = 'BOLO FUNCIONÁRIOS' WHERE id = '61756777-908e-4d87-b9b5-0137f60d738a';
UPDATE public.plano_de_contas SET nome = 'COMBUSTÍVEL' WHERE id = 'c3251f44-556e-46ef-9404-333b3617d448';
UPDATE public.plano_de_contas SET nome = 'COMPRA VEÍCULO' WHERE id = '1b7fb398-941f-4f97-9438-5eb68ad124ee';
UPDATE public.plano_de_contas SET nome = 'CONSÓRCIO' WHERE id = '3c0c7acf-56ac-443a-a013-3d9aaafe5dde';
UPDATE public.plano_de_contas SET nome = 'EMPRÉSTIMO' WHERE id = '565b0c1a-bf7b-4de7-ba06-abf5c215b2bc';
UPDATE public.plano_de_contas SET nome = 'ENERGIA ELÉTRICA' WHERE id = '9c028a81-a80f-45f1-a48d-a78303165f24';
UPDATE public.plano_de_contas SET nome = 'INFORMÁTICA E CARTUCHOS' WHERE id = '60a95559-d88e-4289-818e-49f796da05ae';
UPDATE public.plano_de_contas SET nome = 'MÁQUINAS E EQUIPAMENTOS' WHERE id = '07c60576-a8e3-47ee-be8f-aeadcdbff13d';
UPDATE public.plano_de_contas SET nome = 'MATERIAL ESCRITÓRIO' WHERE id = '69ff1286-dd13-4bb0-9e0d-27bc1395e950';
UPDATE public.plano_de_contas SET nome = 'MÓVEIS E UTENSÍLIOS' WHERE id = '94a0de22-a1bb-472b-b2f5-979b97a5844e';
UPDATE public.plano_de_contas SET nome = 'PEDÁGIOS' WHERE id = '2ee1fda5-6990-47ba-b840-2dc2a8e9ebb7';
UPDATE public.plano_de_contas SET nome = 'REFORMA ESCRITÓRIO' WHERE id = 'ba964a8d-39ae-4af1-8650-55a09cae403a';
UPDATE public.plano_de_contas SET nome = 'VALE DE FUNCIONÁRIO' WHERE id = '7586dac6-b21d-4c1d-b5a6-112bb4f65db5';
UPDATE public.plano_de_contas SET nome = 'VENDAS À VISTA' WHERE id = '886b004f-111c-4351-bc33-e06c3655057b';

-- Alem de acento (mesma categoria, grafia/pontuacao diferente):
UPDATE public.plano_de_contas SET nome = '13º SALÁRIO' WHERE id = '572da27c-def5-4914-bd2b-20297ca6e97c';
UPDATE public.plano_de_contas SET nome = 'DARF/FGPS' WHERE id = '1fff4cdb-9afe-4174-af36-095a24642bd0';
UPDATE public.plano_de_contas SET nome = 'RECEBIMENTO VENDA A PRAZO' WHERE id = '2b40afb2-ee1a-4421-a01b-13a8de4cbffc';
UPDATE public.plano_de_contas SET nome = 'MANUTENÇÃO/REVISÃO' WHERE id = 'a40c5e1f-35f8-4cad-ab61-87e5838a522c';
UPDATE public.plano_de_contas SET nome = 'VIAGENS/VISTAS' WHERE id = 'b1de54a7-50d3-48dd-95d5-23385ffb6421';
UPDATE public.plano_de_contas SET nome = 'TAXIS / FRETE / UBER' WHERE id = '03c2ae59-ba4c-4989-a69f-620afaf99135';

-- ============================================================
-- 2) INSERCOES (34 itens novos, nivel 3)
-- ============================================================
-- codigo_connect e NOT NULL (sem default) e faz parte da unique key
-- (codigo_connect, nivel, parent_id). Itens vindos do Connect usam a faixa
-- 1.000.000-10.000.000; itens novos (nao existem no Connect) usam a faixa
-- 90.000.001+ pra deixar claro que sao criacoes manuais desta reconciliacao.
-- tipo segue o Grupo (nivel 1) do parent_id escolhido: DESPESAS->despesa,
-- INVESTIMENTOS->investimento, RECEITAS->receita.

INSERT INTO public.plano_de_contas (codigo_connect, nome, nivel, parent_id, tipo, ativo) VALUES
  (90000001, 'ACORDO TRABALHISTA',        3, 'd4a03ce4-78db-452e-9487-4a06db410cdf', 'despesa', true), -- Com Pessoal
  (90000002, 'AJUSTE DE OBRA',            3, 'ce518e98-8324-459a-a9ab-dd728393cd6d', 'despesa', true), -- Com Vendas
  (90000003, 'ALUGUEL SÃO PAULO',         3, '514abb31-3f5b-452b-9dc8-5c3cba9982dd', 'receita', true), -- Entradas e Abatimentos
  (90000004, 'APORTE ENTRE CONTAS',       3, '71f017c2-1f71-4ac3-ab2a-a0037a5bf146', 'despesa', true), -- Bancarias
  (90000005, 'ASSISTÊNCIA JURÍDICA',      3, 'fdb4360c-c88e-459b-8be4-baa8bc549c5c', 'despesa', true), -- Administrativas
  (90000006, 'CELULAR E PLANOS',          3, '25489921-e5e8-4898-927a-f8e807d25644', 'despesa', true), -- Fixas
  (90000007, 'CH DEVOLVIDOS',             3, '71f017c2-1f71-4ac3-ab2a-a0037a5bf146', 'despesa', true), -- Bancarias
  (90000008, 'CONDOMÍNIO',                3, '25489921-e5e8-4898-927a-f8e807d25644', 'despesa', true), -- Fixas
  (90000009, 'CONDOMÍNIO - SÃO PAULO',    3, '25489921-e5e8-4898-927a-f8e807d25644', 'despesa', true), -- Fixas
  (90000010, 'CRÉDITOS COM IMPOSTO',      3, 'ce518e98-8324-459a-a9ab-dd728393cd6d', 'despesa', true), -- Com Vendas
  (90000011, 'DENTISTA',                  3, 'd4a03ce4-78db-452e-9487-4a06db410cdf', 'despesa', true), -- Com Pessoal
  (90000012, 'DEPÓSITOS',                 3, '71f017c2-1f71-4ac3-ab2a-a0037a5bf146', 'despesa', true), -- Bancarias
  (90000013, 'DESCONTOS',                 3, 'ce518e98-8324-459a-a9ab-dd728393cd6d', 'despesa', true), -- Com Vendas
  (90000014, 'DESP. OPERAC. FILIPPO',     3, '1692472a-fac3-4c33-b5ef-79ae42c6a9c2', 'despesa', true), -- Operacional
  (90000015, 'DESP. OPERAC. MANOELLA',    3, '1692472a-fac3-4c33-b5ef-79ae42c6a9c2', 'despesa', true), -- Operacional
  (90000016, 'DPVAT',                     3, '5b757fff-3a86-4e0d-91f8-94a2eb9df430', 'despesa', true), -- Veiculos
  (90000017, 'GUIA ST',                   3, 'ce518e98-8324-459a-a9ab-dd728393cd6d', 'despesa', true), -- Com Vendas
  (90000018, 'INSS',                      3, 'd4a03ce4-78db-452e-9487-4a06db410cdf', 'despesa', true), -- Com Pessoal
  (90000019, 'JUROS',                     3, '71f017c2-1f71-4ac3-ab2a-a0037a5bf146', 'despesa', true), -- Bancarias
  (90000020, 'JUROS RECEBIDOS',           3, '514abb31-3f5b-452b-9dc8-5c3cba9982dd', 'receita', true), -- Entradas e Abatimentos
  (90000021, 'MANUTENÇÃO CONTA',          3, '71f017c2-1f71-4ac3-ab2a-a0037a5bf146', 'despesa', true), -- Bancarias
  (90000022, 'MARCA E PATENTES',          3, 'fdb4360c-c88e-459b-8be4-baa8bc549c5c', 'despesa', true), -- Administrativas
  (90000023, 'MERCADORIA DANIFICADA',     3, 'ce518e98-8324-459a-a9ab-dd728393cd6d', 'despesa', true), -- Com Vendas
  (90000024, 'OBRA',                      3, 'ce518e98-8324-459a-a9ab-dd728393cd6d', 'despesa', true), -- Com Vendas
  (90000025, 'PAGAMENTO ALUGUEL',         3, '25489921-e5e8-4898-927a-f8e807d25644', 'despesa', true), -- Fixas
  (90000026, 'RECEBIMENTOS DE CHEQUES',   3, '514abb31-3f5b-452b-9dc8-5c3cba9982dd', 'receita', true), -- Entradas e Abatimentos
  (90000027, 'RECEITA MANOELLA',          3, '514abb31-3f5b-452b-9dc8-5c3cba9982dd', 'receita', true), -- Entradas e Abatimentos
  (90000028, 'SERASA EXPERIAN',           3, 'fdb4360c-c88e-459b-8be4-baa8bc549c5c', 'despesa', true), -- Administrativas
  (90000029, 'SISTEMA FOTOVOLTAICO',      3, 'd16339a2-b5d1-48ca-84be-1e0a8576beda', 'investimento', true), -- Investimentos
  (90000030, 'SITE',                      3, '2c666cc0-851c-4ed7-8032-da2c02fa86e4', 'investimento', true), -- Publicidade e Propaganda
  (90000031, 'TÍTULOS E CAPITALIZAÇÕES',  3, 'd16339a2-b5d1-48ca-84be-1e0a8576beda', 'investimento', true), -- Investimentos
  (90000032, 'TRANSFERÊNCIA',             3, '71f017c2-1f71-4ac3-ab2a-a0037a5bf146', 'despesa', true), -- Bancarias
  (90000033, 'TRIBUTOS',                  3, 'ce518e98-8324-459a-a9ab-dd728393cd6d', 'despesa', true), -- Com Vendas
  (90000034, 'VALE ALIMENTAÇÃO',          3, 'd4a03ce4-78db-452e-9487-4a06db410cdf', 'despesa', true); -- Com Pessoal
