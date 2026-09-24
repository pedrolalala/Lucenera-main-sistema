-- SPEC-163: registra Controle de Produção e Controle de Garantia em
-- public.systems para aparecerem como card na Central Lucenera (Hub) e no
-- menu lateral SystemSwitcher dos outros sistemas (SPEC-120). Mesmo padrão de
-- 20260917_153_notas_fiscais_parcial_multipagador/002_registro_vendas_no_hub.sql.
--
-- Links = URLs de produção do Skip (60535 / 60545), criados na SPEC-156.
-- display_order 14/15: próximos livres (maior atual = vendas 13; solicitacoes
-- usa 100 à parte).
--
-- Acesso (decisão do usuário, 24/09/2026): TODOS os papéis veem os dois cards
-- -> uma linha 'visualizar' por papel em papel_permissoes (o que
-- hub_sistemas_permitidos lê). Admin já vê tudo por bypass no frontend.
-- Os dois sistemas continuam exigindo só login (não chamam hub_pode_executar).

BEGIN;

INSERT INTO public.systems (name, description, link, icon_name, display_order, slug, visivel_no_hub)
VALUES
  ('Controle de Produção',
   'Pedidos de produção (Lineas/Steccas, Peças Avulsas, Cortes): status em tempo real, anexos, handoff e ocorrências.',
   'https://pagina-em-branco-e9c45.goskip.app',
   'Factory', 14, 'controle-producao', true),
  ('Controle de Garantia',
   'Itens em garantia e protocolos com fornecedor, do contato até o desfecho.',
   'https://pagina-em-branco-b044c.goskip.app',
   'ShieldCheck', 15, 'controle-garantia', true)
ON CONFLICT (slug) DO UPDATE SET
  name = EXCLUDED.name,
  description = EXCLUDED.description,
  link = EXCLUDED.link,
  icon_name = EXCLUDED.icon_name,
  visivel_no_hub = EXCLUDED.visivel_no_hub;

INSERT INTO public.papel_permissoes (papel_id, system_id, modulo_id, acao)
SELECT p.id, s.id, NULL, 'visualizar'
FROM public.papeis p
CROSS JOIN public.systems s
WHERE s.slug IN ('controle-producao', 'controle-garantia')
ON CONFLICT (papel_id, system_id, modulo_id, acao) DO NOTHING;

NOTIFY pgrst, 'reload schema';

COMMIT;
