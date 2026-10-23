-- SPEC-224 (pedido do usuário 23/10): sistema "Movimentação de Peças" — mudar a peça de setor (físico e de venda),
-- sem aprovação, registrando quem, quando, de onde, para onde, quantidade e motivo.
--   Setores físicos: Estoque Geral (= estoque_itens local 'Estoque'), Showroom (= produtos.estoque_showroom),
--   Estoque Garantia, Estoque Casa Cor, Estoque Defeito, Amostra / Emprestado (= estoque_itens do local).
--   Venda (por L): Reserva -> Entrega Futura, Entrega Futura -> Reserva, Separação -> Reserva.
-- O Estoque Geral não pode ficar com menos do que está guardado para vendas (reserva/separação dos L + reserva
-- herdada da Connect): "livre" = quantidade - (quantidade_reservada - entrega futura dos L).
-- Também: fn_atualizar_preco_venda deixa de recalcular o preço quando o UPDATE só mexe em estoque (mover para o
-- Showroom não pode mudar preco_venda — incidente de 10/09), e o sistema é registrado no Hub.
-- Sem BEGIN/COMMIT: o aplicador envolve em transação.

-- 1. Preço: UPDATE só de estoque não recalcula ------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_atualizar_preco_venda()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_valor_liquido    NUMERIC;
    v_valor_st         NUMERIC;
    v_valor_ipi        NUMERIC;
    v_valor_despesas   NUMERIC;
    v_bdi_total        NUMERIC;
    v_custo_total      NUMERIC;
BEGIN
    -- SPEC-224: UPDATE que só mexe em estoque (movimentação de setor, entrada de nota) não recalcula o preço.
    -- tem_st/sku são colunas geradas: no BEFORE ainda vêm nulas no NEW, por isso ficam fora da comparação.
    IF TG_OP = 'UPDATE'
       AND (to_jsonb(NEW) - ARRAY['estoque_showroom', 'estoque_total', 'estoque_disponivel', 'updated_at', 'tem_st', 'sku'])
         = (to_jsonb(OLD) - ARRAY['estoque_showroom', 'estoque_total', 'estoque_disponivel', 'updated_at', 'tem_st', 'sku']) THEN
        RETURN NEW;
    END IF;

    -- 1. Valor Líquido = preço de custo menos desconto percentual
    v_valor_liquido := NEW.preco_custo - (NEW.preco_custo * (COALESCE(NEW.porc_desconto, 0) / 100));

    -- 2. Valor ST sobre Valor Líquido
    v_valor_st := v_valor_liquido * (COALESCE(NEW.icms_entrada, 0) / 100);

    -- 3. Valor IPI sobre Valor Líquido
    v_valor_ipi := v_valor_liquido * (COALESCE(NEW.ipi_entrada, 0) / 100);

    -- 4. Valor Despesas sobre Valor Líquido (porc_frete é propositalmente ignorado)
    v_valor_despesas := v_valor_liquido * (COALESCE(NEW.porc_despesas, 0) / 100);

    -- 5. BDI Total
    v_bdi_total := v_valor_st + v_valor_ipi + v_valor_despesas;

    -- 6. Custo Total
    v_custo_total := v_valor_liquido + v_bdi_total;

    -- 7. Preço de Venda com margem de 150% (multiplica por 2.5)
    NEW.preco_venda := v_custo_total * 2.5;

    RETURN NEW;
END;
$function$;

-- 2. Registro dos movimentos -------------------------------------------------------------------------------------
CREATE SEQUENCE IF NOT EXISTS public.movimentacoes_peca_numero_seq;

