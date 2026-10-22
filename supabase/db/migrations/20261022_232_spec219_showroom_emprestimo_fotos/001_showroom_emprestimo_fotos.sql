-- SPEC-219 fase 2 (22/10/2026): fotos de como as peças SAÍRAM da Lucenera e de como VOLTARAM.
-- Bucket PRIVADO `showroom-emprestimos` (registro interno — diferente do `showroom-lucenera`, que é
-- a vitrine pública). O /admin do Showroom é sempre anon, então storage.objects não sabe quem é o
-- usuário: envio e leitura passam por liberação temporária por path (mesmo mecanismo da SPEC-148,
-- showroom_upload_grants), criada por RPC que confere a credencial do /admin.
--   saída:     showroom_emp_liberar_fotos('saida')     -> upload -> showroom_emp_confirmar_fotos_saida
--   devolução: showroom_emp_liberar_fotos('devolucao') -> upload -> showroom_emp_registrar_devolucao(p_fotos)
--   ver:       showroom_emp_liberar_leitura_fotos -> createSignedUrls (10 min)
-- A devolução passa a EXIGIR pelo menos 1 foto. Sem BEGIN/COMMIT no texto (dry-run + rollback antes).

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES ('showroom-emprestimos', 'showroom-emprestimos', false, 5242880,
        ARRAY['image/jpeg', 'image/png', 'image/webp'])
ON CONFLICT (id) DO NOTHING;

CREATE TABLE IF NOT EXISTS public.showroom_emprestimo_fotos (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  emprestimo_id uuid NOT NULL REFERENCES public.showroom_emprestimos (id) ON DELETE CASCADE,
  -- saída: foto geral do empréstimo (item_id nulo); devolução: foto da peça devolvida.
  item_id       uuid REFERENCES public.showroom_emprestimo_itens (id) ON DELETE CASCADE,
  momento       text NOT NULL CHECK (momento IN ('saida', 'devolucao')),
  path          text NOT NULL UNIQUE,
  criado_por    text,
  criado_em     timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT showroom_emprestimo_fotos_item_ck CHECK ((momento = 'devolucao') = (item_id IS NOT NULL))
);
CREATE INDEX IF NOT EXISTS showroom_emprestimo_fotos_emprestimo_idx
  ON public.showroom_emprestimo_fotos (emprestimo_id);

-- Liberação temporária por arquivo. pode_inserir = envio ainda não confirmado.
CREATE TABLE IF NOT EXISTS public.showroom_emp_foto_grants (
  path          text PRIMARY KEY,
  emprestimo_id uuid NOT NULL REFERENCES public.showroom_emprestimos (id) ON DELETE CASCADE,
  item_id       uuid,
  momento       text NOT NULL,
  pode_inserir  boolean NOT NULL,
  expira_em     timestamptz NOT NULL,
  criado_por    text
);

ALTER TABLE public.showroom_emprestimo_fotos ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.showroom_emp_foto_grants ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.showroom_emprestimo_fotos FROM anon, authenticated;
REVOKE ALL ON public.showroom_emp_foto_grants FROM anon, authenticated;


-- Usada só nas policies de storage.objects.
CREATE OR REPLACE FUNCTION public.showroom_emp_foto_permitida(p_name text, p_inserir boolean)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM showroom_emp_foto_grants g
     WHERE g.path = p_name
       AND g.expira_em > now()
       AND (NOT p_inserir OR g.pode_inserir)
  );
$$;
REVOKE ALL ON FUNCTION public.showroom_emp_foto_permitida(text, boolean) FROM public;
GRANT EXECUTE ON FUNCTION public.showroom_emp_foto_permitida(text, boolean) TO anon, authenticated;

-- Sem UPDATE/DELETE: foto registrada não é trocada nem apagada pela tela.
DROP POLICY IF EXISTS showroom_emprestimos_fotos_insert ON storage.objects;
CREATE POLICY showroom_emprestimos_fotos_insert
ON storage.objects FOR INSERT TO anon
WITH CHECK (
  bucket_id = 'showroom-emprestimos'
  AND public.showroom_emp_foto_permitida(name, true)
);

DROP POLICY IF EXISTS showroom_emprestimos_fotos_select ON storage.objects;
CREATE POLICY showroom_emprestimos_fotos_select
ON storage.objects FOR SELECT TO anon
USING (
  bucket_id = 'showroom-emprestimos'
  AND public.showroom_emp_foto_permitida(name, false)
);


-- Libera o envio de N fotos (máx. 20 por vez) e devolve os paths a usar no upload.
CREATE OR REPLACE FUNCTION public.showroom_emp_liberar_fotos(
  p_user text,
  p_senha text,
  p_emprestimo_id uuid,
  p_momento text,
  p_item_id uuid,
  p_extensoes text[]
)
RETURNS text[]
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_emp   record;
  v_ext   text;
  v_path  text;
  v_paths text[] := '{}';
