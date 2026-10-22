-- SPEC-219 (22/10/2026): empréstimo de peças do Showroom com termo para o cliente assinar.
-- Só registro: produtos.estoque_showroom e a vitrine NÃO mudam (decisão 1 da SPEC).
-- O /admin do Showroom é sempre anon (sem sessão Supabase): tabelas fechadas, tudo passa por
-- RPC SECURITY DEFINER que confere a credencial do /admin (showroom_cred_ok).
-- Sem BEGIN/COMMIT no texto (aplicar com dry-run + rollback antes).

CREATE SEQUENCE IF NOT EXISTS public.showroom_emprestimos_numero_seq;

CREATE TABLE IF NOT EXISTS public.showroom_emprestimos (
  id                      uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  numero                  integer NOT NULL UNIQUE DEFAULT nextval('public.showroom_emprestimos_numero_seq'),
  empresa_id              uuid NOT NULL REFERENCES public.empresas (id),
  contato_id              uuid NOT NULL REFERENCES public.contatos (id),
  -- Dados do cliente no dia do empréstimo: o termo assinado não muda se o cadastro for editado.
  cliente_snapshot        jsonb NOT NULL,
  data_emprestimo         date NOT NULL DEFAULT (now() AT TIME ZONE 'America/Sao_Paulo')::date,
  data_prevista_devolucao date NOT NULL,
  observacoes             text,
  cancelado_em            timestamptz,
  cancelado_motivo        text,
  criado_por              text,
  criado_em               timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT showroom_emprestimos_prazo_ck CHECK (data_prevista_devolucao >= data_emprestimo)
);
ALTER SEQUENCE public.showroom_emprestimos_numero_seq OWNED BY public.showroom_emprestimos.numero;

CREATE TABLE IF NOT EXISTS public.showroom_emprestimo_itens (
  id                       uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  emprestimo_id            uuid NOT NULL REFERENCES public.showroom_emprestimos (id) ON DELETE CASCADE,
  produto_id               uuid NOT NULL REFERENCES public.produtos (id),
  codigo_produto           integer NOT NULL,
  nome                     text NOT NULL,
  referencia               text,
  quantidade               integer NOT NULL CHECK (quantidade > 0),
  -- valor_venda no dia do empréstimo = valor cobrado em caso de dano.
  valor_unitario           numeric(14,2) NOT NULL CHECK (valor_unitario >= 0),
  situacao                 text NOT NULL DEFAULT 'emprestado'
                           CHECK (situacao IN ('emprestado', 'devolvido', 'devolvido_com_dano')),
  data_devolucao           date,
  descricao_dano           text,
  valor_dano               numeric(14,2),
  devolvido_registrado_por text,
  CONSTRAINT showroom_emprestimo_itens_dano_ck CHECK (
    situacao <> 'devolvido_com_dano'
    OR (nullif(trim(descricao_dano), '') IS NOT NULL AND valor_dano IS NOT NULL)
  )
);
CREATE INDEX IF NOT EXISTS showroom_emprestimo_itens_emprestimo_idx
  ON public.showroom_emprestimo_itens (emprestimo_id);
CREATE INDEX IF NOT EXISTS showroom_emprestimo_itens_abertos_idx
  ON public.showroom_emprestimo_itens (codigo_produto) WHERE situacao = 'emprestado';

-- Só as RPCs abaixo mexem nelas (SPEC-196: RLS ligado, sem policy, sem grant).
ALTER TABLE public.showroom_emprestimos ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.showroom_emprestimo_itens ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.showroom_emprestimos FROM anon, authenticated;
REVOKE ALL ON public.showroom_emprestimo_itens FROM anon, authenticated;
REVOKE ALL ON SEQUENCE public.showroom_emprestimos_numero_seq FROM anon, authenticated;


