-- Migration 20260721_054 - SPEC-038 Item 4
--
-- Decisao do usuario (P-04, 2026-07-21): Alternativa A (nova tabela real
-- pedido_compra_parcelas), com ajuste explicito: o valor de cada parcela
-- precisa poder ser EDITADO MANUALMENTE depois de gerada (nao trava na
-- divisao automatica igual) -- "Tendo tambem a possibilidade de valor de
-- parcela! assim conseguimos estipular todos os campos necessarios!".
--
-- Reaproveita _lucenera_parse_prazo_pagamento() ja existente e testado
-- (01_schema_full.sql:314-373), mas cria tabela PROPRIA para o lado pagavel
-- -- nao reaproveita projeto_parcelas (lado recebivel, cliente -> Lucenera)
-- nem o enum parcela_status (mesmo dominio recebivel). boletos/projeto_parcelas
-- continuam exclusivos do fluxo recebivel -- invariante do ecossistema, nao
-- violado aqui.

ALTER TABLE public.pedidos_compra
  ADD COLUMN IF NOT EXISTS prazo_pagamento_dias integer[];  -- mesmo padrao de orcamentos.prazo_pagamento_dias

COMMENT ON COLUMN public.pedidos_compra.prazo_pagamento_dias IS
'SPEC-038. Override opcional de dias de vencimento por parcela (mesmo padrao
de orcamentos.prazo_pagamento_dias). Se NULL, gerar_parcelas_pedido_compra
interpreta pedidos_compra.condicoes_pagamento via _lucenera_parse_prazo_pagamento().';

CREATE TABLE IF NOT EXISTS public.pedido_compra_parcelas (
    id              uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    pedido_id       uuid NOT NULL REFERENCES public.pedidos_compra(id) ON DELETE CASCADE,
    numero_parcela  integer NOT NULL,
    valor           numeric(12,2) NOT NULL CHECK (valor > 0),
    data_vencimento date NOT NULL,
    status          text NOT NULL DEFAULT 'pendente'
                    CHECK (status IN ('pendente', 'pago', 'atrasado', 'cancelado')),
    forma_pagamento public.pagamento_forma,
    observacao      text,
    criado_em       timestamptz NOT NULL DEFAULT now(),
    atualizado_em   timestamptz NOT NULL DEFAULT now(),
    UNIQUE (pedido_id, numero_parcela)
);

COMMENT ON TABLE public.pedido_compra_parcelas IS
'SPEC-038. Parcelas do PAGAVEL (Lucenera -> fornecedor), analogas a
projeto_parcelas (RECEBIVEL, cliente -> Lucenera), mas tabela separada e sem
relacao com boletos (boletos.orcamento_id continua exclusivo do lado
recebivel). Geradas por RPC gerar_parcelas_pedido_compra, editaveis
manualmente depois via atualizar_parcela_pedido_compra (decisao do usuario,
P-04).';

CREATE INDEX IF NOT EXISTS idx_pcp_pedido ON public.pedido_compra_parcelas (pedido_id);
CREATE INDEX IF NOT EXISTS idx_pcp_status ON public.pedido_compra_parcelas (status);

ALTER TABLE public.pedido_compra_parcelas ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS authenticated_select_pedido_compra_parcelas ON public.pedido_compra_parcelas;
CREATE POLICY authenticated_select_pedido_compra_parcelas
  ON public.pedido_compra_parcelas
  AS PERMISSIVE FOR SELECT TO authenticated
  USING (true);

GRANT SELECT ON TABLE public.pedido_compra_parcelas TO authenticated;

