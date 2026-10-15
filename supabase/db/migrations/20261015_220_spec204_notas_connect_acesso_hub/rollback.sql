-- Volta à regra da 219 (só Acesso a Sistemas).
BEGIN;
DROP POLICY IF EXISTS notas_fiscais_connect_select ON public.notas_fiscais_connect;
DROP POLICY IF EXISTS notas_fiscais_connect_itens_select ON public.notas_fiscais_connect_itens;
DROP POLICY IF EXISTS notas_fiscais_connect_duplicatas_select ON public.notas_fiscais_connect_duplicatas;
DROP POLICY IF EXISTS notas_fiscais_connect_eventos_select ON public.notas_fiscais_connect_eventos;
CREATE POLICY notas_fiscais_connect_select ON public.notas_fiscais_connect
  FOR SELECT TO authenticated USING ((SELECT public.pode_acessar_sistema('vendas')));
CREATE POLICY notas_fiscais_connect_itens_select ON public.notas_fiscais_connect_itens
  FOR SELECT TO authenticated USING ((SELECT public.pode_acessar_sistema('vendas')));
CREATE POLICY notas_fiscais_connect_duplicatas_select ON public.notas_fiscais_connect_duplicatas
  FOR SELECT TO authenticated USING ((SELECT public.pode_acessar_sistema('vendas')));
CREATE POLICY notas_fiscais_connect_eventos_select ON public.notas_fiscais_connect_eventos
  FOR SELECT TO authenticated USING ((SELECT public.pode_acessar_sistema('vendas')));
COMMIT;
