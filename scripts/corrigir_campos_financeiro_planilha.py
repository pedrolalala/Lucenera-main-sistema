"""
SPEC-245 (G12) — Alinha ao que a PLANILHA do dia diz os campos de backend do Contas a Receber / Contas a Pagar que a auditoria
(scripts/auditar_financeiro_vs_planilha.py) achou diferentes:

  * negociacoes.plano_contas_id  <- planilha cod_apropriacao (via plano_de_contas.codigo_connect; alias 10000007 -> 90000014, decisão de 22/09).
    Causa do erro: 2.981 negociações de RECEBER carregavam a conta de DESPESA da duplicata de MESMO NÚMERO (cópia de 29/06/26).
  * negociacoes.cod_venda        <- planilha cod_venda, só PREENCHE quando o sistema está vazio/0 (não sobrescreve um valor diferente: lista o conflito).
  * negociacoes.total_parc       <- planilha total_parc (o sistema ficou com o total de quando a duplicata nasceu; acordos acrescentam parcelas).
  * transacoes.tipo_pagamento    <- planilha tipo_pagamento (a planilha muda de "Duplicata Gerada" para "Pix"/"Cartão" quando paga; o importador não atualizava).

Só altera uma negociação quando TODAS as linhas dela na planilha concordam com um único valor (senão lista em "conflitos"). Não mexe em status, valores,
datas, empresa, pessoa, estoque nem vendas. Backup campo a campo em backup._bkp_financeiro_campos_<data_hora>. Idempotente.

Uso:  python scripts/corrigir_campos_financeiro_planilha.py            # DRY-RUN (transação desfeita)
      python scripts/corrigir_campos_financeiro_planilha.py --aplicar  # grava
Depois: python scripts/auditar_financeiro_vs_planilha.py
"""

from __future__ import annotations

import argparse
import sys
from datetime import datetime
from pathlib import Path

import pandas as pd
import psycopg2
import psycopg2.extras

if sys.stdout.encoding and sys.stdout.encoding.lower() != "utf-8":
    sys.stdout.reconfigure(encoding="utf-8")

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "scripts"))
from _supabase_client import SUPABASE_DB_URL, para_pooler  # noqa: E402
from sync_connect_common import descobrir_planilha_mais_recente  # noqa: E402

PASTA = ROOT / "01-Documento" / "01 - Planilhas"
CASOS = [("ContaReceber_", "receita"), ("ContaPagar_", "despesa")]
PC_ALIAS = {10000007: 90000014}


