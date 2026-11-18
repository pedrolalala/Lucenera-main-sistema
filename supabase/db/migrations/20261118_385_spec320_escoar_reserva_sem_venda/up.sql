-- SPEC-320 (18/11/2026): sistema "Escoar reserva sem venda" (heranca Connect).
-- Matheus/Vitoria lancam, por lista de entrega baixada na Connect, as pecas e quantidades; o sistema tira a quantidade da
-- "reserva sem venda" e do Estoque Geral (mesma conta da SPEC-250/298: Geral -q, reservado -q; Disponivel e Separacao nao mudam).
-- Cada lote fica gravado (tabelas abaixo) e vira movimento no kardex. Estorno so da Administracao.
-- NAO usa nem cria limpar_reserva_sem_venda_connect (298 continua em rascunho). Nao altera vendas nem reservas por cliente.
BEGIN;

-- ---------------------------------------------------------------- quem opera (alem da Administracao e de quem trata heranca)
CREATE TABLE IF NOT EXISTS public.escoar_reserva_operadores (
  usuario_id uuid PRIMARY KEY
);
ALTER TABLE public.escoar_reserva_operadores ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.escoar_reserva_operadores FROM PUBLIC, anon, authenticated;
INSERT INTO public.escoar_reserva_operadores (usuario_id) VALUES
  ('af3035fd-266b-4b3a-952b-cb8866096c49'),  -- Matheus
  ('d875ff50-2220-48af-9ed7-0a670ec877c3')   -- Vitoria
ON CONFLICT (usuario_id) DO NOTHING;

CREATE OR REPLACE FUNCTION public.pode_escoar_reserva_connect()
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public' AS $$
  SELECT coalesce(auth.uid() IS NOT NULL AND (
    coalesce(public.is_admin(), false)
    OR coalesce(public.pode_tratar_heranca_connect(), false)
    OR EXISTS (SELECT 1 FROM public.escoar_reserva_operadores o WHERE o.usuario_id = (SELECT auth.uid()))
  ), false)
$$;
REVOKE ALL ON FUNCTION public.pode_escoar_reserva_connect() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.pode_escoar_reserva_connect() TO authenticated;

-- ---------------------------------------------------------------- lotes
CREATE TABLE IF NOT EXISTS public.escoar_reserva_lotes (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  numero_lista    text NOT NULL,            -- numero da lista de entrega na Connect
  cliente         text,                     -- texto livre
  data_baixa      date NOT NULL,            -- data da baixa na Connect
  criado_por      uuid NOT NULL,
  criado_em       timestamptz NOT NULL DEFAULT now(),
  estornado_em    timestamptz,
  estornado_por   uuid,
  motivo_estorno  text
);
CREATE TABLE IF NOT EXISTS public.escoar_reserva_itens (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  lote_id          uuid NOT NULL REFERENCES public.escoar_reserva_lotes(id),
  produto_id       uuid NOT NULL,
  codigo           integer NOT NULL,
  quantidade       numeric NOT NULL CHECK (quantidade > 0),
  geral_antes      numeric NOT NULL,
  geral_depois     numeric NOT NULL,
  sem_venda_antes  numeric NOT NULL,
  sem_venda_depois numeric NOT NULL
);
CREATE INDEX IF NOT EXISTS escoar_reserva_itens_lote_idx ON public.escoar_reserva_itens (lote_id);
CREATE INDEX IF NOT EXISTS escoar_reserva_itens_produto_idx ON public.escoar_reserva_itens (produto_id);
ALTER TABLE public.escoar_reserva_lotes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.escoar_reserva_itens ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.escoar_reserva_lotes, public.escoar_reserva_itens FROM PUBLIC, anon, authenticated;
-- sem policy: so as funcoes SECURITY DEFINER abaixo leem/gravam.

