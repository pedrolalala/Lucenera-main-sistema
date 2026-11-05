-- SPEC-244 (05/11): o orçamento "XML importado da Connect" (antes "Vínculo Connect", SPEC-195/197) passa a ser só de administradores.
-- Não muda nada nos orçamentos já vinculados; só quem pode CRIAR um novo vínculo.
BEGIN;
CREATE OR REPLACE FUNCTION public.vincular_orcamento_connect(p_orcamento_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_o public.orcamentos%ROWTYPE;
  v_numero text;
  v_numero_venda text;
  v_itens integer := 0;
BEGIN
  -- SPEC-244 (05/11): com a Connect e o sistema novo em paralelo, o "XML importado da Connect" (antes "Vínculo Connect") deixa de ser rotina das equipes:
  -- só administrador usa (a opção existia para trabalhar de forma progressiva).
  IF COALESCE(auth.role(), '') <> 'service_role' AND NOT COALESCE(public.is_admin(), false) THEN
    RAISE EXCEPTION 'Só administradores podem vincular o XML importado da Connect.' USING ERRCODE = 'P0001';
  END IF;

  SELECT * INTO v_o FROM public.orcamentos WHERE id = p_orcamento_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Orçamento % não encontrado.', p_orcamento_id USING ERRCODE = 'P0001';
  END IF;
  v_numero := coalesce(v_o.numero, left(p_orcamento_id::text, 8));

  -- idempotente: já vinculado
  IF v_o.vinculo_connect AND v_o.status = 'Orçamento Aprovado' THEN
    RETURN jsonb_build_object('orcamento_id', p_orcamento_id, 'numero_venda', v_o.numero_venda,
      'projeto_itens_criados', 0, 'ja_vinculado', true);
  END IF;

  IF v_o.origem_connect_cod_orcamento IS NULL THEN
    RAISE EXCEPTION 'Orçamento % não veio da Connect (importe pelo XML da Connect).', v_numero USING ERRCODE = 'P0001';
  END IF;
  IF v_o.natureza_operacao IS DISTINCT FROM 'venda' THEN
    RAISE EXCEPTION 'Orçamento % não é de venda.', v_numero USING ERRCODE = 'P0001';
  END IF;
  IF v_o.status IN ('Orçamento Aprovado', 'Aprovação Financeira', 'cancelado') THEN
    RAISE EXCEPTION 'Orçamento % está em "%" — não pode ser vinculado.', v_numero, v_o.status USING ERRCODE = 'P0001';
  END IF;
  IF v_o.projeto_id IS NULL THEN
    RAISE EXCEPTION 'Orçamento % não possui projeto vinculado.', v_numero USING ERRCODE = 'P0001';
  END IF;
  IF v_o.empresa_id IS NULL THEN
    RAISE EXCEPTION 'Orçamento % não possui empresa vinculada.', v_numero USING ERRCODE = 'P0001';
  END IF;
  IF v_o.cliente_id IS NULL THEN
    RAISE EXCEPTION 'Orçamento % não possui cliente vinculado.', v_numero USING ERRCODE = 'P0001';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.orcamento_itens WHERE orcamento_id = p_orcamento_id) THEN
    RAISE EXCEPTION 'Orçamento % não possui itens.', v_numero USING ERRCODE = 'P0001';
  END IF;
  IF EXISTS (SELECT 1 FROM public.orcamento_itens WHERE orcamento_id = p_orcamento_id AND produto_id IS NULL) THEN
    RAISE EXCEPTION 'Orçamento % possui item sem produto cadastrado — cadastre/vincule a peça antes.', v_numero USING ERRCODE = 'P0001';
  END IF;
  IF EXISTS (SELECT 1 FROM public.orcamento_itens WHERE orcamento_id = p_orcamento_id
             AND (coalesce(quantidade, 0) <= 0 OR preco_unitario IS NULL OR preco_unitario < 0)) THEN
    RAISE EXCEPTION 'Orçamento % possui item sem quantidade ou preço válido.', v_numero USING ERRCODE = 'P0001';
  END IF;
  IF EXISTS (SELECT 1 FROM public.projeto_itens WHERE orcamento_id = p_orcamento_id) THEN
    RAISE EXCEPTION 'Orçamento % já tem itens no projeto — processamento inconsistente.', v_numero USING ERRCODE = 'P0001';
  END IF;

  v_numero_venda := 'VENDA-' || lpad(v_o.origem_connect_cod_orcamento::text, 4, '0');
  IF EXISTS (SELECT 1 FROM public.orcamentos WHERE numero_venda = v_numero_venda AND id <> p_orcamento_id) THEN
    RAISE EXCEPTION 'O número de venda % já existe no sistema — confira o número da Connect.', v_numero_venda USING ERRCODE = 'P0001';
  END IF;

  UPDATE public.orcamentos
  SET status = 'Orçamento Aprovado', vinculo_connect = true, numero_venda = v_numero_venda,
      requer_revisao_financeira = false
  WHERE id = p_orcamento_id;

  INSERT INTO public.historico_status_orcamentos (orcamento_id, status_anterior, status_novo, usuario, observacao)
  VALUES (p_orcamento_id, v_o.status, 'Orçamento Aprovado', auth.uid()::text,
    format('Vínculo de venda aprovada na Connect nº %s — sem reserva de estoque, sem financeiro e sem nota (SPEC-195)',
           v_o.origem_connect_cod_orcamento));

  INSERT INTO public.projeto_itens (
    projeto_id, produto_id, descricao, quantidade, preco_unitario, desconto, validado, orcamento_id,
    orcamento_item_id, l_fixo
  )
  SELECT v_o.projeto_id, oi.produto_id, coalesce(oi.descricao, p.nome, oi.custom_id, 'Item do Orçamento'),
    oi.quantidade, oi.preco_unitario, coalesce(oi.desconto, 0), true, p_orcamento_id, oi.id, oi.custom_id
  FROM public.orcamento_itens oi LEFT JOIN public.produtos p ON p.id = oi.produto_id
  WHERE oi.orcamento_id = p_orcamento_id;
  GET DIAGNOSTICS v_itens = ROW_COUNT;

  RETURN jsonb_build_object('orcamento_id', p_orcamento_id, 'numero_venda', v_numero_venda,
    'projeto_itens_criados', v_itens, 'ja_vinculado', false);
END;
$function$;
COMMIT;
