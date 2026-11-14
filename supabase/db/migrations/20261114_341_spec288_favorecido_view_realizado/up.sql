-- SPEC-288 — v_financeiro_realizado_novo ganha a coluna `favorecido` (nome do contato do título:
-- fornecedor, agência, funcionário…), no FIM da lista de colunas. Serve à janela de detalhe dos
-- custos do Dashboard Financeiro (categoria → apropriação → favorecido).
-- O resto da view é IGUAL ao que está no ar em 14/11/2026 (pg_get_viewdef), mesmas colunas, mesma
-- ordem, mesmos portões (pode_acessar_sistema('dashboard-financeiro') e pode_ver_distribuicao_lucro()).
-- Nomes de funcionários aparecem (decisão do Filippo, 14/11: "sì, anche i nomi").

begin;

create or replace view public.v_financeiro_realizado_novo as
select id, tipo, descricao, desc_sub_grupo, desc_grupo, natureza, status_pago, dt_pagamento,
       dt_vencimento, dt_emissao, vl_pago, vl_parcela, vl_desconto, empresa_id, cod_duplicata,
       tipo_custo, perfil, previsao, favorecido
from (
  select x.id, x.tipo, x.descricao, x.desc_sub_grupo, x.desc_grupo, x.natureza, x.status_pago,
         x.dt_pagamento, x.dt_vencimento, x.dt_emissao, x.vl_pago, x.vl_parcela, x.vl_desconto,
         x.empresa_id, x.cod_duplicata, x.tipo_custo, x.perfil, x.previsao, x.favorecido
  from (
    with hierarquia as (
      select p3.id as plano_contas_id,
             coalesce(p2.nome, p3.nome) as desc_sub_grupo,
             coalesce(p1.nome, p2.nome, p3.nome) as desc_grupo
      from plano_de_contas p3
      left join plano_de_contas p2 on p2.id = p3.parent_id
      left join plano_de_contas p1 on p1.id = p2.parent_id
    )
    select coalesce(l.id_antigo, p.id) as id,
           (case when t.natureza = 'receber'::fin_natureza then 'receita'::text
                 else 'despesa'::text end)::transacao_tipo as tipo,
           p.descricao,
           h.desc_sub_grupo,
           h.desc_grupo,
           case
             when t.natureza = 'pagar'::fin_natureza
                  and (h.desc_sub_grupo ilike '%FILIPPO%' or h.desc_sub_grupo ilike '%MANOELLA%'
                       or p.descricao ilike '%RETIRADA LUCRO%' or p.descricao ilike '%RETIRADA DE LUCRO%'
                       or p.descricao ilike '%LUCRO DISTRIB%')
               then 'distribuicao_lucro'::text
             when t.natureza = 'pagar'::fin_natureza then 'despesa_operacional'::text
             else null::text
           end as natureza,
           (case when b.n_baixas > 0 and p.valor_liquidado >= p.valor then 1 else 0 end)::smallint as status_pago,
           case when b.n_baixas > 0 and p.valor_liquidado >= p.valor then b.ultima_data else null::date end as dt_pagamento,
           p.vencimento as dt_vencimento,
           p.emissao as dt_emissao,
           case when b.n_baixas > 0 and p.valor_liquidado >= p.valor then b.dinheiro else 0::numeric end as vl_pago,
           p.valor as vl_parcela,
           p.desconto as vl_desconto,
           t.empresa_id,
           t.legado_cod_duplicata as cod_duplicata,
           case
             when t.natureza <> 'pagar'::fin_natureza then null::text
             when h.desc_sub_grupo = any (array['FIXAS', 'COM PESSOAL', 'ADMINISTRATIVAS', 'BANCARIAS', 'VEICULOS']) then 'fixo'::text
             when h.desc_sub_grupo = any (array['COM VENDAS', 'PRODUTOS']) then 'variavel'::text
             else 'outro'::text
           end as tipo_custo,
           t.perfil,
           (p.situacao = 'prevista'::fin_situacao and not (b.n_baixas > 0 and p.valor_liquidado >= p.valor)) as previsao,
           c.nome as favorecido
    from financeiro_parcelas p
    join financeiro_titulos t on t.id = p.titulo_id
    left join contatos c on c.id = t.contato_id
    left join financeiro_legado_ids l on l.id_novo = p.id and l.tabela_antiga = 'transacoes'
    left join hierarquia h on h.plano_contas_id = t.plano_contas_id
    left join lateral (
      select count(*) filter (where bx.tipo <> 'estorno'::fin_baixa_tipo) as n_baixas,
             max(bx.data) filter (where bx.tipo <> 'estorno'::fin_baixa_tipo) as ultima_data,
             coalesce(sum(case
                            when bx.movimenta_caixa then bx.valor + bx.juros
                            when bx.tipo = 'estorno'::fin_baixa_tipo and o.movimenta_caixa then -(o.valor + o.juros)
                            else 0::numeric
                          end), 0::numeric) as dinheiro,
             coalesce(sum(case when bx.movimenta_caixa then bx.desconto else 0::numeric end), 0::numeric) as desconto
      from financeiro_baixas bx
      left join financeiro_baixas o on o.id = bx.estorno_de
      where bx.parcela_id = p.id
    ) b on true
    where p.situacao = any (array['prevista'::fin_situacao, 'firme'::fin_situacao])
      and t.cancelado_em is null
  ) x
  where x.natureza is distinct from 'distribuicao_lucro' or (select pode_ver_distribuicao_lucro())
) y
where (select pode_acessar_sistema('dashboard-financeiro'));

commit;
