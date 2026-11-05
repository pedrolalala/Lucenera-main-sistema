"""
SPEC-245 — Conferência (SÓ LEITURA) do Contas a Receber e do Contas a Pagar do sistema contra as planilhas do dia.

Compara a ContaReceber_*.xlsx e a ContaPagar_*.xlsx mais recentes de `01-Documento/01 - Planilhas` com `transacoes` (tipo receita/despesa), por
`cod_itens_duplicata`, e responde o que o Filippo precisa conferir todo dia:

  1. EM ABERTO: quantidade e valor, por empresa — planilha × sistema. Tem que fechar com diferença zero (é o critério de aceite da SPEC-245).
  2. Linhas da planilha que não estão no sistema, e linhas EM ABERTO no sistema que não estão em aberto na planilha (e vice-versa).
  2b. EMPRESA: no sistema a empresa de cada parcela vem da negociação (transacoes.empresa_id não é usado); a planilha traz a empresa por linha
     (LUCE NERA = MANOELLA). Divergências ficam na aba *_empresa_divergente.
  3. Pagas e canceladas: status e valor da parcela divergentes. Alguns códigos se repetem no sistema (acordos/negociações duplicadas, que o
     importador cancela de propósito): a linha da planilha conta como "ok" se existir no sistema uma linha com o MESMO status e o mesmo valor.
  4. Linhas só no sistema (histórico fora do período exportado), por status.

NÃO grava nada. Gera um Excel em scripts/logs/conferencia_financeiro/ e sai com código 1 se as listas EM ABERTO não fecharem.

Uso:  python scripts/conferir_contas_pagar_receber.py [--receber arquivo.xlsx] [--pagar arquivo.xlsx]
"""

from __future__ import annotations

import argparse
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
from sync_connect_common import descobrir_planilha_mais_recente  # noqa: E402

PASTA = ROOT / "01-Documento" / "01 - Planilhas"
STATUS = {0: "aberta", 1: "paga", 2: "cancelada"}
# "LUCE NERA" é como a Connect chama a MANOELLA (regra fixa do projeto, AGENTS.md)
EMPRESA_NORMAL = {"LUCE NERA": "MANOELLA"}
CASOS = [("receber", "ContaReceber_", "receita", "Contas a Receber"), ("pagar", "ContaPagar_", "despesa", "Contas a Pagar")]


