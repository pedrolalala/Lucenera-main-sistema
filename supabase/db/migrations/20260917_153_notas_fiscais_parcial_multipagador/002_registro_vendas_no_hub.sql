-- SPEC-153: registra o sistema novo "Vendas" em public.systems para aparecer
-- como card na Central Lucenera (Hub). Mesmo padrão de
-- supabase/db/migrations/20260916_125_showroom_registro_hub/001_....sql.
--
-- Link real do Skip do sistema Vendas (projectId 59346, "Página de Vendas"),
-- confirmado com o usuário: https://pagina-de-vendas-9549c.goskip.app --
-- aponta pra rota principal (tela "Vendas"), mesmo padrão dos demais cards
-- (ferramenta de trabalho interna).
--
-- display_order = 13: próximo livre na sequência conhecida por este
-- repositório no momento da redação (hub=0 ... separacao-parcial=7,
-- logistica=8, ubiqua=9, dashboard-financeiro=10, memoria=11, showroom=12).
-- "Central de Solicitações" usa 100 à parte -- não é sequência estrita.
-- CONFERIR contra o valor real de public.systems antes de aplicar, já que
-- supabase/db/current/ está desatualizado (ver SPEC-153, seção "Análise de
-- ecossistema").
--
-- RASCUNHO -- NÃO aplicar sem aprovação/execução manual do usuário.

BEGIN;

INSERT INTO public.systems (name, description, link, icon_name, display_order, slug, visivel_no_hub)
VALUES (
  'Vendas',
  'Único lugar onde nota fiscal e boleto são orquestrados a partir de um orçamento aprovado (venda). Suporta nota fiscal parcial com pagador diferente do titular da venda.',
  'https://pagina-de-vendas-9549c.goskip.app',
  'ShoppingCart',
  13,
  'vendas',
  true
)
ON CONFLICT (slug) DO UPDATE SET
  name = EXCLUDED.name,
  description = EXCLUDED.description,
  link = EXCLUDED.link,
  icon_name = EXCLUDED.icon_name,
  visivel_no_hub = EXCLUDED.visivel_no_hub;

-- SPEC-153 (Pendências): RBAC real (Carol completo / Lana sem acesso) fica
-- para quando Administração Bancária e Vendas migrarem pra hub_pode_executar
-- de fato (SPEC-069). Sem nenhuma linha em papel_permissoes para o slug
-- 'vendas', a RPC registrar_nota_fiscal_parcial (001_...sql) nega todo
-- usuário não-service_role -- decisão consciente de não inventar regra de
-- acesso aqui. Ação manual mínima para o sistema ficar utilizável por um
-- papel (ex. admin) fica documentada nos "Passos manuais do usuário" da
-- SPEC-153, não decidida por esta migration.

NOTIFY pgrst, 'reload schema';

COMMIT;
