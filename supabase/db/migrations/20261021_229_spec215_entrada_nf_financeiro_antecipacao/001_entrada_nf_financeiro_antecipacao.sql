-- SPEC-215 (pedido do usuário 21/10): Entrada de Nota Fiscal com fornecedor/CNPJ, parcelas da nota e pagamento
-- antecipado (sinal pago antes da nota).
-- Decisões 21/10: a nota continua sendo lançada no Connect (as parcelas daqui valem no A Pagar até a duplicata do
-- Connect daquela nota chegar); a nota substitui a previsão do pedido; antecipação lançada na Adm. Bancária;
-- trocar o fornecedor na entrada muda o fornecedor do pedido.
-- Não toca em transacoes nem em pedido_compra_parcelas.
BEGIN;

-- 1. Colunas -------------------------------------------------------------------------------------------------------
ALTER TABLE public.notas_fiscais_compra ADD COLUMN IF NOT EXISTS valor_st numeric(14,2);
COMMENT ON COLUMN public.notas_fiscais_compra.valor_st IS 'SPEC-215: valor do ST destacado na nota (cobrado na 1ª parcela).';

ALTER TABLE public.negociacoes ADD COLUMN IF NOT EXISTS num_nota bigint;
COMMENT ON COLUMN public.negociacoes.num_nota IS
  'SPEC-215: número da nota no Connect (num_nota da planilha). Usado para tirar do A Pagar a parcela digitada na entrada quando a duplicata do Connect chega.';
CREATE INDEX IF NOT EXISTS idx_negociacoes_empresa_num_nota
  ON public.negociacoes (empresa_id, num_nota) WHERE num_nota IS NOT NULL;

-- 2. Parcelas da nota ----------------------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.nota_fiscal_compra_parcelas (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  nota_id         uuid NOT NULL REFERENCES public.notas_fiscais_compra(id) ON DELETE CASCADE,
  numero_parcela  integer NOT NULL,
  data_vencimento date NOT NULL,
  valor           numeric(14,2) NOT NULL CHECK (valor > 0),
  criado_em       timestamptz NOT NULL DEFAULT now(),
  UNIQUE (nota_id, numero_parcela)
);
COMMENT ON TABLE public.nota_fiscal_compra_parcelas IS
  'SPEC-215: parcelas digitadas na Entrada de Nota Fiscal. Gravadas só pela RPC registrar_entrada_nota_compra.';

-- 3. Pagamento antecipado ------------------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.pagamentos_antecipados (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  fornecedor_id    uuid NOT NULL REFERENCES public.contatos(id),
  empresa_id       uuid NOT NULL REFERENCES public.empresas(id),
  pedido_compra_id uuid REFERENCES public.pedidos_compra(id) ON DELETE SET NULL,
  valor            numeric(14,2) NOT NULL CHECK (valor > 0),
  data_pagamento   date NOT NULL,
  observacao       text,
  criado_por       uuid DEFAULT auth.uid(),
  criado_em        timestamptz NOT NULL DEFAULT now(),
  cancelado_em     timestamptz,
  cancelado_por    uuid,
  motivo_cancelamento text
);
COMMENT ON TABLE public.pagamentos_antecipados IS
  'SPEC-215: pagamento ao fornecedor antes da nota (sinal ou 100%). Lançado na Adm. Bancária; vinculado na Entrada de Nota Fiscal.';
CREATE INDEX IF NOT EXISTS idx_pagamentos_antecipados_fornecedor ON public.pagamentos_antecipados (fornecedor_id);
CREATE INDEX IF NOT EXISTS idx_pagamentos_antecipados_pedido ON public.pagamentos_antecipados (pedido_compra_id);

CREATE TABLE IF NOT EXISTS public.pagamento_antecipado_vinculos (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  pagamento_id   uuid NOT NULL REFERENCES public.pagamentos_antecipados(id),
  nota_id        uuid NOT NULL REFERENCES public.notas_fiscais_compra(id) ON DELETE CASCADE,
  valor_aplicado numeric(14,2) NOT NULL CHECK (valor_aplicado > 0),
  criado_por     uuid DEFAULT auth.uid(),
  criado_em      timestamptz NOT NULL DEFAULT now(),
  UNIQUE (pagamento_id, nota_id)
);
COMMENT ON TABLE public.pagamento_antecipado_vinculos IS 'SPEC-215: quanto de cada pagamento antecipado foi usado em cada nota.';