def brl(v: float) -> str:
    return f"R$ {v:,.2f}".replace(",", "X").replace(".", ",").replace("X", ".")


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--receber")
    ap.add_argument("--pagar")
    args = ap.parse_args()
    escolhidos = {"receber": args.receber, "pagar": args.pagar}

    con = psycopg2.connect(para_pooler(SUPABASE_DB_URL), connect_timeout=30)
    cur = con.cursor()
    cur.execute("SELECT id::text, nome FROM public.empresas")
    nome_empresa = {i: n for i, n in cur.fetchall()}

    saida = ROOT / "scripts" / "logs" / "conferencia_financeiro"
    saida.mkdir(parents=True, exist_ok=True)
    xlsx = saida / f"conferencia_financeiro_{datetime.now():%Y%m%d_%H%M%S}.xlsx"
    abas: dict[str, pd.DataFrame] = {}
    aberta_fecha = True
    resumo_linhas = []

    for chave, prefixo, tipo, titulo in CASOS:
        arq = Path(escolhidos[chave]) if escolhidos[chave] else descobrir_planilha_mais_recente(PASTA, prefixo)
        d = pd.read_excel(arq)
        d["cod"] = pd.to_numeric(d["cod_itens_duplicata"], errors="coerce")
        d["status"] = pd.to_numeric(d["pago"], errors="coerce").map(STATUS)
        d["vl_parcela"] = pd.to_numeric(d["vl_parcela"], errors="coerce").fillna(0.0)
        d["empresa"] = d["nm_empresa"].astype(str).str.strip().str.upper().replace(EMPRESA_NORMAL)
        print(f"\n=== {titulo} — {Path(arq).name} ({len(d)} linhas) ===")

        cur.execute(
            """SELECT t.id::text, t.cod_itens_duplicata, t.status_pago, t.vl_parcela, t.vl_pago, t.dt_vencimento, t.dt_pagamento,
                      n.empresa_id::text, t.negociacao_id IS NOT NULL
                 FROM public.transacoes t LEFT JOIN public.negociacoes n ON n.id = t.negociacao_id WHERE t.tipo::text = %s""",
            (tipo,),
        )
        db = pd.DataFrame(cur.fetchall(), columns=["id", "cod", "status_pago", "vl_parcela", "vl_pago", "dt_venc", "dt_pag", "empresa_id", "tem_neg"])
        db["status"] = db["status_pago"].map(STATUS)
        db["vl_parcela"] = pd.to_numeric(db["vl_parcela"]).fillna(0.0)
        db["empresa"] = db["empresa_id"].map(nome_empresa).fillna("(sem empresa)")

        # 1) EM ABERTO por empresa
        pa = d[d["status"] == "aberta"].groupby("empresa").agg(planilha_qtd=("cod", "size"), planilha_valor=("vl_parcela", "sum"))
        sa = db[db["status"] == "aberta"].groupby("empresa").agg(sistema_qtd=("id", "size"), sistema_valor=("vl_parcela", "sum"))
        ab = pa.join(sa, how="outer").fillna(0.0)
        ab["dif_qtd"] = ab["sistema_qtd"] - ab["planilha_qtd"]
        ab["dif_valor"] = (ab["sistema_valor"] - ab["planilha_valor"]).round(2)
        tot = ab.sum(numeric_only=True)
        fecha = bool((ab["dif_qtd"] == 0).all() and (ab["dif_valor"].abs() < 0.01).all())
        fecha_total = bool(abs(tot.sistema_qtd - tot.planilha_qtd) == 0 and abs(tot.sistema_valor - tot.planilha_valor) < 0.01)
        aberta_fecha &= fecha
        print("EM ABERTO por empresa (planilha × sistema):")
        for emp, r in ab.iterrows():
            print(f"  {emp:16s} planilha {int(r.planilha_qtd):5d} · {brl(r.planilha_valor):>18s} | sistema {int(r.sistema_qtd):5d} · {brl(r.sistema_valor):>18s} | dif {int(r.dif_qtd):+d} · {brl(r.dif_valor)}")
        print(f"  TOTAL            planilha {int(tot.planilha_qtd):5d} · {brl(tot.planilha_valor):>18s} | sistema {int(tot.sistema_qtd):5d} · {brl(tot.sistema_valor):>18s}  => TOTAL {'FECHA' if fecha_total else 'NÃO FECHA'} | POR EMPRESA {'FECHA' if fecha else 'NÃO FECHA'}")
        abas[f"{chave}_abertas_por_empresa"] = ab.reset_index()

        # 2) planilha × sistema por código
        cods_planilha = set(d["cod"].dropna().astype(int))
        db_cod = db.dropna(subset=["cod"]).copy()
        db_cod["cod"] = db_cod["cod"].astype(int)
        cods_db = set(db_cod["cod"])
        fora = d[~d["cod"].isin(cods_db)]
        print(f"Linhas da planilha ausentes do sistema: {len(fora)}")
        abas[f"{chave}_planilha_fora_do_sistema"] = fora[["cod", "status", "vl_parcela", "empresa"]]

        por_cod = {k: g for k, g in db_cod.groupby("cod")}
        div_status, div_valor, div_emp = [], [], []
        for _, r in d.dropna(subset=["cod"]).iterrows():
            g = por_cod.get(int(r["cod"]))
            if g is None:
                continue
            mesmo = g[g["status"] == r["status"]]
            if mesmo.empty:
                div_status.append({"cod": int(r["cod"]), "planilha": r["status"], "sistema": ", ".join(sorted(set(g["status"]))), "vl_planilha": r["vl_parcela"], "linhas_no_sistema": len(g)})
            elif not ((mesmo["vl_parcela"] - r["vl_parcela"]).abs() < 0.01).any():
                div_valor.append({"cod": int(r["cod"]), "status": r["status"], "vl_planilha": r["vl_parcela"], "vl_sistema": float(mesmo.iloc[0]["vl_parcela"]), "linhas_no_sistema": len(g)})
            elif not (mesmo["empresa"] == r["empresa"]).any():
                div_emp.append({"cod": int(r["cod"]), "status": r["status"], "empresa_planilha": r["empresa"], "empresa_sistema": ", ".join(sorted(set(mesmo["empresa"]))), "vl_parcela": r["vl_parcela"]})
        ds, dv = pd.DataFrame(div_status), pd.DataFrame(div_valor)
        print(f"Status divergente (nenhuma linha do sistema com o mesmo status): {len(ds)} | valor da parcela divergente: {len(dv)}")
        if len(ds):
            print("  status divergentes:", ds.groupby(["planilha", "sistema"]).size().to_dict())
        de = pd.DataFrame(div_emp)
        print(f"Empresa divergente (planilha × negociação do sistema), com status e valor iguais: {len(de)}")
        if len(de):
            print("  por par (planilha -> sistema):", de.groupby(["empresa_planilha", "empresa_sistema"]).size().to_dict())
            print("  das abertas:", de[de["status"] == "aberta"].groupby(["empresa_planilha", "empresa_sistema"]).size().to_dict())
        abas[f"{chave}_status_divergente"] = ds
        abas[f"{chave}_valor_divergente"] = dv
        abas[f"{chave}_empresa_divergente"] = de

        # 3) aberta no sistema fora da planilha / aberta na planilha que não está aberta no sistema
        so_db_abertas = db_cod[(db_cod["status"] == "aberta") & (~db_cod["cod"].isin(cods_planilha))]
        sem_cod_abertas = db[(db["status"] == "aberta") & (db["cod"].isna())]
        print(f"Abertas no sistema fora da planilha: {len(so_db_abertas)} | abertas no sistema SEM código da Connect (lançadas aqui): {len(sem_cod_abertas)}")
        abas[f"{chave}_abertas_so_no_sistema"] = pd.concat([so_db_abertas, sem_cod_abertas])[["id", "cod", "status", "vl_parcela", "dt_venc", "empresa"]]

        # 4) só no sistema (histórico)
        so_db = db_cod[~db_cod["cod"].isin(cods_planilha)]
        print(f"Linhas só no sistema (fora do período da planilha): {len(so_db)} — {so_db['status'].value_counts().to_dict()}")
        repetidos = db_cod.groupby("cod").size()
        print(f"Códigos repetidos no sistema (acordos/duplicatas): {int((repetidos > 1).sum())}")

        resumo_linhas.append({"sistema": titulo, "planilha": Path(arq).name, "linhas_planilha": len(d), "abertas_total_fecha": "SIM" if fecha_total else "NÃO", "abertas_planilha": int(tot.planilha_qtd),
                              "valor_abertas_planilha": round(float(tot.planilha_valor), 2), "abertas_sistema": int(tot.sistema_qtd),
                              "valor_abertas_sistema": round(float(tot.sistema_valor), 2), "abertas_por_empresa_fecham": "SIM" if fecha else "NÃO",
                              "planilha_fora_do_sistema": len(fora), "status_divergente": len(ds), "valor_divergente": len(dv),
                              "empresa_divergente": len(de), "abertas_so_no_sistema": len(so_db_abertas) + len(sem_cod_abertas), "linhas_so_no_sistema": len(so_db)})

    con.close()
    with pd.ExcelWriter(xlsx) as w:
        pd.DataFrame(resumo_linhas).to_excel(w, sheet_name="resumo", index=False)
        for nome, df in abas.items():
            df.to_excel(w, sheet_name=nome[:31], index=False)
    print(f"\nExcel: {xlsx}")
    print("RESULTADO: as listas EM ABERTO " + ("FECHAM com a planilha, no total e por empresa (diferença zero)." if aberta_fecha else "NÃO fecham por empresa com a planilha — ver o Excel (abas *_empresa_divergente)."))
    sys.exit(0 if aberta_fecha else 1)


if __name__ == "__main__":
    main()
