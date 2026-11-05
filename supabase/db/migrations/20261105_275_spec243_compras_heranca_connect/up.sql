-- SPEC-243 item I (RASCUNHO, NÃO APLICADA) — Compras (entrada de NF): a herança da Connect aparece junto na lista "para quem vai", marcada,
-- e SÓ a Débora e a administração podem vincular a chegada a ela.
--
-- Hoje `entregas_futuras_para_entrada` já devolve a Entrega Futura da Connect (os itens dela têm saldo), mas sem dizer que é herança.
-- O vínculo da NF (SPEC-220) continua o mesmo: entrega futura -> reserva do L; o reservado total NÃO muda (regra A: reservado = Reserva + Entrega Futura),
-- o Estoque Geral NÃO é tocado por este vínculo e nada vai para Contas a Pagar/Receber.
--
-- A trava fica no banco (trigger em `nota_fiscal_compra_vinculos`), então vale também se alguém chamar a RPC direto; não é preciso reescrever
-- `registrar_entrada_nota_compra`. Quem pode = mesma regra da caixa fechada (SPEC-240, `pode_editar_caixa_fechada`): admin, editores da Débora e papel
-- `administracao_comercial`. Sem usuário logado (script/serviço) não trava, igual à caixa fechada.
BEGIN;

CREATE OR REPLACE FUNCTION public.pode_vincular_heranca_connect()
 RETURNS boolean
 LANGUAGE sql
 STABLE
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  SELECT public.pode_editar_caixa_fechada();
$function$;
REVOKE ALL ON FUNCTION public.pode_vincular_heranca_connect() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.pode_vincular_heranca_connect() TO authenticated;

CREATE OR REPLACE FUNCTION public.trg_nf_vinculo_heranca_connect()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  IF auth.uid() IS NULL THEN
    RETURN NEW;
  END IF;
  IF EXISTS (SELECT 1 FROM public.projeto_itens pi JOIN public.orcamentos o ON o.id = pi.orcamento_id
              WHERE pi.id = NEW.projeto_item_id AND o.origem = 'connect')
     AND NOT public.pode_vincular_heranca_connect() THEN
    RAISE EXCEPTION 'Só a Débora e a administração podem vincular a chegada de uma peça à herança da Connect.'
      USING ERRCODE = '42501';
  END IF;
  RETURN NEW;
END;
$function$;

DROP TRIGGER IF EXISTS trg_nf_vinculo_heranca_connect ON public.nota_fiscal_compra_vinculos;
CREATE TRIGGER trg_nf_vinculo_heranca_connect
  BEFORE INSERT ON public.nota_fiscal_compra_vinculos
  FOR EACH ROW EXECUTE FUNCTION public.trg_nf_vinculo_heranca_connect();

-- A lista passa a dizer de onde vem cada entrega futura (coluna nova no retorno => DROP antes, para não ficar sobrecarga).
DROP FUNCTION IF EXISTS public.entregas_futuras_para_entrada(uuid[]);
CREATE FUNCTION public.entregas_futuras_para_entrada(p_produto_ids uuid[])
 RETURNS TABLE(projeto_item_id uuid, produto_id uuid, venda_numero text, orcamento_numero text, projeto_codigo text,
               cliente_nome text, l_fixo text, empresa_nome text, q_entrega_futura numeric, origem text)
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
         coalesce(c.nome, '—')::text, pi.l_fixo, e.nome::text, s.q_entrega_futura,
         CASE WHEN o.origem = 'connect' THEN 'connect' ELSE 'sistema' END::text
    FROM public.estoque_saldos_projeto_item s
    JOIN public.projeto_itens pi ON pi.id = s.projeto_item_id
    LEFT JOIN public.orcamentos o ON o.id = pi.orcamento_id
    LEFT JOIN public.projetos pr ON pr.id = pi.projeto_id
    LEFT JOIN public.contatos c ON c.id = coalesce(o.cliente_id, pr.cliente_id)
    LEFT JOIN public.empresas e ON e.id = o.empresa_id
   WHERE pi.produto_id = ANY (p_produto_ids)
     AND s.q_entrega_futura > 0
   ORDER BY (o.origem = 'connect') NULLS FIRST, o.numero_venda NULLS LAST, pi.l_fixo;
END;
$function$;
REVOKE ALL ON FUNCTION public.entregas_futuras_para_entrada(uuid[]) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.entregas_futuras_para_entrada(uuid[]) TO authenticated;

COMMIT;
