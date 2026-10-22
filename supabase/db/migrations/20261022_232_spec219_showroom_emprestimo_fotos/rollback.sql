-- Rollback SPEC-219 fase 2 (fotos): volta registrar_devolucao e listar da migration 231 e tira as fotos.
-- ATENÇÃO: as fotos já enviadas ficam no bucket (storage não apaga por SQL); copiar a tabela antes se houver dado:
--   CREATE TABLE backup._bkp_showroom_emprestimo_fotos_AAAAMMDD AS SELECT * FROM public.showroom_emprestimo_fotos;
BEGIN;
DROP POLICY IF EXISTS showroom_emprestimos_fotos_insert ON storage.objects;
DROP POLICY IF EXISTS showroom_emprestimos_fotos_select ON storage.objects;
DROP FUNCTION IF EXISTS public.showroom_emp_liberar_fotos(text, text, uuid, text, uuid, text[]);
DROP FUNCTION IF EXISTS public.showroom_emp_confirmar_fotos_saida(text, text, uuid, text[]);
DROP FUNCTION IF EXISTS public.showroom_emp_liberar_leitura_fotos(text, text, uuid);
DROP FUNCTION IF EXISTS public.showroom_emp_registrar_devolucao(text, text, uuid, boolean, text, numeric, text[]);
DROP FUNCTION IF EXISTS public.showroom_emp_gravar_fotos(text, uuid, text, uuid, text[]);
DROP FUNCTION IF EXISTS public.showroom_emp_foto_permitida(text, boolean);
DROP FUNCTION IF EXISTS public.showroom_emp_listar(text, text, text, text);
DROP TABLE IF EXISTS public.showroom_emp_foto_grants;
DROP TABLE IF EXISTS public.showroom_emprestimo_fotos;

CREATE OR REPLACE FUNCTION public.showroom_emp_registrar_devolucao(
  p_user text,
  p_senha text,
  p_item_id uuid,
  p_com_dano boolean,
  p_descricao_dano text DEFAULT NULL,
  p_valor_dano numeric DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_item     record;
  v_integral numeric;
  v_valor    numeric;
BEGIN
  IF NOT public.showroom_cred_ok(p_user, p_senha) THEN
    RAISE EXCEPTION 'usuario ou senha invalidos' USING ERRCODE = '28000';
  END IF;
  SELECT i.*, e.cancelado_em
    INTO v_item
    FROM showroom_emprestimo_itens i
    JOIN showroom_emprestimos e ON e.id = i.emprestimo_id
   WHERE i.id = p_item_id
     FOR UPDATE OF i;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Peça do empréstimo não encontrada.' USING ERRCODE = '22023';
  END IF;
  IF v_item.cancelado_em IS NOT NULL THEN
    RAISE EXCEPTION 'Empréstimo cancelado.' USING ERRCODE = '22023';
  END IF;
  IF v_item.situacao <> 'emprestado' THEN
    RAISE EXCEPTION 'Esta peça já foi devolvida.' USING ERRCODE = '22023';
  END IF;

  IF coalesce(p_com_dano, false) THEN
    IF nullif(trim(coalesce(p_descricao_dano, '')), '') IS NULL THEN
      RAISE EXCEPTION 'Descreva o dano.' USING ERRCODE = '22023';
    END IF;
    v_integral := round(v_item.valor_unitario * v_item.quantidade, 2);
    v_valor := round(coalesce(p_valor_dano, v_integral), 2);
    IF v_valor < 0 OR v_valor > v_integral THEN
      RAISE EXCEPTION 'O valor do dano deve ficar entre 0 e o valor integral (%).', v_integral
        USING ERRCODE = '22023';
    END IF;
    UPDATE showroom_emprestimo_itens
       SET situacao = 'devolvido_com_dano',
           data_devolucao = (now() AT TIME ZONE 'America/Sao_Paulo')::date,
           descricao_dano = trim(p_descricao_dano),
           valor_dano = v_valor,
           devolvido_registrado_por = p_user
     WHERE id = p_item_id;
  ELSE
    UPDATE showroom_emprestimo_itens
       SET situacao = 'devolvido',
           data_devolucao = (now() AT TIME ZONE 'America/Sao_Paulo')::date,
           devolvido_registrado_por = p_user
     WHERE id = p_item_id;
  END IF;

  RETURN jsonb_build_object('ok', true, 'status', public.showroom_emp_status(v_item.emprestimo_id));
END;
$$;

CREATE OR REPLACE FUNCTION public.showroom_emp_listar(
  p_user text,
  p_senha text,
  p_status text DEFAULT NULL,
  p_termo text DEFAULT NULL
)
RETURNS TABLE (
  id uuid,
  numero integer,
  empresa_nome text,
  cliente_nome text,
  data_emprestimo date,
  data_prevista_devolucao date,
  status text,
  qtd_pecas integer,
  qtd_pecas_em_aberto integer,
  valor_total numeric,
  valor_dano numeric,
  criado_em timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_termo text := nullif(trim(coalesce(p_termo, '')), '');
BEGIN
  IF NOT public.showroom_cred_ok(p_user, p_senha) THEN
    RAISE EXCEPTION 'usuario ou senha invalidos' USING ERRCODE = '28000';
  END IF;
  RETURN QUERY
  SELECT * FROM (
    SELECT e.id,
           e.numero,
           emp.nome,
           e.cliente_snapshot->>'nome',
           e.data_emprestimo,
           e.data_prevista_devolucao,
           public.showroom_emp_status(e.id) AS st,
           coalesce(sum(i.quantidade), 0)::integer,
           coalesce(sum(i.quantidade) FILTER (WHERE i.situacao = 'emprestado'), 0)::integer,
           coalesce(sum(i.quantidade * i.valor_unitario), 0),
           coalesce(sum(i.valor_dano) FILTER (WHERE i.situacao = 'devolvido_com_dano'), 0),
           e.criado_em
      FROM showroom_emprestimos e
      JOIN empresas emp ON emp.id = e.empresa_id
      LEFT JOIN showroom_emprestimo_itens i ON i.emprestimo_id = e.id
     WHERE v_termo IS NULL
        OR e.cliente_snapshot->>'nome' ILIKE '%' || v_termo || '%'
        OR e.numero::text = regexp_replace(v_termo, '\D', '', 'g')
     GROUP BY e.id, emp.nome
  ) t
  WHERE p_status IS NULL
     OR t.st = p_status
     OR (p_status = 'em_aberto' AND t.st = 'atrasado')
  ORDER BY t.criado_em DESC
  LIMIT 500;
END;
$$;

REVOKE ALL ON FUNCTION public.showroom_emp_registrar_devolucao(text, text, uuid, boolean, text, numeric) FROM public, authenticated;
REVOKE ALL ON FUNCTION public.showroom_emp_listar(text, text, text, text) FROM public, authenticated;
GRANT EXECUTE ON FUNCTION public.showroom_emp_registrar_devolucao(text, text, uuid, boolean, text, numeric) TO anon;
GRANT EXECUTE ON FUNCTION public.showroom_emp_listar(text, text, text, text) TO anon;
COMMIT;
-- O bucket showroom-emprestimos fica (vazio ou com as fotos); apagar pelo painel se quiser.
