-- View: v_cash_flow_lucenera
CREATE OR REPLACE VIEW public.v_cash_flow_lucenera AS
 SELECT dt_pagamento,
    dt_vencimento,
    (tipo)::text AS tipo,
        CASE
            WHEN (((descricao ~~* '%LUCRO%'::text) OR (descricao ~~* '%RETIRADA%'::text)) AND ((tipo)::text = 'despesa'::text)) THEN 'distribuicao_lucro'::text
            ELSE (tipo)::text
        END AS categoria_fluxo,
    vl_pago,
    descricao,
    status_pago
   FROM transacoes
  WHERE ((status_pago = 1) AND (dt_pagamento IS NOT NULL));
;
-- View: vw_catalogo_ubiqua
CREATE OR REPLACE VIEW public.vw_catalogo_ubiqua AS
 SELECT TRIM(BOTH FROM descricao) AS nome_exibicao,
    array_agg(DISTINCT TRIM(BOTH FROM cor) ORDER BY (TRIM(BOTH FROM cor))) AS cores_disponiveis,
    sum(disponivel) AS estoque_total,
    max(valor_revenda) AS valor_revenda,
    (array_agg(imagem_catalogo_url ORDER BY disponivel DESC))[1] AS imagem_principal,
    array_agg(json_build_object('cor', TRIM(BOTH FROM cor), 'disponivel', disponivel, 'referencia', referencia)) AS detalhes_por_cor
   FROM revenda_ubiqua
  WHERE (descricao IS NOT NULL)
  GROUP BY (TRIM(BOTH FROM descricao));
;
-- View: vw_catalogo_unificado
CREATE OR REPLACE VIEW public.vw_catalogo_unificado AS
 SELECT TRIM(BOTH FROM regexp_replace(referencia, '-IS$'::text, ''::text, 'i'::text)) AS referencia_base,
    max(regexp_replace(descricao, '-\s*(ISLIGHT|MANOELLA)\s*$'::text, ''::text, 'i'::text)) AS nome_exibicao,
    sum(disponivel) AS estoque_total,
    array_agg(DISTINCT TRIM(BOTH FROM upper(COALESCE(cor, 'PADRÃO'::text)))) AS cores_disponiveis,
    max(imagem_catalogo_url) AS imagem_principal,
    min(valor_revenda) AS valor_minimo
   FROM revenda_ubiqua
  GROUP BY (TRIM(BOTH FROM regexp_replace(referencia, '-IS$'::text, ''::text, 'i'::text)));
;
-- View: vw_comissao_mensal
CREATE OR REPLACE VIEW public.vw_comissao_mensal AS
 SELECT fn.id AS funcionario_id,
    fn.nome AS funcionario,
    ep.id AS equipe_id,
    ep.equipes AS equipe,
    ff.comissao_percentual,
    (date_trunc('month'::text, (p.data_entrada)::timestamp with time zone))::date AS mes,
    count(p.id) AS total_projetos,
    round(sum(p.valor_total), 2) AS valor_total_projetos,
    round(sum(((p.valor_total * COALESCE(ff.comissao_percentual, (0)::numeric)) / 100.0)), 2) AS comissao_calculada
   FROM (((projetos p
     JOIN equipes_projetos ep ON ((ep.id = p.equipe_id)))
     JOIN funcionarios_financeiro ff ON ((ff.equipes_id = ep.id)))
     JOIN funcionarios_novo fn ON ((fn.id = ff.funcionario_id)))
  WHERE ((p.valor_total > (0)::numeric) AND (p.data_entrada IS NOT NULL) AND (fn.ativo IS TRUE))
  GROUP BY fn.id, fn.nome, ep.id, ep.equipes, ff.comissao_percentual, (date_trunc('month'::text, (p.data_entrada)::timestamp with time zone));
;
-- View: vw_conferencia_financeira
CREATE OR REPLACE VIEW public.vw_conferencia_financeira AS
 SELECT t.data_transacao,
    t.descricao,
    t.valor,
    e.nome AS nome_empresa,
    c.nome AS nome_fornecedor,
    t.status_pago,
    t.dt_vencimento
   FROM ((transacoes t
     LEFT JOIN empresas e ON ((t.empresa_id = e.id)))
     LEFT JOIN contatos c ON ((t.parcela_id = c.id)))
  ORDER BY t.data_transacao DESC;
;
-- View: vw_controle_ferias_clt
CREATE OR REPLACE VIEW public.vw_controle_ferias_clt AS
 WITH resumo_periodos AS (
         SELECT pa.funcionario_id,
            f.nome AS funcionario_nome,
            (count(pa.id) * 30) AS direito_total_acumulado,
            COALESCE(( SELECT sum(fer.dias) AS sum
                   FROM ferias fer
                  WHERE ((fer.funcionario_id = pa.funcionario_id) AND (fer.status = 'Aprovado'::text))), (0)::bigint) AS total_gozado
           FROM (periodos_aquisitivos pa
             JOIN funcionarios f ON ((pa.funcionario_id = f.id)))
          GROUP BY pa.funcionario_id, f.nome
        )
 SELECT funcionario_id,
    funcionario_nome,
    direito_total_acumulado,
    total_gozado,
    (direito_total_acumulado - total_gozado) AS saldo_disponivel
   FROM resumo_periodos;
;
-- View: vw_custos_pendentes_mes
CREATE OR REPLACE VIEW public.vw_custos_pendentes_mes AS
 SELECT cr.descricao,
    cf.nome AS categoria,
    crl.data_vencimento,
    crl.valor_original,
    crl.status,
    cb.nome AS conta
   FROM (((custos_recorrentes_lancamentos crl
     JOIN custos_recorrentes cr ON ((cr.id = crl.custo_id)))
     LEFT JOIN categorias_financeiras cf ON ((cf.id = cr.categoria_id)))
     LEFT JOIN contas_bancarias cb ON ((cb.id = cr.conta_id)))
  WHERE ((crl.status = 'pendente'::lancamento_status) AND (date_trunc('month'::text, (crl.data_vencimento)::timestamp with time zone) = date_trunc('month'::text, now())))
  ORDER BY crl.data_vencimento;