-- 4. Segurança (SPEC-196): RLS ligado, nada para anon, escrita só pelas RPCs ---------------------------------------
ALTER TABLE public.nota_fiscal_compra_parcelas ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pagamentos_antecipados ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pagamento_antecipado_vinculos ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.nota_fiscal_compra_parcelas, public.pagamentos_antecipados, public.pagamento_antecipado_vinculos FROM anon;
REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON public.nota_fiscal_compra_parcelas, public.pagamentos_antecipados,
  public.pagamento_antecipado_vinculos FROM authenticated;
GRANT SELECT ON public.nota_fiscal_compra_parcelas, public.pagamentos_antecipados, public.pagamento_antecipado_vinculos TO authenticated;

CREATE POLICY nota_fiscal_compra_parcelas_select ON public.nota_fiscal_compra_parcelas
  FOR SELECT TO authenticated
  USING ((SELECT public.pode_acessar_sistema('necessidade-de-compra'))
         OR (SELECT public.pode_acessar_sistema('financeiro'))
         OR (SELECT public.pode_acessar_sistema('dashboard-financeiro')));

CREATE POLICY pagamentos_antecipados_select ON public.pagamentos_antecipados
  FOR SELECT TO authenticated
  USING ((SELECT public.pode_acessar_sistema('financeiro'))
         OR (SELECT public.pode_acessar_sistema('dashboard-financeiro')));

CREATE POLICY pagamento_antecipado_vinculos_select ON public.pagamento_antecipado_vinculos
  FOR SELECT TO authenticated
  USING ((SELECT public.pode_acessar_sistema('financeiro'))
         OR (SELECT public.pode_acessar_sistema('dashboard-financeiro')));

CREATE TRIGGER auditoria_registrar AFTER INSERT OR DELETE OR UPDATE ON public.pagamentos_antecipados
  FOR EACH ROW EXECUTE FUNCTION auditoria.fn_registrar();
CREATE TRIGGER auditoria_registrar AFTER INSERT OR DELETE OR UPDATE ON public.pagamento_antecipado_vinculos
  FOR EACH ROW EXECUTE FUNCTION auditoria.fn_registrar();

-- 5. Lista com saldo (Adm. Bancária) -------------------------------------------------------------------------------
CREATE OR REPLACE VIEW public.vw_pagamentos_antecipados AS
SELECT a.id, a.fornecedor_id, c.nome AS fornecedor_nome,
       regexp_replace(coalesce(nullif(c.cnpj, ''), c.cpf_cnpj, ''), '\D', '', 'g') AS fornecedor_documento,
       a.empresa_id, e.nome AS empresa_nome,
       a.pedido_compra_id, p.numero AS pedido_numero,
       a.valor, a.data_pagamento, a.observacao, a.criado_em, a.criado_por, u.nome AS criado_por_nome,
       a.cancelado_em, a.motivo_cancelamento,
       coalesce(v.aplicado, 0)::numeric(14,2)            AS valor_aplicado,
       (a.valor - coalesce(v.aplicado, 0))::numeric(14,2) AS saldo,
       coalesce(v.notas, '')                              AS notas_vinculadas,
       CASE WHEN a.cancelado_em IS NOT NULL THEN 'cancelado'
            WHEN coalesce(v.aplicado, 0) = 0 THEN 'disponivel'
            WHEN coalesce(v.aplicado, 0) < a.valor THEN 'usado_em_parte'
            ELSE 'usado' END                              AS situacao
  FROM public.pagamentos_antecipados a
  JOIN public.contatos c ON c.id = a.fornecedor_id
  JOIN public.empresas e ON e.id = a.empresa_id
  LEFT JOIN public.pedidos_compra p ON p.id = a.pedido_compra_id
  LEFT JOIN public.usuarios u ON u.id = a.criado_por
  LEFT JOIN LATERAL (
    SELECT sum(x.valor_aplicado) AS aplicado,
           string_agg(n.numero_nf, ', ' ORDER BY x.criado_em) AS notas
      FROM public.pagamento_antecipado_vinculos x
      JOIN public.notas_fiscais_compra n ON n.id = x.nota_id
     WHERE x.pagamento_id = a.id
  ) v ON true
 WHERE (SELECT public.pode_acessar_sistema('financeiro'))
    OR (SELECT public.pode_acessar_sistema('dashboard-financeiro'));
