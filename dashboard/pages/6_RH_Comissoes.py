import streamlit as st
import pandas as pd
import plotly.express as px
import plotly.graph_objects as go
from config import fetch_view, fetch_all, LUCENERA_VERDE

st.set_page_config(page_title="RH & Comissões — Lucenera", layout="wide")
st.title("RH & Comissões")

@st.cache_data(ttl=300)
def load():
    comissao    = fetch_view("vw_comissao_mensal")
    funcionarios = fetch_view("vw_funcionarios_completo")
    ferias      = fetch_all("funcionarios_ferias", "*") if True else pd.DataFrame()
    return comissao, funcionarios, ferias


try:
    com_df, func_df, ferias_df = load()

    # ── filtros ────────────────────────────────────────────────────────────────
    st.sidebar.header("Filtros — RH")
    if "mes" in com_df.columns:
        com_df["mes"] = pd.to_datetime(com_df["mes"], errors="coerce")
        meses_disp = sorted(com_df["mes"].dropna().dt.to_period("M").unique().astype(str).tolist(), reverse=True)
        if meses_disp:
            sel_mes = st.sidebar.selectbox("Mês de referência", ["Todos"] + meses_disp)
            if sel_mes != "Todos":
                com_df = com_df[com_df["mes"].dt.to_period("M").astype(str) == sel_mes]

    if "equipe" in com_df.columns:
        equipes = ["Todas"] + sorted(com_df["equipe"].dropna().unique().tolist())
        sel_equipe = st.sidebar.selectbox("Equipe", equipes)
        if sel_equipe != "Todas":
            com_df = com_df[com_df["equipe"] == sel_equipe]

    # ── KPIs ───────────────────────────────────────────────────────────────────
    total_comissao = com_df["comissao_calculada"].sum() if "comissao_calculada" in com_df.columns else 0
    total_projetos_base = com_df["valor_total_projetos"].sum() if "valor_total_projetos" in com_df.columns else 0
    n_func_ativos = func_df[func_df["ativo"] == True].shape[0] if "ativo" in func_df.columns else len(func_df)

    k1, k2, k3, k4 = st.columns(4)
    k1.metric("Funcionários ativos", n_func_ativos)
    k2.metric("Comissão total (filtro)", f"R$ {total_comissao:,.2f}")
    k3.metric("Base de cálculo (projetos)", f"R$ {total_projetos_base:,.2f}")
    pct_medio = (total_comissao / total_projetos_base * 100) if total_projetos_base > 0 else 0
    k4.metric("% comissão médio", f"{pct_medio:.2f}%")

    st.divider()

    tab1, tab2, tab3 = st.tabs(["Comissões Mensais", "Equipes", "Funcionários"])

    with tab1:
        st.subheader("Comissão Mensal por Funcionário")

        if not com_df.empty and "comissao_calculada" in com_df.columns:
            # ranking por funcionário
            func_group = (
                com_df.groupby("funcionario")
                .agg(
                    total_projetos=("total_projetos", "sum"),
                    valor_base=("valor_total_projetos", "sum"),
                    comissao_total=("comissao_calculada", "sum"),
                )
                .reset_index()
                .sort_values("comissao_total", ascending=False)
            )

            col_a, col_b = st.columns(2)
            with col_a:
                fig = px.bar(
                    func_group,
                    x="comissao_total", y="funcionario", orientation="h",
                    color_discrete_sequence=[LUCENERA_VERDE],
                    text_auto=".2s",
                    labels={"comissao_total": "Comissão (R$)", "funcionario": ""},
                )
                fig.update_layout(margin=dict(t=10, l=0))
                st.plotly_chart(fig, use_container_width=True)

            with col_b:
                st.dataframe(func_group, use_container_width=True, hide_index=True)

            # evolução mensal
            if "mes" in com_df.columns:
                st.subheader("Evolução Mensal da Comissão")
                df_evol = (
                    com_df.groupby(["mes", "funcionario"])["comissao_calculada"]
                    .sum()
                    .reset_index()
                    .sort_values("mes")
                )
                fig2 = px.bar(
                    df_evol,
                    x="mes", y="comissao_calculada",
                    color="funcionario",
                    barmode="group",
                    labels={"comissao_calculada": "Comissão (R$)", "mes": "Mês"},
                    color_discrete_sequence=px.colors.qualitative.Safe,
                )
                fig2.update_layout(xaxis_tickangle=-30, margin=dict(t=10))
                st.plotly_chart(fig2, use_container_width=True)

            # tabela completa
            st.subheader("Detalhe Completo")
            disp_cols = [c for c in ["mes", "equipe", "funcionario", "comissao_percentual",
                                      "total_projetos", "valor_total_projetos", "comissao_calculada"]
                         if c in com_df.columns]
            st.dataframe(com_df[disp_cols].sort_values(["mes", "equipe", "funcionario"] if all(c in com_df.columns for c in ["mes","equipe","funcionario"]) else disp_cols[:1], ascending=[False, True, True] if len(disp_cols) >= 3 else [False]),
                         use_container_width=True, hide_index=True)
        else:
            st.info("Sem dados de comissão para os filtros selecionados.")

    with tab2:
        st.subheader("Comissão por Equipe")
        if not com_df.empty and "equipe" in com_df.columns and "comissao_calculada" in com_df.columns:
            eq_group = (
                com_df.groupby("equipe")
                .agg(
                    funcionarios=("funcionario", "nunique"),
                    valor_base=("valor_total_projetos", "sum"),
                    comissao_total=("comissao_calculada", "sum"),
                )
                .reset_index()
                .sort_values("comissao_total", ascending=False)
            )

            fig3 = px.bar(
                eq_group,
                x="equipe", y="comissao_total",
                color="equipe",
                text_auto=".2s",
                labels={"comissao_total": "Comissão Total (R$)", "equipe": "Equipe"},
                color_discrete_sequence=px.colors.qualitative.Safe,
            )
            fig3.update_layout(showlegend=False, margin=dict(t=10))
            st.plotly_chart(fig3, use_container_width=True)
            st.dataframe(eq_group, use_container_width=True, hide_index=True)

            # evolução por equipe
            if "mes" in com_df.columns:
                st.subheader("Evolução por Equipe")
                eq_evol = (
                    com_df.groupby(["mes", "equipe"])["comissao_calculada"]
                    .sum()
                    .reset_index()
                    .sort_values("mes")
                )
                fig4 = px.line(eq_evol, x="mes", y="comissao_calculada",
                               color="equipe", markers=True,
                               labels={"comissao_calculada": "Comissão (R$)", "mes": "Mês"},
                               color_discrete_sequence=px.colors.qualitative.Safe)
                fig4.update_layout(xaxis_tickangle=-30, margin=dict(t=10))
                st.plotly_chart(fig4, use_container_width=True)

    with tab3:
        st.subheader("Funcionários")
        if not func_df.empty:
            # filtros inline
            search_func = st.text_input("Buscar por nome")
            if search_func:
                nome_col = next((c for c in ["nome", "name"] if c in func_df.columns), None)
                if nome_col:
                    func_df = func_df[func_df[nome_col].str.contains(search_func, case=False, na=False)]

            st.dataframe(func_df, use_container_width=True, hide_index=True)

        st.subheader("Férias / Afastamentos")
        if not ferias_df.empty:
            st.dataframe(ferias_df, use_container_width=True, hide_index=True)
        else:
            st.info("Sem registros de férias encontrados (tabela funcionarios_ferias).")

except RuntimeError as e:
    st.error(str(e))
except Exception as e:
    st.error(f"Erro: {e}")
