-- SPEC-231 bloco A (reunião 26/10/2026)
--
-- A1: a Separação Parcial não marca mais a separação como 'Pronto' quando a venda inteira foi pedida.
--     'Pronto' disparava sync_separado_ao_ficar_pronto e as peças iam de "Aguardando separar" para "Separado"
--     sem ninguém separar (no teste: ORC-0002, 10 peças da 12822). Agora vai para 'material_solicitado'
--     (fila "Solicitado" do estoque na Logística) e quem marca separado é o estoque (Sérgio).
--     - finalizar_separacao_parcial_pronta: status 'material_solicitado' + cria a entrega (antes vinha do
--       trigger_separacao_pronta, que só roda em 'Pronto').
--     - sync_separado_ao_ficar_pronto: também roda quando a Logística marca 'separado'; e se a Logística
--       voltar de separado/Pronto para Solicitado/Em separação, as peças voltam para "Aguardando separar".
--
-- A2: toda entrada de NF de compra com parcelas gera as duplicatas no Contas a Pagar (boletos, tipo_operacao 'CP').
--     Ligação nota -> duplicatas: boletos.conta_grupo_id = notas_fiscais_compra.id (o mesmo campo que o
--     Contas a Pagar usa para agrupar as parcelas de uma conta). Cancelar a entrada apaga as não pagas; se
--     alguma já foi paga, o cancelamento é bloqueado.

BEGIN;

-- ---------------------------------------------------------------- A1

CREATE OR REPLACE FUNCTION public.finalizar_separacao_parcial_pronta(p_separacao_id uuid, p_data_entrega date)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_numero_venda text;
  v_pendentes integer;
  v_cliente_id uuid;
  v_endereco text;
  v_telefone text;
  v_sep public.separacoes%ROWTYPE;
BEGIN
  IF p_data_entrega IS NULL THEN
    RAISE EXCEPTION 'Informe a data de entrega.' USING ERRCODE = 'P0001';
  END IF;

  SELECT numero_venda, cliente_id INTO v_numero_venda, v_cliente_id
  FROM public.separacoes
  WHERE id = p_separacao_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Separação % não encontrada.', p_separacao_id USING ERRCODE = 'P0001';
  END IF;

  SELECT count(*) INTO v_pendentes
  FROM public.vw_estoque_saldos_projeto_item
  WHERE orcamento_numero = v_numero_venda
    AND status_operacional = 'ativo'
    AND q_reserva > 0;

  IF v_pendentes > 0 THEN
    RAISE EXCEPTION 'Ainda há % item(ns) com saldo em reserva nesta venda — não é possível enviar para separação.', v_pendentes
      USING ERRCODE = 'P0001';
  END IF;

  IF v_cliente_id IS NOT NULL THEN
    SELECT
      NULLIF(trim(both ', ' from
        concat_ws(', ',
          NULLIF(trim(concat_ws(' ', COALESCE(c.endereco_entrega, c.endereco), c.numero_entrega)), ''),
          NULLIF(c.bairro_entrega, ''),
          NULLIF(c.cidade_entrega, ''),
          NULLIF(c.estado_entrega, '')
        )
      ), ''),
      NULLIF(COALESCE(c.celular, c.telefone), '')
    INTO v_endereco, v_telefone
    FROM public.contatos c
    WHERE c.id = v_cliente_id;
  END IF;

  -- SPEC-231 A1: vai para a fila do estoque ("Solicitado"), não para 'Pronto' (= separado).
  UPDATE public.separacoes
  SET status = 'material_solicitado',
      data_entrega = p_data_entrega,
      endereco_entrega = COALESCE(endereco_entrega, v_endereco),
      telefone = COALESCE(telefone, v_telefone)
  WHERE id = p_separacao_id
  RETURNING * INTO v_sep;

  -- SPEC-231 A1: a entrega continua sendo criada aqui (mesma regra do trigger_separacao_pronta).
  IF NOT EXISTS (
    SELECT 1 FROM public.entregas
    WHERE separacao_id = p_separacao_id
      AND status <> 'Cancelado'::public.entrega_status
  ) THEN
    INSERT INTO public.entregas (
      separacao_id, projeto_id, entregador_id, endereco_entrega, contato_destino, data_prevista, status
    ) VALUES (
      v_sep.id, v_sep.projeto_id, v_sep.responsavel_id, v_sep.endereco_entrega, v_sep.cliente,
      v_sep.data_entrega, 'Pendente'::public.entrega_status
    );
  ELSE
    UPDATE public.entregas
    SET data_prevista = p_data_entrega,
        updated_at    = now()
    WHERE separacao_id = p_separacao_id
      AND status = 'Pendente'::public.entrega_status;
  END IF;

  RETURN jsonb_build_object('separacao_id', p_separacao_id, 'status', 'material_solicitado', 'data_entrega', p_data_entrega);
