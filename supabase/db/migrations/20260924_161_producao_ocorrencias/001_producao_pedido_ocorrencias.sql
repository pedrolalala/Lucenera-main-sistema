-- SPEC-162 — Controle de Produção: registro de ocorrências por pedido.
--
-- Preenchido pela produção em situações como desenho errado, desenho
-- incompleto, retrabalho de peça pronta etc. Pode ser registrado em
-- qualquer status do pedido (em andamento OU já concluído/pronto) — por
-- isso não há nenhuma checagem de status aqui nem no frontend.
--
-- Histórico append-only (sem UPDATE/DELETE pela aplicação): cada
-- ocorrência é um registro de fato, com quem registrou + quando.
--
-- Depende de: 20260922_157_producao_pedidos (tabela producao_pedidos).
-- Independente das migrations da SPEC-161 (20260923_160_*).

BEGIN;

CREATE TABLE public.producao_pedido_ocorrencias (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    producao_pedido_id  uuid NOT NULL REFERENCES public.producao_pedidos(id) ON DELETE CASCADE,
    -- Texto livre no banco (mesmo padrão de producao_pedidos.status): a
    -- lista de categorias fica no frontend, dá pra acrescentar categoria
    -- nova sem migration. Valores iniciais: desenho_errado,
    -- desenho_incompleto, retrabalho_peca_pronta, outro.
    categoria           text NOT NULL CHECK (btrim(categoria) <> ''),
    descricao           text NOT NULL CHECK (btrim(descricao) <> ''),
    registrado_por      uuid REFERENCES public.usuarios(id),
    registrado_em       timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.producao_pedido_ocorrencias IS
  'SPEC-162: ocorrências registradas pela produção num pedido (desenho errado, desenho incompleto, retrabalho de peça pronta, outro). Permitido em qualquer status do pedido, inclusive pronto. Append-only.';

CREATE INDEX idx_producao_pedido_ocorrencias_pedido ON public.producao_pedido_ocorrencias USING btree (producao_pedido_id);

ALTER TABLE public.producao_pedido_ocorrencias ENABLE ROW LEVEL SECURITY;

CREATE POLICY producao_pedido_ocorrencias_select ON public.producao_pedido_ocorrencias
  FOR SELECT TO authenticated USING (true);

CREATE POLICY producao_pedido_ocorrencias_insert ON public.producao_pedido_ocorrencias
  FOR INSERT TO authenticated WITH CHECK (true);

COMMIT;
