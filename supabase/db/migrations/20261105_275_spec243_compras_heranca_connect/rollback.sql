-- Rollback da 275: volta a lista sem a coluna `origem` e tira a trava da herança. Vínculos já gravados não são tocados.
BEGIN;
DROP TRIGGER IF EXISTS trg_nf_vinculo_heranca_connect ON public.nota_fiscal_compra_vinculos;
DROP FUNCTION IF EXISTS public.trg_nf_vinculo_heranca_connect();
DROP FUNCTION IF EXISTS public.pode_vincular_heranca_connect();

DROP FUNCTION IF EXISTS public.entregas_futuras_para_entrada(uuid[]);
CREATE FUNCTION public.entregas_futuras_para_entrada(p_produto_ids uuid[])
 RETURNS TABLE(projeto_item_id uuid, produto_id uuid, venda_numero text, orcamento_numero text, projeto_codigo text,
               cliente_nome text, l_fixo text, empresa_nome text, q_entrega_futura numeric)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  IF NOT public.hub_pode_executar(auth.uid(), 'necessidade-de-compra', NULL, NULL) THEN
    RAISE EXCEPTION 'Sem permissao.' USING ERRCODE = '42501';
  END IF;
  RETURN QUERY
  SELECT s.projeto_item_id, pi.produto_id, o.numero_venda::text, o.numero::text, pr.codigo::text,
         coalesce(c.nome, '—')::text, pi.l_fixo, e.nome::text, s.q_entrega_futura
    FROM public.estoque_saldos_projeto_item s
    JOIN public.projeto_itens pi ON pi.id = s.projeto_item_id
    LEFT JOIN public.orcamentos o ON o.id = pi.orcamento_id
    LEFT JOIN public.projetos pr ON pr.id = pi.projeto_id
    LEFT JOIN public.contatos c ON c.id = coalesce(o.cliente_id, pr.cliente_id)
    LEFT JOIN public.empresas e ON e.id = o.empresa_id
   WHERE pi.produto_id = ANY (p_produto_ids)
     AND s.q_entrega_futura > 0
   ORDER BY o.numero_venda NULLS LAST, pi.l_fixo;
END;
$function$;
REVOKE ALL ON FUNCTION public.entregas_futuras_para_entrada(uuid[]) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.entregas_futuras_para_entrada(uuid[]) TO authenticated;
COMMIT;
