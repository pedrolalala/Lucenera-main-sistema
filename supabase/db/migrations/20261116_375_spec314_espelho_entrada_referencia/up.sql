-- SPEC-314: espelho da entrada de NF passa a trazer a REFERENCIA (codigo do fornecedor) de cada item,
-- para os meninos acharem a peca no estoque. So acrescenta a chave 'referencia' no JSON.
BEGIN;

CREATE OR REPLACE FUNCTION public.espelho_entrada_nota_compra(p_nota_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v jsonb;
BEGIN
  IF NOT (public.hub_pode_executar(auth.uid(), 'necessidade-de-compra', NULL, NULL)
          OR public.pode_acessar_sistema('separacao-parcial') OR public.pode_acessar_sistema('logistica')) THEN
    RAISE EXCEPTION 'Sem permissao.' USING ERRCODE = '42501';
  END IF;
  SELECT jsonb_build_object(
    'nota', jsonb_build_object('id', n.id, 'numero_nf', n.numero_nf, 'chave_acesso', n.chave_acesso,
             'data_emissao', n.data_emissao, 'data_entrega', n.data_entrega, 'data_entrada', n.data_entrada,
             'valor', n.valor, 'valor_st', n.valor_st, 'valor_desconto', n.valor_desconto,
             'valor_despesas_acessorias', n.valor_despesas_acessorias, 'valor_frete', n.valor_frete, 'observacao', n.observacao,
             'cancelada_em', n.cancelada_em, 'criado_em', n.criado_em,
             'pedido_numero', p.numero, 'fornecedor_nome', f.nome,
             'fornecedor_documento', regexp_replace(coalesce(nullif(f.cnpj, ''), f.cpf_cnpj, ''), '\D', '', 'g'),
             'empresa_nome', e.nome, 'apropriacao', pc.nome, 'lancado_por', u.nome),
    'itens', coalesce((
      SELECT jsonb_agg(jsonb_build_object('produto_id', g.produto_id, 'codigo', g.codigo, 'referencia', g.referencia, 'produto', g.produto,
               'quantidade', g.quantidade, 'valor_unitario', g.valor_unitario, 'valor_ipi', g.valor_ipi,
               'valor_st', g.valor_st) ORDER BY g.produto)
        FROM (SELECT pi.produto_id, pr.codigo_produto AS codigo, pr.referencia AS referencia, pr.nome AS produto, sum(x.quantidade) AS quantidade,
                     max(x.valor_unitario) AS valor_unitario, max(x.valor_ipi) AS valor_ipi, max(x.valor_st) AS valor_st
                FROM public.nota_fiscal_compra_itens x
                JOIN public.pedido_compra_itens pi ON pi.id = x.pedido_item_id
                JOIN public.produtos pr ON pr.id = pi.produto_id
               WHERE x.nota_id = n.id
               GROUP BY pi.produto_id, pr.codigo_produto, pr.referencia, pr.nome) g), '[]'::jsonb),
    'vinculos', coalesce((
      SELECT jsonb_agg(jsonb_build_object('produto_id', v.produto_id, 'quantidade', v.quantidade,
               'venda_numero', o.numero_venda, 'orcamento_numero', o.numero, 'cliente_nome', c.nome,
               'l_fixo', pit.l_fixo, 'projeto_codigo', prj.codigo) ORDER BY o.numero_venda, pit.l_fixo)
        FROM public.nota_fiscal_compra_vinculos v
        JOIN public.projeto_itens pit ON pit.id = v.projeto_item_id
        LEFT JOIN public.orcamentos o ON o.id = pit.orcamento_id
        LEFT JOIN public.projetos prj ON prj.id = pit.projeto_id
        LEFT JOIN public.contatos c ON c.id = coalesce(o.cliente_id, prj.cliente_id)
       WHERE v.nota_id = n.id), '[]'::jsonb),
    'parcelas', coalesce((
      SELECT jsonb_agg(jsonb_build_object('numero', np.numero_parcela, 'vencimento', np.data_vencimento,
               'valor', np.valor) ORDER BY np.numero_parcela)
        FROM public.nota_fiscal_compra_parcelas np WHERE np.nota_id = n.id), '[]'::jsonb),
    'antecipacao', coalesce((SELECT sum(valor_aplicado) FROM public.pagamento_antecipado_vinculos WHERE nota_id = n.id), 0))
    INTO v
    FROM public.notas_fiscais_compra n
    LEFT JOIN public.pedidos_compra p ON p.id = n.pedido_compra_id
    LEFT JOIN public.contatos f ON f.id = coalesce(n.fornecedor_id, p.fornecedor_id)
    LEFT JOIN public.empresas e ON e.id = coalesce(n.empresa_id, p.empresa_id)
    LEFT JOIN public.plano_de_contas pc ON pc.id = n.plano_contas_id
    LEFT JOIN public.usuarios u ON u.id = n.criado_por
   WHERE n.id = p_nota_id;
  IF v IS NULL THEN
    RAISE EXCEPTION 'Nota fiscal nao encontrada.' USING ERRCODE = 'P0001';
  END IF;
  RETURN v;
END;
$function$;

COMMIT;