-- -----------------------------------------------------------------------
-- gerar_parcelas_pedido_compra: divisao automatica inicial (ponto de
-- partida -- pode ser editada depois via atualizar_parcela_pedido_compra)
-- -----------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.gerar_parcelas_pedido_compra(
    p_pedido_id uuid
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_pedido          public.pedidos_compra%ROWTYPE;
    v_prazos          integer[];
    v_qtd_parcelas    integer;
    v_valor_base      numeric(12,2);
    v_valor_acumulado numeric(12,2) := 0;
    v_valor_parcela   numeric(12,2);
    v_i               integer;
    v_criadas         integer := 0;
BEGIN
    SELECT * INTO v_pedido FROM public.pedidos_compra WHERE id = p_pedido_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Pedido de compra % nao encontrado.', p_pedido_id USING ERRCODE = 'P0001';
    END IF;

    IF v_pedido.valor_total IS NULL OR v_pedido.valor_total <= 0 THEN
        RAISE EXCEPTION 'Pedido % nao possui valor_total valido.', v_pedido.numero USING ERRCODE = 'P0001';
    END IF;

    v_prazos := public._lucenera_parse_prazo_pagamento(
        v_pedido.condicoes_pagamento, v_pedido.prazo_pagamento_dias
    );
    v_qtd_parcelas := COALESCE(array_length(v_prazos, 1), 0);

    IF v_qtd_parcelas = 0 THEN
        RAISE EXCEPTION 'Nao foi possivel interpretar condicoes_pagamento/prazo_pagamento_dias do pedido %.', v_pedido.numero
            USING ERRCODE = 'P0001';
    END IF;

    -- Idempotente: nao duplica se ja houver parcelas geradas
    IF EXISTS (SELECT 1 FROM public.pedido_compra_parcelas WHERE pedido_id = p_pedido_id) THEN
        RAISE EXCEPTION 'Pedido % ja possui parcelas geradas.', v_pedido.numero USING ERRCODE = 'P0001';
    END IF;

    v_valor_base := round(v_pedido.valor_total / v_qtd_parcelas, 2);

    FOR v_i IN 1..v_qtd_parcelas LOOP
        v_valor_parcela := CASE
            WHEN v_i < v_qtd_parcelas THEN v_valor_base
            ELSE v_pedido.valor_total - v_valor_acumulado
        END;

        INSERT INTO public.pedido_compra_parcelas (
            pedido_id, numero_parcela, valor, data_vencimento, status
        ) VALUES (
            p_pedido_id, v_i, v_valor_parcela,
            v_pedido.data_emissao + v_prazos[v_i],
            'pendente'
        );

        v_valor_acumulado := v_valor_acumulado + v_valor_parcela;
        v_criadas := v_criadas + 1;
    END LOOP;

    RETURN jsonb_build_object('pedido_id', p_pedido_id, 'parcelas_criadas', v_criadas);
END;
$$;

COMMENT ON FUNCTION public.gerar_parcelas_pedido_compra(uuid) IS
'SPEC-038. Gera pedido_compra_parcelas a partir de condicoes_pagamento/
prazo_pagamento_dias do pedido, reaproveitando _lucenera_parse_prazo_pagamento()
ja usada por orcamentos. Idempotente: falha se ja houver parcelas.';

GRANT EXECUTE ON FUNCTION public.gerar_parcelas_pedido_compra(uuid) TO authenticated;

-- -----------------------------------------------------------------------
-- atualizar_parcela_pedido_compra: edicao manual (decisao P-04)
-- -----------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.atualizar_parcela_pedido_compra(
    p_parcela_id      uuid,
    p_valor           numeric,
    p_data_vencimento date
) RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_pedido_id     uuid;
    v_valor_total   numeric(12,2);
    v_soma_parcelas numeric(12,2);
BEGIN
    IF p_valor IS NULL OR p_valor <= 0 THEN
        RAISE EXCEPTION 'Valor da parcela deve ser maior que zero.' USING ERRCODE = 'P0001';
    END IF;

    SELECT pedido_id INTO v_pedido_id
    FROM public.pedido_compra_parcelas WHERE id = p_parcela_id;

    IF v_pedido_id IS NULL THEN
        RAISE EXCEPTION 'Parcela % nao encontrada.', p_parcela_id USING ERRCODE = 'P0001';
    END IF;

    UPDATE public.pedido_compra_parcelas
    SET valor = p_valor,
        data_vencimento = COALESCE(p_data_vencimento, data_vencimento),
        atualizado_em = now()
    WHERE id = p_parcela_id;

    SELECT valor_total INTO v_valor_total
    FROM public.pedidos_compra WHERE id = v_pedido_id;

    SELECT COALESCE(SUM(valor), 0) INTO v_soma_parcelas
    FROM public.pedido_compra_parcelas WHERE pedido_id = v_pedido_id;

    IF v_soma_parcelas <> v_valor_total THEN
        RAISE WARNING 'Soma das parcelas (%) diverge do valor_total do pedido (%) apos edicao manual.',
          v_soma_parcelas, v_valor_total;
    END IF;
END;
$$;

COMMENT ON FUNCTION public.atualizar_parcela_pedido_compra(uuid, numeric, date) IS
'SPEC-038 (P-04). Permite editar manualmente valor/data_vencimento de uma
parcela ja gerada por gerar_parcelas_pedido_compra -- decisao do usuario de
nao travar a divisao automatica igual entre parcelas. Emite WARNING (nao
bloqueia) se a soma das parcelas divergir de pedidos_compra.valor_total,
para o comprador poder ajustar arredondamento manualmente entre parcelas.';

GRANT EXECUTE ON FUNCTION public.atualizar_parcela_pedido_compra(uuid, numeric, date) TO authenticated;
