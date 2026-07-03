import streamlit as st
import pandas as pd
import plotly.express as px
import plotly.graph_objects as go
from config import fetch_all, LUCENERA_VERDE

st.set_page_config(page_title="Financeiro — Lucenera", layout="wide")
st.title("Financeiro")

LIMITE_MIN = pd.Timestamp("2000-01-01")
LIMITE_MAX = pd.Timestamp.today().normalize()


@st.cache_data(ttl=180)
def load():
    trans = fetch_all(
        "transacoes",
        "id,tipo,descricao,valor,data_transacao,status_pago,tipo_pagamento,"
        "vl_pago,vl_parcela,vl_desconto,vl_juros,vl_frete,vl_ipi,"
        "dt_emissao,dt_vencimento,dt_pagamento,"
        "empresa_id,projeto_id,negociacao_id,categoria_id,funcionario_id,"
        "num_parc,acordo",
        order="data_transacao",
    )
    empresas = fetch_all("empresas", "id,nome,codigo")
    projetos = fetch_all("projetos", "id,codigo,nome,status,responsavel_nome")
    cats     = fetch_all("categorias_financeiras", "id,nome,tipo,grupo")
    negs     = fetch_all("negociacoes", "id,empresa_id,contato_id,plano_contas_id,projeto_id,cod_duplicata,cod_venda")
    contatos = fetch_all("contatos", "id,nome,tipo")
    return trans, empresas, projetos, cats, negs, contatos


