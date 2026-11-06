-- SPEC-255 A: garantia e demais saídas SEM cobrança não passam pela revisão financeira.
-- Hoje (SPEC-234 A) elas já não geram parcela, boleto nem nº de venda, mas depois da aprovação da equipe ainda caem na fila da
-- Lana/Carol (Aprovação Financeira) só para serem liberadas. Agora a aprovação da equipe conclui a operação na hora:
--   regra 'saida_cliente' (GARANTIA, OUTRAS SAIDAS, BONIFICACAO, CASA COR SAIDA), 'baixa_direta' (USO E CONSUMO, DESCARTE)
--   e 'sem_estoque' (REMESSA TRANSP, SAIDA INDUSTRIALIZACAO, REMESSA CONSERTO, DEV EM GARANTIA).
-- Venda, devolução, empréstimo e tipo sem regra seguem o caminho de antes. Se a operação falhar (ex.: baixa maior que o
-- Estoque Geral), a aprovação inteira é desfeita e a mensagem aparece para a equipe.
CREATE OR REPLACE FUNCTION public.equipe_aprovar_orcamento(p_orcamento_id uuid, p_observacao text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_orcamento public.orcamentos%ROWTYPE;
  v_status_anterior text;
  v_numero text;
  v_user_role text;
  v_regra text;
  v_res jsonb;
BEGIN
  SELECT u.role INTO v_user_role FROM public.usuarios u WHERE u.id = auth.uid();

  IF NOT (
    v_user_role IN ('admin', 'gerente')
    OR public.hub_pode_executar(auth.uid(), 'orcamentos', 'aprovacao_equipe', 'editar')
  ) THEN
    RAISE EXCEPTION 'Permissão negada para aprovar como equipe.' USING ERRCODE = 'P0001';
  END IF;

  SELECT * INTO v_orcamento FROM public.orcamentos WHERE id = p_orcamento_id FOR UPDATE;
  IF NOT FOUND OR NOT public.orcamento_da_minha_equipe(v_orcamento.equipe_id, v_orcamento.digitado_por) THEN
    RAISE EXCEPTION 'Orçamento não encontrado.' USING ERRCODE = 'P0001';
  END IF;

  v_status_anterior := v_orcamento.status;
  v_numero := COALESCE(v_orcamento.numero, left(p_orcamento_id::text, 8));

  IF v_orcamento.status <> 'Aprovação da Equipe' THEN
    RAISE EXCEPTION 'Orçamento % não está em Aprovação da Equipe. Status atual: %', v_numero, v_status_anterior
      USING ERRCODE = 'P0002';
  END IF;

  UPDATE public.orcamentos
  SET status = 'Aprovação Financeira',
      requer_revisao_financeira = true
  WHERE id = p_orcamento_id;

  INSERT INTO public.historico_status_orcamentos (orcamento_id, status_anterior, status_novo, usuario, observacao)
  VALUES (p_orcamento_id, v_status_anterior, 'Aprovação Financeira', auth.uid()::text,
          COALESCE(p_observacao, 'Aprovado pela equipe após visita à obra — encaminhado para revisão financeira'));

  -- SPEC-255 A: operação sem cobrança não precisa de revisão financeira
  v_regra := public.tipo_operacao_regra(v_orcamento.natureza_operacao, v_orcamento.subgrupo);
  IF v_regra IN ('saida_cliente', 'baixa_direta', 'sem_estoque') THEN
    v_res := public._aprovar_operacao_sem_financeiro(p_orcamento_id);
    RETURN v_res || jsonb_build_object('numero', v_numero, 'sem_revisao_financeira', true);
  END IF;

  RETURN jsonb_build_object('orcamento_id', p_orcamento_id, 'numero', v_numero, 'status', 'Aprovação Financeira');
END;
$function$;