CREATE TABLE public.movimentacoes_peca (
  id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  numero                bigint NOT NULL UNIQUE DEFAULT nextval('public.movimentacoes_peca_numero_seq'),
  produto_id            uuid NOT NULL REFERENCES public.produtos(id),
  quantidade            numeric(14,3) NOT NULL CHECK (quantidade > 0),
  tipo                  text NOT NULL CHECK (tipo IN ('setor', 'venda')),
  origem                text NOT NULL,
  destino               text NOT NULL,
  projeto_item_id       uuid REFERENCES public.projeto_itens(id),
  motivo                text NOT NULL CHECK (btrim(motivo) <> ''),
  saldo_origem_antes    numeric(14,3),
  saldo_origem_depois   numeric(14,3),
  saldo_destino_antes   numeric(14,3),
  saldo_destino_depois  numeric(14,3),
  criado_por            uuid NOT NULL REFERENCES public.usuarios(id),
  criado_em             timestamptz NOT NULL DEFAULT now(),
  CHECK (origem <> destino),
  CHECK (tipo = 'setor' OR projeto_item_id IS NOT NULL)
);
ALTER SEQUENCE public.movimentacoes_peca_numero_seq OWNED BY public.movimentacoes_peca.numero;
CREATE INDEX movimentacoes_peca_produto_idx ON public.movimentacoes_peca (produto_id, criado_em DESC);
CREATE INDEX movimentacoes_peca_criado_em_idx ON public.movimentacoes_peca (criado_em DESC);
CREATE INDEX movimentacoes_peca_criado_por_idx ON public.movimentacoes_peca (criado_por);
COMMENT ON TABLE public.movimentacoes_peca IS
  'SPEC-224: movimentação interna de peça (troca de setor físico ou de venda) com quem, quando, de onde, para onde e motivo. Leitura só pelas RPCs movimentacao_*.';

ALTER TABLE public.movimentacoes_peca ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.movimentacoes_peca FROM anon, authenticated;
REVOKE ALL ON SEQUENCE public.movimentacoes_peca_numero_seq FROM anon, authenticated;

-- 3. Auxiliares (sem grant) --------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public._mov_pode()
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  SELECT auth.uid() IS NOT NULL AND (public.is_admin() OR public.pode_acessar_sistema('movimentacao-pecas'))
$function$;

CREATE OR REPLACE FUNCTION public._mov_local(p_setor text)
 RETURNS public.estoque_local
 LANGUAGE sql
 IMMUTABLE
AS $function$
  SELECT CASE p_setor
    WHEN 'Estoque Geral' THEN 'Estoque'::public.estoque_local
    WHEN 'Estoque Garantia' THEN 'Estoque Garantia'::public.estoque_local
    WHEN 'Estoque Casa Cor' THEN 'Estoque Casa Cor'::public.estoque_local
    WHEN 'Estoque Defeito' THEN 'Estoque Defeito'::public.estoque_local
    WHEN 'Amostra / Emprestado' THEN 'Amostra / Emprestado'::public.estoque_local
  END
$function$;

-- Quanto do Estoque Geral está livre (não guardado para venda): quantidade − (reservado − entrega futura dos L).
CREATE OR REPLACE FUNCTION public._mov_livre_estoque_geral(p_produto_id uuid)
 RETURNS numeric
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  SELECT coalesce((SELECT quantidade - coalesce(quantidade_reservada, 0) FROM public.estoque_itens
                    WHERE produto_id = p_produto_id AND local = 'Estoque'), 0)
       + coalesce((SELECT sum(esp.q_entrega_futura)
                     FROM public.estoque_saldos_projeto_item esp
                     JOIN public.projeto_itens pi ON pi.id = esp.projeto_item_id
                    WHERE pi.produto_id = p_produto_id AND esp.status_operacional = 'ativo'), 0)
$function$;

CREATE OR REPLACE FUNCTION public._mov_saldo(p_produto_id uuid, p_setor text)
 RETURNS numeric
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  SELECT CASE WHEN p_setor = 'Showroom'
              THEN (SELECT coalesce(estoque_showroom, 0)::numeric FROM public.produtos WHERE id = p_produto_id)
              ELSE coalesce((SELECT quantidade FROM public.estoque_itens
                              WHERE produto_id = p_produto_id AND local = public._mov_local(p_setor)), 0)
         END
$function$;