try:
    trans_df, emp_df, proj_df, cats_df, negs_df, cont_df = load()

    if trans_df.empty:
        st.warning("Tabela transacoes sem dados.")
        st.stop()

    # ── enriquecer com nomes via merge pandas ──────────────────────────────────
    df = trans_df.copy()

    if not emp_df.empty:
        emp_df = emp_df.rename(columns={"id": "empresa_id", "nome": "empresa_nome", "codigo": "empresa_codigo"})
        df = df.merge(emp_df[["empresa_id", "empresa_nome"]], on="empresa_id", how="left")

    if not proj_df.empty:
        proj_df = proj_df.rename(columns={"id": "projeto_id", "codigo": "projeto_codigo", "nome": "projeto_nome"})
        df = df.merge(proj_df[["projeto_id", "projeto_codigo", "projeto_nome"]], on="projeto_id", how="left")

    if not cats_df.empty:
        cats_df = cats_df.rename(columns={"id": "categoria_id", "nome": "categoria_nome", "grupo": "categoria_grupo"})
        df = df.merge(cats_df[["categoria_id", "categoria_nome", "categoria_grupo"]], on="categoria_id", how="left")

    if not negs_df.empty and not cont_df.empty:
        negs_df = negs_df.rename(columns={"id": "negociacao_id"})
        cont_df = cont_df.rename(columns={"id": "contato_id", "nome": "favorecido"})
        negs_enr = negs_df.merge(cont_df[["contato_id", "favorecido"]], on="contato_id", how="left")
        df = df.merge(negs_enr[["negociacao_id", "favorecido"]], on="negociacao_id", how="left")

    # ── normalizar tipos ───────────────────────────────────────────────────────
    df["data_transacao"] = pd.to_datetime(df["data_transacao"], errors="coerce")
    df = df[df["data_transacao"].between(LIMITE_MIN, LIMITE_MAX, inclusive="both")]

    for c in ["dt_emissao", "dt_vencimento", "dt_pagamento"]:
        if c in df.columns:
            df[c] = pd.to_datetime(df[c], errors="coerce")

    for c in ["valor", "vl_pago", "vl_parcela", "vl_desconto", "vl_juros"]:
        if c in df.columns:
            df[c] = pd.to_numeric(df[c], errors="coerce").fillna(0)

    df["_pago"] = pd.to_numeric(df["status_pago"], errors="coerce").fillna(0) == 1
    df["_tipo"] = df["tipo"].astype(str).str.lower()

    # ── filtros sidebar ────────────────────────────────────────────────────────
    st.sidebar.header("Filtros")

    d_min = df["data_transacao"].min().date()
    d_max = df["data_transacao"].max().date()
    periodo = st.sidebar.date_input("Período", value=(d_min, d_max))
    if isinstance(periodo, tuple) and len(periodo) == 2:
        df = df[
            (df["data_transacao"].dt.date >= periodo[0]) &
            (df["data_transacao"].dt.date <= periodo[1])
        ]

    tipos = ["Todos"] + sorted(df["tipo"].dropna().unique().tolist())
    sel_tipo = st.sidebar.selectbox("Tipo", tipos)
    if sel_tipo != "Todos":
        df = df[df["tipo"] == sel_tipo]

    if "empresa_nome" in df.columns:
        emps = ["Todas"] + sorted(df["empresa_nome"].dropna().unique().tolist())
        sel_emp = st.sidebar.selectbox("Empresa", emps)
        if sel_emp != "Todas":
            df = df[df["empresa_nome"] == sel_emp]

    if "categoria_grupo" in df.columns:
        grupos = ["Todos"] + sorted(df["categoria_grupo"].dropna().unique().tolist())
        sel_grupo = st.sidebar.selectbox("Grupo (categoria)", grupos)
        if sel_grupo != "Todos":
            df = df[df["categoria_grupo"] == sel_grupo]

    sel_status = st.sidebar.selectbox("Status pagamento", ["Todos", "Pago", "Pendente"])
    if sel_status == "Pago":
        df = df[df["_pago"]]
    elif sel_status == "Pendente":
        df = df[~df["_pago"]]

    # ── máscaras e totais ──────────────────────────────────────────────────────
    m_rec  = df["_tipo"] == "receita"
    m_desp = df["_tipo"] == "despesa"
    m_pago = df["_pago"]

    rec_realizada = float(df.loc[m_rec & m_pago,  "valor"].sum())
    des_realizada = float(df.loc[m_desp & m_pago, "valor"].sum())
    resultado     = rec_realizada - des_realizada
    a_receber     = float(df.loc[m_rec & ~m_pago,  "valor"].sum())
    a_pagar       = float(df.loc[m_desp & ~m_pago, "valor"].sum())

    # ── KPIs ───────────────────────────────────────────────────────────────────
    k1, k2, k3, k4, k5 = st.columns(5)
    k1.metric("Receita Realizada",  f"R$ {rec_realizada:,.2f}", delta=f"{int(m_rec.sum())} lançamentos")
    k2.metric("Despesa Realizada",  f"R$ {des_realizada:,.2f}", delta=f"{int(m_desp.sum())} lançamentos")
    k3.metric("Resultado Líquido",  f"R$ {resultado:,.2f}",
              delta_color="normal" if resultado >= 0 else "inverse")
    k4.metric("A Receber (pend.)",  f"R$ {a_receber:,.2f}")
    k5.metric("A Pagar (pend.)",    f"R$ {a_pagar:,.2f}", delta_color="inverse")

    st.divider()

    tab1, tab2, tab3, tab4 = st.tabs([
        "Receita × Despesa", "Por Empresa / Projeto", "Categorias", "Lançamentos"
    ])

    # ═══ TAB 1 — Receita × Despesa ════════════════════════════════════════════
    with tab1:
        col_a, col_b = st.columns(2)

        with col_a:
            st.subheader("Evolução Mensal")
            df_m = df.copy()
            df_m["mes"] = df_m["data_transacao"].dt.to_period("M").astype(str)
            mensal = (
                df_m.groupby(["mes", "tipo"])["valor"]
                .sum().reset_index().sort_values("mes")
            )
            fig1 = px.bar(
                mensal, x="mes", y="valor", color="tipo", barmode="group",
                color_discrete_map={"receita": LUCENERA_VERDE, "despesa": "#d32f2f"},
                labels={"valor": "R$", "mes": "Mês"},
            )
            fig1.update_layout(xaxis_tickangle=-30, margin=dict(t=10))
            st.plotly_chart(fig1, use_container_width=True)

        with col_b:
            st.subheader("Receita × Despesa (total)")
            tipo_sum = df.groupby("tipo")["valor"].sum().reset_index()
            fig2 = px.pie(
                tipo_sum, names="tipo", values="valor", hole=0.45,
                color="tipo",
                color_discrete_map={"receita": LUCENERA_VERDE, "despesa": "#d32f2f"},
            )
            fig2.update_layout(margin=dict(t=20, b=0))
            st.plotly_chart(fig2, use_container_width=True)

        # resultado líquido acumulado por mês
        st.subheader("Resultado Líquido Acumulado")
        rec_m = df_m[df_m["_tipo"] == "receita"].groupby("mes")["valor"].sum()
        des_m = df_m[df_m["_tipo"] == "despesa"].groupby("mes")["valor"].sum()
        res_m = (rec_m.subtract(des_m, fill_value=0)).sort_index().cumsum().reset_index()
        res_m.columns = ["mes", "resultado_acumulado"]
        fig3 = px.area(res_m, x="mes", y="resultado_acumulado",
                       color_discrete_sequence=[LUCENERA_VERDE],
                       labels={"resultado_acumulado": "R$ Acumulado", "mes": "Mês"})
        fig3.add_hline(y=0, line_dash="dash", line_color="#d32f2f")
        fig3.update_layout(xaxis_tickangle=-30, margin=dict(t=10))
        st.plotly_chart(fig3, use_container_width=True)

        # tipo de pagamento
        if "tipo_pagamento" in df.columns:
            with st.expander("Por Tipo de Pagamento"):
                tp = df.groupby("tipo_pagamento", dropna=False)["valor"].sum().reset_index().sort_values("valor", ascending=False)
                fig4 = px.bar(tp, x="tipo_pagamento", y="valor",
                              color_discrete_sequence=["#1565C0"], text_auto=".2s")
                fig4.update_layout(xaxis_tickangle=-30, margin=dict(t=10))
                st.plotly_chart(fig4, use_container_width=True)

    # ═══ TAB 2 — Empresa / Projeto ════════════════════════════════════════════
    with tab2:
        col_c, col_d = st.columns(2)

        with col_c:
            st.subheader("Receita por Empresa")
            if "empresa_nome" in df.columns:
                er = df[m_rec].groupby("empresa_nome", dropna=False)["valor"].sum().reset_index().sort_values("valor", ascending=False)
                fig5 = px.bar(er, x="valor", y="empresa_nome", orientation="h",
                              color_discrete_sequence=[LUCENERA_VERDE], text_auto=".2s")
                fig5.update_layout(yaxis_title="", margin=dict(t=10, l=0))
                st.plotly_chart(fig5, use_container_width=True)

        with col_d:
            st.subheader("Despesa por Empresa")
            if "empresa_nome" in df.columns:
                ed = df[m_desp].groupby("empresa_nome", dropna=False)["valor"].sum().reset_index().sort_values("valor", ascending=False)
                fig6 = px.bar(ed, x="valor", y="empresa_nome", orientation="h",
                              color_discrete_sequence=["#d32f2f"], text_auto=".2s")
                fig6.update_layout(yaxis_title="", margin=dict(t=10, l=0))
                st.plotly_chart(fig6, use_container_width=True)

        st.subheader("Top 20 Projetos por Receita")
        if "projeto_nome" in df.columns:
            pr = (
                df[m_rec]
                .groupby(["projeto_codigo", "projeto_nome"], dropna=False)["valor"]
                .sum().reset_index()
                .sort_values("valor", ascending=False).head(20)
            )
            fig7 = px.bar(pr, x="valor", y="projeto_nome", orientation="h",
                          color_discrete_sequence=[LUCENERA_VERDE], text_auto=".2s",
                          hover_data=["projeto_codigo"])
            fig7.update_layout(yaxis_title="", margin=dict(t=10, l=0), height=500)
            st.plotly_chart(fig7, use_container_width=True)

        if "favorecido" in df.columns:
            st.subheader("Por Favorecido / Contato")
            fav = df.groupby("favorecido", dropna=False)["valor"].sum().reset_index().sort_values("valor", ascending=False).head(20)
            fig8 = px.bar(fav, x="valor", y="favorecido", orientation="h",
                          color_discrete_sequence=["#7B1FA2"], text_auto=".2s")
            fig8.update_layout(yaxis_title="", margin=dict(t=10, l=0))
            st.plotly_chart(fig8, use_container_width=True)

    # ═══ TAB 3 — Categorias ════════════════════════════════════════════════════
    with tab3:
        if "categoria_grupo" in df.columns:
            st.subheader("Por Grupo de Categoria")
            cg = df.groupby(["categoria_grupo", "tipo"], dropna=False)["valor"].sum().reset_index().sort_values("valor", ascending=False)
            fig9 = px.bar(cg, x="valor", y="categoria_grupo", color="tipo",
                          orientation="h", barmode="group",
                          color_discrete_map={"receita": LUCENERA_VERDE, "despesa": "#d32f2f"},
                          text_auto=".2s")
            fig9.update_layout(yaxis_title="", margin=dict(t=10, l=0), height=400)
            st.plotly_chart(fig9, use_container_width=True)

        if "categoria_nome" in df.columns:
            st.subheader("Por Categoria")
            cn = df.groupby(["categoria_nome", "tipo"], dropna=False)["valor"].sum().reset_index().sort_values("valor", ascending=False).head(30)
            fig10 = px.bar(cn, x="valor", y="categoria_nome", color="tipo",
                           orientation="h", barmode="group",
                           color_discrete_map={"receita": LUCENERA_VERDE, "despesa": "#d32f2f"},
                           text_auto=".2s")
            fig10.update_layout(yaxis_title="", margin=dict(t=10, l=0), height=600)
            st.plotly_chart(fig10, use_container_width=True)
            st.dataframe(cn, use_container_width=True, hide_index=True)

    # ═══ TAB 4 — Lançamentos ══════════════════════════════════════════════════
    with tab4:
        st.subheader(f"Lançamentos ({len(df):,} registros)")

        search = st.text_input("Buscar na descrição")
        if search:
            df = df[df["descricao"].str.contains(search, case=False, na=False)]

        priority = [
            "data_transacao", "tipo", "valor", "vl_pago", "status_pago",
            "descricao", "empresa_nome", "projeto_codigo", "projeto_nome",
            "categoria_nome", "categoria_grupo", "tipo_pagamento",
            "favorecido", "dt_vencimento", "dt_pagamento",
            "vl_desconto", "vl_juros",
        ]
        cols_show = [c for c in priority if c in df.columns]
        remaining = [c for c in df.columns if c not in cols_show
                     and not c.startswith("_") and c not in ("id", "empresa_id", "projeto_id",
                                                              "categoria_id", "negociacao_id",
                                                              "funcionario_id", "parcela_id",
                                                              "conta_id", "_tipo")]

        def highlight_tipo(row):
            if str(row.get("tipo", "")).lower() == "receita":
                return ["background-color: #e8f5e9"] * len(row)
            if str(row.get("tipo", "")).lower() == "despesa":
                return ["background-color: #ffebee"] * len(row)
            return [""] * len(row)

        display = df[cols_show + remaining].reset_index(drop=True)
        st.dataframe(
            display.style.apply(highlight_tipo, axis=1),
            use_container_width=True,
            hide_index=True,
        )

except RuntimeError as e:
    st.error(str(e))
except Exception as e:
    st.error(f"Erro: {e}")
    st.exception(e)
