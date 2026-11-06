-- SPEC-251: Matheus (Líder de Logística) e Vitória (Assistente Administrativa) fazem transferências de peça entre vendas
-- (botão Transferir da Venda Parcial) e hoje não conseguem: pode_trocar_reserva() e aprovar_transferencia_estoque() só aceitam admin,
-- gerente e cargo Projetista (reunião 06/11: "a Vi faz as transferências", "o Matheus pega emprestado para garantia").
-- Em vez de fixar cargo no código, usa o mecanismo de exceção individual do Acesso a Sistemas (igual ao ajuste de reserva da SPEC-235
-- e ao Tratar da SPEC-243): módulo "transferir_reserva" do sistema separacao-parcial + exceção "conceder" por usuário (a administração
-- concede ou tira pela Central, sem migration).

INSERT INTO public.modulos (system_id, chave, nome, descricao, ordem)
SELECT s.id, 'transferir_reserva', 'Transferir peça entre vendas (Venda Parcial)',
       'SPEC-251: pegar a peça reservada de outra venda para atender esta (botão Transferir). Projetista, gerente e admin já podem; outros só por exceção individual (conceder).',
       110
  FROM public.systems s WHERE s.slug = 'separacao-parcial'
ON CONFLICT (system_id, chave) DO NOTHING;

-- Matheus e Vitória
INSERT INTO public.usuario_permissao_excecoes (usuario_id, system_id, modulo_id, acao, tipo, justificativa)
SELECT u.id, s.id, m.id, 'editar', 'conceder',
       'SPEC-251: faz transferências de peça entre vendas e garantias (reunião 06/11)'
  FROM (VALUES ('af3035fd-266b-4b3a-952b-cb8866096c49'::uuid), ('d875ff50-2220-48af-9ed7-0a670ec877c3'::uuid)) AS u(id)
  JOIN public.systems s ON s.slug = 'separacao-parcial'
  JOIN public.modulos m ON m.system_id = s.id AND m.chave = 'transferir_reserva'
 WHERE NOT EXISTS (SELECT 1 FROM public.usuario_permissao_excecoes e WHERE e.usuario_id = u.id AND e.modulo_id = m.id);

-- Quem pode transferir: admin, gerente, Projetista (como antes) OU exceção "conceder" do módulo transferir_reserva
CREATE OR REPLACE FUNCTION public.pode_trocar_reserva()
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
    v_role public.usuario_role;
BEGIN
    SELECT role INTO v_role FROM public.usuarios WHERE id = auth.uid();
    IF v_role IN ('admin', 'gerente') THEN
        RETURN true;
    END IF;
    IF EXISTS (
        SELECT 1 FROM public.funcionarios
        WHERE usuario_id = auth.uid() AND btrim(cargo) = 'Projetista'
    ) THEN
        RETURN true;
    END IF;
    -- SPEC-251: exceção individual concedida pela administração (ex.: Matheus e Vitória)
    RETURN coalesce((
        SELECT e.tipo = 'conceder'
          FROM public.usuario_permissao_excecoes e
          JOIN public.modulos m ON m.id = e.modulo_id AND m.chave = 'transferir_reserva'
          JOIN public.systems s ON s.id = m.system_id AND s.slug = 'separacao-parcial'
         WHERE e.usuario_id = auth.uid()
           AND (e.valido_até IS NULL OR e.valido_até > now())
         ORDER BY e.criado_em DESC
         LIMIT 1), false);
END;
$function$;

REVOKE ALL ON FUNCTION public.pode_trocar_reserva() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.pode_trocar_reserva() TO authenticated;

-- A aprovação da transferência usava a mesma regra escrita à mão; passa a usar pode_trocar_reserva() (mesma conta + a exceção).
CREATE OR REPLACE FUNCTION public.aprovar_transferencia_estoque(p_transferencia_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
    v_transf     public.transferencias_estoque%ROWTYPE;
    v_origem     public.estoque_saldos_projeto_item%ROWTYPE;
    v_destino    public.estoque_saldos_projeto_item%ROWTYPE;
    v_reduzir_ef numeric(10,3);
BEGIN
    IF NOT public.pode_trocar_reserva() THEN
        RAISE EXCEPTION 'Apenas Projetista, gerente, admin ou quem recebeu a permissão de transferir pode aprovar transferencia de estoque.' USING ERRCODE = '42501';
    END IF;

    SELECT * INTO v_transf FROM public.transferencias_estoque WHERE id = p_transferencia_id FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Transferencia % nao encontrada.', p_transferencia_id USING ERRCODE = 'P0001';
    END IF;

    IF v_transf.status <> 'solicitada' THEN
        RAISE EXCEPTION 'Transferencia % nao esta mais solicitada (status atual: %).', p_transferencia_id, v_transf.status USING ERRCODE = 'P0001';
    END IF;

    SELECT * INTO v_origem
    FROM public.estoque_saldos_projeto_item
    WHERE projeto_item_id = v_transf.origem_projeto_item_id
    FOR UPDATE;

    SELECT * INTO v_destino
    FROM public.estoque_saldos_projeto_item
    WHERE projeto_item_id = v_transf.destino_projeto_item_id
    FOR UPDATE;

    IF v_origem.q_reserva < v_transf.quantidade THEN
        RAISE EXCEPTION 'Origem nao tem mais q_reserva suficiente (era % no momento da solicitacao).', v_transf.quantidade USING ERRCODE = 'P0001';
    END IF;

    v_reduzir_ef := LEAST(v_transf.quantidade, v_destino.q_entrega_futura);

    UPDATE public.estoque_saldos_projeto_item
    SET q_reserva = q_reserva - v_transf.quantidade,
        q_entrega_futura = q_entrega_futura + v_transf.quantidade,
        q_transferida_saida = q_transferida_saida + v_transf.quantidade,
        atualizado_em = now()
    WHERE projeto_item_id = v_transf.origem_projeto_item_id;

    UPDATE public.estoque_saldos_projeto_item
    SET q_entrega_futura = q_entrega_futura - v_reduzir_ef,
        q_reserva = q_reserva + v_transf.quantidade,
        atualizado_em = now()
    WHERE projeto_item_id = v_transf.destino_projeto_item_id;

    INSERT INTO public.estoque_movimentos_projeto_item
        (projeto_item_id, projeto_item_destino_id, tipo, quantidade, origem, referencia_id, criado_por)
    VALUES
        (v_transf.origem_projeto_item_id, v_transf.destino_projeto_item_id, 'transferencia_saida', v_transf.quantidade, 'transferencia_estoque', v_transf.id, auth.uid());

    INSERT INTO public.estoque_movimentos_projeto_item
        (projeto_item_id, projeto_item_destino_id, tipo, quantidade, origem, referencia_id, criado_por)
    VALUES
        (v_transf.destino_projeto_item_id, v_transf.origem_projeto_item_id, 'transferencia_entrada', v_transf.quantidade, 'transferencia_estoque', v_transf.id, auth.uid());

    UPDATE public.transferencias_estoque
    SET status = 'aprovada', aprovado_por = auth.uid(), aprovado_em = now()
    WHERE id = p_transferencia_id;

    RETURN jsonb_build_object('transferencia_id', p_transferencia_id, 'status', 'aprovada');
END;
$function$;
