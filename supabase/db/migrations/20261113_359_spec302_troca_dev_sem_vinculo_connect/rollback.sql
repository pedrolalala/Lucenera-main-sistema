-- Rollback SPEC-302: devolve aprovar_orcamento_financeiro ao estado da migration 357.
-- ATENCAO: nao desfaz vendas de registro/devolucoes 'TROCA DEV SEM VINCULO CONNECT' ja aprovadas.
BEGIN;
DO $$
DECLARE v_def text; v_novo text;
BEGIN
  SELECT pg_get_functiondef(p.oid) INTO v_def FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace AND n.nspname = 'public'
   WHERE p.proname = 'aprovar_orcamento_financeiro';
  v_novo := v_def;

  v_novo := replace(v_novo,
$b$WHERE oi.orcamento_id = p_orcamento_id AND oi.projeto_item_origem_id IS NULL AND oi.origem_connect_venda IS NULL
        AND coalesce(v_orcamento.subgrupo, '') <> 'TROCA DEV SEM VINCULO CONNECT'
    ) THEN
      RAISE EXCEPTION 'Orçamento de devolução % possui item sem venda de origem vinculada.', v_numero_orcamento
        USING ERRCODE = 'P0001';
    END IF;

    -- SPEC-302: devolução sem vínculo Connect — peça entregue antes da virada; não mistura com venda de origem.
    IF v_orcamento.subgrupo = 'TROCA DEV SEM VINCULO CONNECT' THEN
      IF EXISTS (SELECT 1 FROM public.orcamento_itens oi
                  WHERE oi.orcamento_id = p_orcamento_id
                    AND (oi.projeto_item_origem_id IS NOT NULL OR oi.origem_connect_venda IS NOT NULL)) THEN
        RAISE EXCEPTION 'Orçamento de devolução % (sem vínculo Connect) tem peça com venda de origem — faça duas devoluções.', v_numero_orcamento
          USING ERRCODE = 'P0001';
      END IF;
      IF EXISTS (SELECT 1 FROM public.orcamento_itens oi
                  WHERE oi.orcamento_id = p_orcamento_id AND (oi.produto_id IS NULL OR oi.quantidade <= 0)) THEN
        RAISE EXCEPTION 'Orçamento de devolução % (sem vínculo Connect): toda linha precisa de produto do cadastro e quantidade maior que zero.', v_numero_orcamento
          USING ERRCODE = 'P0001';
      END IF;
    END IF;$b$,
$a$WHERE oi.orcamento_id = p_orcamento_id AND oi.projeto_item_origem_id IS NULL AND oi.origem_connect_venda IS NULL
    ) THEN
      RAISE EXCEPTION 'Orçamento de devolução % possui item sem venda de origem vinculada.', v_numero_orcamento
        USING ERRCODE = 'P0001';
    END IF;$a$);
  IF v_novo = v_def THEN RAISE EXCEPTION 'SPEC-302 rollback: trecho 1 nao encontrado'; END IF;
  v_def := v_novo;

  v_novo := replace(v_novo,
$b$    -- SPEC-302: devolução sem vínculo Connect — a venda de registro nasce aprovada e a devolução só vincula.
    IF v_orcamento.subgrupo = 'TROCA DEV SEM VINCULO CONNECT' THEN
      DECLARE
        v_reg_id uuid := gen_random_uuid();
        v_reg_numero_venda text := 'REG-' || v_numero_orcamento;
        v_reg_total numeric;
        v_l record;
        v_pi_id uuid;
        v_oi_id uuid;
      BEGIN
        SELECT coalesce(sum(oi.quantidade * oi.preco_unitario - coalesce(oi.desconto, 0)), 0) INTO v_reg_total
          FROM public.orcamento_itens oi WHERE oi.orcamento_id = p_orcamento_id;

        INSERT INTO public.orcamentos
          (id, empresa_id, cliente_id, vendedor_id, projeto_id, equipe_id, digitado_por, status, natureza_operacao,
           numero_venda, origem, vinculo_connect, valor_total, data_emissao, observacoes, perfil, subgrupo)
        SELECT v_reg_id, o.empresa_id, o.cliente_id, o.vendedor_id, o.projeto_id, o.equipe_id, o.digitado_por,
               'Orçamento Aprovado', 'venda', v_reg_numero_venda, 'connect', false, v_reg_total, now(),
               format('Venda de registro (SPEC-302): peças entregues antes da virada da Connect, criada automaticamente pela devolução %s. Sem reserva, sem parcela, sem baixa de estoque.', v_numero_orcamento),
               o.perfil, 'VENDAS'
          FROM public.orcamentos o WHERE o.id = p_orcamento_id;

        FOR v_l IN
          SELECT oi.id, oi.produto_id, oi.descricao, oi.quantidade, oi.preco_unitario, coalesce(oi.desconto, 0) AS desconto
            FROM public.orcamento_itens oi WHERE oi.orcamento_id = p_orcamento_id ORDER BY oi.id
        LOOP
          v_oi_id := gen_random_uuid();
          INSERT INTO public.orcamento_itens (id, orcamento_id, produto_id, descricao, quantidade, preco_unitario, desconto)
          VALUES (v_oi_id, v_reg_id, v_l.produto_id, v_l.descricao, v_l.quantidade, v_l.preco_unitario, v_l.desconto);

          v_pi_id := gen_random_uuid();
          INSERT INTO public.projeto_itens (id, projeto_id, produto_id, descricao, quantidade, preco_unitario, desconto, orcamento_id, orcamento_item_id)
          VALUES (v_pi_id, v_orcamento.projeto_id, v_l.produto_id, v_l.descricao, v_l.quantidade, v_l.preco_unitario, v_l.desconto, v_reg_id, v_oi_id);

          INSERT INTO public.estoque_saldos_projeto_item (projeto_item_id, q_entregue)
          VALUES (v_pi_id, v_l.quantidade)
          ON CONFLICT (projeto_item_id) DO UPDATE SET q_entregue = EXCLUDED.q_entregue;

          UPDATE public.orcamento_itens SET projeto_item_origem_id = v_pi_id, setor_origem = 'entregue' WHERE id = v_l.id;
        END LOOP;

        -- o gatilho de workflow reescreve o status no INSERT; a venda de registro tem que ficar Aprovada.
        UPDATE public.orcamentos SET status = 'Orçamento Aprovado' WHERE id = v_reg_id;
      END;
    END IF;

    -- SPEC-178: linha com setor_origem devolve exatamente daquele setor$b$,
$a$    -- SPEC-178: linha com setor_origem devolve exatamente daquele setor$a$);
  IF v_novo = v_def THEN RAISE EXCEPTION 'SPEC-302 rollback: trecho 2 nao encontrado'; END IF;
  v_def := v_novo;

  EXECUTE v_novo;
END $$;
NOTIFY pgrst, 'reload schema';
COMMIT;
