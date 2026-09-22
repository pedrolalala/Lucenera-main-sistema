-- SPEC-156 Módulo 1 — Controle de Produção.
--
-- Réplica digital da planilha "CONTROLE DE PRODUÇÃO (1).xlsx" (3 abas:
-- LINEAS E STECCAS / PEÇAS AVULSAS / CORTES (GAP - SLOT - VISTA)) +
-- gestão de status em tempo real + handoff com dupla assinatura
-- (quem entrega / quem recebe), que resolveu a "bucha" de responsabilidade
-- descrita pelo Vinícius (implantado em papel na semana anterior à
-- reunião de 16/09/2026, nunca existiu na planilha).
--
-- Decisão explícita (Vinícius, reunião 16/09): SEM vínculo com
-- orcamentos/projeto_itens/estoque_itens/venda nesta fase. cliente_nome e
-- arquiteto_nome ficam como texto livre (sem cadastro formal hoje).
-- empresa_id é FK real porque os 5 valores da coluna EMPRESA da planilha
-- batem com empresas.nome já cadastradas (LUCENERA/ISLIGHT/FOCO/CONNECT/
-- CITEL).
--
-- status é texto livre, SEM CHECK constraint: a planilha real confirma dado
-- sujo (PRONTO/Pronto/PRONTA, mais CANCELADO/EXCLUÍDO/ENTRADA PARCIAL
-- soltos) e o próprio Vinícius descreveu o status como algo vivo, digitado
-- em tempo real pelo João ("em andamento", "aguardando pintura", "com o
-- Cunha" etc.) — lista de sugestões fica só na UI.

CREATE TABLE public.producao_pedidos (
    id                 uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    tipo_peca          text NOT NULL
        CHECK (tipo_peca IN ('lineas_steccas', 'peca_avulsa', 'corte')),
    numero_pedido      text,           -- nullable: aba CORTES não tem número de pedido
    data_pedido        date NOT NULL,  -- "DATA" (1ª coluna)
    empresa_id         uuid NOT NULL REFERENCES public.empresas(id),
    sistema_origem     text,           -- só usado quando tipo_peca = 'lineas_steccas'
    arquiteto_nome     text,           -- "ARQUITETA (O)", texto livre (sem cadastro formal hoje)
    cliente_nome       text,           -- texto livre, SEM FK (decisão: sem vínculo com venda)
    data_prazo         date,           -- "PRAZO" = data prevista de entrega
    prioridade         text NOT NULL DEFAULT 'normal'
        CHECK (prioridade IN ('normal', 'alta', 'urgente')),  -- coluna "NORMAL" na planilha
    status             text NOT NULL DEFAULT 'em_andamento',  -- texto livre, sem CHECK (ver acima)
    data_ficou_pronto  date,           -- 2ª coluna "DATA"/"ENTREGA" na planilha
    observacao         text,
    pdf_pedido_url     text,           -- Storage bucket producao_pedidos
    pdf_desenho_url    text,           -- Storage bucket producao_pedidos
    created_by         uuid REFERENCES public.usuarios(id),
    created_at         timestamptz NOT NULL DEFAULT now(),
    updated_at         timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.producao_pedidos IS
  'SPEC-156 Módulo 1: réplica digital da planilha de pedidos de produção interna (Lineas/Steccas, Peças Avulsas, Cortes). Sem vínculo com orcamentos/projeto_itens/estoque_itens (decisão explícita do Vinícius, reunião 16/09/2026).';
COMMENT ON COLUMN public.producao_pedidos.tipo_peca IS
  '1 por aba real da planilha: lineas_steccas / peca_avulsa / corte.';
COMMENT ON COLUMN public.producao_pedidos.numero_pedido IS
  'Nullable: a aba CORTES (GAP - SLOT - VISTA) nunca teve coluna PEDIDO.';
COMMENT ON COLUMN public.producao_pedidos.sistema_origem IS
  'Texto livre (LUCENERA/CONNECT/FOCO/ISLIGHT/CITEL), só existia na aba LINEAS E STECCAS da planilha.';
COMMENT ON COLUMN public.producao_pedidos.status IS
  'Texto livre sem CHECK — dado real da planilha é sujo (PRONTO/Pronto/PRONTA + CANCELADO/EXCLUÍDO/ENTRADA PARCIAL). UI sugere: em_andamento, aguardando_pintura, com_terceiro, pronto, entrada_parcial, cancelado, excluido.';

CREATE INDEX idx_producao_pedidos_tipo_peca ON public.producao_pedidos USING btree (tipo_peca);
CREATE INDEX idx_producao_pedidos_status ON public.producao_pedidos USING btree (status);
CREATE INDEX idx_producao_pedidos_empresa ON public.producao_pedidos USING btree (empresa_id);
CREATE INDEX idx_producao_pedidos_data_pedido ON public.producao_pedidos USING btree (data_pedido);

CREATE TRIGGER producao_pedidos_updated_at
    BEFORE UPDATE ON public.producao_pedidos
    FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

ALTER TABLE public.producao_pedidos ENABLE ROW LEVEL SECURITY;

-- Leitura ampla para authenticated ("para que todos consigam consultar",
-- elimina a ligação Débora->Cláudio) e escrita para authenticated também
-- (sem regra de dono/criador nesta fase — times de estoque/produção
-- compartilham o mesmo fluxo, mesmo padrão de notas_fiscais_compra).
CREATE POLICY producao_pedidos_select ON public.producao_pedidos
  FOR SELECT TO authenticated USING (true);

CREATE POLICY producao_pedidos_insert ON public.producao_pedidos
  FOR INSERT TO authenticated WITH CHECK (true);

CREATE POLICY producao_pedidos_update ON public.producao_pedidos
  FOR UPDATE TO authenticated USING (true);

-- Handoff com dupla assinatura: reproduz o processo implantado em papel
-- (não existe, nunca existiu, na planilha) para resolver a "bucha" de
-- responsabilidade quando some peça. entregue_por_nome/recebido_por_nome
-- são NOT NULL — os *_usuario_id ficam nullable porque ainda não está
-- confirmado se todo funcionário citado (Cláudio/João/Manoel/Antônio/
-- Leandro/Alexandre/Matheus) tem login em usuarios/Supabase Auth
-- (pendência aberta na SPEC-156).

CREATE TABLE public.producao_pedido_handoffs (
    id                       uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    producao_pedido_id       uuid NOT NULL REFERENCES public.producao_pedidos(id) ON DELETE CASCADE,
    entregue_por_usuario_id  uuid REFERENCES public.usuarios(id),
    entregue_por_nome        text NOT NULL,
    recebido_por_usuario_id  uuid REFERENCES public.usuarios(id),
    recebido_por_nome        text NOT NULL,
    data_hora                timestamptz NOT NULL DEFAULT now(),
    observacao               text,
    created_at               timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.producao_pedido_handoffs IS
  'SPEC-156 Módulo 1: registro de handoff (quem entrega / quem recebe) de um pedido de produção. Aditivo — não existe/nunca existiu na planilha Excel de origem. Um handoff só é salvo com os dois lados preenchidos (validado no frontend).';

CREATE INDEX idx_producao_pedido_handoffs_pedido ON public.producao_pedido_handoffs USING btree (producao_pedido_id);

ALTER TABLE public.producao_pedido_handoffs ENABLE ROW LEVEL SECURITY;

CREATE POLICY producao_pedido_handoffs_select ON public.producao_pedido_handoffs
  FOR SELECT TO authenticated USING (true);

CREATE POLICY producao_pedido_handoffs_insert ON public.producao_pedido_handoffs
  FOR INSERT TO authenticated WITH CHECK (true);

-- Bucket de storage para os 2 PDFs (pedido + desenho) por producao_pedidos.id
-- -- mesmo padrão do bucket "notas_fiscais_compra" já em uso no mesmo
-- sistema (compras-lucenera-3o23t98ee): público para leitura, authenticated
-- para upload.
INSERT INTO storage.buckets (id, name, public)
VALUES ('producao_pedidos', 'producao_pedidos', true)
ON CONFLICT (id) DO NOTHING;

CREATE POLICY producao_pedidos_storage_read ON storage.objects
  FOR SELECT USING (bucket_id = 'producao_pedidos');

CREATE POLICY producao_pedidos_storage_insert ON storage.objects
  FOR INSERT TO authenticated WITH CHECK (bucket_id = 'producao_pedidos');
