-- Migration 20260727_068 — Parte 1 (SPEC-053)
-- Gera public.produtos.codigo_produto (integer, hoje sem DEFAULT, unique via
-- produtos_codigo_produto_key) automaticamente por sequence do Postgres.
--
-- Decisao do usuario (2026-07-27): sequence, nao RPC dedicada. Existem dois
-- caminhos de INSERT independentes em produtos — Cadastro
-- (cadastro-lucenera-b86fe, INSERT direto via services/produtos.ts
-- createProduto()) e Orcamentos (gestao-financeira-clone-544cb (1), via RPC
-- criar_produto_orcamento) — uma sequence com DEFAULT na coluna cobre os dois
-- automaticamente e qualquer INSERT futuro, sem depender de nenhum
-- codigo-fonte lembrar de chamar uma funcao auxiliar. Buracos na numeracao
-- (ex.: um INSERT que falha apos consumir um numero da sequence) sao
-- aceitaveis para o negocio.
--
-- setval(..., false) faz o PROXIMO nextval() retornar exatamente
-- MAX(codigo_produto)+1 (ou 1, se a tabela estiver vazia), sem pular um
-- numero logo na primeira chamada.

CREATE SEQUENCE IF NOT EXISTS public.produtos_codigo_produto_seq;

SELECT setval(
  'public.produtos_codigo_produto_seq',
  COALESCE((SELECT MAX(codigo_produto) FROM public.produtos), 0) + 1,
  false
);

ALTER TABLE public.produtos
  ALTER COLUMN codigo_produto SET DEFAULT nextval('public.produtos_codigo_produto_seq');

-- OWNED BY faz a sequence acompanhar o ciclo de vida da coluna (ex.: se a
-- coluna for removida no futuro, a sequence e removida junto).
ALTER SEQUENCE public.produtos_codigo_produto_seq OWNED BY public.produtos.codigo_produto;

-- Achado da revisao (2026-07-27): a coluna era nullable e o UNIQUE em Postgres
-- permite varios NULL. Sem NOT NULL, publicar o frontend novo (que parou de
-- enviar codigo_produto, confiando so no DEFAULT) antes desta migration --
-- ou qualquer outro caminho de INSERT que ainda envie codigo_produto = NULL
-- explicitamente -- gravaria produto com codigo_produto NULL silenciosamente,
-- quebrando casamento por codigo em buscas/import de XML sem nenhum erro.
-- Backfill defensivo (nao deveria encontrar nenhuma linha, mas protege contra
-- o ALTER falhar se existir algum NULL legado) + NOT NULL para que qualquer
-- INSERT fora de ordem falhe alto, com erro claro, em vez de gravar ausente.
UPDATE public.produtos
SET codigo_produto = nextval('public.produtos_codigo_produto_seq')
WHERE codigo_produto IS NULL;

ALTER TABLE public.produtos
  ALTER COLUMN codigo_produto SET NOT NULL;

COMMENT ON SEQUENCE public.produtos_codigo_produto_seq IS
  'SPEC-053. Gera produtos.codigo_produto automaticamente via DEFAULT nextval(...). '
  'Cobre tanto o INSERT direto do Cadastro quanto a RPC criar_produto_orcamento '
  'de Orcamentos. Buracos na numeracao sao aceitaveis (decisao do usuario, '
  '2026-07-27).';
