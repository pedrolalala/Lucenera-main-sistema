import streamlit as st
import pandas as pd
import plotly.express as px
from config import fetch_view, fetch_all, LUCENERA_VERDE

st.set_page_config(page_title="Projetos — Lucenera", layout="wide")
st.title("Projetos")

@st.cache_data(ttl=300)
def load():
    dashboard = fetch_view("vw_projetos_dashboard")
    por_status = fetch_view("vw_projetos_por_status")
    financeiro = fetch_view("vw_financeiro_projetos")
    return dashboard, por_status, financeiro


try:
    df, por_status_df, fin_df = load()

    # ── filtros ────────────────────────────────────────────────────────────────
    st.sidebar.header("Filtros — Projetos")
    if "status" in df.columns:
        statuses = ["Todos"] + sorted(df["status"].dropna().unique().tolist())
        sel_status = st.sidebar.selectbox("Status", statuses)
        if sel_status != "Todos":
            df = df[df["status"] == sel_status]

    if "responsavel_nome" in df.columns:
        resps = ["Todos"] + sorted(df["responsavel_nome"].dropna().unique().tolist())
        sel_resp = st.sidebar.selectbox("Responsável", resps)
        if sel_resp != "Todos":
            df = df[df["responsavel_nome"] == sel_resp]

    if "tipo_projeto" in df.columns:
        tipos = ["Todos"] + sorted(df["tipo_projeto"].dropna().unique().tolist())
        sel_tipo = st.sidebar.selectbox("Tipo", tipos)
        if sel_tipo != "Todos":
            df = df[df["tipo_projeto"] == sel_tipo]

    # ── KPIs ───────────────────────────────────────────────────────────────────
    k1, k2, k3, k4 = st.columns(4)
    k1.metric("Total projetos (filtrado)", len(df))
    valor_col = next((c for c in ["valor_total", "valor_orcamento", "valor"] if c in df.columns), None)
    if valor_col:
        k2.metric("Valor total", f"R$ {df[valor_col].sum():,.2f}")
        k3.metric("Ticket médio", f"R$ {df[valor_col].mean():,.2f}")
    if "data_entrada" in df.columns:
        df["data_entrada"] = pd.to_datetime(df["data_entrada"], errors="coerce")
        recentes = df[df["data_entrada"] >= pd.Timestamp.now() - pd.DateOffset(months=1)]
        k4.metric("Novos (último mês)", len(recentes))

    st.divider()

    # ── gráficos ───────────────────────────────────────────────────────────────
    col_a, col_b = st.columns(2)

    with col_a:
        st.subheader("Por Status")
        if not por_status_df.empty and "status" in por_status_df.columns and "total" in por_status_df.columns:
            fig = px.bar(
                por_status_df.sort_values("total", ascending=False),
                x="total", y="status", orientation="h",
                color_discrete_sequence=[LUCENERA_VERDE],
                text="total",
            )
            fig.update_layout(margin=dict(t=10, b=10, l=0, r=0), yaxis_title="")
            st.plotly_chart(fig, use_container_width=True)

    with col_b:
        st.subheader("Por Responsável")
        if "responsavel_nome" in df.columns and valor_col:
            resp_group = (
                df.groupby("responsavel_nome", dropna=False)[valor_col]
                .sum()
                .reset_index()
                .sort_values(valor_col, ascending=False)
                .head(10)
            )
            fig2 = px.bar(
                resp_group,
                x=valor_col, y="responsavel_nome", orientation="h",
                color_discrete_sequence=["#1565C0"],
                text_auto=".2s",
            )
            fig2.update_layout(margin=dict(t=10, b=10, l=0, r=0), yaxis_title="")
            st.plotly_chart(fig2, use_container_width=True)

    # ── evolução mensal ────────────────────────────────────────────────────────
    if "data_entrada" in df.columns and valor_col:
        st.subheader("Evolução Mensal — Valor de Projetos")
        df_mes = df.dropna(subset=["data_entrada"]).copy()
        df_mes["mes"] = df_mes["data_entrada"].dt.to_period("M").astype(str)
        mensal = df_mes.groupby("mes")[valor_col].sum().reset_index().sort_values("mes")
        fig3 = px.bar(mensal, x="mes", y=valor_col, color_discrete_sequence=[LUCENERA_VERDE])
        fig3.update_layout(xaxis_title="Mês", yaxis_title="Valor (R$)", margin=dict(t=10))
        st.plotly_chart(fig3, use_container_width=True)

    # ── tabela detalhada ───────────────────────────────────────────────────────
    st.subheader("Lista de Projetos")
    priority_cols = ["codigo", "nome", "status", "responsavel_nome", "tipo_projeto", valor_col, "data_entrada"]
    cols_show = [c for c in priority_cols if c and c in df.columns]
    remaining = [c for c in df.columns if c not in cols_show]
    st.dataframe(df[cols_show + remaining], use_container_width=True, hide_index=True)

    with st.expander("Financeiro por Projeto"):
        if not fin_df.empty:
            st.dataframe(fin_df, use_container_width=True, hide_index=True)

except RuntimeError as e:
    st.error(str(e))
except Exception as e:
    st.error(f"Erro: {e}")
