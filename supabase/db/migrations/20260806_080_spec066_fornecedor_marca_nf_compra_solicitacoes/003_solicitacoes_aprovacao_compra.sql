-- SPEC-066 Frente F: aba "Solicitações" = "Aprovar Necessidade de
-- Compra" no desenho da Débora (Reunião.02/04). É um passo OPCIONAL
-- entre "escolher o que comprar" (Necessidade de Compra, que soma todas
-- as empresas) e "efetivar o pedido" -- coexiste com o atalho direto
-- "Fechar Pedido em Lote" já existente (SPEC-030/057), não o substitui
-- (P-F2).
--
-- NOME: "solicitacoes_compra" já existe no banco com outro propósito —
-- é um log interno criado *junto* com o pedido por
-- criar_pedido_compra_de_necessidade()/criar_pedido_compra_lote()
-- (status sempre 'pedido_gerado', 14 linhas hoje), não uma fila de
-- aprovação PRÉVIA ao pedido. Por isso esta tabela nova tem nome
-- diferente, para não colidir nem ser confundida com aquela.
--
-- fornecedor_id aqui referencia public.contatos (não public.fornecedores,
-- que existe mas está vazia/não usada — ver 001 desta mesma migration
-- para o achado completo).
--
-- Status v1: aguardando_aprovar -> aprovado/rejeitado. "confirmado" fica
-- previsto no CHECK (fluxo de 2 pessoas, só ativado se um dia existir um
-- segundo responsável de compras -- P-F1) mas a UI do v1 não usa.

CREATE TABLE public.solicitacoes_aprovacao_compra (
    id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    produto_id uuid NOT NULL REFERENCES public.produtos(id),
    marca_id uuid REFERENCES public.marcas(id),
    fornecedor_id uuid REFERENCES public.contatos(id),
    empresa_id uuid REFERENCES public.empresas(id),
    perfil text,
    quantidade numeric(12,3) NOT NULL,
    custo_unitario numeric(12,2),
    cliente_id uuid REFERENCES public.contatos(id),
    condicao_pagamento text,
    data_prevista_entrega date,
    observacao text,
    status text DEFAULT 'aguardando_aprovar' NOT NULL,
    pedido_compra_id uuid REFERENCES public.pedidos_compra(id),
    motivo_rejeicao text,
    criado_por uuid REFERENCES public.usuarios(id),
    criado_em timestamp with time zone DEFAULT now() NOT NULL,
    atualizado_em timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT solicitacoes_aprovacao_compra_status_check
      CHECK (status IN ('aguardando_aprovar', 'confirmado', 'aprovado', 'rejeitado')),
    CONSTRAINT solicitacoes_aprovacao_compra_perfil_check
      CHECK (perfil IS NULL OR perfil = ANY (ARRAY['ribeirao', 'sao_paulo'])),
    CONSTRAINT solicitacoes_aprovacao_compra_quantidade_check CHECK (quantidade > 0)
);

COMMENT ON TABLE public.solicitacoes_aprovacao_compra IS
  'SPEC-066: passo opcional de aprovação entre Necessidade de Compra e Pedido de Compra (aba "Solicitações"). Não confundir com public.solicitacoes_compra (log interno criado junto do pedido). Aprovar gera um pedidos_compra via criar_pedido_compra_de_necessidade(); rejeitar só muda o status (item volta pra Necessidade de Compra).';

CREATE INDEX idx_solicitacoes_aprovacao_compra_status ON public.solicitacoes_aprovacao_compra USING btree (status);
CREATE INDEX idx_solicitacoes_aprovacao_compra_produto ON public.solicitacoes_aprovacao_compra USING btree (produto_id);

CREATE TRIGGER solicitacoes_aprovacao_compra_updated_at
    BEFORE UPDATE ON public.solicitacoes_aprovacao_compra
    FOR EACH ROW EXECUTE FUNCTION public.fn_atualiza_updated_at();

ALTER TABLE public.solicitacoes_aprovacao_compra ENABLE ROW LEVEL SECURITY;

CREATE POLICY solicitacoes_aprovacao_compra_select ON public.solicitacoes_aprovacao_compra
  FOR SELECT TO authenticated USING (true);