;
-- View: vw_dashboard_crm_fechamento
CREATE OR REPLACE VIEW public.vw_dashboard_crm_fechamento AS
 SELECT date_trunc('month'::text, (p.data_entrada)::timestamp with time zone) AS mes,
    count(*) AS total_projetos,
    count(DISTINCT p.client_id) AS total_clientes,
    COALESCE(sum(v.valor_total), (0)::numeric) AS valor_total,
    count(*) FILTER (WHERE ((p.area_do_projeto ->> 'tipo'::text) = 'Residential'::text)) AS projetos_residenciais,
    count(*) FILTER (WHERE ((p.area_do_projeto ->> 'tipo'::text) = 'Corporativo'::text)) AS projetos_corporativos,
    count(*) FILTER (WHERE ((p.area_do_projeto ->> 'tipo'::text) = 'Exposição Comercial'::text)) AS projetos_comerciais,
    count(*) FILTER (WHERE ((p.area_do_projeto ->> 'tipo'::text) = 'Paisagismo'::text)) AS projetos_paisagismo
   FROM (projetos p
     LEFT JOIN LATERAL ( SELECT sum(vendas.valor_total) AS valor_total
           FROM vendas
          WHERE (vendas.projeto_id = p.id)) v ON (true))
  WHERE (p.data_entrada IS NOT NULL)
  GROUP BY (date_trunc('month'::text, (p.data_entrada)::timestamp with time zone))
  ORDER BY (date_trunc('month'::text, (p.data_entrada)::timestamp with time zone)) DESC;
;
-- View: vw_detalhe_produto_estoque
CREATE OR REPLACE VIEW public.vw_detalhe_produto_estoque AS
 SELECT produto_id,
    COALESCE(sum(quantidade), (0)::numeric) AS estoque_total,
    COALESCE(sum((quantidade - COALESCE(quantidade_reservada, (0)::numeric))), (0)::numeric) AS estoque_disponivel,
    COALESCE(sum(COALESCE(quantidade_reservada, (0)::numeric)), (0)::numeric) AS estoque_reservado
   FROM estoque_itens
  GROUP BY produto_id;
;
-- View: vw_entrega_futura_projeto_item
CREATE OR REPLACE VIEW public.vw_entrega_futura_projeto_item AS
 SELECT esp.projeto_item_id,
    pi.produto_id,
    p.nome AS produto,
    p.codigo_produto AS produto_codigo,
    pi.projeto_id,
    pr.codigo AS projeto_codigo,
    pi.orcamento_id,
    o.numero AS orcamento_numero,
    COALESCE(o.cliente_id, pr.cliente_id, pr.client_id) AS cliente_id,
    c.nome AS cliente,
    pi.quantidade AS q_venda,
    esp.q_entrega_futura,
    esp.q_reserva,
    esp.q_transferida_saida,
    esp.atualizado_em
   FROM (((((estoque_saldos_projeto_item esp
     JOIN projeto_itens pi ON ((pi.id = esp.projeto_item_id)))
     LEFT JOIN produtos p ON ((p.id = pi.produto_id)))
     LEFT JOIN projetos pr ON ((pr.id = pi.projeto_id)))
     LEFT JOIN orcamentos o ON ((o.id = pi.orcamento_id)))
     LEFT JOIN contatos c ON ((c.id = COALESCE(o.cliente_id, pr.cliente_id, pr.client_id))))
  WHERE ((esp.status_operacional = 'ativo'::text) AND (esp.q_entrega_futura > (0)::numeric))
  ORDER BY p.nome, esp.atualizado_em;
;
-- View: vw_estoque_liquido
CREATE OR REPLACE VIEW public.vw_estoque_liquido AS
 WITH calc AS (
         SELECT p.id AS produto_id,
            p.nome AS produto,
            p.sku,
            m.nome AS marca,
            p.categoria,
            p.preco_custo,
            p.preco_venda,
            COALESCE(sum(ei.quantidade) FILTER (WHERE (ei.local = 'Estoque'::estoque_local)), (0)::numeric) AS qtd_fisico,
            (COALESCE(sum(ei.quantidade_reservada) FILTER (WHERE (ei.local = 'Estoque'::estoque_local)), (0)::numeric) + COALESCE(sum(ei.quantidade) FILTER (WHERE (ei.local = 'Reservado'::estoque_local)), (0)::numeric)) AS qtd_reservado,
            COALESCE(sum(ei.quantidade) FILTER (WHERE (ei.local = 'Showroom'::estoque_local)), (0)::numeric) AS qtd_showroom,
            COALESCE(sum(ei.quantidade) FILTER (WHERE (ei.local = 'Em trânsito'::estoque_local)), (0)::numeric) AS qtd_em_transito
           FROM ((produtos p
             LEFT JOIN marcas m ON ((m.id = p.marca_id)))
             LEFT JOIN estoque_itens ei ON ((ei.produto_id = p.id)))
          WHERE (p.ativo = true)
          GROUP BY p.id, p.nome, p.sku, m.nome, p.categoria, p.preco_custo, p.preco_venda
        )
 SELECT produto_id,
    produto,
    sku,
    marca,
    categoria,
    preco_custo,
    preco_venda,
    qtd_fisico,
    qtd_reservado,
    qtd_showroom,
    qtd_em_transito,
    GREATEST((0)::numeric, (qtd_fisico - qtd_reservado)) AS qtd_disponivel,
        CASE
            WHEN (GREATEST((0)::numeric, (qtd_fisico - qtd_reservado)) = (0)::numeric) THEN 'critico'::text
            WHEN (GREATEST((0)::numeric, (qtd_fisico - qtd_reservado)) <= (3)::numeric) THEN 'baixo'::text
            ELSE 'normal'::text
        END AS alerta_estoque,
    round((qtd_fisico * preco_venda), 2) AS valor_estoque_total,
    round((qtd_reservado * preco_venda), 2) AS valor_reservado_total
   FROM calc;
;
-- View: vw_estoque_por_marca
CREATE OR REPLACE VIEW public.vw_estoque_por_marca AS
 SELECT m.nome AS marca,
    count(p.id) AS skus_total,
    sum(e.quantidade) FILTER (WHERE (e.local = 'Estoque'::estoque_local)) AS qtd_estoque,
    sum(e.quantidade) FILTER (WHERE (e.local = 'Showroom'::estoque_local)) AS qtd_showroom,
    sum((p.preco_venda * e.quantidade)) AS valor_disponivel_venda
   FROM ((marcas m
     LEFT JOIN produtos p ON ((p.marca_id = m.id)))
     LEFT JOIN estoque_itens e ON ((e.produto_id = p.id)))
  GROUP BY m.id, m.nome;
