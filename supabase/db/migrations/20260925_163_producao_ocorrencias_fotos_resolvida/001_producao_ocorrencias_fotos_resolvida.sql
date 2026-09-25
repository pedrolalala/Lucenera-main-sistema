-- SPEC-162 (revisão 25/09/2026) — decisões do usuário sobre as ocorrências:
--   * "pode ter foto sim"            -> fotos_urls (0..N fotos, bucket producao_pedidos)
--   * "colocar esse campo de resolvida e marcar a data de quando isso
--      aconteceu"                     -> resolvida_em (date) + resolvido_por
--   * tipo: os 3 fixos + campo aberto -> sem mudança de banco (categoria já é
--     text livre; "Outro" grava o texto digitado).
--
-- Deixa de ser append-only: a aplicação agora precisa de UPDATE, mas SÓ nas
-- colunas de resolução. Em vez de liberar UPDATE na linha inteira, restringe
-- por GRANT de coluna — categoria/descricao/registrado_* continuam imutáveis
-- pra authenticated. DELETE fica bloqueado (não há policy de DELETE).
--
-- Tabela tem 0 linhas em 25/09/2026 (confirmado antes da migration).

BEGIN;

ALTER TABLE public.producao_pedido_ocorrencias
  ADD COLUMN fotos_urls    text[] NOT NULL DEFAULT '{}',
  ADD COLUMN resolvida_em  date,
  ADD COLUMN resolvido_por uuid REFERENCES public.usuarios(id);

COMMENT ON COLUMN public.producao_pedido_ocorrencias.resolvida_em IS
  'SPEC-162: data em que a ocorrência foi resolvida (informada pelo usuário). NULL = em aberto.';

REVOKE UPDATE ON public.producao_pedido_ocorrencias FROM anon, authenticated;
GRANT UPDATE (resolvida_em, resolvido_por) ON public.producao_pedido_ocorrencias TO authenticated;

CREATE POLICY producao_pedido_ocorrencias_update ON public.producao_pedido_ocorrencias
  FOR UPDATE TO authenticated USING (true) WITH CHECK (true);

NOTIFY pgrst, 'reload schema';

COMMIT;
