-- Migration 20260805_077 - SPEC-064 (complemento)
--
-- Achado ao implementar: o RH (dashboard-rh-lucenera-5fe9c) tem DUAS tabelas
-- de funcionario distintas -- `funcionarios` (legada, 29 linhas, usada por
-- Ferias/Faltas) e `funcionarios_novo` (28 linhas, usada pela tela real de
-- Cadastro de Funcionarios via EmployeeForm.tsx + vw_funcionarios_completo).
-- 001_add_perfil.sql so adicionou a coluna em `funcionarios` -- a tela de
-- cadastro que o usuario quer marcar (funcionario admitido em Sao Paulo)
-- grava em `funcionarios_novo`, que tambem precisa da coluna.

ALTER TABLE public.funcionarios_novo
  ADD COLUMN IF NOT EXISTS perfil text CHECK (perfil IN ('ribeirao', 'sao_paulo'));

CREATE OR REPLACE VIEW public.vw_funcionarios_completo AS
SELECT fn.id,
    fn.nome,
    fn.cargo,
    fn.ativo,
    fn.data_admissao,
    fn.created_at,
    fd.cpf,
    fd.rg,
    fd.data_nascimento,
    fd.endereco,
    fd.telefone,
    fd.email,
    ff.salario_base,
    ff.salario_por_fora,
    ff.comissao_percentual,
    ff.salario_liquido,
    fb.empresa,
    fb.valor_vt_dia,
    fn.perfil
   FROM funcionarios_novo fn
     LEFT JOIN funcionarios_detalhes fd ON fd.funcionario_id = fn.id
     LEFT JOIN funcionarios_financeiro ff ON ff.funcionario_id = fn.id
     LEFT JOIN funcionarios_beneficios_empresas fb ON fb.funcionario_id = fn.id;
