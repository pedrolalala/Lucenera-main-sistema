"""
Comparacao SO LEITURA: planilhas da Connect (Produtos, ReservaxAmbiente, EntregaFuturaxAmbiente) x Supabase.
Grava scripts/logs/comparacao_pecas/comparacao_<data>.xlsx. Nao altera nada no banco.
Uso: python scripts/comparar_connect_vs_sistema_pecas.py
"""
from __future__ import annotations
import sys
from datetime import datetime
from pathlib import Path
import pandas as pd
import psycopg2

if sys.stdout.encoding and sys.stdout.encoding.lower() != "utf-8":
    sys.stdout.reconfigure(encoding="utf-8")
ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "scripts"))
from _supabase_client import SUPABASE_DB_URL, para_pooler  # noqa: E402

PASTA = ROOT / "01-Documento" / "01 - Planilhas"
OUT = ROOT / "scripts" / "logs" / "comparacao_pecas"
OUT.mkdir(parents=True, exist_ok=True)

conn = psycopg2.connect(para_pooler(SUPABASE_DB_URL))
conn.set_session(readonly=True)

def sql(s):
    return pd.read_sql(s, conn)

def num(s):
    return pd.to_numeric(s, errors="coerce").fillna(0)

# ---------- 1. Produtos ----------
pl = pd.read_excel(PASTA / "Produtos__2026-11-12.xlsx", dtype={"CodProduto": str})
pl["cod"] = pl["CodProduto"].astype(int)
pl = pl[["cod", "Referencia", "DescProduto", "EstoqueTotal", "Showroom", "Disponivel"]].rename(
    columns={"EstoqueTotal": "pl_total", "Showroom": "pl_showroom", "Disponivel": "pl_disp"})
sy = sql("""select p.codigo_produto cod, p.nome, p.estoque_total sy_total, p.estoque_showroom sy_showroom,
  p.estoque_disponivel sy_disp, p.ativo,
  coalesce((select sum(quantidade) from estoque_itens e where e.produto_id=p.id and e.local='Estoque'),0) sy_ei_estoque,
  coalesce((select sum(quantidade_reservada) from estoque_itens e where e.produto_id=p.id and e.local='Estoque'),0) sy_ei_reservada
  from produtos p where p.codigo_produto is not null""")
m = pl.merge(sy, on="cod", how="outer", indicator=True)
so_pl = m[m._merge == "left_only"]
so_sy = m[m._merge == "right_only"]
both = m[m._merge == "both"].copy()
for c in ["pl_total", "pl_showroom", "pl_disp", "sy_total", "sy_showroom", "sy_disp"]:
    both[c] = num(both[c])
both["dif_total"] = both.sy_total - both.pl_total
both["dif_showroom"] = both.sy_showroom - both.pl_showroom
both["dif_disp"] = both.sy_disp - both.pl_disp
dif_prod = both[(both.dif_total.abs() > 0.001) | (both.dif_showroom.abs() > 0.001) | (both.dif_disp.abs() > 0.001)]

# ---------- 2. Reserva / Entrega futura ----------
def ler(f):
    d = pd.read_excel(PASTA / f, dtype=str).fillna("")
    d.columns = ["orc", "venda", "cliente", "nome", "produto", "ref", "desc", "qtd", "amb", "dt_ent", "func", "valor", "obs", "adic"]
    d["qtd"] = pd.to_numeric(d.qtd, errors="coerce").fillna(0)
    d["produto"] = pd.to_numeric(d.produto, errors="coerce").fillna(-1).astype(int)
    d["venda"] = pd.to_numeric(d.venda, errors="coerce").fillna(0).astype(int)
    return d
R, E = ler("ReservaxAmbiente.xlsx"), ler("EntregaFuturaxAmbiente.xlsx")

import warnings; warnings.filterwarnings("ignore")
esp = sql("select tipo, cod_venda_connect venda, produto_codigo produto, ambiente amb, quantidade qtd, projeto_item_id from connect_reserva_ambiente")
live = sql("""select pi.id projeto_item_id, pr.codigo_produto produto, o.origem, o.numero_venda, pi.l_fixo,
  esp.q_reserva, esp.q_entrega_futura from estoque_saldos_projeto_item esp
  join projeto_itens pi on pi.id=esp.projeto_item_id join produtos pr on pr.id=pi.produto_id
  left join orcamentos o on o.id=pi.orcamento_id where esp.status_operacional<>'cancelado'""")