def ival(v):
    n = pd.to_numeric(v, errors="coerce")
    return None if pd.isna(n) else int(n)


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--aplicar", action="store_true")
    args = ap.parse_args()
    con = psycopg2.connect(para_pooler(SUPABASE_DB_URL), connect_timeout=30)
    cur = con.cursor()
    try:
        cur.execute("SELECT codigo_connect, id::text FROM public.plano_de_contas WHERE codigo_connect IS NOT NULL")
        pc_map = {int(c): i for c, i in cur.fetchall()}
        for novo, antigo in PC_ALIAS.items():
            if antigo in pc_map:
                pc_map[novo] = pc_map[antigo]

        mud_neg: dict[tuple, dict] = {}   # (negociacao, coluna) -> {antes, depois}
        mud_tx: dict[str, dict] = {}      # transacao -> {antes, depois}
        conflitos, sem_plano = [], []

        for prefixo, tipo in CASOS:
            d = pd.read_excel(descobrir_planilha_mais_recente(PASTA, prefixo))
            d["cod"] = pd.to_numeric(d["cod_itens_duplicata"], errors="coerce").astype("Int64")
            d["status_pl"] = pd.to_numeric(d["pago"], errors="coerce")
            cur.execute(
                """SELECT t.id::text, t.cod_itens_duplicata, t.status_pago, t.vl_parcela, t.tipo_pagamento, t.negociacao_id::text, n.plano_contas_id::text, n.cod_venda, n.total_parc
                     FROM public.transacoes t JOIN public.negociacoes n ON n.id = t.negociacao_id WHERE t.tipo::text = %s AND t.cod_itens_duplicata IS NOT NULL""",
                (tipo,),
            )
            db = pd.DataFrame(cur.fetchall(), columns=["tid", "cod", "status_db", "vl_db", "tpag_db", "neg", "plano_db", "venda_db", "total_db"])
            db["cod"] = db["cod"].astype("Int64")
            m = d.merge(db, on="cod", how="inner")
            m["_pref"] = (m["status_db"] == m["status_pl"]).astype(int) * 2 + ((m["vl_db"].astype(float) - pd.to_numeric(m["vl_parcela"], errors="coerce")).abs() < 0.01).astype(int)
            m = m.sort_values(["cod", "_pref"], ascending=[True, False]).drop_duplicates("cod", keep="first")

            # forma de pagamento (por transação)
            for r in m.itertuples(index=False):
                pl = str(r.tipo_pagamento).strip() if pd.notna(r.tipo_pagamento) else None
                if (pl or None) != (r.tpag_db or None) and pl:
                    mud_tx[r.tid] = {"antes": r.tpag_db, "depois": pl, "tipo": tipo}

            # por negociação
            for neg, g in m.groupby("neg"):
                atual_plano, atual_venda, atual_total = g["plano_db"].iloc[0], ival(g["venda_db"].iloc[0]), ival(g["total_db"].iloc[0])
                # plano de contas
                cods = {ival(x) for x in g["cod_apropriacao"] if ival(x) is not None}
                if len(cods) == 1:
                    cod = next(iter(cods))
                    alvo = pc_map.get(cod)
                    if alvo is None:
                        sem_plano.append({"tipo": tipo, "negociacao": neg, "cod_apropriacao": cod, "desc": str(g["desc_apropriacao"].iloc[0])})
                    elif alvo != atual_plano:
                        mud_neg[(neg, "plano_contas_id")] = {"antes": atual_plano, "depois": alvo, "tipo": tipo}
                elif len(cods) > 1:
                    conflitos.append({"tipo": tipo, "negociacao": neg, "campo": "plano", "valores": sorted(cods)})
                # cod_venda (só preenche vazio/0)
                vendas = {ival(x) for x in g["cod_venda"] if ival(x)}
                if len(vendas) == 1:
                    v = next(iter(vendas))
                    if not atual_venda:
                        mud_neg[(neg, "cod_venda")] = {"antes": atual_venda, "depois": v, "tipo": tipo}
                    elif atual_venda != v:
                        conflitos.append({"tipo": tipo, "negociacao": neg, "campo": "cod_venda (sistema já tem outro)", "valores": [atual_venda, v]})
                elif len(vendas) > 1:
                    conflitos.append({"tipo": tipo, "negociacao": neg, "campo": "cod_venda", "valores": sorted(vendas)})
                # total de parcelas
                totais = {ival(x) for x in g["total_parc"] if ival(x)}
                if len(totais) == 1:
                    t = next(iter(totais))
                    if t != atual_total:
                        mud_neg[(neg, "total_parc")] = {"antes": atual_total, "depois": t, "tipo": tipo}
                elif len(totais) > 1:
                    conflitos.append({"tipo": tipo, "negociacao": neg, "campo": "total_parc", "valores": sorted(totais)})

        res = pd.DataFrame([{"tabela": "negociacoes", "id": k[0], "coluna": k[1], "tipo": v["tipo"], "antes": v["antes"], "depois": v["depois"]} for k, v in mud_neg.items()]
                           + [{"tabela": "transacoes", "id": k, "coluna": "tipo_pagamento", "tipo": v["tipo"], "antes": v["antes"], "depois": v["depois"]} for k, v in mud_tx.items()])
        print("Alterações previstas por coluna e tipo:")
        print(res.groupby(["tabela", "coluna", "tipo"]).size().to_string() if len(res) else "  nenhuma")
        print(f"Conflitos (não alterados): {len(conflitos)} | contas sem plano correspondente: {len(sem_plano)}")

        saida = ROOT / "scripts" / "logs" / "conferencia_financeiro"
        saida.mkdir(parents=True, exist_ok=True)
        xlsx = saida / f"correcao_campos_{datetime.now():%Y%m%d_%H%M%S}{'' if args.aplicar else '_dryrun'}.xlsx"
        with pd.ExcelWriter(xlsx) as w:
            res.to_excel(w, sheet_name="alteracoes", index=False)
            pd.DataFrame(conflitos).to_excel(w, sheet_name="conflitos", index=False)
            pd.DataFrame(sem_plano).to_excel(w, sheet_name="sem_plano", index=False)
        print("Excel:", xlsx)

        if len(res):
            cur.execute("SELECT (SELECT count(*) FROM public.transacoes), (SELECT count(*) FROM public.negociacoes), (SELECT coalesce(sum(vl_parcela),0) FROM public.transacoes), "
                        "(SELECT coalesce(sum(vl_parcela),0) FROM public.transacoes WHERE status_pago = 0), (SELECT coalesce(sum(vl_pago),0) FROM public.transacoes)")
            antes = cur.fetchone()
            bk = f"_bkp_financeiro_campos_{datetime.now():%Y%m%d_%H%M%S}"
            cur.execute("CREATE SCHEMA IF NOT EXISTS backup")
            cur.execute(f"CREATE TABLE backup.{bk} (tabela text, id uuid, coluna text, antes text, depois text, criado_em timestamptz DEFAULT now())")
            psycopg2.extras.execute_values(cur, f"INSERT INTO backup.{bk} (tabela, id, coluna, antes, depois) VALUES %s",
                                           [(r.tabela, r.id, r.coluna, None if pd.isna(r.antes) else str(r.antes), str(r.depois)) for r in res.itertuples()],
                                           template="(%s, %s::uuid, %s, %s, %s)", page_size=1000)
            for col, cast in (("plano_contas_id", "uuid"), ("cod_venda", "integer"), ("total_parc", "integer")):
                lin = [(r.id, str(r.depois)) for r in res[(res.tabela == "negociacoes") & (res.coluna == col)].itertuples()]
                if lin:
                    psycopg2.extras.execute_values(cur, f"UPDATE public.negociacoes n SET {col} = v.novo::{cast} FROM (VALUES %s) AS v(id, novo) WHERE n.id = v.id::uuid", lin, page_size=1000)
            lin = [(r.id, str(r.depois)) for r in res[res.tabela == "transacoes"].itertuples()]
            if lin:
                psycopg2.extras.execute_values(cur, "UPDATE public.transacoes t SET tipo_pagamento = v.novo FROM (VALUES %s) AS v(id, novo) WHERE t.id = v.id::uuid", lin, page_size=1000)
            cur.execute("SELECT (SELECT count(*) FROM public.transacoes), (SELECT count(*) FROM public.negociacoes), (SELECT coalesce(sum(vl_parcela),0) FROM public.transacoes), "
                        "(SELECT coalesce(sum(vl_parcela),0) FROM public.transacoes WHERE status_pago = 0), (SELECT coalesce(sum(vl_pago),0) FROM public.transacoes)")
            depois = cur.fetchone()
            print("transações / negociações / soma das parcelas / soma em aberto / soma paga — antes:", antes, "| depois:", depois, "->", "IGUAL" if antes == depois else "DIFERENTE")
            if antes != depois:
                raise SystemExit("ABORTADO: contagens ou valores mudaram; nada foi gravado.")
            print(f"Backup: backup.{bk} ({len(res)} alterações)")

        if args.aplicar:
            con.commit()
            print("GRAVADO.")
        else:
            con.rollback()
            print("DRY-RUN: tudo desfeito, nada foi gravado.")
    except BaseException:
        con.rollback()
        raise
    finally:
        con.close()


if __name__ == "__main__":
    main()
