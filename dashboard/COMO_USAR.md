# Dashboard Admin — Lucenera

## Instalação

```bash
cd dashboard
pip install -r requirements.txt
```

## Configuração

1. Copie `.env.example` para `.env`
2. Preencha com os dados do seu projeto Supabase:

```
SUPABASE_URL=https://SEU-PROJETO.supabase.co
SUPABASE_SERVICE_KEY=sua-service-role-key
```

> Use a **service role key** (não a anon key) para ter acesso completo às views.

## Execução

```bash
cd dashboard
streamlit run app.py
```

O dashboard abre em `http://localhost:8501`.

## Páginas

| Página | Conteúdo |
|--------|----------|
| **Home** | KPIs gerais: projetos, estoque crítico, entregas do dia, boletos pendentes |
| **Projetos** | Status, responsável, tipo, evolução mensal, valor total |
| **Financeiro** | Fluxo de caixa, boletos, parcelas, contas a pagar, transações |
| **Estoque** | Alertas (crítico/baixo), por marca, detalhado por local |
| **Logística** | Agenda de separações, urgência, evolução por data |
| **CRM & Arquitetos** | Rankings arquitetos, pipeline, fechamentos mensais |
| **RH & Comissões** | Comissão mensal por funcionário e equipe, férias |

## Views utilizadas

- `vw_projetos_dashboard`, `vw_projetos_por_status`, `vw_financeiro_projetos`
- `vw_fluxo_caixa_projetado`, `v_cash_flow_lucenera`, `vw_transacoes_completas`
- `vw_remessas_vencimento`, `boletos`, `projeto_parcelas`
- `vw_estoque_liquido`, `vw_produtos_estoque_detalhado`, `vw_estoque_por_marca`
- `vw_separacoes_agenda`
- `vw_dashboard_crm_fechamento`, `vw_projetos_pipeline`
- `vw_comissao_mensal`, `vw_funcionarios_completo`