;
-- View: vw_estoque_por_produto_projeto
CREATE OR REPLACE VIEW public.vw_estoque_por_produto_projeto AS
 SELECT projeto_item_id,
    projeto_id,
    orcamento_id,
    produto_id,
    cliente_id,
    produto,
    produto_codigo,
    projeto_codigo,
    orcamento_numero,
    q_venda,
    q_reserva,
    q_entrega_futura,
    q_ag_separar,
    q_separado,
    q_entregue,
    q_devolvida,
    q_transferida_saida,
    status_operacional,
    atualizado_em
   FROM vw_estoque_saldos_projeto_item
  WHERE (status_operacional = 'ativo'::text);
;
-- View: vw_estoque_produtos
CREATE OR REPLACE VIEW public.vw_estoque_produtos AS
 SELECT p.codigo_legado AS codigo_produto,
    p.referencia,
    p.nome AS descricao,
    m.nome AS marca,
    cp.nome AS categoria,
    p.estoque_total,
    p.estoque_showroom,
    p.estoque_disponivel,
    p.valor_venda,
        CASE
            WHEN (p.estoque_disponivel <= (0)::numeric) THEN 'Sem Estoque'::text
            WHEN (p.estoque_disponivel <= (5)::numeric) THEN 'Estoque Baixo'::text
            ELSE 'OK'::text
        END AS status_estoque
   FROM ((produtos p
     LEFT JOIN marcas m ON ((m.id = p.marca_id)))
     LEFT JOIN categorias_produto cp ON ((cp.id = p.categoria_id)))
  WHERE (p.ativo = true)
  ORDER BY p.nome;
;
-- View: vw_estoque_resumo
CREATE OR REPLACE VIEW public.vw_estoque_resumo AS
 SELECT ei.produto_id,
    p.nome AS produto,
    p.codigo_produto AS produto_codigo,
    ei.quantidade AS qtd_total,
    COALESCE(comprometido.qtd_comprometida, (0)::numeric) AS qtd_comprometida,
    (ei.quantidade - COALESCE(comprometido.qtd_comprometida, (0)::numeric)) AS qtd_disponivel,
    COALESCE(comprometido.qtd_entrega_futura, (0)::numeric) AS qtd_entrega_futura
   FROM ((estoque_itens ei
     JOIN produtos p ON ((p.id = ei.produto_id)))
     LEFT JOIN ( SELECT pi.produto_id,
            sum((((esp.q_reserva + esp.q_entrega_futura) + esp.q_ag_separar) + esp.q_separado)) AS qtd_comprometida,
            sum(esp.q_entrega_futura) AS qtd_entrega_futura
           FROM (estoque_saldos_projeto_item esp
             JOIN projeto_itens pi ON ((pi.id = esp.projeto_item_id)))
          WHERE (esp.status_operacional = 'ativo'::text)
          GROUP BY pi.produto_id) comprometido ON ((comprometido.produto_id = ei.produto_id)))
  WHERE (ei.local = 'Estoque'::estoque_local);
;
-- View: vw_estoque_saldos_projeto_item
CREATE OR REPLACE VIEW public.vw_estoque_saldos_projeto_item AS
 SELECT esp.projeto_item_id,
    pi.projeto_id,
    pi.orcamento_id,
    pi.produto_id,
    COALESCE(o.cliente_id, pr.cliente_id, pr.client_id) AS cliente_id,
    p.nome AS produto,
    p.codigo_produto AS produto_codigo,
    pr.codigo AS projeto_codigo,
    o.numero AS orcamento_numero,
    pi.quantidade AS q_venda,
    esp.q_reserva,
    esp.q_entrega_futura,
    esp.q_ag_separar,
    esp.q_separado,
    esp.q_entregue,
    esp.q_devolvida,
    esp.q_transferida_saida,
    esp.status_operacional,
    esp.atualizado_em
   FROM ((((estoque_saldos_projeto_item esp
     JOIN projeto_itens pi ON ((pi.id = esp.projeto_item_id)))
     LEFT JOIN projetos pr ON ((pr.id = pi.projeto_id)))
     LEFT JOIN orcamentos o ON ((o.id = pi.orcamento_id)))
     LEFT JOIN produtos p ON ((p.id = pi.produto_id)));
;
-- View: vw_financeiro_projetos
CREATE OR REPLACE VIEW public.vw_financeiro_projetos AS
 SELECT p.id,
    p.codigo,
    p.nome,
    p.status,
    p.client_id,
    c.nome AS cliente_nome,
    v.valor_total,
    v.valor_recebido,
    v.valor_pendente,
    v.total_parcelas,
    v.parcelas_pagas,
    v.parcelas_pendentes
   FROM ((projetos p
     LEFT JOIN contatos c ON (((c.id = p.client_id) AND (c.tipo = 'cliente'::contato_tipo))))
     LEFT JOIN LATERAL ( SELECT sum(vendas.valor_total) AS valor_total,
            sum(
                CASE
                    WHEN (vendas.status_pagamento = 'Pago'::status_pagamento) THEN vendas.valor_total
                    ELSE (0)::numeric
                END) AS valor_recebido,
            sum(
                CASE
                    WHEN (vendas.status_pagamento <> 'Pago'::status_pagamento) THEN vendas.valor_total
                    ELSE (0)::numeric
                END) AS valor_pendente,
            count(*) AS total_parcelas,
            count(*) FILTER (WHERE (vendas.status_pagamento = 'Pago'::status_pagamento)) AS parcelas_pagas,
            count(*) FILTER (WHERE (vendas.status_pagamento <> 'Pago'::status_pagamento)) AS parcelas_pendentes
           FROM vendas
          WHERE (vendas.projeto_id = p.id)) v ON (true));
