-- Dry-run da 275: aplica o rascunho, confere a lista (origem), barra Marina na herança e libera admin. Termina em ROLLBACK.
BEGIN;
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


CREATE TEMP TABLE _ctx (k text PRIMARY KEY, v text);
GRANT SELECT ON _ctx TO authenticated;
INSERT INTO _ctx SELECT 'nota', id::text FROM public.notas_fiscais_compra LIMIT 1;
INSERT INTO _ctx SELECT 'connect_pi', pi.id::text || '|' || pi.produto_id::text
  FROM public.projeto_itens pi JOIN public.orcamentos o ON o.id = pi.orcamento_id WHERE o.origem = 'connect' LIMIT 1;
INSERT INTO _ctx SELECT 'sistema_pi', pi.id::text || '|' || pi.produto_id::text
  FROM public.projeto_itens pi JOIN public.orcamentos o ON o.id = pi.orcamento_id WHERE o.origem IS DISTINCT FROM 'connect' LIMIT 1;
INSERT INTO _ctx SELECT 'admin', id::text FROM public.usuarios WHERE role::text = 'admin' ORDER BY id LIMIT 1;

DO $$ BEGIN
  RAISE NOTICE 'ctx: %', (SELECT string_agg(k || '=' || CASE WHEN v IS NULL THEN 'NULL' ELSE 'ok' END, ', ') FROM _ctx);
  RAISE NOTICE 'lista (sem login de admin, direto): conectadas com origem=connect: %',
    (SELECT count(*) FROM public.estoque_saldos_projeto_item s JOIN public.projeto_itens pi ON pi.id = s.projeto_item_id
       JOIN public.orcamentos o ON o.id = pi.orcamento_id WHERE s.q_entrega_futura > 0 AND o.origem = 'connect');
END $$;

-- a lista devolve a coluna origem (como admin)
SELECT set_config('request.jwt.claims', json_build_object('role','authenticated','sub',(SELECT v FROM _ctx WHERE k='admin'))::text, true);
DO $$
DECLARE r record; n_c int := 0; n_s int := 0; prods uuid[];
BEGIN
  SELECT array_agg(DISTINCT pi.produto_id) INTO prods FROM public.estoque_saldos_projeto_item s JOIN public.projeto_itens pi ON pi.id = s.projeto_item_id WHERE s.q_entrega_futura > 0;
  FOR r IN SELECT * FROM public.entregas_futuras_para_entrada(prods) LOOP
    IF r.origem = 'connect' THEN n_c := n_c + 1; ELSE n_s := n_s + 1; END IF;
  END LOOP;
  RAISE NOTICE 'lista com origem: connect=% sistema=% (esperado: sistema primeiro, connect por ultimo)', n_c, n_s;
  RAISE NOTICE 'primeira linha origem=%, ultima=%', (SELECT origem FROM public.entregas_futuras_para_entrada(prods) LIMIT 1),
    (SELECT origem FROM (SELECT origem, row_number() OVER () rn FROM public.entregas_futuras_para_entrada(prods)) x ORDER BY rn DESC LIMIT 1);
  RAISE NOTICE 'admin pode vincular heranca: %', public.pode_vincular_heranca_connect();
EXCEPTION WHEN OTHERS THEN RAISE NOTICE 'ERRO na lista como admin: %', SQLERRM;
END $$;

-- 1) Marina (projetista) NAO pode vincular herança; PODE vincular peça do sistema
SELECT set_config('request.jwt.claims', '{"role":"authenticated","sub":"438d37e0-ae72-4226-83c7-15d501a49dd4"}', true);
DO $$
DECLARE nota uuid := (SELECT v::uuid FROM _ctx WHERE k='nota');
        c text := (SELECT v FROM _ctx WHERE k='connect_pi'); s text := (SELECT v FROM _ctx WHERE k='sistema_pi');
BEGIN
  RAISE NOTICE 'Marina pode vincular heranca: %', public.pode_vincular_heranca_connect();
  IF nota IS NULL OR c IS NULL THEN RAISE NOTICE 'sem nota ou item Connect para testar'; RETURN; END IF;
  BEGIN
    INSERT INTO public.nota_fiscal_compra_vinculos (nota_id, produto_id, projeto_item_id, quantidade)
    VALUES (nota, split_part(c,'|',2)::uuid, split_part(c,'|',1)::uuid, 1);
    RAISE NOTICE 'FALHOU: Marina vinculou herança';
  EXCEPTION WHEN insufficient_privilege THEN RAISE NOTICE 'OK: Marina barrada: %', SQLERRM; END;
  IF s IS NOT NULL THEN
    INSERT INTO public.nota_fiscal_compra_vinculos (nota_id, produto_id, projeto_item_id, quantidade)
    VALUES (nota, split_part(s,'|',2)::uuid, split_part(s,'|',1)::uuid, 1);
    RAISE NOTICE 'OK: Marina vinculou peça do sistema (nao afetada)';
  ELSE RAISE NOTICE 'sem item do sistema para testar'; END IF;
END $$;

-- 2) admin pode vincular herança
SELECT set_config('request.jwt.claims', json_build_object('role','authenticated','sub',(SELECT v FROM _ctx WHERE k='admin'))::text, true);
DO $$
DECLARE nota uuid := (SELECT v::uuid FROM _ctx WHERE k='nota'); c text := (SELECT v FROM _ctx WHERE k='connect_pi');
BEGIN
  IF nota IS NULL OR c IS NULL THEN RETURN; END IF;
  INSERT INTO public.nota_fiscal_compra_vinculos (nota_id, produto_id, projeto_item_id, quantidade)
  VALUES (nota, split_part(c,'|',2)::uuid, split_part(c,'|',1)::uuid, 1);
  RAISE NOTICE 'OK: admin vinculou herança';
EXCEPTION WHEN OTHERS THEN RAISE NOTICE 'FALHOU admin: %', SQLERRM;
END $$;
ROLLBACK;
