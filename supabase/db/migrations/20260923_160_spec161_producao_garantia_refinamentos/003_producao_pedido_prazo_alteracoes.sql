-- SPEC-161 Prioridade 8 — Controle de Produção: rastrear alteração de
-- prazo, com justificativa obrigatória.
--
-- Cenário descrito pelo Vinícius: o prazo já foi definido, mas algo impede
-- o cumprimento ("deu algum B.O.") e precisa ser adiado. Toda vez que
-- data_prazo mudar depois de já ter sido definida, o frontend exige uma
-- justificativa (texto livre) antes de salvar. Histórico completo (mais de
-- uma alteração possível no mesmo pedido), não só "motivo mais recente".

BEGIN;

CREATE TABLE public.producao_pedido_prazo_alteracoes (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    producao_pedido_id  uuid NOT NULL REFERENCES public.producao_pedidos(id) ON DELETE CASCADE,
    prazo_anterior      date,
    prazo_novo          date,
    motivo              text NOT NULL,
    alterado_por        uuid REFERENCES public.usuarios(id),
    alterado_em         timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.producao_pedido_prazo_alteracoes IS
  'SPEC-161 Prioridade 8: histórico de alteração de data_prazo de um pedido de produção, com justificativa obrigatória (motivo). Exigido pelo frontend sempre que data_prazo mudar depois de já definida.';

CREATE INDEX idx_producao_pedido_prazo_alteracoes_pedido ON public.producao_pedido_prazo_alteracoes USING btree (producao_pedido_id);

ALTER TABLE public.producao_pedido_prazo_alteracoes ENABLE ROW LEVEL SECURITY;

CREATE POLICY producao_pedido_prazo_alteracoes_select ON public.producao_pedido_prazo_alteracoes
  FOR SELECT TO authenticated USING (true);

CREATE POLICY producao_pedido_prazo_alteracoes_insert ON public.producao_pedido_prazo_alteracoes
  FOR INSERT TO authenticated WITH CHECK (true);

COMMIT;