BEGIN
  IF NOT public.showroom_cred_ok(p_user, p_senha) THEN
    RAISE EXCEPTION 'usuario ou senha invalidos' USING ERRCODE = '28000';
  END IF;
  SELECT * INTO v_emp FROM showroom_emprestimos WHERE id = p_emprestimo_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Empréstimo não encontrado.' USING ERRCODE = '22023';
  END IF;
  IF v_emp.cancelado_em IS NOT NULL THEN
    RAISE EXCEPTION 'Empréstimo cancelado.' USING ERRCODE = '22023';
  END IF;
  IF p_momento NOT IN ('saida', 'devolucao') THEN
    RAISE EXCEPTION 'Momento inválido.' USING ERRCODE = '22023';
  END IF;
  IF p_momento = 'saida' AND p_item_id IS NOT NULL THEN
    RAISE EXCEPTION 'Foto de saída é do empréstimo, não de uma peça.' USING ERRCODE = '22023';
  END IF;
  IF p_momento = 'devolucao' AND NOT EXISTS (
       SELECT 1 FROM showroom_emprestimo_itens
        WHERE id = p_item_id AND emprestimo_id = p_emprestimo_id AND situacao = 'emprestado') THEN
    RAISE EXCEPTION 'Peça não encontrada ou já devolvida.' USING ERRCODE = '22023';
  END IF;
  IF coalesce(array_length(p_extensoes, 1), 0) = 0 OR array_length(p_extensoes, 1) > 20 THEN
    RAISE EXCEPTION 'Envie de 1 a 20 fotos por vez.' USING ERRCODE = '22023';
  END IF;

  DELETE FROM showroom_emp_foto_grants WHERE expira_em < now() - interval '1 day';

  FOREACH v_ext IN ARRAY p_extensoes LOOP
    v_ext := lower(v_ext);
    IF v_ext = 'jpeg' THEN v_ext := 'jpg'; END IF;
    IF v_ext NOT IN ('jpg', 'png', 'webp') THEN
      RAISE EXCEPTION 'Formato de foto não aceito: %', v_ext USING ERRCODE = '22023';
    END IF;
    v_path := p_emprestimo_id || '/' || p_momento || '/' || gen_random_uuid() || '.' || v_ext;
    INSERT INTO showroom_emp_foto_grants (path, emprestimo_id, item_id, momento, pode_inserir, expira_em, criado_por)
    VALUES (v_path, p_emprestimo_id, p_item_id, p_momento, true, now() + interval '15 minutes', p_user);
    v_paths := v_paths || v_path;
  END LOOP;
  RETURN v_paths;
END;
$$;


-- Interna: valida os paths enviados (liberados para este empréstimo/momento/peça e já no storage)
-- e grava em showroom_emprestimo_fotos. Devolve quantas gravou.
CREATE OR REPLACE FUNCTION public.showroom_emp_gravar_fotos(
  p_user text,
  p_emprestimo_id uuid,
  p_momento text,
  p_item_id uuid,
  p_paths text[]
)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_path text;
  v_n    integer := 0;
BEGIN
  FOREACH v_path IN ARRAY coalesce(p_paths, '{}') LOOP
    IF NOT EXISTS (
         SELECT 1 FROM showroom_emp_foto_grants g
          WHERE g.path = v_path AND g.emprestimo_id = p_emprestimo_id AND g.momento = p_momento
            AND g.item_id IS NOT DISTINCT FROM p_item_id AND g.pode_inserir) THEN
      RAISE EXCEPTION 'Foto não liberada para este registro: %', v_path USING ERRCODE = '22023';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM storage.objects WHERE bucket_id = 'showroom-emprestimos' AND name = v_path) THEN
      RAISE EXCEPTION 'Foto não chegou ao servidor: %', v_path USING ERRCODE = '22023';
    END IF;
    INSERT INTO showroom_emprestimo_fotos (emprestimo_id, item_id, momento, path, criado_por)
    VALUES (p_emprestimo_id, p_item_id, p_momento, v_path, p_user)
    ON CONFLICT (path) DO NOTHING;
    UPDATE showroom_emp_foto_grants SET pode_inserir = false WHERE path = v_path;
    v_n := v_n + 1;
  END LOOP;
  RETURN v_n;
END;
$$;
REVOKE ALL ON FUNCTION public.showroom_emp_gravar_fotos(text, uuid, text, uuid, text[]) FROM public, anon, authenticated;