;
-- View: vw_fluxo_caixa_projetado
CREATE OR REPLACE VIEW public.vw_fluxo_caixa_projetado AS
 SELECT date_trunc('month'::text, (data_vencimento)::timestamp with time zone) AS mes,
    sum(valor) FILTER (WHERE (status = 'pendente'::parcela_status)) AS a_receber,
    sum(valor) FILTER (WHERE (status = 'paga'::parcela_status)) AS recebido,
    sum(valor) FILTER (WHERE (status = 'atrasada'::parcela_status)) AS atrasado,
    count(*) FILTER (WHERE (status = 'pendente'::parcela_status)) AS qtd_pendente,
    count(*) FILTER (WHERE (status = 'atrasada'::parcela_status)) AS qtd_atrasado
   FROM projeto_parcelas
  WHERE (data_vencimento IS NOT NULL)
  GROUP BY (date_trunc('month'::text, (data_vencimento)::timestamp with time zone))
  ORDER BY (date_trunc('month'::text, (data_vencimento)::timestamp with time zone));
;
-- View: vw_fornecedores_remessas
CREATE OR REPLACE VIEW public.vw_fornecedores_remessas AS
 SELECT f.id,
    f.nome,
    f.cnpj_cpf,
    f.status,
    e.id AS empresa_id,
    e.nome AS empresa_nome,
    count(r.id) AS total_remessas,
    COALESCE(sum(r.valor), (0)::numeric) AS total_valor_remessas,
    COALESCE(sum(
        CASE
            WHEN (r.status = 'pago'::text) THEN r.valor_pago
            ELSE (0)::numeric
        END), (0)::numeric) AS total_pago
   FROM ((fornecedores f
     LEFT JOIN empresas e ON ((e.id = f.empresa_id)))
     LEFT JOIN remessas r ON ((r.fornecedor_id = f.id)))
  GROUP BY f.id, f.nome, f.cnpj_cpf, f.status, e.id, e.nome;
;
-- View: vw_fornecedores_resumo
CREATE OR REPLACE VIEW public.vw_fornecedores_resumo AS
 SELECT f.id,
    f.nome,
    f.cnpj_cpf,
    f.email,
    f.telefone,
    f.status,
    f.categoria,
    e.id AS empresa_id,
    e.nome AS empresa_nome,
    f.created_at,
    f.updated_at
   FROM (fornecedores f
     LEFT JOIN empresas e ON ((e.id = f.empresa_id)));
;
-- View: vw_funcionarios_completo
CREATE OR REPLACE VIEW public.vw_funcionarios_completo AS
 SELECT fn.id,
    fn.nome,
    fn.cargo,
    fn.ativo,
    fn.data_admissao,
    fn.created_at,
    fd.cpf,
    fd.rg,
    fd.data_nascimento,
    fd.endereco,
    fd.telefone,
    fd.email,
    ff.salario_base,
    ff.salario_por_fora,
    ff.comissao_percentual,
    ff.salario_liquido,
    fb.empresa,
    fb.valor_vt_dia
   FROM (((funcionarios_novo fn
     LEFT JOIN funcionarios_detalhes fd ON ((fd.funcionario_id = fn.id)))
     LEFT JOIN funcionarios_financeiro ff ON ((ff.funcionario_id = fn.id)))
     LEFT JOIN funcionarios_beneficios_empresas fb ON ((fb.funcionario_id = fn.id)));
;
-- View: vw_historico_faltas
CREATE OR REPLACE VIEW public.vw_historico_faltas AS
 SELECT f.id AS funcionario_id,
    f.nome AS funcionario_nome,
    cf.data AS data_falta,
    cf.status,
    cf.justificativa,
    pa.id AS periodo_id,
    pa.data_inicio,
    pa.data_fim
   FROM ((controle_falta cf
     JOIN funcionarios f ON ((cf.funcionario_id = f.id)))
     JOIN periodos_aquisitivos pa ON ((cf.funcionario_id = pa.funcionario_id)))
  WHERE ((cf.data >= pa.data_inicio) AND (cf.data <= pa.data_fim))
  ORDER BY cf.data DESC;
;
-- View: vw_logs_auditoria_recentes
CREATE OR REPLACE VIEW public.vw_logs_auditoria_recentes AS
 SELECT id,
    created_at,
    tabela,
    operacao,
    registro_id,
    usuario_id,
    dados_anteriores,
    dados_novos,
    observacao
   FROM logs_auditoria
  ORDER BY created_at DESC
 LIMIT 1000;
;
-- View: vw_necessidade_compra
CREATE OR REPLACE VIEW public.vw_necessidade_compra AS
 SELECT pi.produto_id,
    p.nome AS produto,
    p.codigo_produto AS produto_codigo,
    COALESCE(ei.quantidade, (0)::numeric) AS qtd_fisica,
    sum((((esp.q_reserva + esp.q_entrega_futura) + esp.q_ag_separar) + esp.q_separado)) AS qtd_comprometida,
    sum(esp.q_entrega_futura) AS necessidade_compra,
    (COALESCE(ei.quantidade, (0)::numeric) - sum((((esp.q_reserva + esp.q_entrega_futura) + esp.q_ag_separar) + esp.q_separado))) AS qtd_disponivel,
    count(DISTINCT pi.projeto_id) FILTER (WHERE (esp.q_entrega_futura > (0)::numeric)) AS projetos_com_entrega_futura
   FROM (((estoque_saldos_projeto_item esp
     JOIN projeto_itens pi ON ((pi.id = esp.projeto_item_id)))
     LEFT JOIN produtos p ON ((p.id = pi.produto_id)))
     LEFT JOIN estoque_itens ei ON (((ei.produto_id = pi.produto_id) AND (ei.local = 'Estoque'::estoque_local))))
  WHERE ((esp.status_operacional = 'ativo'::text) AND (pi.produto_id IS NOT NULL))
  GROUP BY pi.produto_id, p.nome, p.codigo_produto, ei.quantidade
 HAVING (sum(esp.q_entrega_futura) > (0)::numeric)
  ORDER BY (sum(esp.q_entrega_futura)) DESC, p.nome;
