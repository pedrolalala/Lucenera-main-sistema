-- SPEC-262: criar Grupo / Subgrupo / Apropriacao do plano de contas pela tela (Contas a Pagar/Receber).
-- plano_de_contas so tinha escrita para service_role (carga da Connect). Esta funcao e a unica porta para o usuario:
--   * exige login e permissao 'criar' no financeiro (hub_pode_executar; admin passa);
--   * nivel 1 (grupo) exige tipo existente; nivel 2/3 herdam o tipo do pai (pai precisa estar um nivel acima e ativo);
--   * nome em MAIUSCULAS (padrao da Connect), sem duplicar no mesmo pai (ignora caixa/espacos);
--   * codigo_connect (obrigatorio, unico por nivel+pai) nasce na faixa 800.000.001+, longe dos codigos da Connect (max 90.000.035).
CREATE OR REPLACE FUNCTION public.plano_contas_criar(p_nome text, p_nivel smallint, p_parent_id uuid DEFAULT NULL, p_tipo text DEFAULT NULL)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $fn$
DECLARE
  v_nome text := upper(btrim(regexp_replace(coalesce(p_nome, ''), '\s+', ' ', 'g')));
  v_tipo text;
  v_codigo bigint;
  v_id uuid;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Faça login para criar.'; END IF;
  IF NOT public.hub_pode_executar(auth.uid(), 'financeiro', NULL, 'criar') THEN
    RAISE EXCEPTION 'Sem permissão para criar no plano de contas.';
  END IF;
  IF v_nome = '' OR length(v_nome) > 80 THEN RAISE EXCEPTION 'Informe um nome (até 80 caracteres).'; END IF;
  IF p_nivel IS NULL OR p_nivel NOT IN (1, 2, 3) THEN RAISE EXCEPTION 'Nível inválido (1=Grupo, 2=Subgrupo, 3=Apropriação).'; END IF;

  IF p_nivel = 1 THEN
    IF p_parent_id IS NOT NULL THEN RAISE EXCEPTION 'Grupo não tem pai.'; END IF;
    IF p_tipo IS NULL OR NOT EXISTS (SELECT 1 FROM public.plano_de_contas WHERE nivel = 1 AND tipo = p_tipo) THEN
      RAISE EXCEPTION 'Tipo do grupo inválido.';
    END IF;
    v_tipo := p_tipo;
  ELSE
    SELECT tipo INTO v_tipo FROM public.plano_de_contas
     WHERE id = p_parent_id AND nivel = p_nivel - 1 AND ativo;
    IF NOT FOUND THEN RAISE EXCEPTION 'Escolha antes o %.', CASE p_nivel WHEN 2 THEN 'Grupo' ELSE 'Subgrupo' END; END IF;
  END IF;

  IF EXISTS (SELECT 1 FROM public.plano_de_contas
              WHERE nivel = p_nivel AND parent_id IS NOT DISTINCT FROM p_parent_id
                AND upper(btrim(nome)) = v_nome) THEN
    RAISE EXCEPTION 'Já existe "%" neste nível.', v_nome;
  END IF;

  PERFORM pg_advisory_xact_lock(hashtext('plano_contas_criar'));
  SELECT greatest(coalesce(max(codigo_connect) FILTER (WHERE codigo_connect >= 800000000), 800000000), 800000000) + 1
    INTO v_codigo FROM public.plano_de_contas;

  INSERT INTO public.plano_de_contas (codigo_connect, nome, nivel, parent_id, tipo, ativo)
  VALUES (v_codigo, v_nome, p_nivel, p_parent_id, v_tipo, true)
  RETURNING id INTO v_id;
  RETURN v_id;
END;
$fn$;

REVOKE ALL ON FUNCTION public.plano_contas_criar(text, smallint, uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.plano_contas_criar(text, smallint, uuid, text) TO authenticated;