CREATE OR REPLACE FUNCTION public.showroom_emp_confirmar_fotos_saida(
  p_user text,
  p_senha text,
  p_emprestimo_id uuid,
  p_paths text[]
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_n integer;
BEGIN
  IF NOT public.showroom_cred_ok(p_user, p_senha) THEN
    RAISE EXCEPTION 'usuario ou senha invalidos' USING ERRCODE = '28000';
  END IF;
  IF coalesce(array_length(p_paths, 1), 0) = 0 THEN
    RAISE EXCEPTION 'Nenhuma foto enviada.' USING ERRCODE = '22023';
  END IF;
  v_n := public.showroom_emp_gravar_fotos(p_user, p_emprestimo_id, 'saida', NULL, p_paths);
  RETURN jsonb_build_object('ok', true, 'fotos', v_n);
END;
$$;


-- Libera leitura (10 min) das fotos de um empréstimo e devolve a lista para a tela/PDF.
CREATE OR REPLACE FUNCTION public.showroom_emp_liberar_leitura_fotos(p_user text, p_senha text, p_emprestimo_id uuid)
RETURNS TABLE (id uuid, item_id uuid, momento text, path text, criado_em timestamptz)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT public.showroom_cred_ok(p_user, p_senha) THEN
    RAISE EXCEPTION 'usuario ou senha invalidos' USING ERRCODE = '28000';
  END IF;
  INSERT INTO showroom_emp_foto_grants (path, emprestimo_id, item_id, momento, pode_inserir, expira_em, criado_por)
  SELECT f.path, f.emprestimo_id, f.item_id, f.momento, false, now() + interval '10 minutes', p_user
    FROM showroom_emprestimo_fotos f
   WHERE f.emprestimo_id = p_emprestimo_id
  ON CONFLICT ON CONSTRAINT showroom_emp_foto_grants_pkey
  DO UPDATE SET expira_em = now() + interval '10 minutes', pode_inserir = false;

  RETURN QUERY
  SELECT f.id, f.item_id, f.momento, f.path, f.criado_em
    FROM showroom_emprestimo_fotos f
   WHERE f.emprestimo_id = p_emprestimo_id
   ORDER BY f.momento DESC, f.criado_em;
END;
$$;


-- Devolução agora exige foto(s) de como a peça voltou. Assinatura muda: apaga a antiga para não
-- ficar sobrecarga (função velha aceitaria devolução sem foto).
DROP FUNCTION IF EXISTS public.showroom_emp_registrar_devolucao(text, text, uuid, boolean, text, numeric);

CREATE OR REPLACE FUNCTION public.showroom_emp_registrar_devolucao(
  p_user text,
  p_senha text,
  p_item_id uuid,
  p_com_dano boolean,
  p_descricao_dano text,
  p_valor_dano numeric,
  p_fotos text[]
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
  IF coalesce(array_length(p_fotos, 1), 0) = 0 THEN
    RAISE EXCEPTION 'Tire pelo menos 1 foto de como a peça voltou.' USING ERRCODE = '22023';
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
  END IF;

  PERFORM public.showroom_emp_gravar_fotos(p_user, v_item.emprestimo_id, 'devolucao', p_item_id, p_fotos);

  IF coalesce(p_com_dano, false) THEN
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


-- Lista ganha a contagem de fotos de saída (a tela avisa empréstimo sem foto). Muda o retorno: drop + create.
DROP FUNCTION IF EXISTS public.showroom_emp_listar(text, text, text, text);

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
  fotos_saida integer,
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
           (SELECT count(*)::integer FROM showroom_emprestimo_fotos f
             WHERE f.emprestimo_id = e.id AND f.momento = 'saida'),
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


REVOKE ALL ON FUNCTION public.showroom_emp_liberar_fotos(text, text, uuid, text, uuid, text[]) FROM public, authenticated;
REVOKE ALL ON FUNCTION public.showroom_emp_confirmar_fotos_saida(text, text, uuid, text[]) FROM public, authenticated;
REVOKE ALL ON FUNCTION public.showroom_emp_liberar_leitura_fotos(text, text, uuid) FROM public, authenticated;
REVOKE ALL ON FUNCTION public.showroom_emp_registrar_devolucao(text, text, uuid, boolean, text, numeric, text[]) FROM public, authenticated;
REVOKE ALL ON FUNCTION public.showroom_emp_listar(text, text, text, text) FROM public, authenticated;

GRANT EXECUTE ON FUNCTION public.showroom_emp_liberar_fotos(text, text, uuid, text, uuid, text[]) TO anon;
GRANT EXECUTE ON FUNCTION public.showroom_emp_confirmar_fotos_saida(text, text, uuid, text[]) TO anon;
GRANT EXECUTE ON FUNCTION public.showroom_emp_liberar_leitura_fotos(text, text, uuid) TO anon;
GRANT EXECUTE ON FUNCTION public.showroom_emp_registrar_devolucao(text, text, uuid, boolean, text, numeric, text[]) TO anon;
GRANT EXECUTE ON FUNCTION public.showroom_emp_listar(text, text, text, text) TO anon;