;
-- View: vw_orcamentos_aprovacao_financeira_auditoria
CREATE OR REPLACE VIEW public.vw_orcamentos_aprovacao_financeira_auditoria AS
 SELECT o.id AS orcamento_id,
    o.numero,
    o.status,
    o.projeto_id,
    o.cliente_id,
    o.valor_total,
    o.requer_revisao_financeira,
    o.aprovado_cliente_em,
    count(DISTINCT pi.id) AS projeto_itens_por_orcamento,
    count(DISTINCT pp.id) AS parcelas_por_orcamento,
    count(DISTINCT b.id) AS boletos_por_orcamento,
        CASE
            WHEN (o.status = 'Aprovação Financeira'::text) THEN 'fila_financeira'::text
            WHEN (o.status = 'Orçamento Aprovado'::text) THEN 'aprovado_final'::text
            WHEN (o.status = ANY (ARRAY['aprovado_cliente'::text, 'aprovado'::text, 'aprovado_financeiro'::text])) THEN 'legado_revisar'::text
            ELSE 'fora_fluxo_financeiro'::text
        END AS classificacao_fluxo
   FROM (((orcamentos o
     LEFT JOIN projeto_itens pi ON ((pi.orcamento_id = o.id)))
     LEFT JOIN projeto_parcelas pp ON ((pp.orcamento_id = o.id)))
     LEFT JOIN boletos b ON ((b.orcamento_id = o.id)))
  GROUP BY o.id, o.numero, o.status, o.projeto_id, o.cliente_id, o.valor_total, o.requer_revisao_financeira, o.aprovado_cliente_em;
;
-- View: vw_produtos_estoque_detalhado
CREATE OR REPLACE VIEW public.vw_produtos_estoque_detalhado AS
 WITH estoque_calculado AS (
         SELECT estoque_itens.produto_id,
            sum(
                CASE
                    WHEN ((estoque_itens.local)::text ~~* 'estoque%'::text) THEN estoque_itens.quantidade
                    ELSE (0)::numeric
                END) AS qtd_geral,
            sum(
                CASE
                    WHEN ((estoque_itens.local)::text ~~* 'showroom%'::text) THEN estoque_itens.quantidade
                    ELSE (0)::numeric
                END) AS qtd_showroom,
            (sum(
                CASE
                    WHEN (estoque_itens.local = 'Estoque'::estoque_local) THEN COALESCE(estoque_itens.quantidade_reservada, (0)::numeric)
                    ELSE (0)::numeric
                END) + sum(
                CASE
                    WHEN ((estoque_itens.local)::text ~~* 'reserva%'::text) THEN estoque_itens.quantidade
                    ELSE (0)::numeric
                END)) AS qtd_reserva,
            sum(
                CASE
                    WHEN (((estoque_itens.local)::text ~~* 'separacao%'::text) OR ((estoque_itens.local)::text ~~* 'separação%'::text)) THEN estoque_itens.quantidade
                    ELSE (0)::numeric
                END) AS qtd_separacao,
            sum(estoque_itens.quantidade) AS total_fisico
           FROM estoque_itens
          GROUP BY estoque_itens.produto_id
        )
 SELECT p.id,
    p.codigo_produto,
    p.nome,
    p.sku,
    p.preco_venda,
    COALESCE(ec.qtd_geral, (0)::numeric) AS estoque_geral,
    COALESCE(ec.qtd_reserva, (0)::numeric) AS reserva,
    COALESCE(ec.qtd_separacao, (0)::numeric) AS separacao,
    ((COALESCE(ec.qtd_geral, (0)::numeric) - COALESCE(ec.qtd_reserva, (0)::numeric)) - COALESCE(ec.qtd_separacao, (0)::numeric)) AS disponivel
   FROM (produtos p
     LEFT JOIN estoque_calculado ec ON ((p.id = ec.produto_id)));
;
-- View: vw_produtos_estoque_por_local
CREATE OR REPLACE VIEW public.vw_produtos_estoque_por_local AS
 SELECT p.codigo_produto,
    p.nome,
    p.unidade,
    p.preco_venda,
    p.cst,
    p.cest,
    p.porc_bdi,
    p.status_comercial,
    p.mascara_produto,
    e.local AS setor,
    e.quantidade,
    e.quantidade_reservada
   FROM (produtos p
     JOIN estoque_itens e ON ((p.id = e.produto_id)));
;
-- View: vw_projetos_dashboard
CREATE OR REPLACE VIEW public.vw_projetos_dashboard AS
 SELECT p.id,
    p.codigo,
    p.nome,
    p.status,
    p.nivel_estrategico,
    p.data_entrada,
    p.cidade,
    p.estado,
    p.arquivado,
    p.responsavel_id,
    p.responsavel_nome,
    u.email AS responsavel_email,
    p.cliente_id,
    c.nome AS cliente_nome,
    c.tipo AS cliente_tipo,
    p.arquiteto_id,
    a.nome AS arquiteto_nome,
    p.empresa_id,
    e.nome AS empresa_nome,
    e.codigo AS empresa_codigo,
    p.area_do_projeto,
    (p.area_do_projeto ->> 'tipo'::text) AS tipo_projeto,
    p.created_at,
    p.updated_at
   FROM ((((projetos p
     LEFT JOIN usuarios u ON ((p.responsavel_id = u.id)))
     LEFT JOIN contatos c ON ((p.cliente_id = c.id)))
     LEFT JOIN contatos a ON ((p.arquiteto_id = a.id)))
     LEFT JOIN empresas e ON ((p.empresa_id = e.id)))
  WHERE (p.arquivado = false)
  ORDER BY p.created_at DESC;
;
-- View: vw_projetos_pipeline
CREATE OR REPLACE VIEW public.vw_projetos_pipeline AS
 SELECT p.id,
    p.codigo,
    p.nome,
    p.status,
    p.data_entrada,
    (p.area_do_projeto ->> 'tipo'::text) AS tipo_projeto,
    p.client_id,
    c.nome AS cliente_nome,
    COALESCE(v.valor_total, (0)::numeric) AS valor_total
   FROM ((projetos p
     LEFT JOIN contatos c ON (((c.id = p.client_id) AND (c.tipo = 'cliente'::contato_tipo))))
     LEFT JOIN LATERAL ( SELECT sum(vendas.valor_total) AS valor_total
           FROM vendas
          WHERE (vendas.projeto_id = p.id)) v ON (true))
  WHERE ((p.arquivado = false) OR (p.arquivado IS NULL));
;
-- View: vw_projetos_por_responsavel
CREATE OR REPLACE VIEW public.vw_projetos_por_responsavel AS
 SELECT u.id AS usuario_id,
    u.nome AS responsavel,
    count(p.id) AS total_projetos,
    count(
        CASE
            WHEN (p.arquivado = false) THEN 1
            ELSE NULL::integer
        END) AS projetos_ativos,
    count(
        CASE
            WHEN (p.arquivado = true) THEN 1
            ELSE NULL::integer
        END) AS projetos_arquivados
   FROM (usuarios u
     LEFT JOIN projetos p ON ((u.id = p.responsavel_id)))
  GROUP BY u.id, u.nome
 HAVING (count(p.id) > 0)
  ORDER BY (count(p.id)) DESC;
