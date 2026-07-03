import streamlit as st
import pandas as pd
import plotly.express as px
from config import fetch_view, LUCENERA_VERDE

st.set_page_config(page_title="Logística — Lucenera", layout="wide")
st.title("Logística & Entregas")

@st.cache_data(ttl=120)
def load():
    agenda = fetch_view("vw_separacoes_agenda")
    return agenda


try:
    df = load()

    # ── filtros ────────────────────────────────────────────────────────────────
    st.sidebar.header("Filtros — Logística")
    if "urgencia" in df.columns:
        urg_opts = ["Todos"] + sorted(df["urgencia"].dropna().unique().tolist())
        sel_urg = st.sidebar.selectbox("Urgência", urg_opts)
        if sel_urg != "Todos":
            df = df[df["urgencia"] == sel_urg]

    if "status_separacao" in df.columns:
        status_opts = ["Todos"] + sorted(df["status_separacao"].dropna().unique().tolist())
        sel_status = st.sidebar.selectbox("Status Separação", status_opts)
        if sel_status != "Todos":
            df = df[df["status_separacao"] == sel_status]

    if "data_entrega" in df.columns:
        df["data_entrega"] = pd.to_datetime(df["data_entrega"], errors="coerce")
        datas_validas = df["data_entrega"].dropna()
        if len(datas_validas) > 0:
            data_min = datas_validas.min().date()
            data_max = datas_validas.max().date()
            date_range = st.sidebar.date_input("Período de entrega", value=(data_min, data_max))
            if isinstance(date_range, tuple) and len(date_range) == 2:
                df = df[
                    (df["data_entrega"].dt.date >= date_range[0]) &
                    (df["data_entrega"].dt.date <= date_range[1])
                ]

    # ── KPIs ───────────────────────────────────────────────────────────────────
    hoje  = int((df["urgencia"] == "hoje").sum())  if "urgencia" in df.columns else 0
    amanha = int((df["urgencia"] == "amanha").sum()) if "urgencia" in df.columns else 0
    pend  = int((df["status_separacao"].isin(["pendente", "Pendente", "aguardando"])).sum()) if "status_separacao" in df.columns else 0
    total = len(df)

    k1, k2, k3, k4 = st.columns(4)
    k1.metric("Total separações", total)
    k2.metric("Entregas HOJE", hoje)
    k3.metric("Entregas AMANHÃ", amanha)
    k4.metric("Pendentes separação", pend)

    st.divider()

    # ── gráficos ───────────────────────────────────────────────────────────────
    col_a, col_b = st.columns(2)

    with col_a:
        if "urgencia" in df.columns:
            st.subheader("Por Urgência")
            urg_ct = df["urgencia"].value_counts().reset_index()
            urg_ct.columns = ["urgencia", "qtd"]
            color_map = {"hoje": "#d32f2f", "amanha": "#f57c00", "proximos_dias": "#1565C0", "futuro": "#388e3c"}
            fig = px.bar(urg_ct, x="urgencia", y="qtd", color="urgencia",
                         color_discrete_map=color_map, text="qtd")
            fig.update_layout(showlegend=False, margin=dict(t=10))
            st.plotly_chart(fig, use_container_width=True)

    with col_b:
        if "status_separacao" in df.columns:
            st.subheader("Por Status de Separação")
            status_ct = df["status_separacao"].value_counts().reset_index()
            status_ct.columns = ["status", "qtd"]
            fig2 = px.pie(status_ct, names="status", values="qtd", hole=0.4,
                          color_discrete_sequence=px.colors.qualitative.Safe)
            fig2.update_layout(margin=dict(t=20, b=0))
            st.plotly_chart(fig2, use_container_width=True)

    # ── evolução por data ──────────────────────────────────────────────────────
    if "data_entrega" in df.columns:
        st.subheader("Entregas por Data")
        df_valid = df.dropna(subset=["data_entrega"]).copy()
        if len(df_valid) > 0:
            df_valid["dia"] = df_valid["data_entrega"].dt.date
            por_dia = df_valid.groupby("dia").size().reset_index(name="qtd")
            fig3 = px.bar(por_dia, x="dia", y="qtd", color_discrete_sequence=[LUCENERA_VERDE])
            fig3.update_layout(xaxis_title="Data", yaxis_title="Qtd Separações", margin=dict(t=10))
            st.plotly_chart(fig3, use_container_width=True)

    # ── tabela ─────────────────────────────────────────────────────────────────
    st.subheader("Agenda de Separações")
    priority_cols = ["cliente_nome", "projeto_codigo", "data_entrega", "status_separacao",
                     "urgencia", "responsavel_nome", "observacoes"]
    cols_show = [c for c in priority_cols if c in df.columns]
    remaining = [c for c in df.columns if c not in cols_show]

    if cols_show:
        st.dataframe(df[cols_show + remaining], use_container_width=True, hide_index=True)
    else:
        st.dataframe(df, use_container_width=True, hide_index=True)

except RuntimeError as e:
    st.error(str(e))
except Exception as e:
    st.error(f"Erro: {e}")
