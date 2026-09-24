-- SPEC-161 Prioridade 4 — Controle de Produção: editar pedido depois de
-- criado, com trilha de auditoria.
--
-- Decisão do usuário (22/09/2026): sem restrição de quem pode editar
-- (qualquer usuário logado), mas toda edição precisa ficar registrada
-- (quem + quando, via usuário logado) — trilha de auditoria, não controle
-- de permissão. Histórico completo (mais de uma edição possível), não só
-- "última edição".
--
-- Mantida como tabela separada de producao_pedido_prazo_alteracoes
-- (Prioridade 8): esta aqui é um log genérico "quem editou o pedido e
-- quando" (sem diff campo a campo, que não foi pedido); a de prazo é
-- estruturada (prazo_anterior/prazo_novo/motivo obrigatório) porque tem
-- uma regra de negócio própria (justificativa obrigatória). Unificar as
-- duas num mecanismo genérico só complicaria sem necessidade real hoje.

BEGIN;

CREATE TABLE public.producao_pedido_edicoes (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    producao_pedido_id  uuid NOT NULL REFERENCES public.producao_pedidos(id) ON DELETE CASCADE,
    editado_por         uuid REFERENCES public.usuarios(id),
    editado_em          timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.producao_pedido_edicoes IS
  'SPEC-161 Prioridade 4: trilha de auditoria de edição de um pedido de produção (quem + quando), histórico completo. Sem restrição de quem pode editar — qualquer authenticated.';

CREATE INDEX idx_producao_pedido_edicoes_pedido ON public.producao_pedido_edicoes USING btree (producao_pedido_id);

ALTER TABLE public.producao_pedido_edicoes ENABLE ROW LEVEL SECURITY;

CREATE POLICY producao_pedido_edicoes_select ON public.producao_pedido_edicoes
  FOR SELECT TO authenticated USING (true);

CREATE POLICY producao_pedido_edicoes_insert ON public.producao_pedido_edicoes
  FOR INSERT TO authenticated WITH CHECK (true);

COMMIT;