;
-- View: vw_projetos_por_status
CREATE OR REPLACE VIEW public.vw_projetos_por_status AS
 SELECT p.status,
    count(*) AS total_projetos,
    count(DISTINCT p.client_id) AS total_clientes,
    COALESCE(sum(v.valor_total), (0)::numeric) AS valor_total
   FROM (projetos p
     LEFT JOIN LATERAL ( SELECT sum(vendas.valor_total) AS valor_total
           FROM vendas
          WHERE (vendas.projeto_id = p.id)) v ON (true))
  WHERE ((p.arquivado = false) OR (p.arquivado IS NULL))
  GROUP BY p.status
  ORDER BY (count(*)) DESC;
;
-- View: vw_projetos_resumo
CREATE OR REPLACE VIEW public.vw_projetos_resumo AS
 SELECT p.id,
    p.codigo,
    p.status,
    count(DISTINCT v.id) AS total_vendas,
    COALESCE(sum(v.valor_total), (0)::numeric) AS valor_total_vendas,
    COALESCE(sum(v.valor_pago), (0)::numeric) AS valor_pago,
    COALESCE((sum(v.valor_total) - sum(v.valor_pago)), (0)::numeric) AS valor_pendente
   FROM (projetos p
     LEFT JOIN vendas v ON ((v.projeto_id = p.id)))
  GROUP BY p.id, p.codigo, p.status;
;
-- View: vw_projetos_sem_empresa
CREATE OR REPLACE VIEW public.vw_projetos_sem_empresa AS
 SELECT id,
    codigo,
    nome,
    status,
    responsavel_nome,
    data_entrada,
    created_at
   FROM projetos
  WHERE ((empresa_id IS NULL) AND (arquivado = false))
  ORDER BY created_at DESC;
;
-- View: vw_projetos_sem_responsavel
CREATE OR REPLACE VIEW public.vw_projetos_sem_responsavel AS
 SELECT id,
    codigo,
    nome,
    status,
    data_entrada,
    created_at,
    cliente_id,
    arquiteto_id
   FROM projetos
  WHERE ((responsavel_id IS NULL) AND (arquivado = false))
  ORDER BY created_at DESC;
;
-- View: vw_projetos_status_enum
CREATE OR REPLACE VIEW public.vw_projetos_status_enum AS
 SELECT DISTINCT status,
    count(*) AS total
   FROM projetos
  GROUP BY status
  ORDER BY (count(*)) DESC;
;
-- View: vw_remessas_completa
CREATE OR REPLACE VIEW public.vw_remessas_completa AS
 SELECT r.id,
    r.descricao,
    r.valor,
    r.vencimento,
    r.status,
    r.nosso_numero,
    r.linha_digitavel,
    r.data_pagamento,
    r.valor_pago,
    r.observacoes,
    f.id AS fornecedor_id,
    f.nome AS fornecedor_nome,
    f.cnpj_cpf AS fornecedor_cnpj_cpf,
    e.id AS empresa_id,
    e.nome AS empresa_nome,
    r.created_at,
    r.updated_at
   FROM ((remessas r
     LEFT JOIN fornecedores f ON ((f.id = r.fornecedor_id)))
     LEFT JOIN empresas e ON ((e.id = r.empresa_id)));
;
-- View: vw_remessas_resumo_status
CREATE OR REPLACE VIEW public.vw_remessas_resumo_status AS
 SELECT e.id AS empresa_id,
    e.nome AS empresa_nome,
    r.status,
    count(*) AS quantidade,
    COALESCE(sum(r.valor), (0)::numeric) AS valor_total,
    COALESCE(sum(r.valor_pago), (0)::numeric) AS valor_pago_total
   FROM (remessas r
     LEFT JOIN empresas e ON ((e.id = r.empresa_id)))
  GROUP BY e.id, e.nome, r.status;
;
-- View: vw_remessas_vencimento
CREATE OR REPLACE VIEW public.vw_remessas_vencimento AS
 SELECT r.id,
    r.created_at,
    r.updated_at,
    r.empresa_id,
    r.fornecedor_id,
    r.descricao,
    r.valor,
    r.vencimento,
    r.status,
    r.linha_digitavel,
    r.codigo_barras,
    r.nosso_numero,
    r.arquivo_remessa,
    r.arquivo_retorno,
    r.data_pagamento,
    r.valor_pago,
    r.observacoes,
    r.user_id,
    f.nome AS fornecedor_nome,
    e.nome AS empresa_nome,
        CASE
            WHEN (r.vencimento < CURRENT_DATE) THEN 'vencida'::text
            WHEN ((r.vencimento >= CURRENT_DATE) AND (r.vencimento <= (CURRENT_DATE + '7 days'::interval))) THEN 'a_vencer_7_dias'::text
            ELSE 'em_dia'::text
        END AS situacao_vencimento
   FROM ((remessas r
     LEFT JOIN fornecedores f ON ((f.id = r.fornecedor_id)))
     LEFT JOIN empresas e ON ((e.id = r.empresa_id)))
  WHERE (r.status <> ALL (ARRAY['pago'::text, 'cancelado'::text]));