-- ---------------------------------------------------------------- saldo por peca (mesma conta do Cadastro / SPEC-250)
CREATE OR REPLACE FUNCTION public.escoar_reserva_pecas(p_busca text DEFAULT NULL, p_somente_com_saldo boolean DEFAULT true)
RETURNS TABLE (codigo integer, peca text, geral numeric, reservado numeric, sem_venda numeric, disponivel numeric, escoado numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public' AS $$
BEGIN
  IF NOT public.pode_escoar_reserva_connect() THEN
    RAISE EXCEPTION 'Sem acesso ao escoamento da reserva sem venda.' USING ERRCODE = '42501';
  END IF;
  RETURN QUERY
  WITH base AS (
    SELECT p.codigo_produto AS cod, p.nome AS nm, p.id AS pid, ei.quantidade AS g, ei.quantidade_reservada AS r,
           coalesce(ei.quantidade_reservada, 0) - coalesce(s.q_reserva, 0) - coalesce(s.q_entrega_futura, 0) - coalesce(s.q_separacao, 0)
             - coalesce(s.q_reserva_connect, 0) - coalesce(s.q_entrega_futura_connect, 0) AS sv
      FROM public.estoque_itens ei
      JOIN public.produtos p ON p.id = ei.produto_id
      LEFT JOIN public.vw_cadastro_produto_setores s ON s.produto_id = p.id
     WHERE ei.local = 'Estoque'::public.estoque_local
  ), esc AS (
    SELECT i.produto_id, sum(i.quantidade) AS q
      FROM public.escoar_reserva_itens i JOIN public.escoar_reserva_lotes l ON l.id = i.lote_id AND l.estornado_em IS NULL
     GROUP BY i.produto_id
  )
  SELECT b.cod, b.nm, b.g, b.r, b.sv, b.g - b.r, coalesce(e.q, 0)
    FROM base b LEFT JOIN esc e ON e.produto_id = b.pid
   WHERE (NOT p_somente_com_saldo OR b.sv > 0 OR coalesce(e.q, 0) > 0)
     AND (nullif(btrim(coalesce(p_busca, '')), '') IS NULL
          OR b.cod::text = btrim(p_busca) OR b.nm ILIKE '%' || btrim(p_busca) || '%')
   ORDER BY b.sv DESC, b.cod;
END $$;
REVOKE ALL ON FUNCTION public.escoar_reserva_pecas(text, boolean) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.escoar_reserva_pecas(text, boolean) TO authenticated;

-- ---------------------------------------------------------------- lancar lote (p_aplicar = false: so mostra antes/depois)
CREATE OR REPLACE FUNCTION public.escoar_reserva_lancar(
  p_numero_lista text, p_cliente text, p_data_baixa date, p_itens jsonb, p_aplicar boolean DEFAULT false)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $$
DECLARE
  v_it     record;
  v_prod   uuid; v_nome text; v_geral numeric; v_reserv numeric; v_sv numeric;
  v_res    jsonb := '[]'::jsonb;
  v_erros  integer := 0;
  v_msg    text;
  v_lista  text := nullif(btrim(coalesce(p_numero_lista, '')), '');
  v_lote   uuid;
  v_motivo text;
BEGIN
  IF NOT public.pode_escoar_reserva_connect() THEN
    RAISE EXCEPTION 'Sem acesso ao escoamento da reserva sem venda.' USING ERRCODE = '42501';
  END IF;
  IF p_itens IS NULL OR jsonb_typeof(p_itens) <> 'array' OR jsonb_array_length(p_itens) = 0 THEN
    RAISE EXCEPTION 'Informe as pecas e quantidades da lista.' USING ERRCODE = 'P0001';
  END IF;
  IF p_aplicar THEN
    IF v_lista IS NULL THEN RAISE EXCEPTION 'Informe o numero da lista de entrega da Connect.' USING ERRCODE = 'P0001'; END IF;
    IF p_data_baixa IS NULL THEN RAISE EXCEPTION 'Informe a data da baixa na Connect.' USING ERRCODE = 'P0001'; END IF;
    IF EXISTS (SELECT 1 FROM public.escoar_reserva_lotes l WHERE lower(l.numero_lista) = lower(v_lista) AND l.estornado_em IS NULL) THEN
      RAISE EXCEPTION 'A lista % ja foi lancada. Estorne o lote antes de lancar de novo.', v_lista USING ERRCODE = 'P0001';
    END IF;
  END IF;

  FOR v_it IN
    SELECT nullif(e->>'codigo', '')::integer AS cod, sum(nullif(e->>'quantidade', '')::numeric) AS q
      FROM jsonb_array_elements(p_itens) e GROUP BY 1 ORDER BY 1
  LOOP
    v_msg := NULL; v_prod := NULL; v_nome := NULL; v_geral := NULL; v_reserv := NULL; v_sv := NULL;
    SELECT p.id, p.nome INTO v_prod, v_nome FROM public.produtos p WHERE p.codigo_produto = v_it.cod;
    IF v_prod IS NULL THEN
      v_msg := 'peca nao encontrada';
    ELSIF v_it.q IS NULL OR v_it.q <= 0 THEN
      v_msg := 'quantidade invalida';
    ELSE
      SELECT ei.quantidade, ei.quantidade_reservada INTO v_geral, v_reserv
        FROM public.estoque_itens ei WHERE ei.produto_id = v_prod AND ei.local = 'Estoque'::public.estoque_local FOR UPDATE;
      SELECT coalesce(v_reserv, 0) - coalesce(s.q_reserva, 0) - coalesce(s.q_entrega_futura, 0) - coalesce(s.q_separacao, 0)
             - coalesce(s.q_reserva_connect, 0) - coalesce(s.q_entrega_futura_connect, 0)
        INTO v_sv FROM (SELECT 1) x LEFT JOIN public.vw_cadastro_produto_setores s ON s.produto_id = v_prod;
      IF v_geral IS NULL THEN v_msg := 'peca sem Estoque Geral';
      ELSIF v_sv <= 0 THEN v_msg := 'peca sem reserva sem venda';
      ELSIF v_it.q > v_sv THEN v_msg := format('quantidade %s maior que a reserva sem venda (%s)', v_it.q, v_sv);
      ELSIF v_it.q > v_geral THEN v_msg := format('quantidade %s maior que o Estoque Geral (%s)', v_it.q, v_geral);
      END IF;
    END IF;
    IF v_msg IS NOT NULL THEN v_erros := v_erros + 1; END IF;
    v_res := v_res || jsonb_build_array(jsonb_build_object(
      'produto_id', v_prod, 'codigo', v_it.cod, 'peca', v_nome, 'quantidade', v_it.q,
      'sem_venda_antes', v_sv, 'geral_antes', v_geral,
      'sem_venda_depois', CASE WHEN v_msg IS NULL THEN v_sv - v_it.q END,
      'geral_depois', CASE WHEN v_msg IS NULL THEN v_geral - v_it.q END,
      'erro', v_msg));
  END LOOP;

  IF NOT p_aplicar THEN
    RETURN jsonb_build_object('aplicado', false, 'erros', v_erros, 'itens', v_res);
  END IF;
  IF v_erros > 0 THEN
    RAISE EXCEPTION 'Nada foi lancado: % peca(s) com problema.', v_erros USING ERRCODE = 'P0001';
  END IF;

  v_motivo := left(format('Lista de entrega Connect %s%s baixada em %s',
                          v_lista,
                          CASE WHEN nullif(btrim(coalesce(p_cliente, '')), '') IS NOT NULL THEN ' (' || btrim(p_cliente) || ')' ELSE '' END,
                          to_char(p_data_baixa, 'DD/MM/YYYY')), 500);
  INSERT INTO public.escoar_reserva_lotes (numero_lista, cliente, data_baixa, criado_por)
  VALUES (v_lista, nullif(btrim(coalesce(p_cliente, '')), ''), p_data_baixa, auth.uid()) RETURNING id INTO v_lote;

  FOR v_it IN SELECT (x->>'produto_id')::uuid AS pid, (x->>'codigo')::integer AS cod, (x->>'quantidade')::numeric AS q,
                     (x->>'geral_antes')::numeric AS ga, (x->>'sem_venda_antes')::numeric AS sa
                FROM jsonb_array_elements(v_res) x
  LOOP
    UPDATE public.estoque_itens
       SET quantidade = quantidade - v_it.q,
           quantidade_reservada = GREATEST(quantidade_reservada - v_it.q, 0),
           atualizado_por = auth.uid(), atualizado_em = now()
     WHERE produto_id = v_it.pid AND local = 'Estoque'::public.estoque_local;
    INSERT INTO public.escoar_reserva_itens (lote_id, produto_id, codigo, quantidade, geral_antes, geral_depois, sem_venda_antes, sem_venda_depois)
    VALUES (v_lote, v_it.pid, v_it.cod, v_it.q, v_it.ga, v_it.ga - v_it.q, v_it.sa, v_it.sa - v_it.q);
    INSERT INTO public.movimentacoes_peca
      (produto_id, quantidade, tipo, origem, destino, motivo, saldo_origem_antes, saldo_origem_depois,
       saldo_destino_antes, saldo_destino_depois, criado_por)
    VALUES (v_it.pid, v_it.q, 'setor', 'Reserva sem venda (herança Connect)', 'Baixa (entregue na Connect)',
            v_motivo, v_it.ga, v_it.ga - v_it.q, NULL, NULL, auth.uid());
  END LOOP;

  RETURN jsonb_build_object('aplicado', true, 'erros', 0, 'lote_id', v_lote, 'itens', v_res);
END $$;
REVOKE ALL ON FUNCTION public.escoar_reserva_lancar(text, text, date, jsonb, boolean) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.escoar_reserva_lancar(text, text, date, jsonb, boolean) TO authenticated;

-- ---------------------------------------------------------------- historico dos lotes
CREATE OR REPLACE FUNCTION public.escoar_reserva_historico(p_limite integer DEFAULT 200)
RETURNS TABLE (lote_id uuid, numero_lista text, cliente text, data_baixa date, criado_em timestamptz, criado_por_nome text,
               pecas integer, unidades numeric, estornado_em timestamptz, motivo_estorno text, itens jsonb)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public' AS $$
BEGIN
  IF NOT public.pode_escoar_reserva_connect() THEN
    RAISE EXCEPTION 'Sem acesso ao escoamento da reserva sem venda.' USING ERRCODE = '42501';
  END IF;
  RETURN QUERY
  SELECT l.id, l.numero_lista, l.cliente, l.data_baixa, l.criado_em, u.nome,
         count(i.id)::integer, coalesce(sum(i.quantidade), 0), l.estornado_em, l.motivo_estorno,
         coalesce(jsonb_agg(jsonb_build_object('codigo', i.codigo, 'peca', p.nome, 'quantidade', i.quantidade,
                  'geral_antes', i.geral_antes, 'geral_depois', i.geral_depois) ORDER BY i.codigo) FILTER (WHERE i.id IS NOT NULL), '[]'::jsonb)
    FROM public.escoar_reserva_lotes l
    LEFT JOIN public.escoar_reserva_itens i ON i.lote_id = l.id
    LEFT JOIN public.produtos p ON p.id = i.produto_id
    LEFT JOIN public.usuarios u ON u.id = l.criado_por
   GROUP BY l.id, u.nome
   ORDER BY l.criado_em DESC
   LIMIT greatest(coalesce(p_limite, 200), 1);
END $$;
REVOKE ALL ON FUNCTION public.escoar_reserva_historico(integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.escoar_reserva_historico(integer) TO authenticated;

-- ---------------------------------------------------------------- estorno (so Administracao)
CREATE OR REPLACE FUNCTION public.escoar_reserva_estornar(p_lote_id uuid, p_motivo text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $$
DECLARE
  v_l record; v_i record; v_geral numeric;
  v_motivo text := nullif(btrim(coalesce(p_motivo, '')), '');
BEGIN
  IF public.is_admin() IS NOT TRUE THEN
    RAISE EXCEPTION 'So a Administracao pode estornar um lote.' USING ERRCODE = '42501';
  END IF;
  IF v_motivo IS NULL THEN RAISE EXCEPTION 'Informe o motivo do estorno.' USING ERRCODE = 'P0001'; END IF;
  SELECT * INTO v_l FROM public.escoar_reserva_lotes WHERE id = p_lote_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Lote nao encontrado.' USING ERRCODE = 'P0001'; END IF;
  IF v_l.estornado_em IS NOT NULL THEN RAISE EXCEPTION 'Lote ja estornado.' USING ERRCODE = 'P0001'; END IF;

  FOR v_i IN SELECT * FROM public.escoar_reserva_itens WHERE lote_id = p_lote_id LOOP
    SELECT quantidade INTO v_geral FROM public.estoque_itens
     WHERE produto_id = v_i.produto_id AND local = 'Estoque'::public.estoque_local FOR UPDATE;
    UPDATE public.estoque_itens
       SET quantidade = quantidade + v_i.quantidade, quantidade_reservada = quantidade_reservada + v_i.quantidade,
           atualizado_por = auth.uid(), atualizado_em = now()
     WHERE produto_id = v_i.produto_id AND local = 'Estoque'::public.estoque_local;
    INSERT INTO public.movimentacoes_peca
      (produto_id, quantidade, tipo, origem, destino, motivo, saldo_origem_antes, saldo_origem_depois,
       saldo_destino_antes, saldo_destino_depois, criado_por)
    VALUES (v_i.produto_id, v_i.quantidade, 'setor', 'Baixa (entregue na Connect)', 'Reserva sem venda (herança Connect)',
            left('Estorno da lista ' || v_l.numero_lista || ': ' || v_motivo, 500), v_geral, v_geral + v_i.quantidade, NULL, NULL, auth.uid());
  END LOOP;
  UPDATE public.escoar_reserva_lotes
     SET estornado_em = now(), estornado_por = auth.uid(), motivo_estorno = v_motivo WHERE id = p_lote_id;
  RETURN jsonb_build_object('estornado', true, 'lote_id', p_lote_id);
END $$;
REVOKE ALL ON FUNCTION public.escoar_reserva_estornar(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.escoar_reserva_estornar(uuid, text) TO authenticated;

COMMIT;
