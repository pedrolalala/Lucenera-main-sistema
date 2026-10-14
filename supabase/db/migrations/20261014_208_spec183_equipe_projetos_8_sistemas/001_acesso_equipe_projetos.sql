-- SPEC-183 (14/10, pedido do usuário): todos da Equipe de Projetos (papel equipe_projetos) veem na Central:
-- Orçamentos, CRM, Consultar Produtos, Separação Parcial, Sistema de Entregas, Fichas Técnicas, Showroom e Memória.
-- Só ACRESCENTA acesso (user_system_access = visibilidade); quem já vê outros sistemas continua vendo.
-- Cópia da tabela antes da mudança em _bkp_user_system_access_20261014 (usada pelo rollback).

CREATE TABLE IF NOT EXISTS public._bkp_user_system_access_20261014 AS
  SELECT * FROM public.user_system_access;
ALTER TABLE public._bkp_user_system_access_20261014 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public._bkp_user_system_access_20261014 FROM anon, authenticated;

INSERT INTO public.user_system_access (user_id, system_id)
SELECT DISTINCT up.usuario_id, s.id
FROM public.usuario_papeis up
JOIN public.papeis p ON p.id = up.papel_id AND p.nome = 'equipe_projetos'
CROSS JOIN public.systems s
WHERE s.slug IN ('orcamentos', 'crm', 'cadastro', 'separacao-parcial', 'logistica', 'ubiqua', 'showroom', 'memoria')
ON CONFLICT (user_id, system_id) DO NOTHING;