;
-- View: vw_separacoes_agenda
CREATE OR REPLACE VIEW public.vw_separacoes_agenda AS
 SELECT s.id AS separacao_id,
    s.status AS separacao_status,
    s.data_entrega,
    s.data_entrega_original,
    s.reagendamentos,
    s.codigo_obra,
    s.cliente,
    s.endereco_entrega,
    s.delivery_type,
    s.scheduled_time,
    s.observacoes,
    pr.id AS projeto_id,
    pr.codigo AS projeto_codigo,
    pr.nome AS projeto_nome,
    pr.status AS projeto_status,
    c.nome AS cliente_nome,
    e.id AS entrega_id,
    e.status AS entrega_status,
    e.entregador_id,
    u.nome AS entregador_nome,
    count(si.id) AS total_itens,
    count(si.id) FILTER (WHERE (si.separado = true)) AS itens_separados,
    (s.data_entrega - CURRENT_DATE) AS dias_ate_entrega,
        CASE
            WHEN ((s.data_entrega < CURRENT_DATE) AND (s.status <> ALL (ARRAY['Enviado'::separacao_status, 'Cancelado'::separacao_status]))) THEN 'atrasado'::text
            WHEN ((s.data_entrega = CURRENT_DATE) AND (s.status <> ALL (ARRAY['Enviado'::separacao_status, 'Cancelado'::separacao_status]))) THEN 'hoje'::text
            WHEN ((s.data_entrega >= (CURRENT_DATE + 1)) AND (s.data_entrega <= (CURRENT_DATE + 3)) AND (s.status <> ALL (ARRAY['Enviado'::separacao_status, 'Cancelado'::separacao_status]))) THEN 'urgente'::text
            ELSE 'normal'::text
        END AS urgencia,
    s.created_at,
    s.updated_at
   FROM (((((separacoes s
     LEFT JOIN projetos pr ON ((pr.id = s.projeto_id)))
     LEFT JOIN contatos c ON ((c.id = pr.cliente_id)))
     LEFT JOIN entregas e ON (((e.separacao_id = s.id) AND (e.status <> 'Cancelado'::entrega_status))))
     LEFT JOIN usuarios u ON ((u.id = e.entregador_id)))
     LEFT JOIN separacao_itens si ON ((si.separacao_id = s.id)))
  WHERE (s.status <> 'Cancelado'::separacao_status)
  GROUP BY s.id, s.status, s.data_entrega, s.data_entrega_original, s.reagendamentos, s.codigo_obra, s.cliente, s.endereco_entrega, s.delivery_type, s.scheduled_time, s.observacoes, s.created_at, s.updated_at, pr.id, pr.codigo, pr.nome, pr.status, c.nome, e.id, e.status, e.entregador_id, u.nome
  ORDER BY
        CASE
            WHEN ((s.data_entrega < CURRENT_DATE) AND (s.status <> ALL (ARRAY['Enviado'::separacao_status, 'Cancelado'::separacao_status]))) THEN 0
            ELSE 1
        END, s.data_entrega;
;
-- View: vw_staging_resumo
CREATE OR REPLACE VIEW public.vw_staging_resumo AS
 SELECT 'conta_pagar'::text AS tabela,
    count(*) AS total,
    count(*) FILTER (WHERE (staging_conta_pagar.processado = true)) AS processados,
    count(*) FILTER (WHERE (staging_conta_pagar.processado = false)) AS pendentes,
    min(staging_conta_pagar.importado_em) AS primeira_importacao,
    max(staging_conta_pagar.importado_em) AS ultima_importacao
   FROM staging_conta_pagar
UNION ALL
 SELECT 'conta_receber'::text AS tabela,
    count(*) AS total,
    count(*) FILTER (WHERE (staging_conta_receber.processado = true)) AS processados,
    count(*) FILTER (WHERE (staging_conta_receber.processado = false)) AS pendentes,
    min(staging_conta_receber.importado_em) AS primeira_importacao,
    max(staging_conta_receber.importado_em) AS ultima_importacao
   FROM staging_conta_receber
UNION ALL
 SELECT 'produtos'::text AS tabela,
    count(*) AS total,
    count(*) FILTER (WHERE (staging_produtos.processado = true)) AS processados,
    count(*) FILTER (WHERE (staging_produtos.processado = false)) AS pendentes,
    min(staging_produtos.importado_em) AS primeira_importacao,
    max(staging_produtos.importado_em) AS ultima_importacao
   FROM staging_produtos
UNION ALL
 SELECT 'pedido_compra'::text AS tabela,
    count(*) AS total,
    count(*) FILTER (WHERE (staging_pedido_compra.processado = true)) AS processados,
    count(*) FILTER (WHERE (staging_pedido_compra.processado = false)) AS pendentes,
    min(staging_pedido_compra.importado_em) AS primeira_importacao,
    max(staging_pedido_compra.importado_em) AS ultima_importacao
   FROM staging_pedido_compra;
;
-- View: vw_transacoes_completas
CREATE OR REPLACE VIEW public.vw_transacoes_completas AS
 SELECT t.id,
    t.negociacao_id,
    n.cod_duplicata,
    t.cod_itens_duplicata,
    t.tipo,
    n.dev_troca,
    t.num_parc,
    n.total_parc,
    t.dt_emissao,
    t.dt_vencimento,
    t.dt_pagamento,
    t.data_transacao,
    COALESCE(t.vl_parcela, t.valor) AS valor,
    t.vl_parcela,
    t.vl_desconto,
    t.vl_juros,
    t.vl_pago,
    t.vl_frete,
    t.vl_ipi,
    t.status_pago,
    t.tipo_pagamento,
    t.acordo,
    e.id AS empresa_id,
    e.nome AS empresa_nome,
    c.id AS contato_id,
    c.nome AS contato_nome,
    c.tipo AS contato_tipo,
    f.id AS funcionario_id,
    f.nome AS funcionario_nome,
    aprop.id AS plano_contas_id,
    aprop.nome AS plano_apropriacao,
    sg.nome AS plano_sub_grupo,
    gr.nome AS plano_grupo,
    cb.id AS conta_bancaria_id,
    cb.nome AS conta_bancaria_nome,
    pj.id AS projeto_id,
    pj.codigo AS projeto_codigo,
    pj.nome AS projeto_nome,
    n.cod_venda,
    pp.id AS parcela_crm_id,
    pp.numero_parcela AS parcela_crm_numero,
    t.descricao,
    t.comprovante_url,
    t.created_by
   FROM ((((((((((transacoes t
     LEFT JOIN negociacoes n ON ((n.id = t.negociacao_id)))
     LEFT JOIN empresas e ON ((e.id = n.empresa_id)))
     LEFT JOIN contatos c ON ((c.id = n.contato_id)))
     LEFT JOIN funcionarios f ON ((f.id = n.funcionario_id)))
     LEFT JOIN plano_de_contas aprop ON ((aprop.id = n.plano_contas_id)))
     LEFT JOIN plano_de_contas sg ON ((sg.id = aprop.parent_id)))
     LEFT JOIN plano_de_contas gr ON ((gr.id = sg.parent_id)))
     LEFT JOIN contas_bancarias cb ON ((cb.id = t.conta_id)))
     LEFT JOIN projetos pj ON ((pj.id = COALESCE(n.projeto_id, t.projeto_id))))
     LEFT JOIN projeto_parcelas pp ON ((pp.transacao_id = t.id)));
