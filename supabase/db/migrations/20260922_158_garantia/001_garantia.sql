-- SPEC-156 Módulo 2 — Controle de Garantia.
--
-- Substitui a planilha manual do Matheus (que já nem existe mais - "nem
-- tem planilha mais", Vinícius, reunião 16/09/2026) por protocolos de
-- garantia por fornecedor com 6 status fixos + itens individuais.
--
-- Decisões do usuário (22/09/2026, ver SPEC-156 seção "Decisões do
-- usuário" no Módulo 2):
-- 1. Qualquer authenticated pode abrir um garantia_itens ("todos podem
--    pedir uma garantia"). O processo com o fornecedor (garantia_protocolos)
--    é conduzido por Vitória e Débora, mas SEM allowlist de RLS por
--    usuario_id, porque a Vitória não tem cadastro em `usuarios` hoje
--    (confirmado por SELECT antes desta migration) — travar por RLS
--    travaria a própria Vitória. responsavel_nome é texto livre
--    obrigatório, responsavel_id é FK nullable ("melhor esforço"), mesmo
--    padrão já usado no handoff do Módulo 1.
-- 2. Data de venda: cascata nota_fiscal -> orçamento -> vendas legado ->
--    manual, via função SECURITY DEFINER (ver abaixo), porque a tabela
--    notas_fiscais tem RLS restrita a quem tem o papel 'financeiro' no
--    Hub — ninguém do Garantia teria esse papel.
-- 3. Prazo de garantia fica editável por item (não vira tabela de
--    configuração), com um campo indicando se o prazo é da peça
--    específica ou do padrão do fornecedor.

CREATE TYPE public.garantia_protocolo_status AS ENUM (
    'em_contato_fornecedor',
    'nota_fiscal_emitida',
    'material_enviado',
    'aguardando_analise',
    'material_recebido',
    'finalizado'
);

CREATE TABLE public.garantia_protocolos (
    id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    fornecedor_id     uuid NOT NULL REFERENCES public.contatos(id),  -- contatos.tipo = 'fornecedor'
    responsavel_id    uuid REFERENCES public.usuarios(id),           -- nullable, "melhor esforço"
    responsavel_nome  text NOT NULL,                                 -- texto livre, normalmente Vitória ou Débora
    status            public.garantia_protocolo_status NOT NULL DEFAULT 'em_contato_fornecedor',
    desfecho          text CHECK (desfecho IN ('peca_nova', 'conserto', 'nao_acatado')),  -- só quando finalizado
    observacao        text,
    created_by        uuid REFERENCES public.usuarios(id),
    created_at        timestamptz NOT NULL DEFAULT now(),
    updated_at        timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.garantia_protocolos IS
  'SPEC-156 Módulo 2: protocolo de garantia com um fornecedor, agregando N garantia_itens. Conduzido normalmente por Vitória/Débora, sem allowlist de RLS (Vitória não tem login em usuarios hoje).';

CREATE INDEX idx_garantia_protocolos_fornecedor ON public.garantia_protocolos USING btree (fornecedor_id);
CREATE INDEX idx_garantia_protocolos_status ON public.garantia_protocolos USING btree (status);

CREATE TRIGGER garantia_protocolos_updated_at
    BEFORE UPDATE ON public.garantia_protocolos
    FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

ALTER TABLE public.garantia_protocolos ENABLE ROW LEVEL SECURITY;

CREATE POLICY garantia_protocolos_select ON public.garantia_protocolos
  FOR SELECT TO authenticated USING (true);

CREATE POLICY garantia_protocolos_insert ON public.garantia_protocolos
  FOR INSERT TO authenticated WITH CHECK (true);

CREATE POLICY garantia_protocolos_update ON public.garantia_protocolos
  FOR UPDATE TO authenticated USING (true);

CREATE TABLE public.garantia_itens (
    id                         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    fornecedor_id              uuid NOT NULL REFERENCES public.contatos(id),
    produto_id                 uuid REFERENCES public.produtos(id),   -- nullable, peça sem cadastro
    produto_descricao_livre    text,                                    -- fallback quando produto_id é NULL
    cliente_id                 uuid REFERENCES public.contatos(id),   -- nullable
    cliente_nome               text,                                    -- fallback texto livre
    orcamento_id               uuid REFERENCES public.orcamentos(id), -- nullable, opcional/informativo
    data_venda_referencia      date,
    data_venda_origem          text CHECK (data_venda_origem IN ('nota_fiscal', 'orcamento', 'vendas_legado', 'manual')),
    prazo_garantia_anos        numeric,
    prazo_garantia_referencia  text CHECK (prazo_garantia_referencia IN ('peca', 'fornecedor')),
    motivo                     text NOT NULL CHECK (motivo IN ('queimou', 'sobrecarga_mau_uso', 'envio_errado', 'producao_errada', 'outro')),
    atendimento                text NOT NULL CHECK (atendimento IN ('imediato', 'analise_fornecedor')),
    adiantamento               boolean NOT NULL DEFAULT false,
    peca_antiga_devolvida_em   date,                                    -- fecha a pendência do adiantamento
    garantia_protocolo_id      uuid REFERENCES public.garantia_protocolos(id),  -- nullable até ser agrupado
    quantidade                 numeric NOT NULL DEFAULT 1,
    observacao                 text,
    created_by                 uuid REFERENCES public.usuarios(id),
    created_at                 timestamptz NOT NULL DEFAULT now(),
    updated_at                 timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.garantia_itens IS
  'SPEC-156 Módulo 2: item individual de garantia (peça com defeito). Qualquer authenticated pode criar. Sem vínculo obrigatório com orcamentos/projeto_itens/estoque_itens (decisão explícita do Vinícius).';
COMMENT ON COLUMN public.garantia_itens.data_venda_origem IS
  'De onde veio data_venda_referencia: nota_fiscal (Focus NFe) > orcamento (aprovado) > vendas_legado (import Connect) > manual. Resolvido via garantia_resolver_data_venda().';
COMMENT ON COLUMN public.garantia_itens.prazo_garantia_referencia IS
  'Indica se prazo_garantia_anos veio de uma garantia específica da peça, ou do padrão geral do fornecedor.';

CREATE INDEX idx_garantia_itens_fornecedor ON public.garantia_itens USING btree (fornecedor_id);
CREATE INDEX idx_garantia_itens_protocolo ON public.garantia_itens USING btree (garantia_protocolo_id);
CREATE INDEX idx_garantia_itens_adiantamento_pendente ON public.garantia_itens (adiantamento) WHERE adiantamento = true AND peca_antiga_devolvida_em IS NULL;

CREATE TRIGGER garantia_itens_updated_at
    BEFORE UPDATE ON public.garantia_itens
    FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

ALTER TABLE public.garantia_itens ENABLE ROW LEVEL SECURITY;

CREATE POLICY garantia_itens_select ON public.garantia_itens
  FOR SELECT TO authenticated USING (true);

CREATE POLICY garantia_itens_insert ON public.garantia_itens
  FOR INSERT TO authenticated WITH CHECK (true);

CREATE POLICY garantia_itens_update ON public.garantia_itens
  FOR UPDATE TO authenticated USING (true);

-- Função de resolução da data de venda (cascata nota_fiscal -> orçamento
-- -> vendas legado -> manual). SECURITY DEFINER porque notas_fiscais tem
-- RLS restrita ao papel 'financeiro' do Hub (spec069_notas_fiscais_select
-- exige hub_pode_executar(..., 'financeiro', ..., 'visualizar')) e
-- ninguém do Garantia teria esse papel. Devolve só a data + a origem,
-- nunca valores financeiros da nota/orçamento.
CREATE OR REPLACE FUNCTION public.garantia_resolver_data_venda(
    p_cliente_id uuid,
    p_produto_id uuid
)
RETURNS TABLE(data_venda date, origem text)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_data date;
BEGIN
    IF p_cliente_id IS NULL OR p_produto_id IS NULL THEN
        RETURN;
    END IF;

    -- 1) Nota fiscal autorizada (Focus NFe) mais recente, via itens da
    -- nota -> item do orçamento -> orçamento do cliente informado.
    SELECT MAX(nf.data_emissao) INTO v_data
    FROM notas_fiscais nf
    JOIN notas_fiscais_itens nfi ON nfi.nota_fiscal_id = nf.id
    JOIN orcamento_itens oi ON oi.id = nfi.orcamento_item_id
    JOIN orcamentos o ON o.id = oi.orcamento_id
    WHERE nf.status_emissao = 'autorizado'
      AND o.cliente_id = p_cliente_id
      AND oi.produto_id = p_produto_id;

    IF v_data IS NOT NULL THEN
        RETURN QUERY SELECT v_data, 'nota_fiscal'::text;
        RETURN;
    END IF;

    -- 2) Orçamento aprovado pelo cliente, com o produto no orçamento.
    SELECT MAX(o.aprovado_cliente_em::date) INTO v_data
    FROM orcamentos o
    JOIN orcamento_itens oi ON oi.orcamento_id = o.id
    WHERE o.cliente_id = p_cliente_id
      AND oi.produto_id = p_produto_id
      AND o.aprovado_cliente_em IS NOT NULL;

    IF v_data IS NOT NULL THEN
        RETURN QUERY SELECT v_data, 'orcamento'::text;
        RETURN;
    END IF;

    -- 3) Venda legada (import Connect) — sem FK formal pra contatos,
    -- casa pelo nome do cliente.
    SELECT MAX(v.data_emissao) INTO v_data
    FROM vendas v
    JOIN contatos c ON c.id = p_cliente_id
    WHERE v.produto_id = p_produto_id
      AND v.nome_cliente ILIKE '%' || c.nome || '%';

    IF v_data IS NOT NULL THEN
        RETURN QUERY SELECT v_data, 'vendas_legado'::text;
        RETURN;
    END IF;

    -- 4) Nada encontrado — UI cai pra preenchimento manual.
    RETURN;
END;
$$;

COMMENT ON FUNCTION public.garantia_resolver_data_venda(uuid, uuid) IS
  'SPEC-156 Módulo 2: resolve a data de venda de um produto pra um cliente, em cascata (nota_fiscal > orcamento > vendas_legado). SECURITY DEFINER pra contornar a RLS financeira de notas_fiscais — devolve só data e origem.';

GRANT EXECUTE ON FUNCTION public.garantia_resolver_data_venda(uuid, uuid) TO authenticated;

-- Bucket de Storage pra futuros anexos (nota fiscal do fornecedor, fotos
-- da peça com defeito) — pendência em aberto na SPEC se vai ser usado
-- nesta fase, mas o bucket já fica criado (mesmo padrão de
-- producao_pedidos: público pra leitura, authenticated pra upload).
INSERT INTO storage.buckets (id, name, public)
VALUES ('garantia_anexos', 'garantia_anexos', true)
ON CONFLICT (id) DO NOTHING;

CREATE POLICY garantia_anexos_storage_read ON storage.objects
  FOR SELECT USING (bucket_id = 'garantia_anexos');

CREATE POLICY garantia_anexos_storage_insert ON storage.objects
  FOR INSERT TO authenticated WITH CHECK (bucket_id = 'garantia_anexos');