REVOKE ALL ON public.vw_pagamentos_antecipados FROM anon;
GRANT SELECT ON public.vw_pagamentos_antecipados TO authenticated;

-- 6. RPCs da antecipação -------------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.lancar_pagamento_antecipado(
  p_fornecedor_id uuid, p_empresa_id uuid, p_valor numeric, p_data_pagamento date,
  p_pedido_compra_id uuid DEFAULT NULL, p_observacao text DEFAULT NULL)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_id uuid;
  v_status text;
BEGIN
  IF NOT (public.pode_acessar_sistema('financeiro') OR public.pode_acessar_sistema('dashboard-financeiro')) THEN
    RAISE EXCEPTION 'Sem permissao para lancar pagamento antecipado.' USING ERRCODE = '42501';
  END IF;
  IF coalesce(p_valor, 0) <= 0 THEN
    RAISE EXCEPTION 'Informe o valor pago.' USING ERRCODE = 'P0001';
  END IF;
  IF p_data_pagamento IS NULL THEN
    RAISE EXCEPTION 'Informe a data do pagamento.' USING ERRCODE = 'P0001';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.contatos WHERE id = p_fornecedor_id) THEN
    RAISE EXCEPTION 'Fornecedor nao encontrado.' USING ERRCODE = 'P0001';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.empresas WHERE id = p_empresa_id) THEN
    RAISE EXCEPTION 'Empresa nao encontrada.' USING ERRCODE = 'P0001';
  END IF;
  IF p_pedido_compra_id IS NOT NULL THEN
    SELECT status INTO v_status FROM public.pedidos_compra WHERE id = p_pedido_compra_id;
    IF v_status IS NULL THEN
      RAISE EXCEPTION 'Pedido de compra nao encontrado.' USING ERRCODE = 'P0001';
    END IF;
    IF v_status = 'cancelado' THEN
      RAISE EXCEPTION 'Pedido de compra cancelado.' USING ERRCODE = 'P0001';
    END IF;
  END IF;

  INSERT INTO public.pagamentos_antecipados
    (fornecedor_id, empresa_id, pedido_compra_id, valor, data_pagamento, observacao, criado_por)
  VALUES (p_fornecedor_id, p_empresa_id, p_pedido_compra_id, round(p_valor, 2), p_data_pagamento,
          nullif(trim(coalesce(p_observacao, '')), ''), auth.uid())
  RETURNING id INTO v_id;
  RETURN v_id;
END;
$function$;

CREATE OR REPLACE FUNCTION public.cancelar_pagamento_antecipado(p_id uuid, p_motivo text DEFAULT NULL)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  IF NOT (public.pode_acessar_sistema('financeiro') OR public.pode_acessar_sistema('dashboard-financeiro')) THEN
    RAISE EXCEPTION 'Sem permissao para cancelar pagamento antecipado.' USING ERRCODE = '42501';
  END IF;
  PERFORM 1 FROM public.pagamentos_antecipados WHERE id = p_id AND cancelado_em IS NULL FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Pagamento antecipado nao encontrado ou ja cancelado.' USING ERRCODE = 'P0001';
  END IF;
  IF EXISTS (SELECT 1 FROM public.pagamento_antecipado_vinculos WHERE pagamento_id = p_id) THEN
    RAISE EXCEPTION 'Pagamento antecipado ja vinculado a nota fiscal; nao pode ser cancelado.' USING ERRCODE = 'P0001';
  END IF;
  UPDATE public.pagamentos_antecipados
     SET cancelado_em = now(), cancelado_por = auth.uid(),
         motivo_cancelamento = nullif(trim(coalesce(p_motivo, '')), '')
   WHERE id = p_id;
END;
$function$;

-- Na entrada (Compras): antecipações com saldo do fornecedor do pedido, do fornecedor da nota ou ligadas ao pedido.
-- SECURITY DEFINER para quem só tem a Compras ver o necessário (sem o resto do financeiro).
CREATE OR REPLACE FUNCTION public.antecipacoes_para_entrada(p_pedido_id uuid, p_fornecedor_id uuid DEFAULT NULL)
 RETURNS TABLE(id uuid, fornecedor_nome text, empresa_nome text, pedido_numero text, data_pagamento date,
               valor numeric, saldo numeric, observacao text)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_forn uuid;