;
-- View: vw_transferencias_estoque
CREATE OR REPLACE VIEW public.vw_transferencias_estoque AS
 SELECT t.id AS transferencia_id,
    t.status,
    pi_o.produto_id,
    p.nome AS produto,
    p.codigo_produto AS produto_codigo,
    t.quantidade,
    t.origem_projeto_item_id,
    pr_o.codigo AS origem_projeto_codigo,
    o_o.numero AS origem_orcamento_numero,
    c_o.nome AS origem_cliente,
    t.destino_projeto_item_id,
    pr_d.codigo AS destino_projeto_codigo,
    o_d.numero AS destino_orcamento_numero,
    c_d.nome AS destino_cliente,
    t.motivo,
    t.solicitado_por,
    t.aprovado_por,
    t.solicitado_em,
    t.aprovado_em,
    t.cancelado_em,
    t.motivo_cancelamento
   FROM (((((((((transferencias_estoque t
     JOIN projeto_itens pi_o ON ((pi_o.id = t.origem_projeto_item_id)))
     JOIN projeto_itens pi_d ON ((pi_d.id = t.destino_projeto_item_id)))
     LEFT JOIN produtos p ON ((p.id = pi_o.produto_id)))
     LEFT JOIN projetos pr_o ON ((pr_o.id = pi_o.projeto_id)))
     LEFT JOIN orcamentos o_o ON ((o_o.id = pi_o.orcamento_id)))
     LEFT JOIN contatos c_o ON ((c_o.id = COALESCE(o_o.cliente_id, pr_o.cliente_id, pr_o.client_id))))
     LEFT JOIN projetos pr_d ON ((pr_d.id = pi_d.projeto_id)))
     LEFT JOIN orcamentos o_d ON ((o_d.id = pi_d.orcamento_id)))
     LEFT JOIN contatos c_d ON ((c_d.id = COALESCE(o_d.cliente_id, pr_d.cliente_id, pr_d.client_id))))
  ORDER BY t.solicitado_em DESC;
;
-- View: vw_vendas_loja
CREATE OR REPLACE VIEW public.vw_vendas_loja AS
 SELECT p.id AS produto_id,
    p.nome AS produto,
    p.sku,
    m.nome AS marca,
    p.categoria,
    si.quantidade,
    p.preco_custo,
    p.preco_venda,
    round(((p.preco_venda - p.preco_custo) * si.quantidade), 2) AS margem_total,
    s.id AS separacao_id,
    s.created_at AS data_venda,
    s.cliente,
    s.observacoes
   FROM (((separacao_itens si
     JOIN produtos p ON ((p.id = si.produto_id)))
     JOIN separacoes s ON ((s.id = si.separacao_id)))
     LEFT JOIN marcas m ON ((m.id = p.marca_id)))
  WHERE ((si.produto_id IS NOT NULL) AND (s.projeto_id IS NULL));
;
-- View: vw_vendas_por_projeto
CREATE OR REPLACE VIEW public.vw_vendas_por_projeto AS
 SELECT p.id AS produto_id,
    p.nome AS produto,
    p.sku,
    m.nome AS marca,
    p.categoria,
    si.quantidade,
    p.preco_custo,
    p.preco_venda,
    round(((p.preco_venda - p.preco_custo) * si.quantidade), 2) AS margem_total,
    s.id AS separacao_id,
    s.created_at AS data_separacao,
    pr.id AS projeto_id,
    pr.codigo AS projeto_codigo,
    pr.nome AS projeto_nome,
    pr.status AS projeto_status,
    cli.nome AS cliente,
    pr.cidade AS projeto_cidade,
    pr.estado AS projeto_estado
   FROM (((((separacao_itens si
     JOIN produtos p ON ((p.id = si.produto_id)))
     JOIN separacoes s ON ((s.id = si.separacao_id)))
     JOIN projetos pr ON ((pr.id = s.projeto_id)))
     LEFT JOIN marcas m ON ((m.id = p.marca_id)))
     LEFT JOIN contatos cli ON ((cli.id = pr.cliente_id)))
  WHERE ((si.produto_id IS NOT NULL) AND (s.projeto_id IS NOT NULL));
;
-- View: vw_vendas_produtos
CREATE OR REPLACE VIEW public.vw_vendas_produtos AS
 SELECT 'projeto'::text AS origem,
    p.id AS produto_id,
    p.nome AS produto,
    p.sku,
    m.nome AS marca,
    p.categoria,
    si.quantidade,
    p.preco_custo,
    p.preco_venda,
    round(((p.preco_venda - p.preco_custo) * si.quantidade), 2) AS margem_total,
    s.created_at AS data_venda,
    pr.codigo AS projeto_codigo,
    pr.nome AS projeto_nome,
    COALESCE(cli.nome, s.cliente) AS cliente
   FROM (((((separacao_itens si
     JOIN produtos p ON ((p.id = si.produto_id)))
     JOIN separacoes s ON ((s.id = si.separacao_id)))
     JOIN projetos pr ON ((pr.id = s.projeto_id)))
     LEFT JOIN marcas m ON ((m.id = p.marca_id)))
     LEFT JOIN contatos cli ON ((cli.id = pr.cliente_id)))
  WHERE ((si.produto_id IS NOT NULL) AND (s.projeto_id IS NOT NULL))
UNION ALL
 SELECT 'loja'::text AS origem,
    p.id AS produto_id,
    p.nome AS produto,
    p.sku,
    m.nome AS marca,
    p.categoria,
    si.quantidade,
    p.preco_custo,
    p.preco_venda,
    round(((p.preco_venda - p.preco_custo) * si.quantidade), 2) AS margem_total,
    s.created_at AS data_venda,
    NULL::character varying AS projeto_codigo,
    NULL::text AS projeto_nome,
    s.cliente
   FROM (((separacao_itens si
     JOIN produtos p ON ((p.id = si.produto_id)))
     JOIN separacoes s ON ((s.id = si.separacao_id)))
     LEFT JOIN marcas m ON ((m.id = p.marca_id)))
  WHERE ((si.produto_id IS NOT NULL) AND (s.projeto_id IS NULL));
;
