-- Migration 20260811_100 — Parte 4
-- Mesmo desenho de replace_projeto_arquitetos (parte 3 desta pasta), agora
-- pra orçamentos. Guard de permissão: mesmo nível já exigido pra editar um
-- orçamento hoje (policy spec069_orcamentos_update): hub_pode_executar do
-- módulo 'orcamentos' com ação 'editar'.

CREATE OR REPLACE FUNCTION public.replace_orcamento_arquitetos(
  p_orcamento_id uuid,
  p_arquitetos jsonb
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $function$
DECLARE
  v_soma numeric(7,2);
  v_qtd integer;
  v_qtd_distintos integer;
  v_arquiteto_maior uuid;
  v_inserted_count integer;
BEGIN
  IF COALESCE(auth.role(), '') <> 'service_role'
     AND NOT public.hub_pode_executar(auth.uid(), 'orcamentos', NULL, 'editar') THEN
    RAISE EXCEPTION 'Permissão negada para editar os arquitetos do orçamento.' USING ERRCODE = 'P0001';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM public.orcamentos WHERE id = p_orcamento_id) THEN
    RAISE EXCEPTION 'Orçamento não encontrado.' USING ERRCODE = 'P0001';
  END IF;

  v_qtd := COALESCE(jsonb_array_length(p_arquitetos), 0);

  IF v_qtd > 0 THEN
    SELECT count(*) INTO v_qtd_distintos FROM (
      SELECT DISTINCT item->>'arquiteto_id' FROM jsonb_array_elements(p_arquitetos) AS item
    ) d;

    IF v_qtd_distintos < v_qtd THEN
      RAISE EXCEPTION 'Não é possível repetir o mesmo arquiteto no orçamento.' USING ERRCODE = 'P0001';
    END IF;

    SELECT sum((item->>'percentual')::numeric) INTO v_soma
    FROM jsonb_array_elements(p_arquitetos) AS item;

    IF v_soma IS NULL OR abs(v_soma - 100) > 0.01 THEN
      RAISE EXCEPTION 'A soma dos percentuais dos arquitetos deve ser 100%% (recebido: %).', COALESCE(v_soma::text, 'null')
        USING ERRCODE = 'P0001';
    END IF;
  END IF;

  DELETE FROM public.orcamento_arquitetos WHERE orcamento_id = p_orcamento_id;

  INSERT INTO public.orcamento_arquitetos (orcamento_id, arquiteto_id, percentual)
  SELECT p_orcamento_id, (item->>'arquiteto_id')::uuid, (item->>'percentual')::numeric
  FROM jsonb_array_elements(p_arquitetos) AS item;

  GET DIAGNOSTICS v_inserted_count = ROW_COUNT;

  SELECT arquiteto_id INTO v_arquiteto_maior
  FROM public.orcamento_arquitetos
  WHERE orcamento_id = p_orcamento_id
  ORDER BY percentual DESC, created_at ASC
  LIMIT 1;

  UPDATE public.orcamentos SET arquiteto_id = v_arquiteto_maior WHERE id = p_orcamento_id;

  RETURN jsonb_build_object('orcamento_id', p_orcamento_id, 'arquitetos_salvos', v_inserted_count, 'arquiteto_principal', v_arquiteto_maior);
END;
$function$;

COMMENT ON FUNCTION public.replace_orcamento_arquitetos(uuid, jsonb) IS
'Substitui atomicamente os arquitetos vinculados a um orçamento, com
percentual de participação na divisão de lucro. Valida duplicata e
soma=100% (quando o array não é vazio). Sincroniza orcamentos.arquiteto_id
(coluna singular legada) com o arquiteto de maior percentual.';

GRANT EXECUTE ON FUNCTION public.replace_orcamento_arquitetos(uuid, jsonb) TO authenticated;
