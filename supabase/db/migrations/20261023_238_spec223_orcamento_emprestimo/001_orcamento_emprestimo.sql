-- SPEC-223 (23/10/2026): orçamento de empréstimo (Tipo de Operação Outros → Tipo EMPRESTIMO).
-- Um empréstimo só para Showroom (/admin, anon + credencial) e Orçamentos (usuário logado):
-- mesmas tabelas showroom_emprestimo* da SPEC-219, mesmo EMP-, termo, fotos e devolução.
-- Estoque e disponível NÃO mudam (decisão 1). O empréstimo não passa pela aprovação financeira;
-- o que o cliente ficar vira um orçamento de venda novo (peças "já com o cliente" vão direto para
-- Entregue na aprovação — decisão 3, desmarcável).
-- Sem BEGIN/COMMIT no texto (dry-run + rollback antes).

-- ===================================================================================== colunas
ALTER TABLE public.showroom_emprestimos
  ADD COLUMN IF NOT EXISTS origem text NOT NULL DEFAULT 'showroom'
    CONSTRAINT showroom_emprestimos_origem_ck CHECK (origem IN ('showroom', 'orcamento')),
  ADD COLUMN IF NOT EXISTS orcamento_id uuid UNIQUE REFERENCES public.orcamentos (id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS projeto_id uuid REFERENCES public.projetos (id) ON DELETE SET NULL;

ALTER TABLE public.showroom_emprestimo_itens DROP CONSTRAINT IF EXISTS showroom_emprestimo_itens_situacao_check;
ALTER TABLE public.showroom_emprestimo_itens ADD CONSTRAINT showroom_emprestimo_itens_situacao_check
  CHECK (situacao IN ('emprestado', 'devolvido', 'devolvido_com_dano', 'convertido_venda'));
ALTER TABLE public.showroom_emprestimo_itens
  ADD COLUMN IF NOT EXISTS orcamento_venda_id uuid REFERENCES public.orcamentos (id) ON DELETE SET NULL;

ALTER TABLE public.orcamentos
  ADD COLUMN IF NOT EXISTS data_prevista_devolucao date,
  ADD COLUMN IF NOT EXISTS emprestimo_origem_id uuid REFERENCES public.showroom_emprestimos (id) ON DELETE SET NULL;

ALTER TABLE public.orcamentos DROP CONSTRAINT IF EXISTS orcamentos_status_check;
ALTER TABLE public.orcamentos ADD CONSTRAINT orcamentos_status_check CHECK (status = ANY (ARRAY[
  'rascunho', 'aguardando_aprovacao', 'enviado_cliente', 'recusado_cliente', 'expirado', 'cancelado',
  'Aprovação Financeira', 'Orçamento Aprovado', 'aprovado_cliente', 'aprovado', 'aprovado_financeiro',
  'pendente_aprovacao_financeira', 'Aprovação da Equipe', 'emprestimo']));

-- Peça de venda que veio de empréstimo e já está com o cliente (vai direto para Entregue).
ALTER TABLE public.orcamento_itens
  ADD COLUMN IF NOT EXISTS ja_com_cliente boolean NOT NULL DEFAULT false;


-- ====================================================================== travas do orçamento
-- Empréstimo só fica em rascunho → emprestimo → cancelado; status 'emprestimo' só muda pelas RPCs
-- do empréstimo (app.emprestimo_rpc = 'on'). Status 'emprestimo' só existe em Outros/EMPRESTIMO.
CREATE OR REPLACE FUNCTION public.orcamento_emprestimo_guard()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public
AS $$
DECLARE
  v_rpc boolean := coalesce(current_setting('app.emprestimo_rpc', true), '') = 'on';
  v_emp boolean := NEW.natureza_operacao = 'outros' AND NEW.subgrupo = 'EMPRESTIMO';
BEGIN
  IF NEW.status = 'emprestimo' AND NOT v_emp THEN
    RAISE EXCEPTION 'Status "Empréstimo" só vale para orçamento de empréstimo.' USING ERRCODE = 'P0001';
  END IF;
  IF v_emp AND NEW.status NOT IN ('rascunho', 'emprestimo', 'cancelado') THEN
    RAISE EXCEPTION 'Orçamento de empréstimo não vai para o cliente nem para a aprovação financeira. Use "Confirmar empréstimo" dentro do orçamento.'
      USING ERRCODE = 'P0001';
  END IF;
  IF TG_OP = 'UPDATE' AND NOT v_rpc THEN
    IF NEW.status = 'emprestimo' AND OLD.status IS DISTINCT FROM 'emprestimo' THEN
      RAISE EXCEPTION 'Use "Confirmar empréstimo" para confirmar o empréstimo.' USING ERRCODE = 'P0001';
    END IF;
    IF OLD.status = 'emprestimo' AND (
         NEW.status IS DISTINCT FROM OLD.status
         OR NEW.cliente_id IS DISTINCT FROM OLD.cliente_id
         OR NEW.empresa_id IS DISTINCT FROM OLD.empresa_id
         OR NEW.natureza_operacao IS DISTINCT FROM OLD.natureza_operacao
         OR NEW.subgrupo IS DISTINCT FROM OLD.subgrupo) THEN
      RAISE EXCEPTION 'Empréstimo confirmado: use os botões do empréstimo (devolução, virar venda, cancelar).'
        USING ERRCODE = 'P0001';
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_2_orcamento_emprestimo_guard ON public.orcamentos;
CREATE TRIGGER trg_2_orcamento_emprestimo_guard
  BEFORE INSERT OR UPDATE ON public.orcamentos
  FOR EACH ROW EXECUTE FUNCTION public.orcamento_emprestimo_guard();

-- Peças de empréstimo confirmado não mudam (o termo já foi assinado com elas).
CREATE OR REPLACE FUNCTION public.orcamento_itens_emprestimo_guard()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
  IF EXISTS (SELECT 1 FROM orcamentos o
              WHERE o.id = coalesce(NEW.orcamento_id, OLD.orcamento_id) AND o.status = 'emprestimo') THEN
    RAISE EXCEPTION 'Empréstimo confirmado: as peças não podem ser alteradas.' USING ERRCODE = 'P0001';
  END IF;
  RETURN coalesce(NEW, OLD);
END;
$$;

DROP TRIGGER IF EXISTS trg_orcamento_itens_emprestimo_guard ON public.orcamento_itens;
CREATE TRIGGER trg_orcamento_itens_emprestimo_guard
  BEFORE INSERT OR UPDATE OR DELETE ON public.orcamento_itens
  FOR EACH ROW EXECUTE FUNCTION public.orcamento_itens_emprestimo_guard();

REVOKE ALL ON FUNCTION public.orcamento_emprestimo_guard() FROM public, anon, authenticated;
REVOKE ALL ON FUNCTION public.orcamento_itens_emprestimo_guard() FROM public, anon, authenticated;


-- ================================================================ funções internas (sem grant)
-- Status calculado: ganha "virou_venda" (tudo convertido) e "parcial" (parte venda, parte devolvida).
CREATE OR REPLACE FUNCTION public.showroom_emp_status(p_id uuid)
RETURNS text
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT CASE
    WHEN e.cancelado_em IS NOT NULL THEN 'cancelado'
    WHEN EXISTS (SELECT 1 FROM showroom_emprestimo_itens i
                  WHERE i.emprestimo_id = e.id AND i.situacao = 'emprestado') THEN
      CASE WHEN e.data_prevista_devolucao < (now() AT TIME ZONE 'America/Sao_Paulo')::date
           THEN 'atrasado' ELSE 'em_aberto' END
    WHEN EXISTS (SELECT 1 FROM showroom_emprestimo_itens i
                  WHERE i.emprestimo_id = e.id AND i.situacao = 'convertido_venda') THEN
      CASE WHEN EXISTS (SELECT 1 FROM showroom_emprestimo_itens i
                         WHERE i.emprestimo_id = e.id AND i.situacao IN ('devolvido', 'devolvido_com_dano'))
           THEN 'parcial' ELSE 'virou_venda' END
    WHEN EXISTS (SELECT 1 FROM showroom_emprestimo_itens i
                  WHERE i.emprestimo_id = e.id AND i.situacao = 'devolvido_com_dano') THEN 'devolvido_com_dano'
    ELSE 'devolvido'
  END
  FROM showroom_emprestimos e
  WHERE e.id = p_id
$$;
REVOKE ALL ON FUNCTION public.showroom_emp_status(uuid) FROM public, anon, authenticated;

-- Tudo de um empréstimo (detalhe e PDF). Usada pelo /admin e pelo Orçamentos.
CREATE OR REPLACE FUNCTION public.showroom_emp_detalhe(p_id uuid)
RETURNS jsonb
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT jsonb_build_object(
           'id', e.id,
           'numero', e.numero,
           'status', public.showroom_emp_status(e.id),
           'origem', e.origem,
           'orcamento_id', e.orcamento_id,
           'orcamento_numero', o.numero,
           'projeto_codigo', pr.codigo,
           'contato_id', e.contato_id,
           'data_emprestimo', e.data_emprestimo,
           'data_prevista_devolucao', e.data_prevista_devolucao,
           'observacoes', e.observacoes,
           'cancelado_em', e.cancelado_em,
           'cancelado_motivo', e.cancelado_motivo,
           'criado_por', e.criado_por,
           'criado_em', e.criado_em,
           'cliente', e.cliente_snapshot,
           'empresa', jsonb_build_object(
             'id', emp.id, 'nome', emp.nome, 'razao_social', emp.razao_social, 'cnpj', emp.cnpj,
             'inscricao_estadual', emp.inscricao_estadual, 'logradouro', emp.logradouro,
             'numero', emp.numero, 'complemento', emp.complemento, 'bairro', emp.bairro,
             'cidade', emp.cidade, 'estado', emp.estado, 'cep', emp.cep),
           'itens', coalesce((
             SELECT jsonb_agg(jsonb_build_object(
                      'id', i.id, 'produto_id', i.produto_id, 'codigo_produto', i.codigo_produto,
                      'nome', i.nome, 'referencia', i.referencia, 'quantidade', i.quantidade,
                      'valor_unitario', i.valor_unitario, 'situacao', i.situacao,
                      'data_devolucao', i.data_devolucao, 'descricao_dano', i.descricao_dano,
                      'valor_dano', i.valor_dano, 'devolvido_registrado_por', i.devolvido_registrado_por,
                      'orcamento_venda_id', i.orcamento_venda_id, 'orcamento_venda_numero', ov.numero)
                    ORDER BY i.nome, i.situacao)
               FROM showroom_emprestimo_itens i
               LEFT JOIN orcamentos ov ON ov.id = i.orcamento_venda_id
              WHERE i.emprestimo_id = e.id), '[]'::jsonb))
    FROM showroom_emprestimos e
    JOIN empresas emp ON emp.id = e.empresa_id
    LEFT JOIN orcamentos o ON o.id = e.orcamento_id
    LEFT JOIN projetos pr ON pr.id = e.projeto_id
   WHERE e.id = p_id
$$;
REVOKE ALL ON FUNCTION public.showroom_emp_detalhe(uuid) FROM public, anon, authenticated;

-- Lista (mesmas colunas da SPEC-219 + origem e número do orçamento).
CREATE OR REPLACE FUNCTION public.showroom_emp_listar_int(p_status text, p_termo text)
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
  criado_em timestamptz,
  origem text,
  orcamento_id uuid,
  orcamento_numero text
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
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
           e.criado_em,
           e.origem,
           e.orcamento_id,
           o.numero
      FROM showroom_emprestimos e
      JOIN empresas emp ON emp.id = e.empresa_id
      LEFT JOIN orcamentos o ON o.id = e.orcamento_id
      LEFT JOIN showroom_emprestimo_itens i ON i.emprestimo_id = e.id
     WHERE nullif(trim(coalesce(p_termo, '')), '') IS NULL
        OR e.cliente_snapshot->>'nome' ILIKE '%' || trim(p_termo) || '%'
        OR e.numero::text = regexp_replace(p_termo, '\D', '', 'g')
        OR o.numero ILIKE '%' || trim(p_termo) || '%'
     GROUP BY e.id, emp.nome, o.numero
  ) t
  WHERE p_status IS NULL
     OR t.st = p_status
     OR (p_status = 'em_aberto' AND t.st = 'atrasado')
  ORDER BY t.criado_em DESC
  LIMIT 500
