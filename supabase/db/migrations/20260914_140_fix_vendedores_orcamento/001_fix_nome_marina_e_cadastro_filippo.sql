-- SPEC-140 (a criar): lista fixa de Vendedores no Orcamento -- pedido do
-- usuario 2026-09-14: so devem aparecer 5 pessoas no campo Vendedor do
-- BudgetFormPage.tsx: Thairine Cristina da Silva, Thais Gomes Pegrucci
-- Favaron, Marina Pousa, Vinicius Bortolin Costa, Filippo Giorgi.
--
-- Investigacao achou 2 problemas de dado antes de poder filtrar por nome:
--
-- 1) funcionarios.nome = 'Marina Pousa Barbara Gregorio' (id
--    cb40527f-edc5-4c21-a8cc-0093e7a8b77f) -- registro unico com 2 nomes
--    colados no campo nome (erro de importacao do Connect, nm_connect =
--    'MARINA', codigo_legado 355). Confirmado com o usuario: e 1 pessoa
--    so, nao 2. O usuario vinculado (usuarios.id
--    438d37e0-ae72-4226-83c7-15d501a49dd4) se chama so 'Marina'
--    (marina@lucenera.com.br) -- confirma que o nome real e 'Marina
--    Pousa'; 'Barbara Gregorio' nunca existiu como funcionaria separada
--    neste banco (nenhum outro registro com esse nome).
--
-- 2) Filippo Giorgi (dono da Lucenera, confirmado com o usuario) nao tem
--    cadastro em funcionarios -- so existe como usuario do CRM (id
--    56bdfb69-01de-462d-94c3-f89db555fd66, filippo@lucenera.com.br,
--    role admin). O campo Vendedor do Orcamento so lista funcionarios,
--    entao ele nunca aparecia. Criado o cadastro vinculado a esse mesmo
--    usuario. empresa_id escolhida (FOCO ILUMINACAO) e cargo
--    (Socio-Diretor) sao defaults razoaveis -- ajustar depois se o
--    usuario quiser outra empresa/cargo, nao afeta o filtro do Vendedor.

BEGIN;

UPDATE public.funcionarios
SET nome = 'Marina Pousa'
WHERE id = 'cb40527f-edc5-4c21-a8cc-0093e7a8b77f'
  AND nome = 'Marina Pousa Barbara Gregorio';

INSERT INTO public.funcionarios (nome, status, cargo, usuario_id, email, empresa_id)
SELECT 'Filippo Giorgi', 'Ativo', 'Sócio-Diretor',
       '56bdfb69-01de-462d-94c3-f89db555fd66',
       'filippo@lucenera.com.br',
       '436913c7-ebd3-44ac-a3b3-14e9b7fbd591'
WHERE NOT EXISTS (
  SELECT 1 FROM public.funcionarios WHERE usuario_id = '56bdfb69-01de-462d-94c3-f89db555fd66'
);

COMMIT;
