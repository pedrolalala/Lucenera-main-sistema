-- SPEC-161 Prioridade 3 — Controle de Produção: anexar múltiplos desenhos
-- por pedido, editável a qualquer momento (não só na criação).
--
-- Causa raiz (confirmada lendo producao_pedidos real no Supabase):
-- pdf_desenho_url é uma coluna text única — cada upload novo sobrescrevia o
-- anterior. Decisão do usuário (22/09/2026): "anexar os 6 arquivos!" —
-- anexos separados, não um PDF único fundido.
--
-- pdf_desenho_url (e pdf_pedido_url) NÃO são removidas/migradas aqui: a
-- reunião só pediu múltiplos "desenhos", nunca deixou explícito se
-- pdf_pedido_url (o pedido em si) também devia virar múltiplo — fica como
-- está (1 arquivo), e um desenho antigo já salvo em pdf_desenho_url
-- continua acessível/exibido normalmente. producao_pedido_anexos é só para
-- os anexos novos, adicionados a partir desta SPEC.

BEGIN;

CREATE TABLE public.producao_pedido_anexos (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    producao_pedido_id  uuid NOT NULL REFERENCES public.producao_pedidos(id) ON DELETE CASCADE,
    url                 text NOT NULL,
    nome_arquivo        text,
    criado_em           timestamptz NOT NULL DEFAULT now(),
    criado_por          uuid REFERENCES public.usuarios(id)
);

COMMENT ON TABLE public.producao_pedido_anexos IS
  'SPEC-161 Prioridade 3: anexos (desenhos) de um pedido de produção, N por pedido, editável a qualquer momento (adicionar/remover). Substitui, para anexos novos, a coluna única producao_pedidos.pdf_desenho_url (mantida por compatibilidade com desenhos já salvos antes desta SPEC).';

CREATE INDEX idx_producao_pedido_anexos_pedido ON public.producao_pedido_anexos USING btree (producao_pedido_id);

ALTER TABLE public.producao_pedido_anexos ENABLE ROW LEVEL SECURITY;

-- Mesmo padrão de RLS aberta de producao_pedidos/producao_pedido_handoffs
-- (leitura/escrita ampla para authenticated, sem regra de dono/criador
-- nesta fase).
CREATE POLICY producao_pedido_anexos_select ON public.producao_pedido_anexos
  FOR SELECT TO authenticated USING (true);

CREATE POLICY producao_pedido_anexos_insert ON public.producao_pedido_anexos
  FOR INSERT TO authenticated WITH CHECK (true);

CREATE POLICY producao_pedido_anexos_delete ON public.producao_pedido_anexos
  FOR DELETE TO authenticated USING (true);

COMMIT;