$$;
REVOKE ALL ON FUNCTION public.showroom_emp_listar_int(text, text) FROM public, anon, authenticated;

-- Separa p_quantidade de uma linha "emprestado": a linha original fica com p_quantidade (é ela que
-- recebe a devolução/conversão e as fotos já liberadas para ela) e o resto vai para uma linha nova
-- que continua com o cliente. Devolve o id da linha que ficou com p_quantidade.
CREATE OR REPLACE FUNCTION public.showroom_emp_separar_item(p_item_id uuid, p_quantidade integer)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_item showroom_emprestimo_itens%ROWTYPE;
BEGIN
  SELECT * INTO v_item FROM showroom_emprestimo_itens WHERE id = p_item_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Peça do empréstimo não encontrada.' USING ERRCODE = '22023';
  END IF;
  IF v_item.situacao <> 'emprestado' THEN
    RAISE EXCEPTION 'Esta peça não está mais com o cliente.' USING ERRCODE = '22023';
  END IF;
  IF p_quantidade IS NULL OR p_quantidade = v_item.quantidade THEN
    RETURN p_item_id;
  END IF;
  IF p_quantidade <= 0 OR p_quantidade > v_item.quantidade THEN
    RAISE EXCEPTION 'Quantidade inválida para %: entre 1 e %.', v_item.nome, v_item.quantidade USING ERRCODE = '22023';
  END IF;
  INSERT INTO showroom_emprestimo_itens (emprestimo_id, produto_id, codigo_produto, nome, referencia,
                                         quantidade, valor_unitario)
  VALUES (v_item.emprestimo_id, v_item.produto_id, v_item.codigo_produto, v_item.nome, v_item.referencia,
          v_item.quantidade - p_quantidade, v_item.valor_unitario);
  UPDATE showroom_emprestimo_itens SET quantidade = p_quantidade WHERE id = p_item_id;
  RETURN p_item_id;
END;
$$;
REVOKE ALL ON FUNCTION public.showroom_emp_separar_item(uuid, integer) FROM public, anon, authenticated;