def cruzar(pla, tipo, colq):
    e = esp[esp.tipo == tipo]
    # por peca
    a = pla.groupby("produto").qtd.sum().rename("planilha")
    b = e.groupby("produto").qtd.sum().rename("espelho_05_11")
    lc = live[live.origem == "connect"].groupby("produto")[colq].sum().rename("sistema_connect")
    ls = live[live.origem != "connect"].groupby("produto")[colq].sum().rename("sistema_vendas_novas")
    t = pd.concat([a, b, lc, ls], axis=1).fillna(0).reset_index()
    t["dif_planilha_x_connect_atual"] = t.sistema_connect - t.planilha
    t["dif_planilha_x_espelho"] = t.espelho_05_11 - t.planilha
    # por linha (venda+peca+ambiente)
    k = ["venda", "produto", "amb"]
    pa = pla.groupby(k).qtd.sum().rename("planilha")
    ea = e.groupby(k).qtd.sum().rename("espelho_05_11")
    l = pd.concat([pa, ea], axis=1).fillna(0).reset_index()
    l["dif"] = l.espelho_05_11 - l.planilha
    l["situacao"] = "diferente"
    l.loc[(l.planilha == 0), "situacao"] = "so no espelho (saiu da planilha)"
    l.loc[(l.espelho_05_11 == 0), "situacao"] = "so na planilha (nova desde 05/11)"
    l = l[l.dif.abs() > 0.001]
    return t, l

print("linhas sem venda: reserva", int((R.venda==0).sum()), "| EF", int((E.venda==0).sum()))
tR, lR = cruzar(R, "reserva", "q_reserva")
tE, lE = cruzar(E, "entrega_futura", "q_entrega_futura")

# formula do Disponivel na planilha de produtos
chk = both.merge(R.groupby("produto").qtd.sum().rename("res"), left_on="cod", right_index=True, how="left") \
          .merge(E.groupby("produto").qtd.sum().rename("ef"), left_on="cod", right_index=True, how="left").fillna({"res": 0, "ef": 0})
f1 = ((chk.pl_total + chk.pl_showroom - chk.res - chk.pl_disp).abs() < 0.01).mean()
f2 = ((chk.pl_total - chk.res - chk.pl_disp).abs() < 0.01).mean()
f3 = ((chk.pl_total + chk.pl_showroom - chk.res - chk.ef - chk.pl_disp).abs() < 0.01).mean()

print("== PRODUTOS ==")
print(f"planilha {len(pl)} | sistema {len(sy)} | so planilha {len(so_pl)} | so sistema {len(so_sy)} | em ambos {len(both)}")
print(f"divergentes: {len(dif_prod)} (total {int((both.dif_total.abs()>0.001).sum())}, showroom {int((both.dif_showroom.abs()>0.001).sum())}, disponivel {int((both.dif_disp.abs()>0.001).sum())})")
print(f"soma total planilha {both.pl_total.sum():.1f} x sistema {both.sy_total.sum():.1f}")
print(f"formula Disponivel planilha: Tot+Show-Res={f1:.1%} | Tot-Res={f2:.1%} | Tot+Show-Res-EF={f3:.1%}")
for nome, t, l, pla in [("RESERVA", tR, lR, R), ("ENTREGA FUTURA", tE, lE, E)]:
    print(f"== {nome} ==  planilha {pla.qtd.sum():.1f} ({len(pla)} linhas) | espelho {t.espelho_05_11.sum():.1f} | sistema(connect) {t.sistema_connect.sum():.1f} | vendas novas {t.sistema_vendas_novas.sum():.1f}")
    print(f"pecas divergentes planilha x sistema(connect): {int((t.dif_planilha_x_connect_atual.abs()>0.001).sum())} de {len(t)} | linhas divergentes planilha x espelho: {len(l)} ({l.situacao.value_counts().to_dict()})")

arq = OUT / f"comparacao_{datetime.now():%Y%m%d_%H%M}.xlsx"
with pd.ExcelWriter(arq) as w:
    dif_prod.drop(columns="_merge").to_excel(w, sheet_name="Produtos divergentes", index=False)
    so_pl.drop(columns="_merge").dropna(axis=1, how="all").to_excel(w, sheet_name="Produtos so na planilha", index=False)
    so_sy.drop(columns="_merge").dropna(axis=1, how="all").to_excel(w, sheet_name="Produtos so no sistema", index=False)
    tR[tR.dif_planilha_x_connect_atual.abs() > 0.001].to_excel(w, sheet_name="Reserva por peca", index=False)
    lR.to_excel(w, sheet_name="Reserva linhas x espelho", index=False)
    tE[tE.dif_planilha_x_connect_atual.abs() > 0.001].to_excel(w, sheet_name="EF por peca", index=False)
    lE.to_excel(w, sheet_name="EF linhas x espelho", index=False)
print("Excel:", arq)
