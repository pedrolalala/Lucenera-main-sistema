-- Desfaz a 233 (SPEC-220): volta a view (230), as RPCs de entrada/cancelamento como estavam e apaga o que é novo.
-- ATENÇÃO: não devolve saldos já movidos (entrega futura -> reserva). Antes de rodar, cancelar as entradas com
-- vínculo (cancelar_entrada_nota_compra desfaz) ou ajustar à mão pelos movimentos 'recebimento_para_reserva'.
BEGIN;

CREATE OR REPLACE VIEW public.vw_contas_pagar_pedidos_compra AS
WITH consumo AS (
  SELECT p.id AS pedido_id,
         coalesce((SELECT sum(n.valor) FROM public.notas_fiscais_compra n
                    WHERE n.pedido_compra_id = p.id AND n.cancelada_em IS NULL), 0)
       + coalesce((SELECT sum(a.valor - coalesce((SELECT sum(x.valor_aplicado) FROM public.pagamento_antecipado_vinculos x
                                                   WHERE x.pagamento_id = a.id), 0))
                     FROM public.pagamentos_antecipados a
                    WHERE a.pedido_compra_id = p.id AND a.cancelado_em IS NULL), 0) AS consumido
    FROM public.pedidos_compra p
), parcelas AS (
  SELECT x.*,
         count(*) OVER (PARTITION BY x.pedido_id) AS total_parcelas,
         sum(x.valor) OVER (PARTITION BY x.pedido_id ORDER BY x.numero_parcela
                            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS acumulado
    FROM public.pedido_compra_parcelas x
   WHERE x.status <> 'cancelado'
), previsao AS (
  SELECT x.*, greatest(0, least(x.valor, x.acumulado - coalesce(k.consumido, 0)))::numeric(14,2) AS restante
    FROM parcelas x
    LEFT JOIN consumo k ON k.pedido_id = x.pedido_id
), nota_parcelas AS (
  SELECT np.*, count(*) OVER (PARTITION BY np.nota_id) AS total_parcelas
    FROM public.nota_fiscal_compra_parcelas np
)
SELECT
  ('pc:' || x.id::text)                                        AS id,
  'despesa'::text                                              AS tipo,
  format('Pedido de compra %s — %s (parcela %s/%s)', p.numero, coalesce(c.nome, 'fornecedor'),
         x.numero_parcela, x.total_parcelas)                   AS descricao,
  'PEDIDOS DE COMPRA'::text                                    AS desc_sub_grupo,
  'DESPESAS'::text                                             AS desc_grupo,
  'despesa_operacional'::text                                  AS natureza,
  0                                                            AS status_pago,
  NULL::date                                                   AS dt_pagamento,
  x.data_vencimento                                            AS dt_vencimento,
  p.data_emissao                                               AS dt_emissao,
  0::numeric                                                   AS vl_pago,
  x.restante::numeric                                          AS vl_parcela,
  0::numeric                                                   AS vl_desconto,
  p.empresa_id,
  NULL::integer                                                AS cod_duplicata,
  'variavel'::text                                             AS tipo_custo,
  p.perfil,
  'pedido_compra'::text                                        AS origem,
  p.id                                                         AS pedido_compra_id,
  p.numero                                                     AS pedido_numero,
  p.status                                                     AS pedido_status
FROM previsao x
JOIN public.pedidos_compra p ON p.id = x.pedido_id
LEFT JOIN public.contatos c ON c.id = p.fornecedor_id
WHERE p.status IN ('aprovado', 'parcialmente_recebido')
  AND p.numero NOT LIKE 'PC-LEGADO-%'
  AND x.status IN ('pendente', 'atrasado')
  AND x.data_vencimento IS NOT NULL
  AND x.restante > 0
  AND (SELECT public.pode_acessar_sistema('dashboard-financeiro'::text))

UNION ALL

SELECT
  ('nf:' || np.id::text),
  'despesa'::text,
  format('Nota %s — %s (parcela %s/%s, pedido %s)', n.numero_nf, coalesce(c.nome, 'fornecedor'),
         np.numero_parcela, np.total_parcelas, p.numero),
  'PEDIDOS DE COMPRA'::text,
  'DESPESAS'::text,
  'despesa_operacional'::text,
  0,
  NULL::date,
  np.data_vencimento,
  coalesce(n.data_emissao, p.data_emissao),
  0::numeric,
  np.valor::numeric,
  0::numeric,
  coalesce(n.empresa_id, p.empresa_id),
  NULL::integer,
  'variavel'::text,
  p.perfil,
  'nota_compra'::text,
  p.id,
  p.numero,
  p.status
FROM nota_parcelas np
JOIN public.notas_fiscais_compra n ON n.id = np.nota_id
JOIN public.pedidos_compra p ON p.id = n.pedido_compra_id
LEFT JOIN public.contatos c ON c.id = coalesce(n.fornecedor_id, p.fornecedor_id)
WHERE p.status <> 'cancelado'
  AND n.cancelada_em IS NULL
  AND NOT EXISTS (
    SELECT 1 FROM public.negociacoes g
     WHERE g.tipo = 'despesa'
       AND g.empresa_id = coalesce(n.empresa_id, p.empresa_id)
       AND g.num_nota = nullif(regexp_replace(n.numero_nf, '\D', '', 'g'), '')::numeric
       AND abs(coalesce((SELECT sum(t.vl_parcela) FROM public.transacoes t
                          WHERE t.negociacao_id = g.id AND t.status_pago <> 2), 0) - n.valor) <= 1)
  AND (SELECT public.pode_acessar_sistema('dashboard-financeiro'::text))

UNION ALL

SELECT
  ('pa:' || a.id::text),
  'despesa'::text,
  format('Pagamento antecipado — %s%s', coalesce(c.nome, 'fornecedor'),
         CASE WHEN p.numero IS NOT NULL THEN ' (pedido ' || p.numero || ')' ELSE '' END),
  'PAGAMENTO ANTECIPADO'::text,
  'DESPESAS'::text,
  'despesa_operacional'::text,
  1,
  a.data_pagamento,
  a.data_pagamento,
  a.data_pagamento,
  a.valor::numeric,
  a.valor::numeric,
  0::numeric,
  a.empresa_id,
  NULL::integer,
  'variavel'::text,
  p.perfil,
  'pagamento_antecipado'::text,
  p.id,
  p.numero,
  p.status
FROM public.pagamentos_antecipados a
LEFT JOIN public.pedidos_compra p ON p.id = a.pedido_compra_id
LEFT JOIN public.contatos c ON c.id = a.fornecedor_id
WHERE a.cancelado_em IS NULL
  AND (SELECT public.pode_acessar_sistema('dashboard-financeiro'::text));


DROP FUNCTION IF EXISTS public.registrar_entrada_nota_compra(uuid, jsonb, jsonb, jsonb, jsonb, uuid, jsonb);
CREATE OR REPLACE FUNCTION public.registrar_entrada_nota_compra(p_pedido_id uuid, p_itens jsonb, p_nota jsonb, p_parcelas jsonb DEFAULT '[]'::jsonb, p_antecipacoes jsonb DEFAULT '[]'::jsonb, p_fornecedor_id uuid DEFAULT NULL::uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_ped        record;
  v_forn       uuid;
  v_numero_nf  text := nullif(trim(coalesce(p_nota->>'numero_nf', '')), '');
  v_valor      numeric := round(coalesce(nullif(p_nota->>'valor', '')::numeric, 0), 2);
  v_nota_id    uuid;
  v_res        jsonb;
  v_el         jsonb;
  v_n          integer := 0;
  v_soma_parc  numeric := 0;
  v_aplicado   numeric := 0;
  v_pag        record;
  v_saldo      numeric;
  v_qtd        numeric;
BEGIN
  IF NOT public.hub_pode_executar(auth.uid(), 'necessidade-de-compra', NULL, 'editar') THEN
    RAISE EXCEPTION 'Sem permissao para dar entrada em pedido de compra.' USING ERRCODE = '42501';
  END IF;

  SELECT id, numero, status, fornecedor_id, empresa_id INTO v_ped
    FROM public.pedidos_compra WHERE id = p_pedido_id FOR UPDATE;
  IF v_ped.id IS NULL THEN
    RAISE EXCEPTION 'Pedido de compra nao encontrado.' USING ERRCODE = 'P0001';
  END IF;
  IF v_numero_nf IS NULL THEN
    RAISE EXCEPTION 'Informe o numero da nota fiscal.' USING ERRCODE = 'P0001';
  END IF;
  IF v_valor <= 0 THEN
    RAISE EXCEPTION 'Informe o valor total da nota.' USING ERRCODE = 'P0001';
  END IF;
  IF EXISTS (SELECT 1 FROM public.notas_fiscais_compra
              WHERE pedido_compra_id = p_pedido_id AND trim(numero_nf) = v_numero_nf AND cancelada_em IS NULL) THEN
    RAISE EXCEPTION 'A nota % ja foi registrada neste pedido.', v_numero_nf USING ERRCODE = 'P0001';
  END IF;

  -- Fornecedor da nota diferente do pedido (ex.: pedido Emétris, nota Spot LED): o pedido passa a ser dele.
  v_forn := v_ped.fornecedor_id;
  IF p_fornecedor_id IS NOT NULL AND p_fornecedor_id IS DISTINCT FROM v_ped.fornecedor_id THEN
    IF NOT EXISTS (SELECT 1 FROM public.contatos WHERE id = p_fornecedor_id) THEN
      RAISE EXCEPTION 'Fornecedor nao encontrado.' USING ERRCODE = 'P0001';
    END IF;
    UPDATE public.pedidos_compra SET fornecedor_id = p_fornecedor_id, atualizado_em = now() WHERE id = p_pedido_id;
    v_forn := p_fornecedor_id;
  END IF;

  -- Quantidades (mesmas regras de antes; muda o status do pedido)
  v_res := public.registrar_entrada_pedido_compra(p_pedido_id, p_itens);

  INSERT INTO public.notas_fiscais_compra
    (pedido_compra_id, numero_nf, data_emissao, valor, valor_st, arquivo_url, observacao,
     criado_por, fornecedor_id, empresa_id)
  VALUES (p_pedido_id, v_numero_nf, nullif(p_nota->>'data_emissao', '')::date, v_valor,
          nullif(round(coalesce(nullif(p_nota->>'valor_st', '')::numeric, 0), 2), 0),
          nullif(p_nota->>'arquivo_url', ''), nullif(trim(coalesce(p_nota->>'observacao', '')), ''),
          auth.uid(), v_forn, v_ped.empresa_id)
  RETURNING id INTO v_nota_id;

  -- SPEC-218: guarda quanto de cada item entrou por esta nota (para o cancelamento devolver).
  INSERT INTO public.nota_fiscal_compra_itens (nota_id, pedido_item_id, quantidade)
  SELECT v_nota_id, (e->>'pedido_item_id')::uuid, sum(nullif(e->>'quantidade', '')::numeric)
    FROM jsonb_array_elements(coalesce(p_itens, '[]'::jsonb)) e
   WHERE coalesce(nullif(e->>'quantidade', '')::numeric, 0) > 0
   GROUP BY (e->>'pedido_item_id')::uuid;

  -- Pagamentos antecipados usados nesta nota
  FOR v_el IN SELECT * FROM jsonb_array_elements(coalesce(p_antecipacoes, '[]'::jsonb))
  LOOP
    v_qtd := round(coalesce(nullif(v_el->>'valor', '')::numeric, 0), 2);
    CONTINUE WHEN v_qtd = 0;
    IF v_qtd < 0 THEN
      RAISE EXCEPTION 'Valor da antecipacao nao pode ser negativo.' USING ERRCODE = 'P0001';
    END IF;
    SELECT * INTO v_pag FROM public.pagamentos_antecipados
     WHERE id = (v_el->>'pagamento_id')::uuid FOR UPDATE;
    IF v_pag.id IS NULL OR v_pag.cancelado_em IS NOT NULL THEN
      RAISE EXCEPTION 'Pagamento antecipado nao encontrado ou cancelado.' USING ERRCODE = 'P0001';
    END IF;
    IF NOT (v_pag.fornecedor_id IN (v_ped.fornecedor_id, v_forn) OR v_pag.pedido_compra_id = p_pedido_id) THEN
      RAISE EXCEPTION 'Pagamento antecipado de outro fornecedor.' USING ERRCODE = 'P0001';
    END IF;
    v_saldo := v_pag.valor - coalesce((SELECT sum(valor_aplicado) FROM public.pagamento_antecipado_vinculos
                                        WHERE pagamento_id = v_pag.id), 0);
    IF v_qtd > v_saldo + 0.001 THEN
      RAISE EXCEPTION 'Valor usado (%) maior que o saldo do pagamento antecipado (%).', v_qtd, v_saldo
        USING ERRCODE = 'P0001';
    END IF;
    INSERT INTO public.pagamento_antecipado_vinculos (pagamento_id, nota_id, valor_aplicado, criado_por)
    VALUES (v_pag.id, v_nota_id, v_qtd, auth.uid());
    v_aplicado := v_aplicado + v_qtd;
  END LOOP;

  -- Parcelas da nota (o restante depois da antecipação)
  FOR v_el IN SELECT * FROM jsonb_array_elements(coalesce(p_parcelas, '[]'::jsonb))
  LOOP
    v_qtd := round(coalesce(nullif(v_el->>'valor', '')::numeric, 0), 2);
    IF v_qtd <= 0 THEN
      RAISE EXCEPTION 'Toda parcela precisa ter valor maior que zero.' USING ERRCODE = 'P0001';
    END IF;
    IF nullif(v_el->>'data_vencimento', '') IS NULL THEN
      RAISE EXCEPTION 'Toda parcela precisa ter vencimento.' USING ERRCODE = 'P0001';
    END IF;
    v_n := v_n + 1;
    INSERT INTO public.nota_fiscal_compra_parcelas (nota_id, numero_parcela, data_vencimento, valor)
    VALUES (v_nota_id, v_n, (v_el->>'data_vencimento')::date, v_qtd);
    v_soma_parc := v_soma_parc + v_qtd;
  END LOOP;

  IF v_aplicado > v_valor + 0.001 THEN
    RAISE EXCEPTION 'Antecipacao usada (%) maior que o valor da nota (%).', v_aplicado, v_valor USING ERRCODE = 'P0001';
  END IF;
  IF abs(v_soma_parc + v_aplicado - v_valor) > 0.01 THEN
    RAISE EXCEPTION 'Parcelas (%) + antecipacao (%) nao batem com o valor da nota (%).', v_soma_parc, v_aplicado, v_valor
      USING ERRCODE = 'P0001';
  END IF;

  RETURN v_res || jsonb_build_object('nota_id', v_nota_id, 'parcelas', v_n, 'antecipacao_aplicada', v_aplicado,
                                     'fornecedor_trocado', v_forn IS DISTINCT FROM v_ped.fornecedor_id);
END;
$function$

;
REVOKE ALL ON FUNCTION public.registrar_entrada_nota_compra(uuid, jsonb, jsonb, jsonb, jsonb, uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.registrar_entrada_nota_compra(uuid, jsonb, jsonb, jsonb, jsonb, uuid) TO authenticated;

CREATE OR REPLACE FUNCTION public.cancelar_entrada_nota_compra(p_nota_id uuid, p_motivo text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_nota      record;
  v_ped       record;
  v_motivo    text := nullif(trim(coalesce(p_motivo, '')), '');
  v_itens     integer := 0;
  v_parcelas  integer := 0;
  v_antecip   numeric := 0;
  v_novo      text;
BEGIN
  IF NOT public.hub_pode_executar(auth.uid(), 'necessidade-de-compra', NULL, 'editar') THEN
    RAISE EXCEPTION 'Sem permissao para cancelar entrada de nota fiscal.' USING ERRCODE = '42501';
  END IF;
  IF v_motivo IS NULL THEN
    RAISE EXCEPTION 'Informe o motivo do cancelamento.' USING ERRCODE = 'P0001';
  END IF;

  SELECT id, numero_nf, pedido_compra_id, cancelada_em INTO v_nota
    FROM public.notas_fiscais_compra WHERE id = p_nota_id FOR UPDATE;
  IF v_nota.id IS NULL THEN
    RAISE EXCEPTION 'Nota fiscal nao encontrada.' USING ERRCODE = 'P0001';
  END IF;
  IF v_nota.cancelada_em IS NOT NULL THEN
    RAISE EXCEPTION 'A nota % ja foi cancelada.', v_nota.numero_nf USING ERRCODE = 'P0001';
  END IF;

  IF v_nota.pedido_compra_id IS NOT NULL THEN
    SELECT id, numero, status INTO v_ped FROM public.pedidos_compra WHERE id = v_nota.pedido_compra_id FOR UPDATE;

    -- Devolve o que entrou por esta nota
    UPDATE public.pedido_compra_itens i
       SET qtd_recebida = greatest(0, i.qtd_recebida - x.quantidade)
      FROM public.nota_fiscal_compra_itens x
     WHERE x.nota_id = p_nota_id AND x.pedido_item_id = i.id;
    GET DIAGNOSTICS v_itens = ROW_COUNT;

    -- Status pelo que sobrou recebido (a entrada só acontece a partir de "aprovado")
    IF v_ped.status <> 'cancelado' THEN
      SELECT CASE WHEN bool_and(qtd_recebida >= quantidade) THEN 'recebido'
                  WHEN bool_or(qtd_recebida > 0) THEN 'parcialmente_recebido'
                  ELSE 'aprovado' END
        INTO v_novo FROM public.pedido_compra_itens WHERE pedido_id = v_ped.id;
      UPDATE public.pedidos_compra
         SET status = coalesce(v_novo, status),
             recebido_em = CASE WHEN v_novo = 'recebido' THEN recebido_em END,
             primeira_entrada_em = CASE WHEN v_novo = 'aprovado' THEN NULL ELSE primeira_entrada_em END,
             atualizado_em = now()
       WHERE id = v_ped.id;
    END IF;
  END IF;

  -- Parcelas da nota saem do A Pagar; antecipação usada volta a ter saldo
  DELETE FROM public.nota_fiscal_compra_parcelas WHERE nota_id = p_nota_id;
  GET DIAGNOSTICS v_parcelas = ROW_COUNT;
  SELECT coalesce(sum(valor_aplicado), 0) INTO v_antecip FROM public.pagamento_antecipado_vinculos WHERE nota_id = p_nota_id;
  DELETE FROM public.pagamento_antecipado_vinculos WHERE nota_id = p_nota_id;

  UPDATE public.notas_fiscais_compra
     SET cancelada_em = now(), cancelada_por = auth.uid(), motivo_cancelamento = v_motivo
   WHERE id = p_nota_id;

  RETURN jsonb_build_object('nota_id', p_nota_id, 'numero_nf', v_nota.numero_nf,
                            'pedido_numero', v_ped.numero, 'pedido_status', v_novo,
                            'itens_devolvidos', v_itens, 'parcelas_removidas', v_parcelas,
                            'antecipacao_devolvida', v_antecip);
END;
$function$

;

DROP FUNCTION IF EXISTS public.espelho_entrada_nota_compra(uuid);
DROP FUNCTION IF EXISTS public.entregas_futuras_para_entrada(uuid[]);
DROP TABLE IF EXISTS public.nota_fiscal_compra_vinculos;
ALTER TABLE public.nota_fiscal_compra_itens
  DROP COLUMN IF EXISTS valor_unitario, DROP COLUMN IF EXISTS valor_ipi,
  DROP COLUMN IF EXISTS valor_icms, DROP COLUMN IF EXISTS valor_st;
ALTER TABLE public.notas_fiscais_compra DROP CONSTRAINT IF EXISTS notas_fiscais_compra_chave_acesso_check;
ALTER TABLE public.notas_fiscais_compra
  DROP COLUMN IF EXISTS chave_acesso, DROP COLUMN IF EXISTS data_entrega, DROP COLUMN IF EXISTS data_entrada,
  DROP COLUMN IF EXISTS plano_contas_id, DROP COLUMN IF EXISTS valor_desconto,
  DROP COLUMN IF EXISTS valor_despesas_acessorias;

COMMIT;
