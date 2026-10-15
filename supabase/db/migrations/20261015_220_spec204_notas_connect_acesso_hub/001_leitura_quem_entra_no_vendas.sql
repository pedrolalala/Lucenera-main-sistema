-- SPEC-204 (15/10/2026): a 219 liberou a leitura só por Acesso a Sistemas (user_system_access), mas o
-- Vendas deixa entrar quem o Hub libera (hub_pode_executar(uid, 'vendas', null, null), use-auth.tsx).
-- Resultado: quem entra no Vendas pelo Hub (ex.: admin) via a aba vazia. Agora vale qualquer um dos dois.
BEGIN;

DROP POLICY IF EXISTS notas_fiscais_connect_select ON public.notas_fiscais_connect;
DROP POLICY IF EXISTS notas_fiscais_connect_itens_select ON public.notas_fiscais_connect_itens;
DROP POLICY IF EXISTS notas_fiscais_connect_duplicatas_select ON public.notas_fiscais_connect_duplicatas;
DROP POLICY IF EXISTS notas_fiscais_connect_eventos_select ON public.notas_fiscais_connect_eventos;

CREATE POLICY notas_fiscais_connect_select ON public.notas_fiscais_connect
  FOR SELECT TO authenticated USING (
    (SELECT public.pode_acessar_sistema('vendas'))
    OR (SELECT public.hub_pode_executar((SELECT auth.uid()), 'vendas', NULL, NULL)));
CREATE POLICY notas_fiscais_connect_itens_select ON public.notas_fiscais_connect_itens
  FOR SELECT TO authenticated USING (
    (SELECT public.pode_acessar_sistema('vendas'))
    OR (SELECT public.hub_pode_executar((SELECT auth.uid()), 'vendas', NULL, NULL)));
CREATE POLICY notas_fiscais_connect_duplicatas_select ON public.notas_fiscais_connect_duplicatas
  FOR SELECT TO authenticated USING (
    (SELECT public.pode_acessar_sistema('vendas'))
    OR (SELECT public.hub_pode_executar((SELECT auth.uid()), 'vendas', NULL, NULL)));
CREATE POLICY notas_fiscais_connect_eventos_select ON public.notas_fiscais_connect_eventos
  FOR SELECT TO authenticated USING (
    (SELECT public.pode_acessar_sistema('vendas'))
    OR (SELECT public.hub_pode_executar((SELECT auth.uid()), 'vendas', NULL, NULL)));

COMMIT;
