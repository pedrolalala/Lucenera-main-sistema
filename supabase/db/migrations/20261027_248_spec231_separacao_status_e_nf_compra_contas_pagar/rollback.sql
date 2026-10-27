-- Rollback SPEC-231 bloco A: volta as 2 funções como estavam em 27/10, tira os triggers de Contas a Pagar e apaga as duplicatas geradas (não pagas).
BEGIN;

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
    RAISE EXCEPTION 'Ainda há % item(ns) com saldo em reserva nesta venda — não é possível marcar como Pronto.', v_pendentes
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

  UPDATE public.separacoes
  SET status = 'Pronto',
      data_entrega = p_data_entrega,
      endereco_entrega = COALESCE(endereco_entrega, v_endereco),
      telefone = COALESCE(telefone, v_telefone)
  WHERE id = p_separacao_id;

  RETURN jsonb_build_object('separacao_id', p_separacao_id, 'status', 'Pronto', 'data_entrega', p_data_entrega);
END;
$function$
;

CREATE OR REPLACE FUNCTION public.sync_separado_ao_ficar_pronto()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
    v_item record;
BEGIN
    IF NEW.status = 'Pronto' AND (OLD.status IS DISTINCT FROM NEW.status) THEN
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
    END IF;
    RETURN NEW;
END;
$function$
;

DROP TRIGGER IF EXISTS trg_nota_compra_parcela_gera_contas_pagar ON public.nota_fiscal_compra_parcelas;
DROP TRIGGER IF EXISTS trg_nota_compra_parcela_remove_contas_pagar ON public.nota_fiscal_compra_parcelas;
DROP FUNCTION IF EXISTS public.fn_nota_compra_parcela_gera_contas_pagar();
DROP FUNCTION IF EXISTS public.fn_nota_compra_parcela_remove_contas_pagar();

DELETE FROM public.boletos
WHERE nosso_numero LIKE 'NFC-%'
  AND tipo_operacao = 'CP'
  AND status <> 'Pago';

COMMIT;