-- Devolução de uma peça (ou parte dela). Regras da SPEC-219: foto obrigatória; com dano, descrição
-- obrigatória e valor entre 0 e o valor integral da parte devolvida.
CREATE OR REPLACE FUNCTION public.showroom_emp_devolver_item(
  p_por text,
  p_item_id uuid,
  p_quantidade integer,
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

  PERFORM public.showroom_emp_separar_item(p_item_id, p_quantidade);
  SELECT * INTO v_item FROM showroom_emprestimo_itens WHERE id = p_item_id;

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

  PERFORM public.showroom_emp_gravar_fotos(p_por, v_item.emprestimo_id, 'devolucao', p_item_id, p_fotos);

  IF coalesce(p_com_dano, false) THEN
    UPDATE showroom_emprestimo_itens
       SET situacao = 'devolvido_com_dano',
           data_devolucao = (now() AT TIME ZONE 'America/Sao_Paulo')::date,
           descricao_dano = trim(p_descricao_dano),
           valor_dano = v_valor,
           devolvido_registrado_por = p_por
     WHERE id = p_item_id;
  ELSE
    UPDATE showroom_emprestimo_itens
       SET situacao = 'devolvido',
           data_devolucao = (now() AT TIME ZONE 'America/Sao_Paulo')::date,
           devolvido_registrado_por = p_por
     WHERE id = p_item_id;
  END IF;

  RETURN jsonb_build_object('ok', true, 'status', public.showroom_emp_status(v_item.emprestimo_id));
END;
$$;
REVOKE ALL ON FUNCTION public.showroom_emp_devolver_item(text, uuid, integer, boolean, text, numeric, text[])
  FROM public, anon, authenticated;

-- Libera o envio de N fotos (máx. 20) — mesma regra da SPEC-219 fase 2.
CREATE OR REPLACE FUNCTION public.showroom_emp_liberar_fotos_int(
  p_por text,
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
    VALUES (v_path, p_emprestimo_id, p_item_id, p_momento, true, now() + interval '15 minutes', p_por);
    v_paths := v_paths || v_path;
  END LOOP;
  RETURN v_paths;
END;
$$;
REVOKE ALL ON FUNCTION public.showroom_emp_liberar_fotos_int(text, uuid, text, uuid, text[]) FROM public, anon, authenticated;

CREATE OR REPLACE FUNCTION public.showroom_emp_liberar_leitura_int(p_por text, p_emprestimo_id uuid)
RETURNS TABLE (id uuid, item_id uuid, momento text, path text, criado_em timestamptz)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO showroom_emp_foto_grants (path, emprestimo_id, item_id, momento, pode_inserir, expira_em, criado_por)
  SELECT f.path, f.emprestimo_id, f.item_id, f.momento, false, now() + interval '10 minutes', p_por
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
REVOKE ALL ON FUNCTION public.showroom_emp_liberar_leitura_int(text, uuid) FROM public, anon, authenticated;


-- ================================================ RPCs do /admin (anon) passam a usar as internas
CREATE OR REPLACE FUNCTION public.showroom_emp_obter(p_user text, p_senha text, p_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_res jsonb;
BEGIN
  IF NOT public.showroom_cred_ok(p_user, p_senha) THEN
    RAISE EXCEPTION 'usuario ou senha invalidos' USING ERRCODE = '28000';
  END IF;
  v_res := public.showroom_emp_detalhe(p_id);
  IF v_res IS NULL THEN
    RAISE EXCEPTION 'Empréstimo não encontrado.' USING ERRCODE = '22023';
  END IF;
  RETURN v_res;
END;
$$;

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
BEGIN
  IF NOT public.showroom_cred_ok(p_user, p_senha) THEN
    RAISE EXCEPTION 'usuario ou senha invalidos' USING ERRCODE = '28000';
  END IF;
  RETURN public.showroom_emp_devolver_item(p_user, p_item_id, NULL, p_com_dano, p_descricao_dano, p_valor_dano, p_fotos);
END;
$$;

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
BEGIN
  IF NOT public.showroom_cred_ok(p_user, p_senha) THEN
    RAISE EXCEPTION 'usuario ou senha invalidos' USING ERRCODE = '28000';
  END IF;
  RETURN public.showroom_emp_liberar_fotos_int(p_user, p_emprestimo_id, p_momento, p_item_id, p_extensoes);
END;
$$;

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
  RETURN QUERY SELECT * FROM public.showroom_emp_liberar_leitura_int(p_user, p_emprestimo_id);
END;
$$;

-- Cancelar pelo /admin: empréstimo que nasceu do orçamento volta o orçamento para "cancelado".
CREATE OR REPLACE FUNCTION public.showroom_emp_cancelar(p_user text, p_senha text, p_id uuid, p_motivo text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_emp record;
BEGIN
  IF NOT public.showroom_cred_ok(p_user, p_senha) THEN
    RAISE EXCEPTION 'usuario ou senha invalidos' USING ERRCODE = '28000';
  END IF;
  SELECT * INTO v_emp FROM showroom_emprestimos WHERE id = p_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Empréstimo não encontrado.' USING ERRCODE = '22023';
  END IF;
  IF v_emp.cancelado_em IS NOT NULL THEN
    RAISE EXCEPTION 'Empréstimo já cancelado.' USING ERRCODE = '22023';
  END IF;
  IF nullif(trim(coalesce(p_motivo, '')), '') IS NULL THEN
    RAISE EXCEPTION 'Informe o motivo do cancelamento.' USING ERRCODE = '22023';
  END IF;
  IF EXISTS (SELECT 1 FROM showroom_emprestimo_itens WHERE emprestimo_id = p_id AND situacao <> 'emprestado') THEN
    RAISE EXCEPTION 'Já existe peça devolvida ou vendida neste empréstimo; não dá para cancelar.' USING ERRCODE = '22023';
  END IF;
  UPDATE showroom_emprestimos
     SET cancelado_em = now(), cancelado_motivo = trim(p_motivo)
   WHERE id = p_id;
  IF v_emp.orcamento_id IS NOT NULL THEN
    PERFORM set_config('app.emprestimo_rpc', 'on', true);
    UPDATE orcamentos SET status = 'cancelado' WHERE id = v_emp.orcamento_id;
    PERFORM set_config('app.emprestimo_rpc', '', true);
  END IF;
  RETURN jsonb_build_object('ok', true);
END;
$$;

-- Lista do /admin com origem (retorno muda: drop + create, re-grant).
DROP FUNCTION IF EXISTS public.showroom_emp_listar(text, text, text, text);
CREATE FUNCTION public.showroom_emp_listar(
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
  criado_em timestamptz,
  origem text,
  orcamento_id uuid,
  orcamento_numero text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT public.showroom_cred_ok(p_user, p_senha) THEN
    RAISE EXCEPTION 'usuario ou senha invalidos' USING ERRCODE = '28000';
  END IF;
  RETURN QUERY SELECT * FROM public.showroom_emp_listar_int(p_status, p_termo);
END;
$$;
REVOKE ALL ON FUNCTION public.showroom_emp_listar(text, text, text, text) FROM public, authenticated;
GRANT EXECUTE ON FUNCTION public.showroom_emp_listar(text, text, text, text) TO anon;


-- ============================================================ RPCs do Orçamentos (authenticated)
-- Quem é o usuário logado (vai em criado_por / devolvido_registrado_por).
CREATE OR REPLACE FUNCTION public.emprestimo_usuario()
RETURNS text
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT coalesce(nullif(u.nome, ''), u.email, auth.uid()::text)
    FROM usuarios u WHERE u.id = auth.uid()
$$;
REVOKE ALL ON FUNCTION public.emprestimo_usuario() FROM public, anon, authenticated;

-- Permissão: os mesmos que criam/editam orçamento hoje (matriz do Hub, decisão 4); leitura para
-- quem acessa o Orçamentos. Empréstimo de orçamento respeita a regra de equipe (SPEC-200).
CREATE OR REPLACE FUNCTION public.emprestimo_checar(p_acao text, p_emprestimo_id uuid DEFAULT NULL)
RETURNS void
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_orc   uuid;
  v_restr uuid;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Faça login.' USING ERRCODE = '28000';
  END IF;
  IF p_acao IS NULL THEN
    IF NOT public.pode_acessar_sistema('orcamentos') THEN
      RAISE EXCEPTION 'Sem acesso ao Orçamentos.' USING ERRCODE = '42501';
    END IF;
  ELSIF NOT public.hub_pode_executar(auth.uid(), 'orcamentos', NULL, p_acao) THEN
    RAISE EXCEPTION 'Sem permissão para esta ação no Orçamentos.' USING ERRCODE = '42501';
  END IF;
  IF p_emprestimo_id IS NOT NULL THEN
    SELECT orcamento_id INTO v_orc FROM showroom_emprestimos WHERE id = p_emprestimo_id;
    v_restr := public.orcamentos_equipe_restrita();
    IF v_orc IS NOT NULL AND v_restr IS NOT NULL AND NOT EXISTS (
         SELECT 1 FROM orcamentos o
          WHERE o.id = v_orc AND (o.equipe_id = v_restr OR o.digitado_por = auth.uid())) THEN
      RAISE EXCEPTION 'Empréstimo de outra equipe.' USING ERRCODE = '42501';
    END IF;
  END IF;
END;
$$;
REVOKE ALL ON FUNCTION public.emprestimo_checar(text, uuid) FROM public, anon, authenticated;

-- Confirma o orçamento de empréstimo: cria o EMP- com as peças do orçamento.
CREATE OR REPLACE FUNCTION public.emprestimo_confirmar_orcamento(p_orcamento_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_orc      orcamentos%ROWTYPE;
  v_hoje     date := (now() AT TIME ZONE 'America/Sao_Paulo')::date;
  v_snapshot jsonb;
  v_id       uuid;
  v_numero   integer;
  v_item     record;
  v_n        integer := 0;
  v_restr    uuid;
BEGIN
  PERFORM public.emprestimo_checar('criar');
  SELECT * INTO v_orc FROM orcamentos WHERE id = p_orcamento_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Orçamento não encontrado.' USING ERRCODE = '22023';
  END IF;
  v_restr := public.orcamentos_equipe_restrita();
  IF v_restr IS NOT NULL AND v_orc.equipe_id IS DISTINCT FROM v_restr AND v_orc.digitado_por IS DISTINCT FROM auth.uid() THEN
    RAISE EXCEPTION 'Orçamento de outra equipe.' USING ERRCODE = '42501';
  END IF;
  IF NOT (v_orc.natureza_operacao = 'outros' AND v_orc.subgrupo = 'EMPRESTIMO') THEN
    RAISE EXCEPTION 'Este orçamento não é de empréstimo (Tipo de Operação Outros → EMPRÉSTIMO).' USING ERRCODE = '22023';
  END IF;
  IF v_orc.status <> 'rascunho' OR EXISTS (SELECT 1 FROM showroom_emprestimos WHERE orcamento_id = p_orcamento_id) THEN
    RAISE EXCEPTION 'Este empréstimo já foi confirmado.' USING ERRCODE = '22023';
  END IF;
  IF v_orc.empresa_id IS NULL THEN
    RAISE EXCEPTION 'Escolha a empresa.' USING ERRCODE = '22023';
  END IF;
  IF v_orc.cliente_id IS NULL THEN
    RAISE EXCEPTION 'Escolha o cliente.' USING ERRCODE = '22023';
  END IF;
  IF v_orc.data_prevista_devolucao IS NULL OR v_orc.data_prevista_devolucao < v_hoje THEN
    RAISE EXCEPTION 'Informe a data prevista de devolução (hoje ou depois).' USING ERRCODE = '22023';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM orcamento_itens WHERE orcamento_id = p_orcamento_id) THEN
    RAISE EXCEPTION 'Inclua pelo menos uma peça.' USING ERRCODE = '22023';
  END IF;
  IF EXISTS (SELECT 1 FROM orcamento_itens WHERE orcamento_id = p_orcamento_id AND produto_id IS NULL) THEN
    RAISE EXCEPTION 'Peça sem cadastro não pode ser emprestada: escolha a peça do cadastro.' USING ERRCODE = '22023';
  END IF;
  IF EXISTS (SELECT 1 FROM orcamento_itens WHERE orcamento_id = p_orcamento_id
              AND (quantidade <= 0 OR quantidade <> trunc(quantidade))) THEN
    RAISE EXCEPTION 'No empréstimo a quantidade precisa ser inteira.' USING ERRCODE = '22023';
  END IF;

  SELECT jsonb_build_object(
           'nome',        c.nome,
           'razao_social', nullif(c.razao_social, ''),
           'cpf_cnpj',    coalesce(nullif(c.cpf_cnpj, ''), nullif(c.cnpj, ''), nullif(c.cpf, '')),
           'telefone',    coalesce(nullif(c.celular, ''), nullif(c.telefone, '')),
           'email',       nullif(c.email, ''),
           'endereco',    nullif(c.endereco, ''),
           'numero',      nullif(c.numero, ''),
           'complemento', nullif(c.complemento, ''),
           'bairro',      nullif(c.bairro, ''),
           'cidade',      nullif(c.cidade, ''),
           'estado',      nullif(c.estado, ''),
           'cep',         nullif(c.cep, ''))
    INTO v_snapshot
    FROM contatos c
   WHERE c.id = v_orc.cliente_id;
  IF v_snapshot IS NULL THEN
    RAISE EXCEPTION 'Cliente não encontrado no cadastro.' USING ERRCODE = '22023';
  END IF;

  INSERT INTO showroom_emprestimos (empresa_id, contato_id, cliente_snapshot, data_emprestimo,
                                    data_prevista_devolucao, observacoes, criado_por,
                                    origem, orcamento_id, projeto_id)
  VALUES (v_orc.empresa_id, v_orc.cliente_id, v_snapshot, v_hoje, v_orc.data_prevista_devolucao,
          nullif(trim(coalesce(v_orc.observacoes, '')), ''), public.emprestimo_usuario(),
          'orcamento', p_orcamento_id, v_orc.projeto_id)
  RETURNING id, numero INTO v_id, v_numero;

  -- Uma linha por peça (soma as linhas/L repetidos). Valor = preço do orçamento com o desconto do
  -- item (é o valor cobrado em caso de dano).
  FOR v_item IN
    SELECT p.id AS produto_id, p.codigo_produto, p.nome, nullif(p.referencia, '') AS referencia,
           sum(oi.quantidade)::integer AS qtd,
           round(max(coalesce(nullif(oi.preco_unitario, 0), p.valor_venda, 0)
                     * (1 - coalesce(oi.desconto, 0) / 100.0)), 2) AS valor
      FROM orcamento_itens oi
      JOIN produtos p ON p.id = oi.produto_id
     WHERE oi.orcamento_id = p_orcamento_id
     GROUP BY p.id, p.codigo_produto, p.nome, p.referencia
  LOOP
    INSERT INTO showroom_emprestimo_itens (emprestimo_id, produto_id, codigo_produto, nome, referencia,
                                           quantidade, valor_unitario)
    VALUES (v_id, v_item.produto_id, v_item.codigo_produto, v_item.nome, v_item.referencia,
            v_item.qtd, greatest(v_item.valor, 0));
    v_n := v_n + 1;
  END LOOP;

  PERFORM set_config('app.emprestimo_rpc', 'on', true);
  UPDATE orcamentos SET status = 'emprestimo' WHERE id = p_orcamento_id;
  PERFORM set_config('app.emprestimo_rpc', '', true);
  BEGIN
    INSERT INTO historico_status_orcamentos (orcamento_id, status_anterior, status_novo, usuario, observacao)
    VALUES (p_orcamento_id, v_orc.status, 'emprestimo', auth.uid()::text,
            format('Empréstimo EMP-%s confirmado', lpad(v_numero::text, 4, '0')));
  EXCEPTION WHEN undefined_table OR undefined_column OR foreign_key_violation THEN NULL;
  END;

  RETURN jsonb_build_object('id', v_id, 'numero', v_numero, 'itens', v_n);
END;
$$;

CREATE OR REPLACE FUNCTION public.emprestimo_obter(p_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_res jsonb;
BEGIN
  PERFORM public.emprestimo_checar(NULL, p_id);
  v_res := public.showroom_emp_detalhe(p_id);
  IF v_res IS NULL THEN
    RAISE EXCEPTION 'Empréstimo não encontrado.' USING ERRCODE = '22023';
  END IF;
  RETURN v_res;
END;
$$;

-- Empréstimo de um orçamento (null se ainda não confirmado).
CREATE OR REPLACE FUNCTION public.emprestimo_do_orcamento(p_orcamento_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_id uuid;
BEGIN
  SELECT id INTO v_id FROM showroom_emprestimos WHERE orcamento_id = p_orcamento_id;
  IF v_id IS NULL THEN
    PERFORM public.emprestimo_checar(NULL);
    RETURN NULL;
  END IF;
  PERFORM public.emprestimo_checar(NULL, v_id);
  RETURN public.showroom_emp_detalhe(v_id);
END;
$$;

-- Lista (Showroom + Orçamentos). Quem só vê a própria equipe não vê empréstimo de orçamento de outra.
CREATE OR REPLACE FUNCTION public.emprestimo_listar(p_status text DEFAULT NULL, p_termo text DEFAULT NULL)
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
  criado_em timestamptz,
  origem text,
  orcamento_id uuid,
  orcamento_numero text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_restr uuid;
BEGIN
  PERFORM public.emprestimo_checar(NULL);
  v_restr := public.orcamentos_equipe_restrita();
  RETURN QUERY
  SELECT l.*
    FROM public.showroom_emp_listar_int(p_status, p_termo) l
   WHERE v_restr IS NULL
      OR l.orcamento_id IS NULL
      OR EXISTS (SELECT 1 FROM orcamentos o
                  WHERE o.id = l.orcamento_id AND (o.equipe_id = v_restr OR o.digitado_por = auth.uid()));
END;
$$;

CREATE OR REPLACE FUNCTION public.emprestimo_liberar_fotos(
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
BEGIN
  PERFORM public.emprestimo_checar('editar', p_emprestimo_id);
  RETURN public.showroom_emp_liberar_fotos_int(public.emprestimo_usuario(), p_emprestimo_id, p_momento,
                                               p_item_id, p_extensoes);
END;
$$;

CREATE OR REPLACE FUNCTION public.emprestimo_confirmar_fotos_saida(p_emprestimo_id uuid, p_paths text[])
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_n integer;
BEGIN
  PERFORM public.emprestimo_checar('editar', p_emprestimo_id);
  IF coalesce(array_length(p_paths, 1), 0) = 0 THEN
    RAISE EXCEPTION 'Nenhuma foto enviada.' USING ERRCODE = '22023';
  END IF;
  v_n := public.showroom_emp_gravar_fotos(public.emprestimo_usuario(), p_emprestimo_id, 'saida', NULL, p_paths);
  RETURN jsonb_build_object('ok', true, 'fotos', v_n);
END;
$$;

CREATE OR REPLACE FUNCTION public.emprestimo_liberar_leitura_fotos(p_emprestimo_id uuid)
RETURNS TABLE (id uuid, item_id uuid, momento text, path text, criado_em timestamptz)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  PERFORM public.emprestimo_checar(NULL, p_emprestimo_id);
  RETURN QUERY SELECT * FROM public.showroom_emp_liberar_leitura_int(public.emprestimo_usuario(), p_emprestimo_id);
END;
$$;

CREATE OR REPLACE FUNCTION public.emprestimo_registrar_devolucao(
  p_item_id uuid,
  p_quantidade integer,
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
  v_emp uuid;
BEGIN
  SELECT emprestimo_id INTO v_emp FROM showroom_emprestimo_itens WHERE id = p_item_id;
  IF v_emp IS NULL THEN
    RAISE EXCEPTION 'Peça do empréstimo não encontrada.' USING ERRCODE = '22023';
  END IF;
  PERFORM public.emprestimo_checar('editar', v_emp);
  RETURN public.showroom_emp_devolver_item(public.emprestimo_usuario(), p_item_id, p_quantidade, p_com_dano,
                                           p_descricao_dano, p_valor_dano, p_fotos);
END;
$$;

-- O cliente ficou com peças: cria um orçamento de VENDA novo (rascunho) só com elas, ligado ao
-- empréstimo. As peças vêm marcadas "já com o cliente" (desmarcável no orçamento). Segue o fluxo
-- normal (cliente → equipe → financeiro). p_itens = [{"item_id": "...", "quantidade": 1}, ...]
CREATE OR REPLACE FUNCTION public.emprestimo_converter_em_venda(p_emprestimo_id uuid, p_itens jsonb)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_emp     showroom_emprestimos%ROWTYPE;
  v_orig    orcamentos%ROWTYPE;
  v_x       record;
  v_item    showroom_emprestimo_itens%ROWTYPE;
  v_novo    uuid;
  v_numero  text;
  v_total   numeric := 0;
  v_ordem   integer := 0;
  v_l       text;
  v_ids     uuid[] := '{}';
BEGIN
  PERFORM public.emprestimo_checar('criar', p_emprestimo_id);
  SELECT * INTO v_emp FROM showroom_emprestimos WHERE id = p_emprestimo_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Empréstimo não encontrado.' USING ERRCODE = '22023';
  END IF;
  IF v_emp.cancelado_em IS NOT NULL THEN
    RAISE EXCEPTION 'Empréstimo cancelado.' USING ERRCODE = '22023';
  END IF;
  IF p_itens IS NULL OR jsonb_typeof(p_itens) <> 'array' OR jsonb_array_length(p_itens) = 0 THEN
    RAISE EXCEPTION 'Escolha as peças que o cliente ficou.' USING ERRCODE = '22023';
  END IF;
  IF v_emp.orcamento_id IS NOT NULL THEN
    SELECT * INTO v_orig FROM orcamentos WHERE id = v_emp.orcamento_id;
  END IF;

  -- Separa as quantidades primeiro (linha original fica com o que virou venda).
  FOR v_x IN
    SELECT (x->>'item_id')::uuid AS item_id, (x->>'quantidade')::integer AS qtd
      FROM jsonb_array_elements(p_itens) x
  LOOP
    IF NOT EXISTS (SELECT 1 FROM showroom_emprestimo_itens
                    WHERE id = v_x.item_id AND emprestimo_id = p_emprestimo_id) THEN
      RAISE EXCEPTION 'Peça não pertence a este empréstimo.' USING ERRCODE = '22023';
    END IF;
    IF v_x.item_id = ANY (v_ids) THEN
      RAISE EXCEPTION 'Peça repetida na lista.' USING ERRCODE = '22023';
    END IF;
    PERFORM public.showroom_emp_separar_item(v_x.item_id, v_x.qtd);
    v_ids := v_ids || v_x.item_id;
  END LOOP;

  INSERT INTO orcamentos (empresa_id, cliente_id, arquiteto_id, vendedor_id, projeto_id, informacoes_cliente_id,
                          equipe_id, perfil, natureza_operacao, subgrupo, status, desconto_tipo, valor_total,
                          observacoes, emprestimo_origem_id)
  VALUES (v_emp.empresa_id, v_emp.contato_id, v_orig.arquiteto_id, v_orig.vendedor_id,
          coalesce(v_orig.projeto_id, v_emp.projeto_id), v_orig.informacoes_cliente_id, v_orig.equipe_id,
          v_orig.perfil, 'venda', 'VENDAS', 'rascunho', 'percentual', 0,
          format('Venda das peças do empréstimo EMP-%s%s.', lpad(v_emp.numero::text, 4, '0'),
                 CASE WHEN v_orig.numero IS NOT NULL THEN ' (orçamento ' || v_orig.numero || ')' ELSE '' END),
          p_emprestimo_id)
  RETURNING id, numero INTO v_novo, v_numero;

  IF v_emp.orcamento_id IS NOT NULL THEN
    INSERT INTO orcamento_arquitetos (orcamento_id, arquiteto_id, percentual)
    SELECT v_novo, oa.arquiteto_id, oa.percentual FROM orcamento_arquitetos oa WHERE oa.orcamento_id = v_emp.orcamento_id;
  END IF;

  FOR v_item IN
    SELECT * FROM showroom_emprestimo_itens WHERE id = ANY (v_ids) ORDER BY nome
  LOOP
    v_ordem := v_ordem + 1;
    -- L da linha do orçamento de empréstimo com a mesma peça (se houver).
    SELECT oi.custom_id INTO v_l FROM orcamento_itens oi
     WHERE oi.orcamento_id = v_emp.orcamento_id AND oi.produto_id = v_item.produto_id AND oi.custom_id IS NOT NULL
     ORDER BY oi.ordem NULLS LAST LIMIT 1;
    INSERT INTO orcamento_itens (orcamento_id, produto_id, descricao, quantidade, preco_unitario, desconto,
                                 custom_id, ordem, ja_com_cliente)
    VALUES (v_novo, v_item.produto_id, v_item.nome, v_item.quantidade, v_item.valor_unitario, 0,
            v_l, coalesce(nullif(regexp_replace(coalesce(v_l, ''), '\D', '', 'g'), '')::integer, v_ordem), true);
    v_total := v_total + v_item.quantidade * v_item.valor_unitario;
    v_l := NULL;
  END LOOP;

  UPDATE orcamentos SET valor_total = round(v_total, 2) WHERE id = v_novo;

  UPDATE showroom_emprestimo_itens
     SET situacao = 'convertido_venda',
         orcamento_venda_id = v_novo,
         data_devolucao = (now() AT TIME ZONE 'America/Sao_Paulo')::date,
         devolvido_registrado_por = public.emprestimo_usuario()
   WHERE id = ANY (v_ids);

  RETURN jsonb_build_object('orcamento_id', v_novo, 'numero', v_numero,
                            'status', public.showroom_emp_status(p_emprestimo_id));
END;
$$;

CREATE OR REPLACE FUNCTION public.emprestimo_cancelar(p_id uuid, p_motivo text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_emp record;
BEGIN
  PERFORM public.emprestimo_checar('editar', p_id);
  SELECT * INTO v_emp FROM showroom_emprestimos WHERE id = p_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Empréstimo não encontrado.' USING ERRCODE = '22023';
  END IF;
  IF v_emp.cancelado_em IS NOT NULL THEN
    RAISE EXCEPTION 'Empréstimo já cancelado.' USING ERRCODE = '22023';
  END IF;
  IF nullif(trim(coalesce(p_motivo, '')), '') IS NULL THEN
    RAISE EXCEPTION 'Informe o motivo do cancelamento.' USING ERRCODE = '22023';
  END IF;
  IF EXISTS (SELECT 1 FROM showroom_emprestimo_itens WHERE emprestimo_id = p_id AND situacao <> 'emprestado') THEN
    RAISE EXCEPTION 'Já existe peça devolvida ou vendida neste empréstimo; não dá para cancelar.' USING ERRCODE = '22023';
  END IF;
  UPDATE showroom_emprestimos SET cancelado_em = now(), cancelado_motivo = trim(p_motivo) WHERE id = p_id;
  IF v_emp.orcamento_id IS NOT NULL THEN
    PERFORM set_config('app.emprestimo_rpc', 'on', true);
    UPDATE orcamentos SET status = 'cancelado' WHERE id = v_emp.orcamento_id;
    PERFORM set_config('app.emprestimo_rpc', '', true);
  END IF;
  RETURN jsonb_build_object('ok', true);
END;
$$;

-- Quanto de cada peça está emprestado (em aberto) e o estoque — aviso no Novo Orçamento e linha
-- "Amostra / Emprestado" nos Setores da peça (Cadastro). Só informação: estoque não muda.
CREATE OR REPLACE FUNCTION public.emprestimo_em_aberto_por_produto(p_produto_ids uuid[])
RETURNS TABLE (
  produto_id uuid,
  quantidade_em_aberto integer,
  estoque_geral numeric,
  estoque_showroom integer,
  emprestimos jsonb
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF auth.uid() IS NULL OR NOT public.pode_acessar_algum(ARRAY['orcamentos', 'cadastro']) THEN
    RAISE EXCEPTION 'Sem acesso.' USING ERRCODE = '42501';
  END IF;
  RETURN QUERY
  SELECT p.id,
         coalesce(sum(i.quantidade) FILTER (WHERE e.id IS NOT NULL), 0)::integer,
         coalesce((SELECT ei.quantidade FROM estoque_itens ei
                    WHERE ei.produto_id = p.id AND ei.local = 'Estoque'::estoque_local), 0),
         coalesce(p.estoque_showroom, 0)::integer,
         coalesce(jsonb_agg(jsonb_build_object(
                    'numero', e.numero, 'cliente', e.cliente_snapshot->>'nome', 'quantidade', i.quantidade,
                    'devolver_ate', e.data_prevista_devolucao))
                  FILTER (WHERE e.id IS NOT NULL), '[]'::jsonb)
    FROM produtos p
    LEFT JOIN showroom_emprestimo_itens i ON i.produto_id = p.id AND i.situacao = 'emprestado'
    LEFT JOIN showroom_emprestimos e ON e.id = i.emprestimo_id AND e.cancelado_em IS NULL
   WHERE p.id = ANY (coalesce(p_produto_ids, '{}'))
   GROUP BY p.id, p.estoque_showroom;
END;
$$;

REVOKE ALL ON FUNCTION public.emprestimo_confirmar_orcamento(uuid) FROM public, anon;
REVOKE ALL ON FUNCTION public.emprestimo_obter(uuid) FROM public, anon;
REVOKE ALL ON FUNCTION public.emprestimo_do_orcamento(uuid) FROM public, anon;
REVOKE ALL ON FUNCTION public.emprestimo_listar(text, text) FROM public, anon;
REVOKE ALL ON FUNCTION public.emprestimo_liberar_fotos(uuid, text, uuid, text[]) FROM public, anon;
REVOKE ALL ON FUNCTION public.emprestimo_confirmar_fotos_saida(uuid, text[]) FROM public, anon;
REVOKE ALL ON FUNCTION public.emprestimo_liberar_leitura_fotos(uuid) FROM public, anon;
REVOKE ALL ON FUNCTION public.emprestimo_registrar_devolucao(uuid, integer, boolean, text, numeric, text[]) FROM public, anon;
REVOKE ALL ON FUNCTION public.emprestimo_converter_em_venda(uuid, jsonb) FROM public, anon;
REVOKE ALL ON FUNCTION public.emprestimo_cancelar(uuid, text) FROM public, anon;
REVOKE ALL ON FUNCTION public.emprestimo_em_aberto_por_produto(uuid[]) FROM public, anon;

GRANT EXECUTE ON FUNCTION public.emprestimo_confirmar_orcamento(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.emprestimo_obter(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.emprestimo_do_orcamento(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.emprestimo_listar(text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.emprestimo_liberar_fotos(uuid, text, uuid, text[]) TO authenticated;
GRANT EXECUTE ON FUNCTION public.emprestimo_confirmar_fotos_saida(uuid, text[]) TO authenticated;
GRANT EXECUTE ON FUNCTION public.emprestimo_liberar_leitura_fotos(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.emprestimo_registrar_devolucao(uuid, integer, boolean, text, numeric, text[]) TO authenticated;
GRANT EXECUTE ON FUNCTION public.emprestimo_converter_em_venda(uuid, jsonb) TO authenticated;
GRANT EXECUTE ON FUNCTION public.emprestimo_cancelar(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.emprestimo_em_aberto_por_produto(uuid[]) TO authenticated;

-- Fotos pelo usuário logado: mesmas liberações temporárias por arquivo (SPEC-219 fase 2).
DROP POLICY IF EXISTS showroom_emprestimos_fotos_insert_auth ON storage.objects;
CREATE POLICY showroom_emprestimos_fotos_insert_auth
ON storage.objects FOR INSERT TO authenticated
WITH CHECK (
  bucket_id = 'showroom-emprestimos'
  AND public.showroom_emp_foto_permitida(name, true)
);

DROP POLICY IF EXISTS showroom_emprestimos_fotos_select_auth ON storage.objects;
CREATE POLICY showroom_emprestimos_fotos_select_auth
ON storage.objects FOR SELECT TO authenticated
USING (
  bucket_id = 'showroom-emprestimos'
  AND public.showroom_emp_foto_permitida(name, false)
);


-- ================================================ aprovação financeira e itens (versões novas)

-- aprovar_orcamento_financeiro: recusa empréstimo; peça 'já com o cliente' vai direto para Entregue.
CREATE OR REPLACE FUNCTION public.aprovar_orcamento_financeiro(p_orcamento_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_orcamento public.orcamentos%ROWTYPE;
  v_cliente_nome text;
  v_status_anterior text;
  v_prazos integer[];
  v_qtd_parcelas integer;
  v_i integer;
  v_valor_total numeric;
  v_valor_base numeric;
  v_valor_parcela numeric;
  v_valor_acumulado numeric := 0;
  v_data_base date := current_date;
  v_itens_existentes integer := 0;
  v_parcelas_existentes integer := 0;
  v_boletos_existentes integer := 0;
  v_itens_criados integer := 0;
  v_parcelas_criadas integer := 0;
  v_boletos_criados integer := 0;
  v_numero_orcamento text;
  v_numero_venda text;
  v_seq_venda integer;
  v_item record;
  v_estoque_fisico numeric(10,2);
  v_estoque_reservado_atual numeric(10,2);
  v_disponivel_fisico numeric(10,3);
  v_q_reserva numeric(10,3);
  v_q_entrega_futura numeric(10,3);
  v_reservas_criadas integer := 0;
  v_saldos_criados integer := 0;
  v_devolucoes_processadas integer := 0;
  v_plano jsonb;
  v_usar_plano boolean := false;
  v_elem jsonb;
  v_valores numeric[];
  v_dias_offsets integer[];
  v_formas text[];
  v_permuta_ids uuid[];
  v_soma_plano numeric;
  v_qtd_boletos_esperados integer;
  v_plano_contas_permuta_id uuid;
  v_permuta_criados integer := 0;
  v_ja_com_cliente boolean;
BEGIN
  IF COALESCE(auth.role(), '') <> 'service_role'
     AND NOT public.hub_pode_executar(auth.uid(), 'orcamentos', NULL, 'aprovar') THEN
    RAISE EXCEPTION 'Permissão negada para aprovar orçamento financeiramente.'
      USING ERRCODE = 'P0001';
  END IF;

  SELECT * INTO v_orcamento FROM public.orcamentos WHERE id = p_orcamento_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Orçamento % não encontrado.', p_orcamento_id USING ERRCODE = 'P0001';
  END IF;

  -- SPEC-195: vínculo de venda da Connect não passa pela aprovação financeira (não gera
  -- reserva, parcela nem boleto). Para aprovar de verdade, desfaça o vínculo antes.
  IF v_orcamento.vinculo_connect THEN
    RAISE EXCEPTION 'Orçamento % é vínculo de venda da Connect — não pode ser aprovado financeiramente. Desfaça o vínculo antes.', coalesce(v_orcamento.numero, p_orcamento_id::text)
      USING ERRCODE = 'P0001';
  END IF;

  -- SPEC-223: empréstimo não gera reserva, parcela nem boleto. Para cobrar, vira venda.
  IF v_orcamento.natureza_operacao = 'outros' AND v_orcamento.subgrupo = 'EMPRESTIMO' THEN
    RAISE EXCEPTION 'Empréstimo não passa pela aprovação financeira. Para cobrar, use "Virar venda" no empréstimo.'
      USING ERRCODE = 'P0001';
  END IF;

  v_status_anterior := v_orcamento.status;
  v_numero_orcamento := coalesce(v_orcamento.numero, left(p_orcamento_id::text, 8));

  IF v_orcamento.projeto_id IS NULL THEN
    RAISE EXCEPTION 'Orçamento % não possui projeto vinculado.', v_numero_orcamento USING ERRCODE = 'P0001';
  END IF;
  IF v_orcamento.empresa_id IS NULL THEN
    RAISE EXCEPTION 'Orçamento % não possui empresa vinculada.', v_numero_orcamento USING ERRCODE = 'P0001';
  END IF;
  IF v_orcamento.cliente_id IS NULL THEN
    RAISE EXCEPTION 'Orçamento % não possui cliente vinculado.', v_numero_orcamento USING ERRCODE = 'P0001';
  END IF;
  IF coalesce(v_orcamento.valor_total, 0) <= 0 THEN
    RAISE EXCEPTION 'Orçamento % possui valor total inválido.', v_numero_orcamento USING ERRCODE = 'P0001';
  END IF;
  IF v_orcamento.forma_pagamento IS NULL THEN
    RAISE EXCEPTION 'Orçamento % não possui forma de pagamento estruturada.', v_numero_orcamento USING ERRCODE = 'P0001';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.orcamento_itens oi WHERE oi.orcamento_id = p_orcamento_id) THEN
    RAISE EXCEPTION 'Orçamento % não possui itens.', v_numero_orcamento USING ERRCODE = 'P0001';
  END IF;
  IF EXISTS (
    SELECT 1 FROM public.orcamento_itens oi
    WHERE oi.orcamento_id = p_orcamento_id AND (coalesce(oi.quantidade, 0) <= 0 OR coalesce(oi.preco_unitario, 0) <= 0)
  ) THEN
    RAISE EXCEPTION 'Orçamento % possui item sem quantidade ou preço válido.', v_numero_orcamento USING ERRCODE = 'P0001';
  END IF;

  -- =====================================================================
  -- SPEC-152: monta v_qtd_parcelas + arrays (valor/dias_offset/forma de
  -- pagamento/fornecedor de permuta) por parcela -- de plano_parcelas
  -- quando presente, senão do jeito legado (parse de prazo + divisão
  -- igual + forma de pagamento única do orçamento).
  -- =====================================================================
  v_plano := v_orcamento.plano_parcelas;
  v_valor_total := coalesce(v_orcamento.valor_total, 0);

  IF v_plano IS NOT NULL AND jsonb_typeof(v_plano) = 'array' AND jsonb_array_length(v_plano) > 0 THEN
    v_usar_plano := true;
    v_qtd_parcelas := jsonb_array_length(v_plano);
    v_valores := ARRAY[]::numeric[];
    v_dias_offsets := ARRAY[]::integer[];
    v_formas := ARRAY[]::text[];
    v_permuta_ids := ARRAY[]::uuid[];

    FOR v_i IN 0..v_qtd_parcelas - 1 LOOP
      v_elem := v_plano -> v_i;
      v_valores := v_valores || round(coalesce((v_elem->>'valor')::numeric, 0), 2);
      v_dias_offsets := v_dias_offsets || coalesce((v_elem->>'dias_offset')::integer, 0);
      v_formas := v_formas || coalesce(nullif(v_elem->>'forma_pagamento', ''), v_orcamento.forma_pagamento::text);
      v_permuta_ids := v_permuta_ids || nullif(v_elem->>'permuta_fornecedor_id', '')::uuid;
    END LOOP;

    -- Regra dura (decisão do usuário, 2026-09-17): soma das parcelas deve
    -- ser EXATAMENTE igual ao valor a pagar -- nunca arredonda
    -- silenciosamente. O frontend já valida isso antes de salvar o
    -- orçamento (BudgetFormPage.tsx); esta é a validação de segurança no
    -- backend, fonte de verdade final.
    SELECT coalesce(sum(v), 0) INTO v_soma_plano FROM unnest(v_valores) AS v;
    IF abs(v_soma_plano - v_valor_total) > 0.01 THEN
      RAISE EXCEPTION 'Soma do plano de parcelas (%) não bate com o valor total do orçamento (%).',
        v_soma_plano, v_valor_total USING ERRCODE = 'P0001';
    END IF;
  ELSE
    v_prazos := public._lucenera_parse_prazo_pagamento(v_orcamento.condicoes_pagamento, v_orcamento.prazo_pagamento_dias);
    v_qtd_parcelas := coalesce(array_length(v_prazos, 1), 0);
    IF v_qtd_parcelas = 0 THEN
      RAISE EXCEPTION 'Orçamento % não possui prazo de pagamento interpretável.', v_numero_orcamento USING ERRCODE = 'P0001';
    END IF;

    v_dias_offsets := v_prazos;
    v_formas := ARRAY(SELECT v_orcamento.forma_pagamento::text FROM generate_series(1, v_qtd_parcelas));
    v_permuta_ids := ARRAY(SELECT NULL::uuid FROM generate_series(1, v_qtd_parcelas));

    v_valor_base := round(v_valor_total / v_qtd_parcelas, 2);
    v_valores := ARRAY[]::numeric[];
    v_valor_acumulado := 0;
    FOR v_i IN 1..v_qtd_parcelas LOOP
      IF v_i = v_qtd_parcelas THEN
        v_valores := v_valores || round(v_valor_total - v_valor_acumulado, 2);
      ELSE
        v_valores := v_valores || v_valor_base;
        v_valor_acumulado := v_valor_acumulado + v_valor_base;
      END IF;
    END LOOP;
  END IF;

  -- SPEC-156: parcela de permuta exige contato real, fornecedor OU cliente
  -- (antes só aceitava tipo='fornecedor' -- às vezes a contraparte da
  -- permuta é o próprio cliente oferecendo produto/serviço em troca).
  FOR v_i IN 1..v_qtd_parcelas LOOP
    IF v_formas[v_i] = 'permuta' THEN
      IF v_permuta_ids[v_i] IS NULL THEN
        RAISE EXCEPTION 'Parcela % está marcada como permuta mas não tem fornecedor/cliente definido.', v_i
          USING ERRCODE = 'P0001';
      END IF;
      IF NOT EXISTS (SELECT 1 FROM public.contatos WHERE id = v_permuta_ids[v_i] AND tipo IN ('fornecedor', 'cliente')) THEN
        RAISE EXCEPTION 'Parcela % de permuta precisa de um fornecedor ou cliente válido (contatos.tipo IN (fornecedor, cliente)).', v_i
          USING ERRCODE = 'P0001';
      END IF;
    END IF;
  END LOOP;

  -- Quantidade de boletos esperada quando o processamento já rodou antes
  -- (idempotência) -- carteira/permuta não geram boleto, então já não é
  -- igual a v_qtd_parcelas como no comportamento legado.
  SELECT count(*) INTO v_qtd_boletos_esperados FROM unnest(v_formas) AS f WHERE f NOT IN ('carteira', 'permuta');

  SELECT nome INTO v_cliente_nome FROM public.contatos WHERE id = v_orcamento.cliente_id;

  -- =====================================================================
  -- SPEC-071: ramo de DEVOLUÇÃO — não cria projeto_itens/reserva de estoque
  -- positiva; devolve estoque via registrar_devolucao_projeto_item (SPEC-015)
  -- e lança crédito financeiro negativo em vez de cobrança.
  -- SPEC-136: devolução não gera numero_venda — é crédito sobre uma venda já
  -- existente, não uma venda nova.
  -- =====================================================================
  IF v_orcamento.natureza_operacao = 'devolucao' THEN
    IF EXISTS (
      SELECT 1 FROM public.orcamento_itens oi
      WHERE oi.orcamento_id = p_orcamento_id AND oi.projeto_item_origem_id IS NULL
    ) THEN
      RAISE EXCEPTION 'Orçamento de devolução % possui item sem venda de origem vinculada.', v_numero_orcamento
        USING ERRCODE = 'P0001';
    END IF;

    -- SPEC-182 (05/10): a devolução se liga ao CÓDIGO DO PROJETO (substitui a
    -- venda única da SPEC-181): cada item precisa vir de uma venda efetivada
    -- do mesmo projeto e da mesma empresa da devolução; pode misturar vendas.
    IF EXISTS (
      SELECT 1 FROM public.orcamento_itens oi
      JOIN public.projeto_itens pi ON pi.id = oi.projeto_item_origem_id
      LEFT JOIN public.orcamentos vo ON vo.id = pi.orcamento_id
      WHERE oi.orcamento_id = p_orcamento_id
        AND (vo.id IS NULL
             OR vo.numero_venda IS NULL
             OR vo.projeto_id IS DISTINCT FROM v_orcamento.projeto_id
             OR pi.projeto_id IS DISTINCT FROM v_orcamento.projeto_id
             OR vo.empresa_id IS DISTINCT FROM v_orcamento.empresa_id)
    ) THEN
      RAISE EXCEPTION 'Orçamento de devolução % possui item que não é de uma venda efetivada deste projeto e desta empresa.', v_numero_orcamento
        USING ERRCODE = 'P0001';
    END IF;
    -- SPEC-182 (D6): peça em separação não se devolve — cancelar a separação antes.
    IF EXISTS (
      SELECT 1 FROM public.orcamento_itens oi
      WHERE oi.orcamento_id = p_orcamento_id AND oi.setor_origem = 'em_separacao'
    ) THEN
      RAISE EXCEPTION 'Orçamento de devolução % tem peça em separação. Cancele a separação antes de devolver.', v_numero_orcamento
        USING ERRCODE = 'P0001';
    END IF;

    SELECT count(*) INTO v_parcelas_existentes FROM public.projeto_parcelas WHERE orcamento_id = p_orcamento_id;
    SELECT count(*) INTO v_boletos_existentes FROM public.boletos WHERE orcamento_id = p_orcamento_id AND tipo_operacao IS DISTINCT FROM 'CP';

    IF v_parcelas_existentes = v_qtd_parcelas AND v_boletos_existentes = v_qtd_boletos_esperados THEN
      UPDATE public.orcamentos SET status = 'Orçamento Aprovado' WHERE id = p_orcamento_id;
      RETURN jsonb_build_object(
        'orcamento_id', p_orcamento_id, 'status', 'Orçamento Aprovado', 'natureza_operacao', 'devolucao',
        'projeto_id', v_orcamento.projeto_id,
        'devolucoes_processadas', 0, 'parcelas_criadas', 0, 'boletos_criados', 0, 'ja_processado', true
      );
    END IF;

    IF v_parcelas_existentes > 0 OR v_boletos_existentes > 0 THEN
      RAISE EXCEPTION 'Orçamento de devolução % possui processamento parcial inconsistente: parcelas %, boletos %.',
        v_numero_orcamento, v_parcelas_existentes, v_boletos_existentes USING ERRCODE = 'P0001';
    END IF;

    IF v_orcamento.status != 'Aprovação Financeira' THEN
      RAISE EXCEPTION 'Orçamento % não está aguardando aprovação financeira. Status atual: %', v_numero_orcamento, v_status_anterior
        USING ERRCODE = 'P0003';
    END IF;

    UPDATE public.orcamentos SET status = 'Orçamento Aprovado', requer_revisao_financeira = false WHERE id = p_orcamento_id;

    BEGIN
      INSERT INTO public.historico_status_orcamentos (orcamento_id, status_anterior, status_novo, usuario, observacao)
      VALUES (p_orcamento_id, v_status_anterior, 'Orçamento Aprovado', auth.uid()::text, 'Aprovação financeira de devolução — estoque devolvido e crédito lançado');
    EXCEPTION
      WHEN undefined_table OR undefined_column OR foreign_key_violation THEN
        NULL;
    END;

    -- SPEC-178: linha com setor_origem devolve exatamente daquele setor
    -- (uma linha por setor); linha antiga sem setor segue a cascata original.
    FOR v_item IN
      SELECT oi.projeto_item_origem_id AS projeto_item_id, oi.quantidade, oi.descricao, oi.setor_origem
      FROM public.orcamento_itens oi
      WHERE oi.orcamento_id = p_orcamento_id
    LOOP
      IF v_item.setor_origem IS NOT NULL THEN
        PERFORM public.registrar_devolucao_projeto_item_setor(
          v_item.projeto_item_id,
          v_item.setor_origem,
          v_item.quantidade,
          format('Devolução via orçamento %s%s', v_numero_orcamento,
            CASE WHEN v_item.descricao IS NOT NULL THEN ' — ' || v_item.descricao ELSE '' END)
        );
      ELSE
        PERFORM public.registrar_devolucao_projeto_item(
          v_item.projeto_item_id,
          v_item.quantidade,
          format('Devolução via orçamento %s%s', v_numero_orcamento,
            CASE WHEN v_item.descricao IS NOT NULL THEN ' — ' || v_item.descricao ELSE '' END)
        );
      END IF;
      v_devolucoes_processadas := v_devolucoes_processadas + 1;
    END LOOP;

    FOR v_i IN 1..v_qtd_parcelas LOOP
      v_valor_parcela := v_valores[v_i];
      INSERT INTO public.projeto_parcelas (
        projeto_id, numero_parcela, valor, data_fechamento, data_vencimento, status,
        forma_pagamento, orcamento_id, descricao, permuta_fornecedor_id
      )
      VALUES (
        v_orcamento.projeto_id, v_i, -v_valor_parcela, current_date, v_data_base + v_dias_offsets[v_i],
        (CASE WHEN v_formas[v_i] = 'permuta' THEN 'paga' ELSE 'pendente' END)::public.parcela_status,
        v_formas[v_i]::public.pagamento_forma, p_orcamento_id,
        'Crédito de devolução gerado pelo orçamento ' || v_numero_orcamento,
        v_permuta_ids[v_i]
      );
      v_parcelas_criadas := v_parcelas_criadas + 1;
    END LOOP;

    -- SPEC-152: carteira/permuta não geram "boleto" (nota de crédito, no
    -- ramo devolução) -- ver comentário no topo do arquivo.
    INSERT INTO public.boletos (nosso_numero, numero_documento, parcela_id, orcamento_id, empresa_id, valor, vencimento, nome_pagador, status, tipo, venda, num_parcela, total_parcelas, emissao)
    SELECT 'DEV-' || regexp_replace(v_numero_orcamento, '[^a-zA-Z0-9]', '', 'g') || '-P' || pp.numero_parcela,
      v_numero_orcamento || '-P' || pp.numero_parcela, pp.id, p_orcamento_id, v_orcamento.empresa_id,
      pp.valor, pp.data_vencimento, coalesce(v_cliente_nome, 'Cliente do orçamento'), 'pendente_registro', 'Nota de Crédito', NULL,
      pp.numero_parcela, v_qtd_parcelas, current_date
    FROM public.projeto_parcelas pp
    WHERE pp.orcamento_id = p_orcamento_id AND pp.forma_pagamento NOT IN ('carteira', 'permuta')
    ON CONFLICT (nosso_numero) DO NOTHING;
    GET DIAGNOSTICS v_boletos_criados = ROW_COUNT;

    -- SPEC-152: contrapartida automática de Contas a Pagar pra cada
    -- parcela de permuta (mesmo padrão manual de "Cadastrar Duplicatas",
    -- SPEC-073: boletos.tipo_operacao = 'CP' + apropriacao_id).
    SELECT id INTO v_plano_contas_permuta_id FROM public.plano_de_contas WHERE nome = 'PERMUTA/CONTRAPARTIDA' AND nivel = 3 LIMIT 1;
    INSERT INTO public.boletos (
      nosso_numero, numero_documento, orcamento_id, empresa_id, apropriacao_id,
      tipo_operacao, valor, vencimento, nome_pagador, status, tipo, num_parcela, total_parcelas, emissao, observacao
    )
    SELECT
      'PERM-' || regexp_replace(v_numero_orcamento, '[^a-zA-Z0-9]', '', 'g') || '-P' || pp.numero_parcela,
      v_numero_orcamento || '-PERMUTA-P' || pp.numero_parcela,
      p_orcamento_id, v_orcamento.empresa_id, v_plano_contas_permuta_id,
      'CP', abs(pp.valor), pp.data_vencimento,
      coalesce(f.razao_social, f.nome, 'Contraparte da permuta'),
      'Pendente', 'Normal', pp.numero_parcela, v_qtd_parcelas, current_date,
      'Contrapartida automática de permuta gerada pela aprovação do orçamento ' || v_numero_orcamento
    FROM public.projeto_parcelas pp
    LEFT JOIN public.contatos f ON f.id = pp.permuta_fornecedor_id
    WHERE pp.orcamento_id = p_orcamento_id AND pp.forma_pagamento = 'permuta'
    ON CONFLICT (nosso_numero) DO NOTHING;
    GET DIAGNOSTICS v_permuta_criados = ROW_COUNT;

    RETURN jsonb_build_object(
      'orcamento_id', p_orcamento_id, 'status', 'Orçamento Aprovado', 'natureza_operacao', 'devolucao',
      'projeto_id', v_orcamento.projeto_id,
      'devolucoes_processadas', v_devolucoes_processadas,
      'parcelas_criadas', v_parcelas_criadas, 'boletos_criados', v_boletos_criados,
      'contrapartidas_permuta_criadas', v_permuta_criados,
      'ja_processado', false
    );
  END IF;

  -- =====================================================================
  -- Ramo VENDA — comportamento original, exceto pela correção de prioridade
  -- da descrição do item (ver cabeçalho da migration).
  -- =====================================================================
  -- SPEC-135: bloqueia aprovação (faturamento) quando existe item sem
  -- produto cadastrado — sem isso, vira uma venda "fantasma" sem controle
  -- de estoque nenhum (o loop abaixo já pula reserva pra item sem
  -- produto_id, mas antes disso deixava aprovar e gerar parcela/boleto
  -- normalmente). O item precisa ser vinculado a um produto real (cadastro)
  -- antes desta aprovação — não se aplica à devolução, que já retorna acima.
  IF EXISTS (
    SELECT 1 FROM public.orcamento_itens oi
    WHERE oi.orcamento_id = p_orcamento_id AND oi.produto_id IS NULL
  ) THEN
    RAISE EXCEPTION 'Orçamento % possui item sem produto cadastrado (peça sem código interno) — cadastre o produto antes de aprovar financeiramente.', v_numero_orcamento
      USING ERRCODE = 'P0001';
  END IF;

  SELECT count(*) INTO v_itens_existentes FROM public.projeto_itens WHERE orcamento_id = p_orcamento_id;
  SELECT count(*) INTO v_parcelas_existentes FROM public.projeto_parcelas WHERE orcamento_id = p_orcamento_id;
  SELECT count(*) INTO v_boletos_existentes FROM public.boletos WHERE orcamento_id = p_orcamento_id AND tipo_operacao IS DISTINCT FROM 'CP';

  IF v_itens_existentes > 0 AND v_parcelas_existentes = v_qtd_parcelas AND v_boletos_existentes = v_qtd_boletos_esperados THEN
    UPDATE public.orcamentos SET status = 'Orçamento Aprovado' WHERE id = p_orcamento_id;
    RETURN jsonb_build_object(
      'orcamento_id', p_orcamento_id, 'status', 'Orçamento Aprovado', 'projeto_id', v_orcamento.projeto_id,
      'numero_venda', v_orcamento.numero_venda,
      'projeto_itens_criados', 0, 'parcelas_criadas', 0, 'boletos_criados', 0,
      'reservas_estoque_aplicadas', 0, 'saldos_operacionais_criados', 0,
      'nota_fiscal_status', 'pendente_api', 'ja_processado', true
    );
  END IF;

  IF v_itens_existentes > 0 OR v_parcelas_existentes > 0 OR v_boletos_existentes > 0 THEN
    RAISE EXCEPTION 'Orçamento % possui processamento parcial inconsistente: itens %, parcelas %, boletos %.',
      v_numero_orcamento, v_itens_existentes, v_parcelas_existentes, v_boletos_existentes USING ERRCODE = 'P0001';
  END IF;

  IF v_orcamento.status != 'Aprovação Financeira' THEN
    RAISE EXCEPTION 'Orçamento % não está aguardando aprovação financeira. Status atual: %', v_numero_orcamento, v_status_anterior
      USING ERRCODE = 'P0003';
  END IF;

  -- SPEC-136: numero da venda, gerado uma unica vez, sequencia global
  -- "VENDA-0001" no mesmo padrao de set_orcamento_numero() para ORC-XXXX.
  IF v_orcamento.numero_venda IS NULL THEN
    SELECT COALESCE(MAX(CAST(SUBSTRING(numero_venda FROM 7) AS INTEGER)), 0) + 1
    INTO v_seq_venda
    FROM public.orcamentos
    WHERE numero_venda LIKE 'VENDA-%' AND numero_venda ~ '^VENDA-\d+$';
    v_numero_venda := 'VENDA-' || LPAD(v_seq_venda::text, 4, '0');
  ELSE
    v_numero_venda := v_orcamento.numero_venda;
  END IF;

  UPDATE public.orcamentos
  SET status = 'Orçamento Aprovado', requer_revisao_financeira = false, numero_venda = v_numero_venda
  WHERE id = p_orcamento_id;

  BEGIN
    INSERT INTO public.historico_status_orcamentos (orcamento_id, status_anterior, status_novo, usuario, observacao)
    VALUES (p_orcamento_id, v_status_anterior, 'Orçamento Aprovado', auth.uid()::text, 'Aprovação financeira — processamento de itens, parcelas e boletos');
  EXCEPTION
    WHEN undefined_table OR undefined_column OR foreign_key_violation THEN
      NULL;
  END;

  FOR v_item IN
    INSERT INTO public.projeto_itens (
      projeto_id, produto_id, descricao, quantidade, preco_unitario, desconto, validado, orcamento_id,
      orcamento_item_id, l_fixo
    )
    SELECT v_orcamento.projeto_id, oi.produto_id, coalesce(oi.descricao, p.nome, oi.custom_id, 'Item do Orçamento'),
      coalesce(oi.quantidade, 0), coalesce(oi.preco_unitario, 0), coalesce(oi.desconto, 0),
      true, p_orcamento_id,
      oi.id, oi.custom_id
    FROM public.orcamento_itens oi LEFT JOIN public.produtos p ON p.id = oi.produto_id
    WHERE oi.orcamento_id = p_orcamento_id
    RETURNING id, produto_id, quantidade, orcamento_item_id
  LOOP
    v_itens_criados := v_itens_criados + 1;

    CONTINUE WHEN v_item.produto_id IS NULL OR coalesce(v_item.quantidade, 0) <= 0;

    -- SPEC-223: peça de venda que veio de empréstimo e já está com o cliente vai direto para
    -- Entregue (sem reserva/separação). A reserva no estoque_itens segue a regra de sempre.
    SELECT coalesce(oi.ja_com_cliente, false) INTO v_ja_com_cliente
      FROM public.orcamento_itens oi WHERE oi.id = v_item.orcamento_item_id;
    IF v_ja_com_cliente THEN
      INSERT INTO public.estoque_itens (produto_id, local, quantidade, quantidade_reservada, atualizado_em)
      VALUES (v_item.produto_id, 'Estoque'::public.estoque_local, 0, 0, NOW())
      ON CONFLICT (produto_id, local) DO NOTHING;
      UPDATE public.estoque_itens
      SET quantidade_reservada = quantidade_reservada + v_item.quantidade, atualizado_em = NOW()
      WHERE produto_id = v_item.produto_id AND local = 'Estoque'::public.estoque_local;
      v_reservas_criadas := v_reservas_criadas + 1;
      INSERT INTO public.estoque_saldos_projeto_item (projeto_item_id, q_reserva, q_entrega_futura, q_entregue)
      VALUES (v_item.id, 0, 0, v_item.quantidade)
      ON CONFLICT (projeto_item_id) DO NOTHING;
      v_saldos_criados := v_saldos_criados + 1;
      INSERT INTO public.estoque_movimentos_projeto_item (
        projeto_item_id, tipo, quantidade, origem, referencia_id, observacao, criado_por
      )
      VALUES (
        v_item.id, 'entregue', v_item.quantidade, 'emprestimo', p_orcamento_id,
        format('Já estava com o cliente (empréstimo) — entregue na aprovação do orçamento %s', v_numero_orcamento),
        auth.uid()
      );
      CONTINUE;
    END IF;

    INSERT INTO public.estoque_itens (produto_id, local, quantidade, quantidade_reservada, atualizado_em)
    VALUES (v_item.produto_id, 'Estoque'::public.estoque_local, 0, 0, NOW())
    ON CONFLICT (produto_id, local) DO NOTHING;

    SELECT quantidade, quantidade_reservada
      INTO v_estoque_fisico, v_estoque_reservado_atual
    FROM public.estoque_itens
    WHERE produto_id = v_item.produto_id AND local = 'Estoque'::public.estoque_local
    FOR UPDATE;

    v_disponivel_fisico := GREATEST(0, coalesce(v_estoque_fisico, 0) - coalesce(v_estoque_reservado_atual, 0));
    v_q_reserva := LEAST(v_item.quantidade, v_disponivel_fisico);
    v_q_entrega_futura := GREATEST(0, v_item.quantidade - v_q_reserva);

    UPDATE public.estoque_itens
    SET quantidade_reservada = quantidade_reservada + v_item.quantidade, atualizado_em = NOW()
    WHERE produto_id = v_item.produto_id AND local = 'Estoque'::public.estoque_local;

    v_reservas_criadas := v_reservas_criadas + 1;

    INSERT INTO public.estoque_saldos_projeto_item (projeto_item_id, q_reserva, q_entrega_futura)
    VALUES (v_item.id, v_q_reserva, v_q_entrega_futura)
    ON CONFLICT (projeto_item_id) DO NOTHING;

    v_saldos_criados := v_saldos_criados + 1;

    INSERT INTO public.estoque_movimentos_projeto_item (
      projeto_item_id, tipo, quantidade, origem, referencia_id, observacao, criado_por
    )
    VALUES (
      v_item.id, 'aprovacao_orcamento', v_item.quantidade, 'aprovar_orcamento_financeiro', p_orcamento_id,
      format('Reserva %s / entrega futura %s na aprovação do orçamento %s', v_q_reserva, v_q_entrega_futura, v_numero_orcamento),
      auth.uid()
    );
  END LOOP;

  FOR v_i IN 1..v_qtd_parcelas LOOP
    v_valor_parcela := v_valores[v_i];
    INSERT INTO public.projeto_parcelas (
      projeto_id, numero_parcela, valor, data_fechamento, data_vencimento, status,
      forma_pagamento, orcamento_id, descricao, permuta_fornecedor_id
    )
    VALUES (
      v_orcamento.projeto_id, v_i, v_valor_parcela, current_date, v_data_base + v_dias_offsets[v_i],
      (CASE WHEN v_formas[v_i] = 'permuta' THEN 'paga' ELSE 'pendente' END)::public.parcela_status,
      v_formas[v_i]::public.pagamento_forma, p_orcamento_id,
      'Parcela gerada pelo orçamento ' || v_numero_orcamento,
      v_permuta_ids[v_i]
    );
    v_parcelas_criadas := v_parcelas_criadas + 1;
  END LOOP;

  -- SPEC-152: carteira/permuta não geram boleto de cobrança pro cliente
  -- (ver comentário no topo do arquivo).
  INSERT INTO public.boletos (nosso_numero, numero_documento, parcela_id, orcamento_id, empresa_id, valor, vencimento, nome_pagador, status, tipo, venda, num_parcela, total_parcelas, emissao)
  SELECT 'ORC-' || regexp_replace(v_numero_orcamento, '[^a-zA-Z0-9]', '', 'g') || '-P' || pp.numero_parcela,
    v_numero_orcamento || '-P' || pp.numero_parcela, pp.id, p_orcamento_id, v_orcamento.empresa_id,
    pp.valor, pp.data_vencimento, coalesce(v_cliente_nome, 'Cliente do orçamento'), 'pendente_registro', 'Nota Fiscal', NULL,
    pp.numero_parcela, v_qtd_parcelas, current_date
  FROM public.projeto_parcelas pp
  WHERE pp.orcamento_id = p_orcamento_id AND pp.forma_pagamento NOT IN ('carteira', 'permuta')
  ON CONFLICT (nosso_numero) DO NOTHING;
  GET DIAGNOSTICS v_boletos_criados = ROW_COUNT;

  -- SPEC-152: contrapartida automática de Contas a Pagar pra cada parcela
  -- de permuta (mesmo padrão manual de "Cadastrar Duplicatas", SPEC-073:
  -- boletos.tipo_operacao = 'CP' + apropriacao_id -- rastreado até a
  -- origem por boletos.orcamento_id, já existente).
  SELECT id INTO v_plano_contas_permuta_id FROM public.plano_de_contas WHERE nome = 'PERMUTA/CONTRAPARTIDA' AND nivel = 3 LIMIT 1;
  INSERT INTO public.boletos (
    nosso_numero, numero_documento, orcamento_id, empresa_id, apropriacao_id,
    tipo_operacao, valor, vencimento, nome_pagador, status, tipo, num_parcela, total_parcelas, emissao, observacao
  )
  SELECT
    'PERM-' || regexp_replace(v_numero_orcamento, '[^a-zA-Z0-9]', '', 'g') || '-P' || pp.numero_parcela,
    v_numero_orcamento || '-PERMUTA-P' || pp.numero_parcela,
    p_orcamento_id, v_orcamento.empresa_id, v_plano_contas_permuta_id,
    'CP', abs(pp.valor), pp.data_vencimento,
    coalesce(f.razao_social, f.nome, 'Contraparte da permuta'),
    'Pendente', 'Normal', pp.numero_parcela, v_qtd_parcelas, current_date,
    'Contrapartida automática de permuta gerada pela aprovação do orçamento ' || v_numero_orcamento
  FROM public.projeto_parcelas pp
  LEFT JOIN public.contatos f ON f.id = pp.permuta_fornecedor_id
  WHERE pp.orcamento_id = p_orcamento_id AND pp.forma_pagamento = 'permuta'
  ON CONFLICT (nosso_numero) DO NOTHING;
  GET DIAGNOSTICS v_permuta_criados = ROW_COUNT;

  RETURN jsonb_build_object(
    'orcamento_id', p_orcamento_id, 'status', 'Orçamento Aprovado', 'projeto_id', v_orcamento.projeto_id,
    'numero_venda', v_numero_venda,
    'projeto_itens_criados', v_itens_criados, 'parcelas_criadas', v_parcelas_criadas, 'boletos_criados', v_boletos_criados,
    'contrapartidas_permuta_criadas', v_permuta_criados,
    'reservas_estoque_aplicadas', v_reservas_criadas, 'saldos_operacionais_criados', v_saldos_criados,
    'nota_fiscal_status', 'pendente_api', 'ja_processado', false
  );
END;
$function$;

-- replace_orcamento_itens: passa a gravar/comparar ja_com_cliente.
CREATE OR REPLACE FUNCTION public.replace_orcamento_itens(p_orcamento_id uuid, p_items jsonb)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  inserted_count integer;
  v_user_role text;
  v_extra_count integer;
  v_itens_iguais boolean;
BEGIN
  IF COALESCE(auth.role(), '') <> 'service_role' THEN
    SELECT u.role::text INTO v_user_role
    FROM public.usuarios u
    WHERE u.id = auth.uid()
      AND COALESCE(u.ativo, true) = true;

    IF v_user_role IS DISTINCT FROM 'admin' THEN
      WITH old_items AS (
        SELECT
          COALESCE(produto_id::text, '') AS identidade,
          COALESCE(descricao, '') AS descricao_,
          preco_unitario,
          row_number() OVER (
            PARTITION BY COALESCE(produto_id::text, ''), COALESCE(descricao, ''), preco_unitario
            ORDER BY id
          ) AS rn
        FROM public.orcamento_itens
        WHERE orcamento_id = p_orcamento_id
      ),
      new_items AS (
        SELECT
          COALESCE(item->>'produto_id', '') AS identidade,
          COALESCE(item->>'descricao', '') AS descricao_,
          (item->>'preco_unitario')::numeric AS preco_unitario,
          row_number() OVER (
            PARTITION BY COALESCE(item->>'produto_id', ''), COALESCE(item->>'descricao', ''), (item->>'preco_unitario')::numeric
            ORDER BY ordinality
          ) AS rn
        FROM jsonb_array_elements(p_items) WITH ORDINALITY AS t(item, ordinality)
      )
      SELECT count(*) INTO v_extra_count
      FROM new_items n
      LEFT JOIN old_items o
        ON o.identidade = n.identidade
       AND o.descricao_ = n.descricao_
       AND o.preco_unitario = n.preco_unitario
       AND o.rn = n.rn
      WHERE o.rn IS NULL;

      IF v_extra_count > 0 THEN
        RAISE EXCEPTION 'Permissao negada: alterar valor ou produto de item do orcamento requer perfil administrador.'
          USING ERRCODE = 'P0001';
      END IF;
    END IF;
  END IF;

  -- SPEC-135: o formulario reenvia os itens em QUALQUER salvamento (mesmo
  -- so mudando forma de pagamento/data/desconto, campos que nao ficam em
  -- orcamento_itens). O DELETE+INSERT abaixo disparava incondicionalmente o
  -- trigger trg_orcamento_item_change_reset, reiniciando o ciclo de
  -- aprovacao do cliente mesmo quando nenhum item mudou de fato. Se o
  -- conjunto recebido e identico ao ja salvo, nao mexe na tabela -- preserva
  -- a regra do SPEC-111 (mudanca REAL de item reseta) sem o falso positivo.
  WITH old_rows AS (
    SELECT
      produto_id, descricao, quantidade, preco_unitario, desconto,
      custom_id, ordem, sub_ordem, item_pai_id, peca_nova, projeto_item_origem_id, setor_origem, ja_com_cliente
    FROM public.orcamento_itens
    WHERE orcamento_id = p_orcamento_id
  ),
  new_rows AS (
    SELECT
      CASE WHEN item->>'produto_id' IS NULL OR item->>'produto_id' = '' THEN NULL ELSE (item->>'produto_id')::uuid END AS produto_id,
      NULLIF(item->>'descricao', '') AS descricao,
      (item->>'quantidade')::numeric AS quantidade,
      (item->>'preco_unitario')::numeric AS preco_unitario,
      (item->>'desconto')::numeric AS desconto,
      NULLIF(item->>'custom_id', '') AS custom_id,
      CASE WHEN item->>'ordem' IS NULL OR item->>'ordem' = '' THEN NULL ELSE (item->>'ordem')::integer END AS ordem,
      CASE WHEN item->>'sub_ordem' IS NULL OR item->>'sub_ordem' = '' THEN NULL ELSE (item->>'sub_ordem')::integer END AS sub_ordem,
      CASE WHEN item->>'item_pai_id' IS NULL OR item->>'item_pai_id' = '' THEN NULL ELSE (item->>'item_pai_id')::uuid END AS item_pai_id,
      COALESCE((item->>'peca_nova')::boolean, false) AS peca_nova,
      CASE WHEN item->>'projeto_item_origem_id' IS NULL OR item->>'projeto_item_origem_id' = '' THEN NULL ELSE (item->>'projeto_item_origem_id')::uuid END AS projeto_item_origem_id,
      NULLIF(item->>'setor_origem', '') AS setor_origem,
      COALESCE((item->>'ja_com_cliente')::boolean, false) AS ja_com_cliente
    FROM jsonb_array_elements(p_items) AS item
    WHERE (item->>'produto_id' IS NOT NULL AND item->>'produto_id' != '')
       OR NULLIF(item->>'descricao', '') IS NOT NULL
  )
  SELECT
    NOT EXISTS (SELECT * FROM old_rows EXCEPT ALL SELECT * FROM new_rows)
    AND NOT EXISTS (SELECT * FROM new_rows EXCEPT ALL SELECT * FROM old_rows)
  INTO v_itens_iguais;

  IF v_itens_iguais THEN
    SELECT count(*) INTO inserted_count FROM public.orcamento_itens WHERE orcamento_id = p_orcamento_id;
    RETURN inserted_count;
  END IF;

  DELETE FROM public.orcamento_itens WHERE orcamento_id = p_orcamento_id;

  INSERT INTO public.orcamento_itens (
    orcamento_id,
    produto_id,
    descricao,
    quantidade,
    preco_unitario,
    desconto,
    custom_id,
    ordem,
    sub_ordem,
    item_pai_id,
    peca_nova,
    projeto_item_origem_id,
    setor_origem,
    ja_com_cliente
  )
  SELECT
    p_orcamento_id,
    CASE
      WHEN item->>'produto_id' IS NULL OR item->>'produto_id' = '' THEN NULL
      ELSE (item->>'produto_id')::uuid
    END,
    NULLIF(item->>'descricao', ''),
    (item->>'quantidade')::numeric,
    (item->>'preco_unitario')::numeric,
    (item->>'desconto')::numeric,
    NULLIF(item->>'custom_id', ''),
    CASE
      WHEN item->>'ordem' IS NULL OR item->>'ordem' = '' THEN NULL
      ELSE (item->>'ordem')::integer
    END,
    CASE
      WHEN item->>'sub_ordem' IS NULL OR item->>'sub_ordem' = '' THEN NULL
      ELSE (item->>'sub_ordem')::integer
    END,
    CASE
      WHEN item->>'item_pai_id' IS NULL OR item->>'item_pai_id' = '' THEN NULL
      ELSE (item->>'item_pai_id')::uuid
    END,
    COALESCE((item->>'peca_nova')::boolean, false),
    CASE
      WHEN item->>'projeto_item_origem_id' IS NULL OR item->>'projeto_item_origem_id' = '' THEN NULL
      ELSE (item->>'projeto_item_origem_id')::uuid
    END,
    NULLIF(item->>'setor_origem', ''),
    COALESCE((item->>'ja_com_cliente')::boolean, false)
  FROM jsonb_array_elements(p_items) AS item
  WHERE (item->>'produto_id' IS NOT NULL AND item->>'produto_id' != '')
     OR NULLIF(item->>'descricao', '') IS NOT NULL;

  GET DIAGNOSTICS inserted_count = ROW_COUNT;
  RETURN inserted_count;
END;
$function$;