-- Status calculado (não gravado). Interna: sem grant para anon/authenticated.
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
                  WHERE i.emprestimo_id = e.id AND i.situacao = 'devolvido_com_dano') THEN 'devolvido_com_dano'
    ELSE 'devolvido'
  END
  FROM showroom_emprestimos e
  WHERE e.id = p_id
$$;
REVOKE ALL ON FUNCTION public.showroom_emp_status(uuid) FROM public, anon, authenticated;


-- Busca de cliente no cadastro (contatos tipo cliente, ativos, não duplicados).
CREATE OR REPLACE FUNCTION public.showroom_emp_buscar_cliente(p_user text, p_senha text, p_termo text)
RETURNS TABLE (id uuid, nome text, cpf_cnpj text, telefone text, email text, cidade text, estado text)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_termo  text := nullif(trim(coalesce(p_termo, '')), '');
  v_digito text;
BEGIN
  IF NOT public.showroom_cred_ok(p_user, p_senha) THEN
    RAISE EXCEPTION 'usuario ou senha invalidos' USING ERRCODE = '28000';
  END IF;
  IF v_termo IS NULL OR length(v_termo) < 2 THEN
    RETURN;
  END IF;
  v_digito := nullif(regexp_replace(v_termo, '\D', '', 'g'), '');

  RETURN QUERY
  SELECT c.id,
         c.nome,
         coalesce(nullif(c.cpf_cnpj, ''), nullif(c.cnpj, ''), nullif(c.cpf, ''))::text,
         coalesce(nullif(c.celular, ''), nullif(c.telefone, ''))::text,
         c.email::text,
         c.cidade::text,
         c.estado::text
    FROM contatos c
   WHERE c.tipo = 'cliente'
     AND c.ativo
     AND c.canonical_id IS NULL
     AND (
       c.nome ILIKE '%' || v_termo || '%'
       OR c.razao_social ILIKE '%' || v_termo || '%'
       OR (v_digito IS NOT NULL AND length(v_digito) >= 3 AND
           regexp_replace(coalesce(c.cpf_cnpj, '') || ' ' || coalesce(c.cnpj, '') || ' ' || coalesce(c.cpf, ''),
                          '\D', '', 'g') LIKE '%' || v_digito || '%')
     )
   ORDER BY c.nome
   LIMIT 20;
END;
$$;


CREATE OR REPLACE FUNCTION public.showroom_emp_listar_empresas(p_user text, p_senha text)
RETURNS TABLE (id uuid, codigo integer, nome text)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT public.showroom_cred_ok(p_user, p_senha) THEN
    RAISE EXCEPTION 'usuario ou senha invalidos' USING ERRCODE = '28000';
  END IF;
  RETURN QUERY SELECT e.id, e.codigo, e.nome FROM empresas e WHERE e.ativo ORDER BY e.codigo;
END;
$$;


-- Quantidade já emprestada (em aberto) por peça: a tela avisa se passar do estoque_showroom.
CREATE OR REPLACE FUNCTION public.showroom_emp_em_aberto_por_peca(p_user text, p_senha text, p_codigos integer[])
RETURNS TABLE (codigo_produto integer, quantidade_em_aberto integer, estoque_showroom integer)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT public.showroom_cred_ok(p_user, p_senha) THEN
    RAISE EXCEPTION 'usuario ou senha invalidos' USING ERRCODE = '28000';
  END IF;
  RETURN QUERY
  SELECT p.codigo_produto,
         coalesce((SELECT sum(i.quantidade)::integer
                     FROM showroom_emprestimo_itens i
                     JOIN showroom_emprestimos e ON e.id = i.emprestimo_id
                    WHERE i.codigo_produto = p.codigo_produto
                      AND i.situacao = 'emprestado'
                      AND e.cancelado_em IS NULL), 0),
         coalesce(p.estoque_showroom, 0)
    FROM produtos p
   WHERE p.codigo_produto = ANY (coalesce(p_codigos, '{}'));
END;
$$;