BEGIN
  IF NOT public.hub_pode_executar(auth.uid(), 'necessidade-de-compra', NULL, NULL) THEN
    RAISE EXCEPTION 'Sem permissao.' USING ERRCODE = '42501';
  END IF;
  SELECT fornecedor_id INTO v_forn FROM public.pedidos_compra WHERE pedidos_compra.id = p_pedido_id;
  RETURN QUERY
  SELECT a.id, c.nome, e.nome, p.numero, a.data_pagamento, a.valor,
         (a.valor - coalesce((SELECT sum(x.valor_aplicado) FROM public.pagamento_antecipado_vinculos x
                               WHERE x.pagamento_id = a.id), 0))::numeric AS saldo,
         a.observacao
    FROM public.pagamentos_antecipados a
    JOIN public.contatos c ON c.id = a.fornecedor_id
    JOIN public.empresas e ON e.id = a.empresa_id
    LEFT JOIN public.pedidos_compra p ON p.id = a.pedido_compra_id
   WHERE a.cancelado_em IS NULL
     AND (a.fornecedor_id IN (v_forn, p_fornecedor_id) OR a.pedido_compra_id = p_pedido_id)
     AND a.valor > coalesce((SELECT sum(x.valor_aplicado) FROM public.pagamento_antecipado_vinculos x
                              WHERE x.pagamento_id = a.id), 0)
   ORDER BY (a.pedido_compra_id = p_pedido_id) DESC NULLS LAST, a.data_pagamento;
END;
$function$;

-- 7. Entrada da nota numa transação só -----------------------------------------------------------------------------
-- p_itens: [{pedido_item_id, quantidade}] (igual à registrar_entrada_pedido_compra, que é chamada aqui dentro)
-- p_nota: {numero_nf, data_emissao, valor, valor_st, arquivo_url, observacao}
-- p_parcelas: [{data_vencimento, valor}]   p_antecipacoes: [{pagamento_id, valor}]
-- p_fornecedor_id: fornecedor da nota quando é diferente do pedido -> o pedido passa a ser desse fornecedor.
CREATE OR REPLACE FUNCTION public.registrar_entrada_nota_compra(
  p_pedido_id uuid, p_itens jsonb, p_nota jsonb, p_parcelas jsonb DEFAULT '[]'::jsonb,
  p_antecipacoes jsonb DEFAULT '[]'::jsonb, p_fornecedor_id uuid DEFAULT NULL)
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
              WHERE pedido_compra_id = p_pedido_id AND trim(numero_nf) = v_numero_nf) THEN
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
$function$;

REVOKE ALL ON FUNCTION public.lancar_pagamento_antecipado(uuid, uuid, numeric, date, uuid, text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.cancelar_pagamento_antecipado(uuid, text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.antecipacoes_para_entrada(uuid, uuid) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.registrar_entrada_nota_compra(uuid, jsonb, jsonb, jsonb, jsonb, uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.lancar_pagamento_antecipado(uuid, uuid, numeric, date, uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.cancelar_pagamento_antecipado(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.antecipacoes_para_entrada(uuid, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.registrar_entrada_nota_compra(uuid, jsonb, jsonb, jsonb, jsonb, uuid) TO authenticated;

-- 8. Contas a Pagar -------------------------------------------------------------------------------------------------
-- a) previsão do pedido: o consumido (notas registradas + saldo das antecipações ligadas ao pedido) abate as
--    parcelas da primeira para a última; pedido concluído sai (a nota substitui a previsão).
-- b) parcelas da nota: até chegar no Connect duplicata de despesa da mesma empresa + mesmo num_nota + mesmo total.
-- c) pagamento antecipado: linha paga em DESPESAS › PAGAMENTO ANTECIPADO.
CREATE OR REPLACE VIEW public.vw_contas_pagar_pedidos_compra AS
WITH consumo AS (
  SELECT p.id AS pedido_id,
         coalesce((SELECT sum(n.valor) FROM public.notas_fiscais_compra n WHERE n.pedido_compra_id = p.id), 0)
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

COMMENT ON VIEW public.vw_contas_pagar_pedidos_compra IS
  'SPEC-209 F + SPEC-215: previsão dos pedidos aprovados (abatida pelas notas e antecipações), parcelas das notas de entrada (até a duplicata do Connect chegar) e pagamentos antecipados (pagos). Formato de v_financeiro_realizado.';

COMMIT;
