-- Rollback da 280: volta a restrição ao Matheus e à administração.
BEGIN;
CREATE OR REPLACE FUNCTION public.ligar_projeto_connect(p_orcamento_id uuid, p_projeto_id uuid, p_observacao text, p_confirmar_cliente_diferente boolean DEFAULT false)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_orc   record;
  v_proj  record;
  v_nome  text;
  v_n     integer;
  a text; b text;
BEGIN
  IF NOT public.pode_tratar_heranca_connect() THEN
    RAISE EXCEPTION 'Só o Matheus ou um administrador pode ligar uma venda da Connect a um projeto.' USING ERRCODE = '42501';
  END IF;
  IF p_observacao IS NULL OR length(btrim(p_observacao)) = 0 THEN
    RAISE EXCEPTION 'A observação é obrigatória (por que esta venda é deste projeto).' USING ERRCODE = 'P0001';
  END IF;

  SELECT o.id, o.numero, o.origem, o.projeto_id, o.cliente_id, o.origem_connect_cod_orcamento
    INTO v_orc FROM public.orcamentos o WHERE o.id = p_orcamento_id FOR UPDATE;
  IF NOT FOUND OR v_orc.origem IS DISTINCT FROM 'connect' THEN
    RAISE EXCEPTION 'Este orçamento não é herança da Connect.' USING ERRCODE = 'P0001';
  END IF;
  IF v_orc.projeto_id IS NOT NULL THEN
    RAISE EXCEPTION 'Este orçamento já está ligado a um projeto.' USING ERRCODE = 'P0001';
  END IF;
  IF v_orc.origem_connect_cod_orcamento IS NULL THEN
    RAISE EXCEPTION 'Orçamento da Connect sem código de origem.' USING ERRCODE = 'P0001';
  END IF;

  SELECT p.id, p.codigo, p.nome, p.cliente_id INTO v_proj FROM public.projetos p WHERE p.id = p_projeto_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Projeto não encontrado.' USING ERRCODE = 'P0001';
  END IF;

  IF v_orc.cliente_id IS NOT NULL AND v_proj.cliente_id IS NOT NULL AND v_orc.cliente_id <> v_proj.cliente_id
     AND NOT coalesce(p_confirmar_cliente_diferente, false) THEN
    RETURN jsonb_build_object('ligado', false, 'cliente_diferente', true,
      'cliente_venda', (SELECT nome FROM public.contatos WHERE id = v_orc.cliente_id),
      'cliente_projeto', (SELECT nome FROM public.contatos WHERE id = v_proj.cliente_id));
  END IF;

  -- fotografia do que NÃO pode mudar
  SELECT concat_ws('|',
           (SELECT coalesce(sum(quantidade),0) || '/' || coalesce(sum(quantidade_reservada),0) FROM public.estoque_itens),
           (SELECT coalesce(sum(q_reserva),0) || '/' || coalesce(sum(q_entrega_futura),0) || '/' || coalesce(sum(q_ag_separar),0) || '/' || coalesce(sum(q_separado),0) || '/' || coalesce(sum(q_entregue),0) || '/' || coalesce(sum(q_devolvida),0) FROM public.estoque_saldos_projeto_item),
           (SELECT count(*) FROM public.transacoes), (SELECT count(*) FROM public.projeto_parcelas), (SELECT count(*) FROM public.boletos),
           (SELECT count(*) FROM public.vendas), (SELECT coalesce(sum(valor_total),0) FROM public.projetos), (SELECT count(*) FROM public.projeto_itens))
    INTO a;

  SELECT coalesce(nullif(u.nome, ''), u.email) INTO v_nome FROM public.usuarios u WHERE u.id = auth.uid();

  INSERT INTO public.connect_orcamento_projeto_manual (cod_orcamento_connect, projeto_id, cliente_id, observacao)
  VALUES (v_orc.origem_connect_cod_orcamento, v_proj.id, coalesce(v_orc.cliente_id, v_proj.cliente_id), btrim(p_observacao))
  ON CONFLICT (cod_orcamento_connect) DO UPDATE
     SET projeto_id = EXCLUDED.projeto_id, cliente_id = EXCLUDED.cliente_id, observacao = EXCLUDED.observacao,
         usuario_id = auth.uid(), criado_em = now();

  UPDATE public.orcamentos
     SET projeto_id = v_proj.id,
         cliente_id = coalesce(cliente_id, v_proj.cliente_id),
         observacoes = coalesce(observacoes, '') || ' Projeto ' || v_proj.codigo || ' ligado em ' || to_char(now() AT TIME ZONE 'America/Sao_Paulo', 'DD/MM/YYYY')
                       || ' por ' || coalesce(v_nome, '-') || ': ' || btrim(p_observacao) || '.'
   WHERE id = v_orc.id;

  UPDATE public.projeto_itens SET projeto_id = v_proj.id WHERE orcamento_id = v_orc.id AND projeto_id IS NULL;
  GET DIAGNOSTICS v_n = ROW_COUNT;

  UPDATE public.connect_reserva_ambiente
     SET projeto_id = v_proj.id, cliente_id = coalesce(cliente_id, v_proj.cliente_id)
   WHERE cod_orcamento_connect = v_orc.origem_connect_cod_orcamento AND projeto_id IS NULL;

  SELECT concat_ws('|',
           (SELECT coalesce(sum(quantidade),0) || '/' || coalesce(sum(quantidade_reservada),0) FROM public.estoque_itens),
           (SELECT coalesce(sum(q_reserva),0) || '/' || coalesce(sum(q_entrega_futura),0) || '/' || coalesce(sum(q_ag_separar),0) || '/' || coalesce(sum(q_separado),0) || '/' || coalesce(sum(q_entregue),0) || '/' || coalesce(sum(q_devolvida),0) FROM public.estoque_saldos_projeto_item),
           (SELECT count(*) FROM public.transacoes), (SELECT count(*) FROM public.projeto_parcelas), (SELECT count(*) FROM public.boletos),
           (SELECT count(*) FROM public.vendas), (SELECT coalesce(sum(valor_total),0) FROM public.projetos), (SELECT count(*) FROM public.projeto_itens))
    INTO b;
  IF a IS DISTINCT FROM b THEN
    RAISE EXCEPTION 'Ligar o projeto alterou estoque, saldos, financeiro, vendas ou valor dos projetos (% x %). Desfeito.', a, b USING ERRCODE = 'P0001';
  END IF;

  RETURN jsonb_build_object('ligado', true, 'orcamento', v_orc.numero, 'projeto', v_proj.codigo, 'itens_ligados', v_n);
END
$function$;
COMMIT;
