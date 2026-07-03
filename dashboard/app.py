import streamlit as st
import pandas as pd
import plotly.express as px
from config import fetch_all, fetch_view, LUCENERA_VERDE

st.set_page_config(
    page_title="Lucenera — Admin",
    page_icon="🏢",
    layout="wide",
    initial_sidebar_state="expanded",
)

st.markdown(
    f"""
    <style>
    .metric-card {{
        background: #fff;
        border-left: 4px solid {LUCENERA_VERDE};
        padding: 1rem 1.25rem;
        border-radius: 6px;
        box-shadow: 0 1px 4px rgba(0,0,0,.08);
    }}
    .metric-label {{ font-size: .8rem; color: #666; margin-bottom: .25rem; }}
    .metric-value {{ font-size: 1.6rem; font-weight: 700; color: #1a1a1a; }}
    .metric-delta {{ font-size: .75rem; color: {LUCENERA_VERDE}; }}
    </style>
    """,
    unsafe_allow_html=True,
)

# ── cabeçalho ──────────────────────────────────────────────────────────────────
col_logo, col_title = st.columns([1, 5])
with col_logo:
    st.markdown(f"<h1 style='color:{LUCENERA_VERDE};margin:0'>L</h1>", unsafe_allow_html=True)
with col_title:
    st.title("Lucenera — Painel Administrativo")
    st.caption("Visão geral em tempo real • dados via Supabase")

st.divider()

# ── KPIs principais ────────────────────────────────────────────────────────────
@st.cache_data(ttl=300)
def load_kpis():
    projetos = fetch_view("vw_projetos_por_status")
    estoque  = fetch_view("vw_estoque_liquido")
    agenda   = fetch_view("vw_separacoes_agenda")
    boletos  = fetch_all("boletos", "id,status,valor,vencimento,data_pagamento")
    return projetos, estoque, agenda, boletos


try:
    projetos_df, estoque_df, agenda_df, boletos_df = load_kpis()

    total_projetos = int(projetos_df["total"].sum()) if "total" in projetos_df.columns else len(projetos_df)
    criticos = int((estoque_df["alerta_estoque"] == "critico").sum()) if "alerta_estoque" in estoque_df.columns else 0
    baixos   = int((estoque_df["alerta_estoque"] == "baixo").sum())   if "alerta_estoque" in estoque_df.columns else 0
    entregas_hoje = int((agenda_df["urgencia"] == "hoje").sum())       if "urgencia" in agenda_df.columns else len(agenda_df)
    boletos_pend  = int((boletos_df["status"].isin(["Pendente", "pendente_registro", "Em Aberto"])).sum()) if "status" in boletos_df.columns else 0
    valor_pend    = boletos_df.loc[boletos_df["status"].isin(["Pendente", "pendente_registro", "Em Aberto"]), "valor"].sum() if "valor" in boletos_df.columns else 0

    k1, k2, k3, k4, k5 = st.columns(5)
    k1.metric("Projetos cadastrados", f"{total_projetos:,}")
    k2.metric("Estoque crítico", f"{criticos} produtos", delta=f"{baixos} baixos", delta_color="inverse")
    k3.metric("Entregas hoje", f"{entregas_hoje}")
    k4.metric("Boletos pendentes", f"{boletos_pend}")
    k5.metric("Valor a receber (pend.)", f"R$ {valor_pend:,.2f}")

    st.divider()

    # ── gráficos resumo ────────────────────────────────────────────────────────
    col_a, col_b = st.columns(2)

    with col_a:
        st.subheader("Projetos por Status")
        if not projetos_df.empty and "status" in projetos_df.columns and "total" in projetos_df.columns:
            fig = px.pie(
                projetos_df,
                names="status",
                values="total",
                color_discrete_sequence=px.colors.qualitative.Safe,
                hole=0.45,
            )
            fig.update_layout(margin=dict(t=20, b=20, l=0, r=0), showlegend=True)
            st.plotly_chart(fig, use_container_width=True)
        else:
            st.info("Sem dados de projetos por status.")

    with col_b:
        st.subheader("Alertas de Estoque")
        if not estoque_df.empty and "alerta_estoque" in estoque_df.columns:
            alerta_counts = estoque_df["alerta_estoque"].value_counts().reset_index()
            alerta_counts.columns = ["alerta", "qtd"]
            color_map = {"critico": "#d32f2f", "baixo": "#f57c00", "normal": "#388e3c", "sem_estoque": "#757575"}
            fig2 = px.bar(
                alerta_counts,
                x="alerta",
                y="qtd",
                color="alerta",
                color_discrete_map=color_map,
                text="qtd",
            )
            fig2.update_layout(margin=dict(t=20, b=20, l=0, r=0), showlegend=False)
            st.plotly_chart(fig2, use_container_width=True)
        else:
            st.info("Sem dados de alerta de estoque.")

    # ── separações próximas ────────────────────────────────────────────────────
    st.subheader("Separações / Entregas Urgentes")
    if not agenda_df.empty:
        urgentes = agenda_df[agenda_df.get("urgencia", pd.Series()).isin(["hoje", "amanha"])] if "urgencia" in agenda_df.columns else agenda_df.head(20)
        cols_show = [c for c in ["cliente_nome", "data_entrega", "status_separacao", "urgencia", "responsavel_nome"] if c in urgentes.columns]
        st.dataframe(urgentes[cols_show].head(30), use_container_width=True, hide_index=True)
    else:
        st.info("Nenhuma separação agendada encontrada.")

except RuntimeError as e:
    st.error(str(e))
    st.info("Crie o arquivo `.env` na pasta `dashboard/` com `SUPABASE_URL` e `SUPABASE_SERVICE_KEY`.")
except Exception as e:
    st.error(f"Erro ao carregar dados: {e}")
    st.info("Verifique a conexão com o Supabase e as permissões do service key.")
