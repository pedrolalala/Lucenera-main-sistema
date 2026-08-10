-- Usuário pediu que só Filippo, Pedro e Vinicius tenham acesso ao
-- "Dashboard Financeiro" (slug dashboard-financeiro, projectId Skip 41135),
-- e reportou que atualmente ninguém conseguia entrar.
--
-- Causa raiz confirmada: o app já tinha o gating de RBAC certo desde a
-- SPEC-063 (Layout.tsx chama hub_pode_executar(..., 'dashboard-financeiro',
-- null, null) e mostra "Acesso negado" se false), mas só existia UMA linha
-- em papel_permissoes para esse sistema — papel admin_geral (hoje só o
-- Vinicius tem). Filippo e Pedro tinham role legado 'admin' em
-- usuarios.role (campo antigo, não usado por hub_pode_executar) mas ZERO
-- linhas em usuario_papeis (RBAC novo) — por isso ambos caíam direto na
-- tela de acesso negado.
--
-- Em vez de dar admin_geral pros três (que também libera todos os outros
-- sistemas), cria um papel dedicado e restrito só a este sistema — assim
-- "de resto ninguém" continua valendo mesmo se algum dia mais gente ganhar
-- admin_geral por outro motivo.

INSERT INTO public.papeis (nome, descricao)
VALUES (
  'dashboard_financeiro_acesso',
  'Acesso exclusivo ao Dashboard Financeiro (Contas a Pagar/Receber) — restrito a Filippo, Pedro e Vinicius por decisão explícita.'
)
ON CONFLICT (nome) DO NOTHING;

INSERT INTO public.papel_permissoes (papel_id, system_id, modulo_id, acao)
SELECT
  (SELECT id FROM public.papeis WHERE nome = 'dashboard_financeiro_acesso'),
  (SELECT id FROM public.systems WHERE slug = 'dashboard-financeiro'),
  NULL,
  NULL
WHERE NOT EXISTS (
  SELECT 1 FROM public.papel_permissoes
  WHERE papel_id = (SELECT id FROM public.papeis WHERE nome = 'dashboard_financeiro_acesso')
    AND system_id = (SELECT id FROM public.systems WHERE slug = 'dashboard-financeiro')
    AND modulo_id IS NULL
    AND acao IS NULL
);

INSERT INTO public.usuario_papeis (usuario_id, papel_id)
SELECT u.id, (SELECT id FROM public.papeis WHERE nome = 'dashboard_financeiro_acesso')
FROM public.usuarios u
WHERE u.email IN ('filippo@lucenera.com.br', 'pedro@lucenera.com.br', 'vinicius@lucenera.com.br')
ON CONFLICT (usuario_id, papel_id) DO NOTHING;
