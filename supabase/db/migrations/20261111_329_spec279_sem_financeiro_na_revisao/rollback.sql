-- SPEC-279: volta a aprovacao automatica das operacoes sem financeiro (SPEC-255 A) e a lista sem o registro de baixa direta.
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

-- SPEC-255 C/D: a lista da Venda Parcial passa a saber o tipo da operação (garantia, bonificação...) para mostrar o rótulo.
-- Só acrescenta duas colunas no FIM da view (as existentes ficam iguais). security_invoker continua valendo.
CREATE OR REPLACE VIEW public.vw_venda_parcial_lista
WITH (security_invoker = true) AS
SELECT o.id AS orcamento_id,
    o.numero AS orcamento_numero,
    o.numero_venda AS venda_numero,
    o.origem,
    o.cliente_id,
    c.nome AS cliente_nome,
    c.razao_social AS cliente_razao_social,
    p.codigo AS projeto_codigo,
    emp.nome AS empresa_nome,
    COALESCE(o.aprovado_cliente_em, o.data_emissao) AS data_venda,
    o.previsao_entrega,
    eq.equipes AS equipe_nome,
    f.nome AS vendedor_nome,
    o.vendas_vinculadas_connect,
    o.origem_connect_cod_orcamento,
    ((o.origem = 'connect'::text) AND (EXISTS ( SELECT 1
           FROM connect_reserva_ambiente r
          WHERE ((r.orcamento_id = o.id) AND r.venda_antiga)))) AS venda_antiga,
    t.itens,
    t.q_venda,
    t.q_reserva,
    t.q_entrega_futura,
    t.q_ag_separar,
    t.q_separado,
    t.q_entregue,
    o.natureza_operacao,
    o.subgrupo
   FROM ((((((orcamentos o
     JOIN ( SELECT pi.orcamento_id,
            count(*) AS itens,
            sum(pi.quantidade) AS q_venda,
            sum(s.q_reserva) AS q_reserva,
            sum(s.q_entrega_futura) AS q_entrega_futura,
            sum(s.q_ag_separar) AS q_ag_separar,
            sum(s.q_separado) AS q_separado,
            sum(s.q_entregue) AS q_entregue
           FROM (projeto_itens pi
             JOIN estoque_saldos_projeto_item s ON ((s.projeto_item_id = pi.id)))
          WHERE ((s.status_operacional = 'ativo'::text) AND (pi.orcamento_id IS NOT NULL))
          GROUP BY pi.orcamento_id) t ON ((t.orcamento_id = o.id)))
     LEFT JOIN contatos c ON ((c.id = o.cliente_id)))
     LEFT JOIN projetos p ON ((p.id = o.projeto_id)))
     LEFT JOIN empresas emp ON ((emp.id = o.empresa_id)))
     LEFT JOIN equipes_projetos eq ON ((eq.id = o.equipe_id)))
     LEFT JOIN funcionarios f ON ((f.id = o.vendedor_id)));
