-- Rollback da 288: tira o gatilho das tabelas novas e restaura auditoria.referencia. Os eventos já gravados são mantidos.
BEGIN;
DO $$
DECLARE t text;
BEGIN
  FOREACH t IN ARRAY ARRAY['transacoes','negociacoes','plano_de_contas','contas_bancarias','empresas','pedido_compra_parcelas','notas_fiscais_connect',
                           'notas_fiscais_connect_duplicatas','equipes_projetos','retorno_bancario_arquivos','contato_legado_ids','vendas_connect','connect_financeiro_encerrado'] LOOP
    IF to_regclass('public.' || t) IS NOT NULL THEN EXECUTE format('DROP TRIGGER IF EXISTS auditoria_registrar ON public.%I', t); END IF;
  END LOOP;
END $$;
CREATE OR REPLACE FUNCTION auditoria.referencia(p_tabela text, r jsonb)
 RETURNS text
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  v_proj text;
BEGIN
  IF r ? 'projeto_id' AND nullif(r->>'projeto_id', '') IS NOT NULL THEN
    SELECT concat_ws(' ', p.codigo, p.nome) INTO v_proj FROM public.projetos p WHERE p.id = (r->>'projeto_id')::uuid;
  END IF;
  RETURN CASE p_tabela
    WHEN 'orcamentos'          THEN concat_ws(' ', 'Orçamento', coalesce(r->>'numero', '(sem número)'))
    WHEN 'projetos'            THEN concat_ws(' ', 'Projeto', r->>'codigo', r->>'nome')
    WHEN 'contatos'            THEN concat_ws(' ', initcap(coalesce(r->>'tipo', 'contato')), r->>'nome')
    WHEN 'vendas'              THEN concat_ws(' ', 'Venda', r->>'cod_venda', r->>'nome_cliente')
    WHEN 'notas_fiscais'       THEN concat_ws(' ', 'NF', coalesce(r->>'numero_nf', '(sem número)'), r->>'nome_destinatario')
    WHEN 'boletos'             THEN concat_ws(' ', 'Boleto', coalesce(r->>'numero_documento', r->>'nosso_numero'), r->>'nome_pagador')
    WHEN 'projeto_arquitetos'  THEN concat_ws(' ', 'Arquiteto do projeto', v_proj,
                                     (SELECT '— ' || c.nome FROM public.contatos c WHERE c.id = (r->>'arquiteto_id')::uuid))
    WHEN 'projeto_parcelas'    THEN concat_ws(' ', 'Parcela', r->>'numero_parcela', 'do projeto', v_proj)
    -- SPEC-226: número da entrega (LUC-0001) junto, é o que o estoque usa
    WHEN 'separacoes'          THEN concat_ws(' ', 'Separação', r->>'numero_entrega',
                                     coalesce(r->>'numero_venda', r->>'codigo_obra'), r->>'cliente')
    WHEN 'entregas_finalizadas' THEN concat_ws(' ', 'Entrega', r->>'numero_entrega', r->>'codigo_obra', r->>'cliente')
    WHEN 'entregas_pendentes'  THEN concat_ws(' ', 'Problema na entrega', r->>'codigo_obra', r->>'cliente')
    WHEN 'separacao_arquivos'  THEN concat_ws(' ', 'Anexo', r->>'nome_arquivo', '—',
                                     (SELECT concat_ws(' ', 'Separação', s.numero_entrega, s.cliente)
                                        FROM public.separacoes s WHERE s.id = (r->>'separacao_id')::uuid))
    WHEN 'estoque_itens'       THEN concat_ws(' ', 'Estoque',
                                     (SELECT concat_ws(' ', pr.codigo_produto, pr.nome) FROM public.produtos pr WHERE pr.id = (r->>'produto_id')::uuid),
                                     '· ' || (r->>'local'))
    WHEN 'devolucoes_estoque'  THEN 'Devolução de estoque'
    WHEN 'entregas'            THEN concat_ws(' ', 'Entrega', v_proj)
    WHEN 'cotacoes_compra'     THEN concat_ws(' ', 'Cotação', r->>'numero')
    WHEN 'pedidos_compra'      THEN concat_ws(' ', 'Pedido de compra', r->>'numero')
    WHEN 'producao_pedidos'    THEN concat_ws(' ', 'Pedido de produção', r->>'numero_pedido', r->>'cliente_nome')
    WHEN 'garantia_itens'      THEN concat_ws(' ', 'Garantia', coalesce(r->>'cliente_nome', r->>'produto_descricao_livre'))
    WHEN 'garantia_protocolos' THEN concat_ws(' ', 'Protocolo de garantia', r->>'responsavel_nome')
    WHEN 'produtos'            THEN concat_ws(' ', 'Peça', r->>'codigo_produto', r->>'nome')
    WHEN 'fornecedores'        THEN concat_ws(' ', 'Fornecedor', r->>'nome')
    WHEN 'funcionarios'        THEN concat_ws(' ', 'Funcionário', r->>'nome')
    WHEN 'usuarios'            THEN concat_ws(' ', 'Usuário', coalesce(r->>'nome', r->>'email'))
    WHEN 'usuario_papeis'      THEN concat_ws(' ', 'Papel', (SELECT pa.nome FROM public.papeis pa WHERE pa.id = (r->>'papel_id')::uuid),
                                     'de', auditoria.nome_usuario((r->>'usuario_id')::uuid))
    WHEN 'user_system_access'  THEN concat_ws(' ', 'Acesso de', auditoria.nome_usuario((r->>'user_id')::uuid), 'ao',
                                     (SELECT sy.name FROM public.systems sy WHERE sy.id = (r->>'system_id')::uuid))
    ELSE p_tabela
  END;
EXCEPTION WHEN OTHERS THEN
  RETURN p_tabela;
END $function$
;
COMMIT;