END;
$function$;

CREATE OR REPLACE FUNCTION public.sync_separado_ao_ficar_pronto()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
    v_item record;
BEGIN
    -- SPEC-231 A1: 'separado' (marcado pelo estoque na Logística) também move para Separado.
    IF NEW.status IN ('Pronto', 'separado') AND OLD.status IS DISTINCT FROM NEW.status THEN
        FOR v_item IN
            SELECT id, projeto_item_id, quantidade - quantidade_estornada AS quantidade
            FROM public.separacao_itens
            WHERE separacao_id = NEW.id
              AND projeto_item_id IS NOT NULL
              AND NOT separado
              AND quantidade > quantidade_estornada
        LOOP
            UPDATE public.estoque_saldos_projeto_item
            SET q_ag_separar = GREATEST(q_ag_separar - v_item.quantidade, 0),
                q_separado = q_separado + v_item.quantidade,
                atualizado_em = now()
            WHERE projeto_item_id = v_item.projeto_item_id;

            UPDATE public.separacao_itens SET separado = true WHERE id = v_item.id;

            INSERT INTO public.estoque_movimentos_projeto_item
                (projeto_item_id, tipo, quantidade, origem, referencia_id, criado_por)
            VALUES
                (v_item.projeto_item_id, 'separado', v_item.quantidade, 'separacao_parcial', NEW.id, auth.uid());
        END LOOP;

    -- SPEC-231 A1: o estoque voltou o pedido para Solicitado / Em separação -> peças voltam para Aguardando separar.
    ELSIF OLD.status IN ('Pronto', 'separado')
          AND NEW.status IN ('material_solicitado', 'Em separação', 'Pendente') THEN
        FOR v_item IN
            SELECT id, projeto_item_id, quantidade - quantidade_estornada AS quantidade
            FROM public.separacao_itens
            WHERE separacao_id = NEW.id
              AND projeto_item_id IS NOT NULL
              AND separado
              AND NOT entregue
              AND quantidade > quantidade_estornada
        LOOP
            UPDATE public.estoque_saldos_projeto_item
            SET q_separado = GREATEST(q_separado - v_item.quantidade, 0),
                q_ag_separar = q_ag_separar + v_item.quantidade,
                atualizado_em = now()
            WHERE projeto_item_id = v_item.projeto_item_id;

            UPDATE public.separacao_itens SET separado = false WHERE id = v_item.id;

            INSERT INTO public.estoque_movimentos_projeto_item
                (projeto_item_id, tipo, quantidade, origem, referencia_id, observacao, criado_por)
            VALUES
                (v_item.projeto_item_id, 'solicitacao_separacao', v_item.quantidade, 'separacao_parcial', NEW.id,
                 'Voltou para separar (status ' || NEW.status::text || ')', auth.uid());
        END LOOP;
    END IF;
    RETURN NEW;
END;
$function$;

-- ---------------------------------------------------------------- A2

