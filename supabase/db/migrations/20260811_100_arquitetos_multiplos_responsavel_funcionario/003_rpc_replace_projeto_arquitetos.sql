-- Migration 20260811_100 — Parte 3
-- RPC pra substituir atomicamente a lista de arquitetos+percentual de um
-- projeto, mesmo molde de replace_orcamento_itens (delete+insert numa
-- função SECURITY DEFINER). Valida soma=100% e duplicata antes de
-- persistir; ao final sincroniza projetos.arquiteto_id (coluna singular
-- antiga) com o arquiteto de maior percentual, pra qualquer relatório ou
-- sistema que ainda leia esse campo continuar funcionando sem mudança.
--
-- Guard de permissão: mesmo nível já exigido pra editar um projeto hoje
-- (policy projetos_update): admin/gerente/operador, OU hub_pode_executar
-- do módulo 'crm' com ação 'editar' (SPEC-069).

CREATE OR REPLACE FUNCTION public.replace_projeto_arquitetos(
  p_projeto_id uuid,
  p_arquitetos jsonb
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $function$
DECLARE
  v_user_role text;
  v_soma numeric(7,2);
  v_qtd integer;
  v_qtd_distintos integer;
  v_arquiteto_maior uuid;
  v_inserted_count integer;
BEGIN
  IF COALESCE(auth.role(), '') <> 'service_role' THEN
    SELECT u.role INTO v_user_role FROM public.usuarios u WHERE u.id = auth.uid();

    IF NOT COALESCE(
      v_user_role IN ('admin', 'gerente', 'operador')
      OR public.hub_pode_executar(auth.uid(), 'crm', NULL, 'editar'),
      false
    ) THEN
      RAISE EXCEPTION 'Permissão negada para editar os arquitetos do projeto.' USING ERRCODE = 'P0001';
    END IF;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM public.projetos WHERE id = p_projeto_id) THEN
    RAISE EXCEPTION 'Projeto não encontrado.' USING ERRCODE = 'P0001';
  END IF;

  v_qtd := COALESCE(jsonb_array_length(p_arquitetos), 0);

  IF v_qtd > 0 THEN
    SELECT count(*) INTO v_qtd_distintos FROM (
      SELECT DISTINCT item->>'arquiteto_id' FROM jsonb_array_elements(p_arquitetos) AS item
    ) d;

    IF v_qtd_distintos < v_qtd THEN
      RAISE EXCEPTION 'Não é possível repetir o mesmo arquiteto no projeto.' USING ERRCODE = 'P0001';
    END IF;

    SELECT sum((item->>'percentual')::numeric) INTO v_soma
    FROM jsonb_array_elements(p_arquitetos) AS item;

    IF v_soma IS NULL OR abs(v_soma - 100) > 0.01 THEN
      RAISE EXCEPTION 'A soma dos percentuais dos arquitetos deve ser 100%% (recebido: %).', COALESCE(v_soma::text, 'null')
        USING ERRCODE = 'P0001';
    END IF;
  END IF;

  DELETE FROM public.projeto_arquitetos WHERE projeto_id = p_projeto_id;

  INSERT INTO public.projeto_arquitetos (projeto_id, arquiteto_id, percentual)
  SELECT p_projeto_id, (item->>'arquiteto_id')::uuid, (item->>'percentual')::numeric
  FROM jsonb_array_elements(p_arquitetos) AS item;

  GET DIAGNOSTICS v_inserted_count = ROW_COUNT;

  SELECT arquiteto_id INTO v_arquiteto_maior
  FROM public.projeto_arquitetos
  WHERE projeto_id = p_projeto_id
  ORDER BY percentual DESC, created_at ASC
  LIMIT 1;

  UPDATE public.projetos SET arquiteto_id = v_arquiteto_maior WHERE id = p_projeto_id;

  RETURN jsonb_build_object('projeto_id', p_projeto_id, 'arquitetos_salvos', v_inserted_count, 'arquiteto_principal', v_arquiteto_maior);
END;
$function$;

COMMENT ON FUNCTION public.replace_projeto_arquitetos(uuid, jsonb) IS
'Substitui atomicamente os arquitetos vinculados a um projeto, com percentual
de participação na divisão de lucro. Valida duplicata e soma=100% (quando o
array não é vazio). Sincroniza projetos.arquiteto_id (coluna singular legada)
com o arquiteto de maior percentual, pra compatibilidade com o que ainda lê
esse campo.';

GRANT EXECUTE ON FUNCTION public.replace_projeto_arquitetos(uuid, jsonb) TO authenticated;