-- Cria o empréstimo. p_itens = [{"codigo_produto": 123, "quantidade": 1}, ...]
CREATE OR REPLACE FUNCTION public.showroom_emp_criar(
  p_user text,
  p_senha text,
  p_empresa_id uuid,
  p_contato_id uuid,
  p_data_prevista date,
  p_observacoes text,
  p_itens jsonb
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_hoje     date := (now() AT TIME ZONE 'America/Sao_Paulo')::date;
  v_snapshot jsonb;
  v_id       uuid;
  v_numero   integer;
  v_item     record;
  v_prod     record;
  v_n        integer := 0;
BEGIN
  IF NOT public.showroom_cred_ok(p_user, p_senha) THEN
    RAISE EXCEPTION 'usuario ou senha invalidos' USING ERRCODE = '28000';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM empresas WHERE id = p_empresa_id AND ativo) THEN
    RAISE EXCEPTION 'Escolha a empresa.' USING ERRCODE = '22023';
  END IF;
  IF p_data_prevista IS NULL OR p_data_prevista < v_hoje THEN
    RAISE EXCEPTION 'A data prevista de devolução não pode ser anterior a hoje.' USING ERRCODE = '22023';
  END IF;
  IF p_itens IS NULL OR jsonb_typeof(p_itens) <> 'array' OR jsonb_array_length(p_itens) = 0 THEN
    RAISE EXCEPTION 'Inclua pelo menos uma peça.' USING ERRCODE = '22023';
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
   WHERE c.id = p_contato_id AND c.tipo = 'cliente' AND c.ativo;
  IF v_snapshot IS NULL THEN
    RAISE EXCEPTION 'Cliente não encontrado no cadastro.' USING ERRCODE = '22023';
  END IF;

  INSERT INTO showroom_emprestimos (empresa_id, contato_id, cliente_snapshot, data_emprestimo,
                                    data_prevista_devolucao, observacoes, criado_por)
  VALUES (p_empresa_id, p_contato_id, v_snapshot, v_hoje, p_data_prevista,
          nullif(trim(coalesce(p_observacoes, '')), ''), p_user)
  RETURNING id, numero INTO v_id, v_numero;

  -- Mesma peça repetida na lista vira uma linha só (soma as quantidades).
  FOR v_item IN
    SELECT (x->>'codigo_produto')::integer AS codigo, sum((x->>'quantidade')::integer)::integer AS qtd
      FROM jsonb_array_elements(p_itens) x
     GROUP BY 1
  LOOP
    IF v_item.codigo IS NULL OR coalesce(v_item.qtd, 0) <= 0 THEN
      RAISE EXCEPTION 'Peça ou quantidade inválida.' USING ERRCODE = '22023';
    END IF;
    SELECT id, codigo_produto, nome, referencia, coalesce(valor_venda, 0) AS valor_venda
      INTO v_prod
      FROM produtos
     WHERE codigo_produto = v_item.codigo;
    IF NOT FOUND THEN
      RAISE EXCEPTION 'Peça % não encontrada.', v_item.codigo USING ERRCODE = '22023';
    END IF;
    INSERT INTO showroom_emprestimo_itens (emprestimo_id, produto_id, codigo_produto, nome, referencia,
                                           quantidade, valor_unitario)
    VALUES (v_id, v_prod.id, v_prod.codigo_produto, v_prod.nome, nullif(v_prod.referencia, ''),
            v_item.qtd, round(v_prod.valor_venda, 2));
    v_n := v_n + 1;
  END LOOP;

  RETURN jsonb_build_object('id', v_id, 'numero', v_numero, 'itens', v_n);
END;
$$;


-- Lista. p_status: em_aberto | atrasado | devolvido | devolvido_com_dano | cancelado | null (todos).
-- "em_aberto" no filtro inclui os atrasados (tudo que ainda tem peça com o cliente).
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


