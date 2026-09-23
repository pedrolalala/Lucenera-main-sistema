-- SPEC-158 (P2.3): registra quem DIGITOU o orçamento, separado de quem é o
-- vendedor (orcamentos.vendedor_id, lista fixa de 5 pessoas, SPEC-140).
-- Decisão do usuário na reunião de 22/09/2026: "é direto do login, que é o
-- seu melhor, porque senão aqui qualquer um pode pôr qualquer um" -- não é
-- campo editável, é capturado automaticamente no momento da criação do
-- orçamento a partir do usuário autenticado.
--
-- Referencia public.usuarios(id) (não auth.users(id) direto, diferente de
-- orcamentos.enviado_cliente_por) de propósito: usuarios.id já é FK 1:1 pra
-- auth.users(id) (ON DELETE CASCADE, confirmado via pg_constraint), e essa
-- escolha permite um embed direto do PostgREST (`digitador:usuarios(nome)`)
-- pra resolver o nome de exibição, no mesmo padrão já usado pra
-- `vendedor:funcionarios!orcamentos_vendedor_id_fkey(nome)` na Edge
-- Function generate-report.
--
-- ON DELETE SET NULL (não CASCADE): apagar o usuário não deve apagar o
-- orçamento histórico, só perder a referência de quem digitou.

BEGIN;

ALTER TABLE public.orcamentos
  ADD COLUMN digitado_por uuid REFERENCES public.usuarios(id) ON DELETE SET NULL;

COMMENT ON COLUMN public.orcamentos.digitado_por IS
  'SPEC-158 (P2.3). Usuário que criou o orçamento (auth.uid() capturado automaticamente na criação, nunca editável pela UI). Distinto de vendedor_id (SPEC-140, lista fixa de vendedores).';

NOTIFY pgrst, 'reload schema';

COMMIT;
