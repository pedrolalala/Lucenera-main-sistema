-- SPEC-140 (a criar): lista fixa de Vendedores no Orcamento -- pedido do
-- usuario 2026-09-14: so devem aparecer 5 pessoas no campo Vendedor do
-- BudgetFormPage.tsx: Thairine Cristina da Silva, Thais Gomes Pegrucci
-- Favaron, Marina Pousa Barbara Gregorio, Vinicius Bortolin Costa,
-- Filippo Giorgi.
--
-- Investigacao inicial (14/09) tinha concluido, com o usuario, que
-- "Marina Pousa Barbara Gregorio" era erro de importacao (1 pessoa so,
-- nome devia ser so "Marina Pousa"). Revertido em 16/09: usuario decidiu
-- MANTER o nome completo como esta no banco -- nao alterar. O filtro do
-- codigo (VENDEDORES_PERMITIDOS em BudgetFormPage.tsx) foi ajustado pra
-- usar o nome completo em vez de renomear o registro.
--
-- Unica alteracao de dado que permanece nesta migration: Filippo Giorgi
-- (dono da Lucenera, confirmado com o usuario) nao tem cadastro em
-- funcionarios -- so existe como usuario do CRM (id
-- 56bdfb69-01de-462d-94c3-f89db555fd66, filippo@lucenera.com.br, role
-- admin). O campo Vendedor do Orcamento so lista funcionarios, entao ele
-- nunca aparecia. Criado o cadastro vinculado a esse mesmo usuario.
-- empresa_id escolhida (FOCO ILUMINACAO) e cargo (Socio-Diretor) sao
-- defaults razoaveis -- ajustar depois se o usuario quiser outra
-- empresa/cargo, nao afeta o filtro do Vendedor.

BEGIN;

INSERT INTO public.funcionarios (nome, status, cargo, usuario_id, email, empresa_id)
SELECT 'Filippo Giorgi', 'Ativo', 'Sócio-Diretor',
       '56bdfb69-01de-462d-94c3-f89db555fd66',
       'filippo@lucenera.com.br',
       '436913c7-ebd3-44ac-a3b3-14e9b7fbd591'
WHERE NOT EXISTS (
  SELECT 1 FROM public.funcionarios WHERE usuario_id = '56bdfb69-01de-462d-94c3-f89db555fd66'
);

COMMIT;