CREATE OR REPLACE FUNCTION public.fn_nota_compra_parcela_gera_contas_pagar()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_total integer;
BEGIN
  INSERT INTO public.boletos (
    nosso_numero, tipo, tipo_operacao, status, nome_pagador, contato_id, empresa_id, numero_documento,
    valor, vencimento, num_parcela, emissao, perfil, apropriacao_id, responsavel_id, referencia,
    conta_grupo_id, observacao
  )
  SELECT
    'NFC-' || NEW.id::text, 'Normal', 'CP', 'Pendente',
    c.nome, c.id, COALESCE(n.empresa_id, p.empresa_id), n.numero_nf,
    NEW.valor, NEW.data_vencimento, NEW.numero_parcela, n.data_emissao,
    CASE WHEN p.perfil IN ('ribeirao', 'sao_paulo') THEN p.perfil END,
    n.plano_contas_id,
    (SELECT u.id FROM public.usuarios u WHERE u.id = n.criado_por),
    CASE WHEN p.numero IS NOT NULL THEN 'Pedido de compra ' || p.numero END,
    n.id,
    'Gerada pela entrada da NF ' || n.numero_nf || ' no Compras'
  FROM public.notas_fiscais_compra n
  LEFT JOIN public.pedidos_compra p ON p.id = n.pedido_compra_id
  LEFT JOIN public.contatos c ON c.id = COALESCE(n.fornecedor_id, p.fornecedor_id)
  WHERE n.id = NEW.nota_id
    AND n.cancelada_em IS NULL
  ON CONFLICT (nosso_numero) DO NOTHING;

  SELECT count(*) INTO v_total FROM public.nota_fiscal_compra_parcelas WHERE nota_id = NEW.nota_id;
  UPDATE public.boletos
  SET total_parcelas = v_total
  WHERE conta_grupo_id = NEW.nota_id
    AND tipo_operacao = 'CP'
    AND total_parcelas IS DISTINCT FROM v_total;

  RETURN NEW;
END;
$function$;

CREATE OR REPLACE FUNCTION public.fn_nota_compra_parcela_remove_contas_pagar()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  IF EXISTS (
    SELECT 1 FROM public.boletos
    WHERE nosso_numero = 'NFC-' || OLD.id::text
      AND status = 'Pago'
  ) THEN
    RAISE EXCEPTION 'A parcela % desta nota já foi paga no Contas a Pagar — estorne o pagamento lá antes de cancelar a entrada.',
      OLD.numero_parcela USING ERRCODE = 'P0001';
  END IF;

  DELETE FROM public.boletos WHERE nosso_numero = 'NFC-' || OLD.id::text;
  RETURN OLD;
END;
$function$;

REVOKE ALL ON FUNCTION public.fn_nota_compra_parcela_gera_contas_pagar() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.fn_nota_compra_parcela_remove_contas_pagar() FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS trg_nota_compra_parcela_gera_contas_pagar ON public.nota_fiscal_compra_parcelas;
CREATE TRIGGER trg_nota_compra_parcela_gera_contas_pagar
  AFTER INSERT ON public.nota_fiscal_compra_parcelas
  FOR EACH ROW EXECUTE FUNCTION public.fn_nota_compra_parcela_gera_contas_pagar();

DROP TRIGGER IF EXISTS trg_nota_compra_parcela_remove_contas_pagar ON public.nota_fiscal_compra_parcelas;
CREATE TRIGGER trg_nota_compra_parcela_remove_contas_pagar
  BEFORE DELETE ON public.nota_fiscal_compra_parcelas
  FOR EACH ROW EXECUTE FUNCTION public.fn_nota_compra_parcela_remove_contas_pagar();

-- Notas já lançadas (ativas, com parcelas) ganham as duplicatas que faltaram.
INSERT INTO public.boletos (
  nosso_numero, tipo, tipo_operacao, status, nome_pagador, contato_id, empresa_id, numero_documento,
  valor, vencimento, num_parcela, total_parcelas, emissao, perfil, apropriacao_id, responsavel_id, referencia,
  conta_grupo_id, observacao
)
SELECT
  'NFC-' || np.id::text, 'Normal', 'CP', 'Pendente',
  c.nome, c.id, COALESCE(n.empresa_id, p.empresa_id), n.numero_nf,
  np.valor, np.data_vencimento, np.numero_parcela,
  count(*) OVER (PARTITION BY np.nota_id), n.data_emissao,
  CASE WHEN p.perfil IN ('ribeirao', 'sao_paulo') THEN p.perfil END,
  n.plano_contas_id,
  (SELECT u.id FROM public.usuarios u WHERE u.id = n.criado_por),
  CASE WHEN p.numero IS NOT NULL THEN 'Pedido de compra ' || p.numero END,
  n.id,
  'Gerada pela entrada da NF ' || n.numero_nf || ' no Compras'
FROM public.nota_fiscal_compra_parcelas np
JOIN public.notas_fiscais_compra n ON n.id = np.nota_id
LEFT JOIN public.pedidos_compra p ON p.id = n.pedido_compra_id
LEFT JOIN public.contatos c ON c.id = COALESCE(n.fornecedor_id, p.fornecedor_id)
WHERE n.cancelada_em IS NULL
ON CONFLICT (nosso_numero) DO NOTHING;

COMMIT;