CREATE POLICY solicitacoes_aprovacao_compra_insert ON public.solicitacoes_aprovacao_compra
  FOR INSERT TO authenticated WITH CHECK (true);

-- Update direto só é usado para editar campos enquanto está
-- aguardando_aprovar (empresa/perfil/quantidade/condição) e para
-- rejeitar (rejeitar não tem efeito colateral, não precisa de RPC).
-- Aprovar SEMPRE passa pela RPC aprovar_solicitacao_compra, porque tem
-- efeito colateral (cria pedido_compra) -- por isso a policy de UPDATE
-- não permite mudar status pra 'aprovado' direto via RLS; a RPC roda
-- como SECURITY DEFINER.
CREATE POLICY solicitacoes_aprovacao_compra_update ON public.solicitacoes_aprovacao_compra
  FOR UPDATE TO authenticated
  USING (status = 'aguardando_aprovar')
  WITH CHECK (status IN ('aguardando_aprovar', 'rejeitado'));

CREATE OR REPLACE FUNCTION public.aprovar_solicitacao_compra(
    p_solicitacao_id uuid,
    p_custo_unitario numeric DEFAULT NULL,
    p_numero text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
    v_sol public.solicitacoes_aprovacao_compra;
    v_pedido_id uuid;
    v_custo numeric;
BEGIN
    SELECT * INTO v_sol FROM public.solicitacoes_aprovacao_compra WHERE id = p_solicitacao_id FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Solicitação não encontrada' USING ERRCODE = 'P0002';
    END IF;

    IF v_sol.status != 'aguardando_aprovar' AND v_sol.status != 'confirmado' THEN
        RAISE EXCEPTION 'Solicitação já foi % — não pode ser aprovada novamente', v_sol.status
            USING ERRCODE = 'P0003';
    END IF;

    IF v_sol.fornecedor_id IS NULL THEN
        RAISE EXCEPTION 'Solicitação sem fornecedor definido — resolva o fornecedor pela marca antes de aprovar'
            USING ERRCODE = 'P0003';
    END IF;

    v_custo := COALESCE(p_custo_unitario, v_sol.custo_unitario);
    IF v_custo IS NULL THEN
        RAISE EXCEPTION 'Informe o custo unitário para gerar o pedido' USING ERRCODE = 'P0003';
    END IF;

    v_pedido_id := (public.criar_pedido_compra_de_necessidade(
        p_produto_id := v_sol.produto_id,
        p_fornecedor_id := v_sol.fornecedor_id,
        p_quantidade := v_sol.quantidade,
        p_custo_unitario := v_custo,
        p_numero := p_numero,
        p_data_prevista_entrega := v_sol.data_prevista_entrega,
        p_condicoes_pagamento := v_sol.condicao_pagamento,
        p_observacao := v_sol.observacao,
        p_empresa_id := v_sol.empresa_id,
        p_perfil := v_sol.perfil
    )->>'pedido_id')::uuid;

    UPDATE public.solicitacoes_aprovacao_compra
    SET status = 'aprovado',
        pedido_compra_id = v_pedido_id
    WHERE id = p_solicitacao_id;

    RETURN jsonb_build_object('pedido_compra_id', v_pedido_id);
END;
$function$;

COMMENT ON FUNCTION public.aprovar_solicitacao_compra IS
  'SPEC-066: aprova uma linha de solicitacoes_aprovacao_compra, gerando o pedido_compra via criar_pedido_compra_de_necessidade(). SECURITY DEFINER porque tem efeito colateral (cria pedido).';

CREATE OR REPLACE FUNCTION public.rejeitar_solicitacao_compra(
    p_solicitacao_id uuid,
    p_motivo text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
BEGIN
    UPDATE public.solicitacoes_aprovacao_compra
    SET status = 'rejeitado',
        motivo_rejeicao = p_motivo
    WHERE id = p_solicitacao_id
      AND status IN ('aguardando_aprovar', 'confirmado');

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Solicitação não encontrada ou já processada' USING ERRCODE = 'P0002';
    END IF;
END;
$function$;
