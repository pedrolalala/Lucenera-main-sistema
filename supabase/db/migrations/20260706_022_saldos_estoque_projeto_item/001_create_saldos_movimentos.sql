-- Migration 20260706_022 — Parte 1
-- SPEC-010: cria as tabelas de saldo operacional e auditoria de estoque por
-- item de projeto (projeto_item_id como chave operacional).
--
-- estoque_saldos_projeto_item: uma linha por projeto_itens.id, com os saldos
-- abertos/fechados do item (reserva, entrega futura, aguardando separação,
-- separado, entregue, devolvida, transferida). Não duplica produto_id/
-- projeto_id/orcamento_id/cliente_id — essas dimensões são lidas via JOIN em
-- projeto_itens (ver views na parte 3 desta migration).
--
-- estoque_movimentos_projeto_item: log de auditoria de cada operação que
-- altera o saldo (aprovação, alocação, transferência, separação, entrega,
-- devolução, cancelamento).

CREATE TABLE public.estoque_saldos_projeto_item (
    projeto_item_id       uuid PRIMARY KEY REFERENCES public.projeto_itens(id) ON DELETE CASCADE,

    q_reserva             numeric(10,3) NOT NULL DEFAULT 0 CHECK (q_reserva >= 0),
    q_entrega_futura      numeric(10,3) NOT NULL DEFAULT 0 CHECK (q_entrega_futura >= 0),
    q_ag_separar          numeric(10,3) NOT NULL DEFAULT 0 CHECK (q_ag_separar >= 0),
    q_separado            numeric(10,3) NOT NULL DEFAULT 0 CHECK (q_separado >= 0),
    q_entregue            numeric(10,3) NOT NULL DEFAULT 0 CHECK (q_entregue >= 0),
    q_devolvida           numeric(10,3) NOT NULL DEFAULT 0 CHECK (q_devolvida >= 0),
    q_transferida_saida   numeric(10,3) NOT NULL DEFAULT 0 CHECK (q_transferida_saida >= 0),

    status_operacional    text NOT NULL DEFAULT 'ativo'
        CHECK (status_operacional IN ('ativo', 'cancelado', 'encerrado')),

    criado_em             timestamptz NOT NULL DEFAULT now(),
    atualizado_em         timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.estoque_saldos_projeto_item IS
'SPEC-010. Saldo operacional vivo por projeto_itens.id. Cliente/projeto/orçamento/produto são lidos por relacionamento (ver vw_estoque_saldos_projeto_item), nunca duplicados aqui.';

CREATE INDEX idx_esp_status
  ON public.estoque_saldos_projeto_item (status_operacional);

-- Mantém atualizado_em em dia a cada UPDATE.
CREATE FUNCTION public.trg_estoque_saldos_projeto_item_atualizado_em()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.atualizado_em := now();
  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_atualizar_estoque_saldos_projeto_item
BEFORE UPDATE ON public.estoque_saldos_projeto_item
FOR EACH ROW EXECUTE FUNCTION public.trg_estoque_saldos_projeto_item_atualizado_em();

-- Garante que a soma dos saldos nunca ultrapasse projeto_itens.quantidade
-- (Q. Venda é imutável e é o teto de qualquer saldo do item — decisão
-- aprovada na SPEC-010).
CREATE FUNCTION public.fn_validar_saldo_projeto_item()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
  v_quantidade_venda numeric(10,2);
  v_soma             numeric(10,3);
BEGIN
  SELECT quantidade INTO v_quantidade_venda
  FROM public.projeto_itens
  WHERE id = NEW.projeto_item_id;

  v_soma := NEW.q_reserva + NEW.q_entrega_futura + NEW.q_ag_separar
          + NEW.q_separado + NEW.q_entregue + NEW.q_devolvida;

  IF v_soma > coalesce(v_quantidade_venda, 0) THEN
    RAISE EXCEPTION
      'Saldo do item de projeto % excede a quantidade vendida (% > %).',
      NEW.projeto_item_id, v_soma, v_quantidade_venda
      USING ERRCODE = 'P0001';
  END IF;

  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_validar_saldo_projeto_item
BEFORE INSERT OR UPDATE ON public.estoque_saldos_projeto_item
FOR EACH ROW EXECUTE FUNCTION public.fn_validar_saldo_projeto_item();

CREATE TABLE public.estoque_movimentos_projeto_item (
    id                         uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    projeto_item_id            uuid NOT NULL REFERENCES public.projeto_itens(id) ON DELETE CASCADE,
    projeto_item_destino_id    uuid REFERENCES public.projeto_itens(id) ON DELETE SET NULL,

    tipo                       text NOT NULL CHECK (tipo IN (
        'aprovacao_orcamento',
        'alocacao_reserva',
        'alocacao_entrega_futura',
        'transferencia_saida',
        'transferencia_entrada',
        'recebimento_para_reserva',
        'solicitacao_separacao',
        'separado',
        'entregue',
        'devolucao',
        'cancelamento'
    )),
    quantidade                 numeric(10,3) NOT NULL CHECK (quantidade > 0),
    origem                     text,
    referencia_id              uuid,
    observacao                 text,
    criado_por                 uuid REFERENCES auth.users(id),
    criado_em                  timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.estoque_movimentos_projeto_item IS
'SPEC-010. Auditoria de cada movimento que altera estoque_saldos_projeto_item.';

CREATE INDEX idx_empi_projeto_item ON public.estoque_movimentos_projeto_item (projeto_item_id);
CREATE INDEX idx_empi_tipo         ON public.estoque_movimentos_projeto_item (tipo);
CREATE INDEX idx_empi_referencia   ON public.estoque_movimentos_projeto_item (referencia_id);

-- RLS: habilitada sem policy nesta migration. Decisão de quem pode ler/
-- escrever (vendedor vê só os próprios projetos vs. visão completa de
-- estoque) está registrada como pendência aberta na SPEC-010 e não deve ser
-- resolvida com `USING (true)` — esse padrão já foi apontado como achado de
-- segurança recorrente no ecossistema (pendência crítica 7 do checklist
-- geral). Sem policy, só service_role acessa até a decisão ser tomada.
ALTER TABLE public.estoque_saldos_projeto_item ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.estoque_movimentos_projeto_item ENABLE ROW LEVEL SECURITY;