-- Tudo de um empréstimo (tela de detalhe e PDF do termo).
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
  SELECT jsonb_build_object(
           'id', e.id,
           'numero', e.numero,
           'status', public.showroom_emp_status(e.id),
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
                      'id', i.id, 'codigo_produto', i.codigo_produto, 'nome', i.nome,
                      'referencia', i.referencia, 'quantidade', i.quantidade,
                      'valor_unitario', i.valor_unitario, 'situacao', i.situacao,
                      'data_devolucao', i.data_devolucao, 'descricao_dano', i.descricao_dano,
                      'valor_dano', i.valor_dano, 'devolvido_registrado_por', i.devolvido_registrado_por)
                    ORDER BY i.nome)
               FROM showroom_emprestimo_itens i
              WHERE i.emprestimo_id = e.id), '[]'::jsonb))
    INTO v_res
    FROM showroom_emprestimos e
    JOIN empresas emp ON emp.id = e.empresa_id
   WHERE e.id = p_id;
  IF v_res IS NULL THEN
    RAISE EXCEPTION 'Empréstimo não encontrado.' USING ERRCODE = '22023';
  END IF;
  RETURN v_res;
END;
$$;


-- Devolução de uma peça (linha). Com dano: descrição obrigatória; valor padrão = valor integral
-- (valor_unitario × quantidade), pode ser menor (ex.: só 1 de 2 unidades danificada), nunca maior.
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


-- Cancelar: só enquanto nenhuma peça foi devolvida (empréstimo lançado errado).
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
    RAISE EXCEPTION 'Já existe peça devolvida neste empréstimo; não dá para cancelar.' USING ERRCODE = '22023';
  END IF;
  UPDATE showroom_emprestimos
     SET cancelado_em = now(), cancelado_motivo = trim(p_motivo)
   WHERE id = p_id;
  RETURN jsonb_build_object('ok', true);
END;
$$;


-- RPCs: só anon (o Showroom nunca tem sessão authenticated); a credencial é conferida dentro.
REVOKE ALL ON FUNCTION public.showroom_emp_buscar_cliente(text, text, text) FROM public, authenticated;
REVOKE ALL ON FUNCTION public.showroom_emp_listar_empresas(text, text) FROM public, authenticated;
REVOKE ALL ON FUNCTION public.showroom_emp_em_aberto_por_peca(text, text, integer[]) FROM public, authenticated;
REVOKE ALL ON FUNCTION public.showroom_emp_criar(text, text, uuid, uuid, date, text, jsonb) FROM public, authenticated;
REVOKE ALL ON FUNCTION public.showroom_emp_listar(text, text, text, text) FROM public, authenticated;
REVOKE ALL ON FUNCTION public.showroom_emp_obter(text, text, uuid) FROM public, authenticated;
REVOKE ALL ON FUNCTION public.showroom_emp_registrar_devolucao(text, text, uuid, boolean, text, numeric) FROM public, authenticated;
REVOKE ALL ON FUNCTION public.showroom_emp_cancelar(text, text, uuid, text) FROM public, authenticated;

GRANT EXECUTE ON FUNCTION public.showroom_emp_buscar_cliente(text, text, text) TO anon;
GRANT EXECUTE ON FUNCTION public.showroom_emp_listar_empresas(text, text) TO anon;
GRANT EXECUTE ON FUNCTION public.showroom_emp_em_aberto_por_peca(text, text, integer[]) TO anon;
GRANT EXECUTE ON FUNCTION public.showroom_emp_criar(text, text, uuid, uuid, date, text, jsonb) TO anon;
GRANT EXECUTE ON FUNCTION public.showroom_emp_listar(text, text, text, text) TO anon;
GRANT EXECUTE ON FUNCTION public.showroom_emp_obter(text, text, uuid) TO anon;
GRANT EXECUTE ON FUNCTION public.showroom_emp_registrar_devolucao(text, text, uuid, boolean, text, numeric) TO anon;
GRANT EXECUTE ON FUNCTION public.showroom_emp_cancelar(text, text, uuid, text) TO anon;