REVOKE ALL ON FUNCTION public._mov_pode() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public._mov_local(text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public._mov_livre_estoque_geral(uuid) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public._mov_saldo(uuid, text) FROM PUBLIC, anon, authenticated;

-- 4. Mover de setor físico ---------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.movimentar_peca_setor(p_produto_id uuid, p_origem text, p_destino text,
                                                         p_quantidade numeric, p_motivo text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_setores    text[] := ARRAY['Estoque Geral', 'Showroom', 'Estoque Garantia', 'Estoque Casa Cor',
                               'Estoque Defeito', 'Amostra / Emprestado'];
  v_motivo     text := NULLIF(btrim(coalesce(p_motivo, '')), '');
  v_q          numeric := round(coalesce(p_quantidade, 0), 3);
  v_prod       record;
  v_orig_antes numeric;
  v_dest_antes numeric;
  v_livre      numeric;
  v_numero     bigint;
BEGIN
  IF NOT public._mov_pode() THEN
    RAISE EXCEPTION 'Sem permissao para movimentar pecas.' USING ERRCODE = '42501';
  END IF;
  IF v_motivo IS NULL THEN
    RAISE EXCEPTION 'Informe o motivo da movimentacao.' USING ERRCODE = 'P0001';
  END IF;
  IF v_q <= 0 THEN
    RAISE EXCEPTION 'A quantidade precisa ser maior que zero.' USING ERRCODE = 'P0001';
  END IF;
  IF NOT (p_origem = ANY (v_setores)) OR NOT (p_destino = ANY (v_setores)) THEN
    RAISE EXCEPTION 'Setor invalido (use: %).', array_to_string(v_setores, ', ') USING ERRCODE = 'P0001';
  END IF;
  IF p_origem = p_destino THEN
    RAISE EXCEPTION 'Origem e destino sao o mesmo setor.' USING ERRCODE = 'P0001';
  END IF;
  IF 'Showroom' IN (p_origem, p_destino) AND v_q <> trunc(v_q) THEN
    RAISE EXCEPTION 'No Showroom a quantidade e inteira.' USING ERRCODE = 'P0001';
  END IF;

  SELECT id, codigo_produto, nome INTO v_prod FROM public.produtos WHERE id = p_produto_id FOR UPDATE;
  IF v_prod.id IS NULL THEN
    RAISE EXCEPTION 'Peca nao encontrada.' USING ERRCODE = 'P0001';
  END IF;

  -- linhas de estoque_itens dos setores envolvidos (cria zerada se faltar) e trava
  INSERT INTO public.estoque_itens (produto_id, local, quantidade, quantidade_reservada, atualizado_em)
  SELECT p_produto_id, public._mov_local(s), 0, 0, now()
    FROM unnest(ARRAY[p_origem, p_destino]) s
   WHERE s <> 'Showroom'
  ON CONFLICT (produto_id, local) DO NOTHING;
  PERFORM 1 FROM public.estoque_itens
   WHERE produto_id = p_produto_id
     AND local IN (public._mov_local(p_origem), public._mov_local(p_destino))
   FOR UPDATE;

  v_orig_antes := public._mov_saldo(p_produto_id, p_origem);
  v_dest_antes := public._mov_saldo(p_produto_id, p_destino);
  IF v_orig_antes < v_q THEN
    RAISE EXCEPTION 'O setor % tem % desta peca (pedido: %).', p_origem, v_orig_antes, v_q USING ERRCODE = 'P0001';
  END IF;
  IF p_origem = 'Estoque Geral' THEN
    v_livre := public._mov_livre_estoque_geral(p_produto_id);
    IF v_livre < v_q THEN
      RAISE EXCEPTION 'So % peca(s) livres no Estoque Geral: as outras estao guardadas para vendas (reserva/separacao).',
        greatest(v_livre, 0) USING ERRCODE = 'P0001';
    END IF;
  END IF;

  -- tira da origem, põe no destino
  IF p_origem = 'Showroom' THEN
    UPDATE public.produtos SET estoque_showroom = estoque_showroom - v_q::integer WHERE id = p_produto_id;
  ELSE
    UPDATE public.estoque_itens SET quantidade = quantidade - v_q, atualizado_por = auth.uid(), atualizado_em = now()
     WHERE produto_id = p_produto_id AND local = public._mov_local(p_origem);
  END IF;
  IF p_destino = 'Showroom' THEN
    UPDATE public.produtos SET estoque_showroom = coalesce(estoque_showroom, 0) + v_q::integer WHERE id = p_produto_id;
  ELSE
    UPDATE public.estoque_itens SET quantidade = quantidade + v_q, atualizado_por = auth.uid(), atualizado_em = now()
     WHERE produto_id = p_produto_id AND local = public._mov_local(p_destino);
  END IF;

  INSERT INTO public.movimentacoes_peca
    (produto_id, quantidade, tipo, origem, destino, motivo, saldo_origem_antes, saldo_origem_depois,
     saldo_destino_antes, saldo_destino_depois, criado_por)
  VALUES (p_produto_id, v_q, 'setor', p_origem, p_destino, v_motivo, v_orig_antes, v_orig_antes - v_q,
          v_dest_antes, v_dest_antes + v_q, auth.uid())
  RETURNING numero INTO v_numero;

  RETURN jsonb_build_object('numero', v_numero, 'produto', concat_ws(' ', v_prod.codigo_produto, v_prod.nome),
                            'origem', p_origem, 'destino', p_destino, 'quantidade', v_q,
                            'saldo_origem', v_orig_antes - v_q, 'saldo_destino', v_dest_antes + v_q);
END;
$function$;

-- 5. Mover dentro da venda (por L) -------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.movimentar_peca_venda(p_projeto_item_id uuid, p_acao text, p_quantidade numeric,
                                                         p_motivo text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_motivo   text := NULLIF(btrim(coalesce(p_motivo, '')), '');
  v_q        numeric := round(coalesce(p_quantidade, 0), 3);
  v_produto  uuid;
  v_saldo    public.estoque_saldos_projeto_item%ROWTYPE;
  v_origem   text;
  v_destino  text;
  v_o_antes  numeric;
  v_d_antes  numeric;
  v_livre    numeric;
  v_resta    numeric;
  v_sep      record;
  v_parte    numeric;
  v_numero   bigint;
BEGIN
  IF NOT public._mov_pode() THEN
    RAISE EXCEPTION 'Sem permissao para movimentar pecas.' USING ERRCODE = '42501';
  END IF;
  IF v_motivo IS NULL THEN
    RAISE EXCEPTION 'Informe o motivo da movimentacao.' USING ERRCODE = 'P0001';
  END IF;
  IF v_q <= 0 THEN
    RAISE EXCEPTION 'A quantidade precisa ser maior que zero.' USING ERRCODE = 'P0001';
  END IF;

  SELECT produto_id INTO v_produto FROM public.projeto_itens WHERE id = p_projeto_item_id;
  SELECT * INTO v_saldo FROM public.estoque_saldos_projeto_item WHERE projeto_item_id = p_projeto_item_id FOR UPDATE;
  IF v_produto IS NULL OR v_saldo.projeto_item_id IS NULL THEN
    RAISE EXCEPTION 'Item de venda (L) nao encontrado.' USING ERRCODE = 'P0001';
  END IF;
  PERFORM 1 FROM public.estoque_itens WHERE produto_id = v_produto AND local = 'Estoque' FOR UPDATE;

  IF p_acao = 'reserva_para_entrega_futura' THEN
    v_origem := 'Reserva'; v_destino := 'Entrega Futura';
    v_o_antes := v_saldo.q_reserva; v_d_antes := v_saldo.q_entrega_futura;
    IF v_q > v_saldo.q_reserva THEN
      RAISE EXCEPTION 'O L tem % em reserva (pedido: %).', v_saldo.q_reserva, v_q USING ERRCODE = 'P0001';
    END IF;
    UPDATE public.estoque_saldos_projeto_item
       SET q_reserva = q_reserva - v_q, q_entrega_futura = q_entrega_futura + v_q, atualizado_em = now()
     WHERE projeto_item_id = p_projeto_item_id;
    INSERT INTO public.estoque_movimentos_projeto_item (projeto_item_id, tipo, quantidade, origem, observacao, criado_por)
    VALUES (p_projeto_item_id, 'alocacao_entrega_futura', v_q, 'movimentacao_pecas',
            'Reserva -> Entrega Futura: ' || v_motivo, auth.uid());

  ELSIF p_acao = 'entrega_futura_para_reserva' THEN
    v_origem := 'Entrega Futura'; v_destino := 'Reserva';
    v_o_antes := v_saldo.q_entrega_futura; v_d_antes := v_saldo.q_reserva;
    IF v_q > v_saldo.q_entrega_futura THEN
      RAISE EXCEPTION 'O L tem % em entrega futura (pedido: %).', v_saldo.q_entrega_futura, v_q USING ERRCODE = 'P0001';
    END IF;
    -- peça física livre no Estoque Geral (sem reserva/separação de ninguém)
    v_livre := public._mov_livre_estoque_geral(v_produto);
    IF coalesce(v_livre, 0) < v_q THEN
      RAISE EXCEPTION 'So % peca(s) livres no Estoque Geral para reservar.', greatest(coalesce(v_livre, 0), 0)
        USING ERRCODE = 'P0001';
    END IF;
    UPDATE public.estoque_saldos_projeto_item
       SET q_entrega_futura = q_entrega_futura - v_q, q_reserva = q_reserva + v_q, atualizado_em = now()
     WHERE projeto_item_id = p_projeto_item_id;
    INSERT INTO public.estoque_movimentos_projeto_item (projeto_item_id, tipo, quantidade, origem, observacao, criado_por)
    VALUES (p_projeto_item_id, 'alocacao_reserva', v_q, 'movimentacao_pecas',
            'Entrega Futura -> Reserva: ' || v_motivo, auth.uid());

  ELSIF p_acao = 'separacao_para_reserva' THEN
    v_origem := 'Separação'; v_destino := 'Reserva';
    v_o_antes := v_saldo.q_ag_separar + v_saldo.q_separado; v_d_antes := v_saldo.q_reserva;
    IF v_q > v_o_antes THEN
      RAISE EXCEPTION 'O L tem % em separacao (pedido: %).', v_o_antes, v_q USING ERRCODE = 'P0001';
    END IF;
    -- usa o estorno da Separação Parcial (mesmas regras: peça já separada só admin/gerente; entregue não volta)
    v_resta := v_q;
    FOR v_sep IN
      SELECT id, quantidade - quantidade_estornada AS restante FROM public.separacao_itens
       WHERE projeto_item_id = p_projeto_item_id AND NOT entregue AND quantidade > quantidade_estornada
       ORDER BY created_at DESC
    LOOP
      EXIT WHEN v_resta <= 0;
      v_parte := least(v_resta, v_sep.restante);
      PERFORM public.estornar_item_separacao(v_sep.id, v_parte, 'Movimentação de Peças: ' || v_motivo);
      v_resta := v_resta - v_parte;
    END LOOP;
    IF v_resta > 0 THEN
      RAISE EXCEPTION 'Nao ha separacao em aberto suficiente para este L (faltou %).', v_resta USING ERRCODE = 'P0001';
    END IF;

  ELSE
    RAISE EXCEPTION 'Acao invalida: use reserva_para_entrega_futura, entrega_futura_para_reserva ou separacao_para_reserva.'
      USING ERRCODE = 'P0001';
  END IF;

  INSERT INTO public.movimentacoes_peca
    (produto_id, quantidade, tipo, origem, destino, projeto_item_id, motivo, saldo_origem_antes, saldo_origem_depois,
     saldo_destino_antes, saldo_destino_depois, criado_por)
  VALUES (v_produto, v_q, 'venda', v_origem, v_destino, p_projeto_item_id, v_motivo, v_o_antes, v_o_antes - v_q,
          v_d_antes, v_d_antes + v_q, auth.uid())
  RETURNING numero INTO v_numero;

  RETURN jsonb_build_object('numero', v_numero, 'origem', v_origem, 'destino', v_destino, 'quantidade', v_q);
END;
$function$;

-- 6. Leitura ------------------------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.movimentacao_buscar_pecas(p_termo text)
 RETURNS TABLE (id uuid, codigo_produto integer, referencia text, nome text, marca text,
                estoque_geral numeric, showroom integer)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_termos text[] := array_remove(regexp_split_to_array(lower(btrim(coalesce(p_termo, ''))), '\s+'), '');
BEGIN
  IF NOT public._mov_pode() THEN
    RAISE EXCEPTION 'Sem permissao.' USING ERRCODE = '42501';
  END IF;
  IF coalesce(array_length(v_termos, 1), 0) = 0 THEN
    RETURN;
  END IF;
  RETURN QUERY
  SELECT p.id, p.codigo_produto, p.referencia, p.nome, m.nome,
         coalesce((SELECT ei.quantidade FROM public.estoque_itens ei WHERE ei.produto_id = p.id AND ei.local = 'Estoque'), 0),
         coalesce(p.estoque_showroom, 0)
    FROM public.produtos p
    LEFT JOIN public.marcas m ON m.id = p.marca_id
   WHERE coalesce(p.ativo, true)
     AND NOT EXISTS (
       SELECT 1 FROM unnest(v_termos) t
        WHERE NOT (coalesce(p.codigo_produto::text, '') LIKE '%' || t || '%'
                   OR lower(coalesce(p.referencia, '')) LIKE '%' || t || '%'
                   OR lower(coalesce(p.nome, '')) LIKE '%' || t || '%'
                   OR lower(coalesce(m.nome, '')) LIKE '%' || t || '%'))
   ORDER BY (p.codigo_produto::text = v_termos[1]) DESC, p.codigo_produto
   LIMIT 40;
END;
$function$;

CREATE OR REPLACE FUNCTION public.movimentacao_peca_setores(p_produto_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v jsonb;
BEGIN
  IF NOT public._mov_pode() THEN
    RAISE EXCEPTION 'Sem permissao.' USING ERRCODE = '42501';
  END IF;
  SELECT jsonb_build_object(
    'produto', jsonb_build_object('id', p.id, 'codigo_produto', p.codigo_produto, 'referencia', p.referencia,
                                  'nome', p.nome, 'marca', m.nome),
    'setores', (SELECT jsonb_agg(jsonb_build_object('setor', s, 'quantidade', public._mov_saldo(p.id, s)) ORDER BY o)
                  FROM unnest(ARRAY['Estoque Geral', 'Showroom', 'Estoque Garantia', 'Estoque Casa Cor',
                                    'Estoque Defeito', 'Amostra / Emprestado']) WITH ORDINALITY AS x(s, o)),
    'livre_estoque_geral', public._mov_livre_estoque_geral(p.id),
    'vendas', coalesce((
      SELECT jsonb_agg(jsonb_build_object(
               'projeto_item_id', v.projeto_item_id, 'venda_numero', v.venda_numero,
               'orcamento_numero', v.orcamento_numero, 'projeto_codigo', v.projeto_codigo,
               'cliente', c.nome, 'l_fixo', pi.l_fixo, 'q_reserva', v.q_reserva,
               'q_entrega_futura', v.q_entrega_futura, 'q_separacao', v.q_ag_separar + v.q_separado)
               ORDER BY v.venda_numero, pi.l_fixo)
        FROM public.vw_estoque_saldos_projeto_item v
        JOIN public.projeto_itens pi ON pi.id = v.projeto_item_id
        LEFT JOIN public.contatos c ON c.id = v.cliente_id
       WHERE v.produto_id = p.id AND v.status_operacional = 'ativo'
         AND (v.q_reserva + v.q_entrega_futura + v.q_ag_separar + v.q_separado) > 0), '[]'::jsonb))
    INTO v
    FROM public.produtos p
    LEFT JOIN public.marcas m ON m.id = p.marca_id
   WHERE p.id = p_produto_id;
  IF v IS NULL THEN
    RAISE EXCEPTION 'Peca nao encontrada.' USING ERRCODE = 'P0001';
  END IF;
  RETURN v;
END;
$function$;

CREATE OR REPLACE FUNCTION public.movimentacao_listar(p_produto_id uuid DEFAULT NULL, p_usuario_id uuid DEFAULT NULL,
                                                       p_setor text DEFAULT NULL, p_tipo text DEFAULT NULL,
                                                       p_de date DEFAULT NULL, p_ate date DEFAULT NULL,
                                                       p_limite integer DEFAULT 500)
 RETURNS TABLE (id uuid, numero bigint, criado_em timestamptz, usuario_id uuid, usuario_nome text,
                produto_id uuid, codigo_produto integer, referencia text, produto text, quantidade numeric,
                tipo text, origem text, destino text, venda text, cliente text, l_fixo text, motivo text,
                saldo_origem_antes numeric, saldo_origem_depois numeric,
                saldo_destino_antes numeric, saldo_destino_depois numeric)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  IF NOT public._mov_pode() THEN
    RAISE EXCEPTION 'Sem permissao.' USING ERRCODE = '42501';
  END IF;
  RETURN QUERY
  SELECT mv.id, mv.numero, mv.criado_em, mv.criado_por, u.nome, mv.produto_id, p.codigo_produto, p.referencia, p.nome,
         mv.quantidade, mv.tipo, mv.origem, mv.destino, coalesce(o.numero_venda, o.numero), c.nome, pi.l_fixo, mv.motivo,
         mv.saldo_origem_antes, mv.saldo_origem_depois, mv.saldo_destino_antes, mv.saldo_destino_depois
    FROM public.movimentacoes_peca mv
    JOIN public.produtos p ON p.id = mv.produto_id
    LEFT JOIN public.usuarios u ON u.id = mv.criado_por
    LEFT JOIN public.projeto_itens pi ON pi.id = mv.projeto_item_id
    LEFT JOIN public.orcamentos o ON o.id = pi.orcamento_id
    LEFT JOIN public.projetos pr ON pr.id = pi.projeto_id
    LEFT JOIN public.contatos c ON c.id = coalesce(o.cliente_id, pr.cliente_id)
   WHERE (p_produto_id IS NULL OR mv.produto_id = p_produto_id)
     AND (p_usuario_id IS NULL OR mv.criado_por = p_usuario_id)
     AND (p_setor IS NULL OR p_setor IN (mv.origem, mv.destino))
     AND (p_tipo IS NULL OR mv.tipo = p_tipo)
     AND (p_de IS NULL OR mv.criado_em >= p_de::timestamp AT TIME ZONE 'America/Sao_Paulo')
     AND (p_ate IS NULL OR mv.criado_em < (p_ate + 1)::timestamp AT TIME ZONE 'America/Sao_Paulo')
   ORDER BY mv.criado_em DESC
   LIMIT least(greatest(coalesce(p_limite, 500), 1), 5000);
END;
$function$;

CREATE OR REPLACE FUNCTION public.movimentacao_usuarios()
 RETURNS TABLE (id uuid, nome text)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  IF NOT public._mov_pode() THEN
    RAISE EXCEPTION 'Sem permissao.' USING ERRCODE = '42501';
  END IF;
  RETURN QUERY
  SELECT DISTINCT u.id, u.nome FROM public.movimentacoes_peca mv JOIN public.usuarios u ON u.id = mv.criado_por
   ORDER BY u.nome;
END;
$function$;

DO $$
DECLARE f text;
BEGIN
  FOREACH f IN ARRAY ARRAY[
    'public.movimentar_peca_setor(uuid, text, text, numeric, text)',
    'public.movimentar_peca_venda(uuid, text, numeric, text)',
    'public.movimentacao_buscar_pecas(text)',
    'public.movimentacao_peca_setores(uuid)',
    'public.movimentacao_listar(uuid, uuid, text, text, date, date, integer)',
    'public.movimentacao_usuarios()']
  LOOP
    EXECUTE format('REVOKE ALL ON FUNCTION %s FROM PUBLIC, anon', f);
    EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO authenticated', f);
  END LOOP;
END $$;

-- 7. Sistema no Hub ----------------------------------------------------------------------------------------------
INSERT INTO public.systems (name, description, link, icon_name, display_order, slug, visivel_no_hub)
SELECT 'Movimentação de Peças',
        'Mudar a peça de setor (Estoque Geral, Showroom, Garantia, Casa Cor, Defeito, Amostra) e de venda (reserva, entrega futura, separação), com registro de quem, quando e por quê.',
        'https://movimentacao-lucenera.pages.dev/', 'ArrowLeftRight',
        (SELECT coalesce(max(display_order), 0) + 1 FROM public.systems), 'movimentacao-pecas', true
 WHERE NOT EXISTS (SELECT 1 FROM public.systems WHERE slug = 'movimentacao-pecas');
