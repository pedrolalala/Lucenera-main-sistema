import streamlit as st
import pandas as pd
import plotly.express as px
from config import fetch_view, fetch_all, LUCENERA_VERDE

st.set_page_config(page_title="CRM & Arquitetos — Lucenera", layout="wide")
st.title("CRM & Arquitetos")

@st.cache_data(ttl=300)
def load():
    crm       = fetch_view("vw_dashboard_crm_fechamento")
    projetos  = fetch_view("vw_projetos_dashboard")
    pipeline  = fetch_view("vw_projetos_pipeline") if True else pd.DataFrame()
    return crm, projetos, pipeline


try:
    crm_df, proj_df, pipeline_df = load()

    # ── filtros ────────────────────────────────────────────────────────────────
    st.sidebar.header("Filtros — CRM")
    arq_col = next((c for c in ["arquiteto_nome", "arquiteto", "nome_arquiteto"] if c in proj_df.columns), None)
    if arq_col:
        arqs = ["Todos"] + sorted(proj_df[arq_col].dropna().unique().tolist())
        sel_arq = st.sidebar.selectbox("Arquiteto", arqs)
        if sel_arq != "Todos":
            proj_df = proj_df[proj_df[arq_col] == sel_arq]

    tipo_col = next((c for c in ["tipo_projeto", "tipo"] if c in proj_df.columns), None)
    if tipo_col:
        tipos = ["Todos"] + sorted(proj_df[tipo_col].dropna().unique().tolist())
        sel_tipo = st.sidebar.selectbox("Tipo de Projeto", tipos)
        if sel_tipo != "Todos":
            proj_df = proj_df[proj_df[tipo_col] == sel_tipo]

    # ── KPIs ───────────────────────────────────────────────────────────────────
    n_arqs = proj_df[arq_col].nunique() if arq_col else 0
    valor_col = next((c for c in ["valor_total", "valor_orcamento", "valor"] if c in proj_df.columns), None)
    ticket_medio = proj_df[valor_col].mean() if valor_col else 0
    total_proj = len(proj_df)

    k1, k2, k3 = st.columns(3)
    k1.metric("Arquitetos com projetos", n_arqs)
    k2.metric("Total projetos (filtrado)", total_proj)
    if valor_col:
        k3.metric("Ticket médio", f"R$ {ticket_medio:,.2f}")

    st.divider()

    tab1, tab2, tab3 = st.tabs(["Rankings Arquitetos", "Pipeline CRM", "Tipos de Projeto"])

    with tab1:
        st.subheader("Top Arquitetos")
        if arq_col and valor_col:
            arq_group = (
                proj_df.groupby(arq_col)
                .agg(total_projetos=("id" if "id" in proj_df.columns else valor_col, "count"),
                     valor_total=(valor_col, "sum"))
                .reset_index()
                .sort_values("valor_total", ascending=False)
            )

            col_a, col_b = st.columns(2)
            with col_a:
                st.markdown("**Por Valor Total**")
                fig = px.bar(
                    arq_group.head(15),
                    x="valor_total", y=arq_col, orientation="h",
                    color_discrete_sequence=[LUCENERA_VERDE],
                    text_auto=".2s",
                )
                fig.update_layout(yaxis_title="", margin=dict(t=10, l=0))
                st.plotly_chart(fig, use_container_width=True)

            with col_b:
                st.markdown("**Por Número de Projetos**")
                fig2 = px.bar(
                    arq_group.sort_values("total_projetos", ascending=False).head(15),
                    x="total_projetos", y=arq_col, orientation="h",
                    color_discrete_sequence=["#1565C0"],
                    text="total_projetos",
                )
                fig2.update_layout(yaxis_title="", margin=dict(t=10, l=0))
                st.plotly_chart(fig2, use_container_width=True)

            st.dataframe(arq_group, use_container_width=True, hide_index=True)
        else:
            st.info("Coluna de arquiteto não encontrada nos dados de projetos.")

    with tab2:
        st.subheader("Dashboard CRM — Fechamentos")
        if not crm_df.empty:
            date_col = next((c for c in ["mes", "data", "data_fechamento", "periodo"] if c in crm_df.columns), None)
            if date_col:
                crm_df[date_col] = pd.to_datetime(crm_df[date_col], errors="coerce")
                crm_df = crm_df.sort_values(date_col)
            num_cols = crm_df.select_dtypes("number").columns.tolist()
            if num_cols and date_col:
                fig3 = px.line(crm_df, x=date_col, y=num_cols[:3],
                               color_discrete_sequence=px.colors.qualitative.Safe)
                fig3.update_layout(xaxis_title="Período", margin=dict(t=10))
                st.plotly_chart(fig3, use_container_width=True)
            st.dataframe(crm_df, use_container_width=True, hide_index=True)

        if not pipeline_df.empty:
            st.subheader("Pipeline de Projetos")
            st.dataframe(pipeline_df, use_container_width=True, hide_index=True)

    with tab3:
        if tipo_col and valor_col:
            st.subheader("Projetos por Tipo")
            tipo_group = proj_df.groupby(tipo_col).agg(
                total=(valor_col, "count"),
                valor=(valor_col, "sum")
            ).reset_index()

            col_c, col_d = st.columns(2)
            with col_c:
                fig4 = px.pie(tipo_group, names=tipo_col, values="total", hole=0.4,
                              title="Quantidade por Tipo",
                              color_discrete_sequence=px.colors.qualitative.Pastel)
                st.plotly_chart(fig4, use_container_width=True)
            with col_d:
                fig5 = px.pie(tipo_group, names=tipo_col, values="valor", hole=0.4,
                              title="Valor por Tipo",
                              color_discrete_sequence=px.colors.qualitative.Safe)
                st.plotly_chart(fig5, use_container_width=True)
        else:
            st.info("Tipo de projeto não disponível nos dados.")

    # ── evolução mensal ────────────────────────────────────────────────────────
    if "data_entrada" in proj_df.columns and valor_col:
        st.subheader("Novos Projetos por Mês")
        proj_df["data_entrada"] = pd.to_datetime(proj_df["data_entrada"], errors="coerce")
        df_mes = proj_df.dropna(subset=["data_entrada"]).copy()
        df_mes["mes"] = df_mes["data_entrada"].dt.to_period("M").astype(str)
        mensal = df_mes.groupby("mes").agg(projetos=("id" if "id" in df_mes.columns else valor_col, "count"),
                                            valor=(valor_col, "sum")).reset_index()
        fig6 = px.bar(mensal, x="mes", y="projetos", color_discrete_sequence=[LUCENERA_VERDE],
                      text="projetos")
        fig6.update_layout(xaxis_title="Mês", yaxis_title="Quantidade", margin=dict(t=10))
        st.plotly_chart(fig6, use_container_width=True)

except RuntimeError as e:
    st.error(str(e))
except Exception as e:
    st.error(f"Erro: {e}")
