import streamlit as st
import pandas as pd
import plotly.express as px
from config import fetch_view, fetch_all, LUCENERA_VERDE

st.set_page_config(page_title="Estoque — Lucenera", layout="wide")
st.title("Estoque")

@st.cache_data(ttl=300)
def load():
    liquido   = fetch_view("vw_estoque_liquido")
    detalhado = fetch_view("vw_produtos_estoque_detalhado")
    por_marca = fetch_view("vw_estoque_por_marca")
    return liquido, detalhado, por_marca


try:
    liq_df, det_df, marca_df = load()

    # ── filtros ────────────────────────────────────────────────────────────────
    st.sidebar.header("Filtros — Estoque")

    if "alerta_estoque" in liq_df.columns:
        alertas = ["Todos"] + sorted(liq_df["alerta_estoque"].dropna().unique().tolist())
        sel_alerta = st.sidebar.selectbox("Alerta", alertas)
        if sel_alerta != "Todos":
            liq_df = liq_df[liq_df["alerta_estoque"] == sel_alerta]

    if "marca" in liq_df.columns:
        marcas = ["Todas"] + sorted(liq_df["marca"].dropna().unique().tolist())
        sel_marca = st.sidebar.selectbox("Marca", marcas)
        if sel_marca != "Todas":
            liq_df = liq_df[liq_df["marca"] == sel_marca]

    search = st.sidebar.text_input("Buscar produto")
    if search and "produto" in liq_df.columns:
        liq_df = liq_df[liq_df["produto"].str.contains(search, case=False, na=False)]

    # ── KPIs ───────────────────────────────────────────────────────────────────
    criticos = int((liq_df["alerta_estoque"] == "critico").sum()) if "alerta_estoque" in liq_df.columns else 0
    baixos   = int((liq_df["alerta_estoque"] == "baixo").sum())   if "alerta_estoque" in liq_df.columns else 0

    total_fisico    = float(liq_df["qtd_fisico"].sum())    if "qtd_fisico"    in liq_df.columns else 0
    total_reservado = float(liq_df["qtd_reservado"].sum()) if "qtd_reservado" in liq_df.columns else 0
    total_disponivel = float(liq_df["qtd_disponivel"].sum()) if "qtd_disponivel" in liq_df.columns else 0

    k1, k2, k3, k4, k5 = st.columns(5)
    k1.metric("Produtos cadastrados",  len(liq_df))
    k2.metric("Total em Estoque",      f"{total_fisico:,.0f} un")
    k3.metric("Reservado (Adm Aprov)", f"{total_reservado:,.0f} un", delta_color="inverse")
    k4.metric("Saldo Disponível",      f"{total_disponivel:,.0f} un")
    k5.metric("Alertas críticos",      criticos, delta=f"{baixos} baixo", delta_color="inverse")

    st.divider()

    tab1, tab2, tab3 = st.tabs(["Estoque Líquido", "Por Marca", "Detalhado por Local"])

    # ═══ TAB 1 — Estoque Líquido ══════════════════════════════════════════════
    with tab1:
        col_a, col_b = st.columns(2)

        with col_a:
            st.subheader("Distribuição de Alertas")
            if "alerta_estoque" in liq_df.columns:
                alerta_ct = liq_df["alerta_estoque"].value_counts().reset_index()
                alerta_ct.columns = ["alerta", "qtd"]
                color_map = {
                    "critico": "#d32f2f",
                    "baixo":   "#f57c00",
                    "normal":  "#388e3c",
                }
                fig = px.pie(alerta_ct, names="alerta", values="qtd", hole=0.45,
                             color="alerta", color_discrete_map=color_map)
                fig.update_layout(margin=dict(t=20, b=0))
                st.plotly_chart(fig, use_container_width=True)

        with col_b:
            st.subheader("Top 10 com Menor Disponível")
            if "qtd_disponivel" in liq_df.columns and "produto" in liq_df.columns:
                top10 = (
                    liq_df[["produto", "qtd_fisico", "qtd_reservado", "qtd_disponivel", "alerta_estoque"]]
                    .nsmallest(10, "qtd_disponivel")
                )
                st.dataframe(top10, use_container_width=True, hide_index=True)

        st.subheader("Tabela Completa — Estoque × Reserva × Disponível")
        st.caption(f"{len(liq_df):,} produtos")

        # Colunas prioritárias na ordem da regra de negócio
        priority = [
            "produto", "sku", "marca", "categoria",
            "qtd_fisico", "qtd_reservado", "qtd_disponivel",
            "qtd_showroom", "qtd_em_transito",
            "alerta_estoque", "valor_estoque_total", "valor_reservado_total",
            "preco_venda",
        ]
        cols_show = [c for c in priority if c in liq_df.columns]
        remaining = [c for c in liq_df.columns if c not in cols_show and c != "produto_id"]

        def highlight_alerta(row):
            alerta = str(row.get("alerta_estoque", "")).lower()
            if alerta == "critico":
                return ["background-color: #ffebee"] * len(row)
            if alerta == "baixo":
                return ["background-color: #fff3e0"] * len(row)
            return [""] * len(row)

        display = liq_df[cols_show + remaining].reset_index(drop=True)
        st.dataframe(
            display.style.apply(highlight_alerta, axis=1),
            use_container_width=True,
            hide_index=True,
        )

    # ═══ TAB 2 — Por Marca ════════════════════════════════════════════════════
    with tab2:
        st.subheader("Estoque por Marca")
        if not marca_df.empty and "marca" in marca_df.columns:
            qty_m = next((c for c in ["qtd_estoque", "quantidade_total", "total", "quantidade"] if c in marca_df.columns), None)
            if qty_m:
                fig2 = px.bar(
                    marca_df.dropna(subset=[qty_m]).sort_values(qty_m, ascending=False).head(30),
                    x="marca", y=qty_m,
                    color_discrete_sequence=[LUCENERA_VERDE],
                    text_auto=True,
                )
                fig2.update_layout(xaxis_tickangle=-35, margin=dict(t=10, b=60))
                st.plotly_chart(fig2, use_container_width=True)
            st.dataframe(marca_df, use_container_width=True, hide_index=True)
        elif "marca" in liq_df.columns and "qtd_disponivel" in liq_df.columns:
            by_marca = (
                liq_df.groupby("marca", dropna=False)["qtd_disponivel"]
                .sum().reset_index().sort_values("qtd_disponivel", ascending=False)
            )
            fig3 = px.bar(by_marca.head(30), x="marca", y="qtd_disponivel",
                          color_discrete_sequence=[LUCENERA_VERDE], text_auto=True)
            fig3.update_layout(xaxis_tickangle=-35, margin=dict(t=10, b=60))
            st.plotly_chart(fig3, use_container_width=True)
            st.dataframe(by_marca, use_container_width=True, hide_index=True)
        else:
            st.info("Dados por marca não disponíveis.")

    # ═══ TAB 3 — Detalhado ════════════════════════════════════════════════════
    with tab3:
        st.subheader("Detalhado — Estoque Geral × Reserva × Disponível")
        if not det_df.empty:
            st.caption(f"{len(det_df):,} produtos")

            search_det = st.text_input("Buscar produto (detalhado)")
            if search_det and "nome" in det_df.columns:
                det_df = det_df[det_df["nome"].str.contains(search_det, case=False, na=False)]

            # Reordenar: colunas importantes primeiro
            pri = ["codigo_produto", "nome", "sku", "preco_venda",
                   "estoque_geral", "reserva", "separacao", "disponivel"]
            c_show = [c for c in pri if c in det_df.columns]
            c_rest = [c for c in det_df.columns if c not in c_show and c != "id"]
            st.dataframe(det_df[c_show + c_rest], use_container_width=True, hide_index=True)
        else:
            st.info("View vw_produtos_estoque_detalhado sem dados.")

except RuntimeError as e:
    st.error(str(e))
except Exception as e:
    st.error(f"Erro: {e}")
    st.exception(e)
