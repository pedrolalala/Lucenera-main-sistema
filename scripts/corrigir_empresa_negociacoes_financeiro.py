"""
SPEC-245 (G9/D7) — Corrige a EMPRESA das negociações do Contas a Receber / Contas a Pagar conforme a planilha do dia.

No sistema a empresa de cada parcela vem da negociação (transacoes.empresa_id não é usado). A planilha traz a empresa por linha (LUCE NERA = MANOELLA,
ISLIGHT, FOCO ILUMINACAO) e é a fonte confiável. Este script alinha `negociacoes.empresa_id` à planilha:

  * só mexe na negociação cujas parcelas da planilha apontam para UMA única empresa;
  * PULA (e lista) as ambíguas (parcelas da mesma negociação em empresas diferentes na planilha) e as que colidiriam com a chave única
    (empresa_id, cod_duplicata, tipo) de outra negociação, ou de outra do mesmo lote;
  * guarda o antes/depois em backup._bkp_negociacoes_empresa_<data> (schema `backup`) e imprime/gera Excel com tudo;
  * não mexe em status, valor, vencimento, estoque nem vendas. Idempotente: depois de aplicado, rodar de novo não muda nada.

Uso:  python scripts/corrigir_empresa_negociacoes_financeiro.py            # DRY-RUN (transação desfeita)
      python scripts/corrigir_empresa_negociacoes_financeiro.py --aplicar  # grava
Depois: python scripts/conferir_contas_pagar_receber.py
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
NORMAL = {"LUCE NERA": "MANOELLA"}
CASOS = [("ContaReceber_", "receita"), ("ContaPagar_", "despesa")]


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--aplicar", action="store_true")
    args = ap.parse_args()

    con = psycopg2.connect(para_pooler(SUPABASE_DB_URL), connect_timeout=30)
    cur = con.cursor()
    try:
        cur.execute("SELECT id::text, nome FROM public.empresas")
        emp = dict(cur.fetchall())
        inv = {v: k for k, v in emp.items()}
        mudar, ambiguas, colisoes = [], [], []

        for prefixo, tipo in CASOS:
            d = pd.read_excel(descobrir_planilha_mais_recente(PASTA, prefixo))
            d["cod"] = pd.to_numeric(d["cod_itens_duplicata"], errors="coerce")
            d["empresa"] = d["nm_empresa"].astype(str).str.strip().str.upper().replace(NORMAL)
            d["status"] = pd.to_numeric(d["pago"], errors="coerce")
            d = d.dropna(subset=["cod"])
            d["cod"] = d["cod"].astype(int)
            cur.execute(
                "SELECT t.cod_itens_duplicata, t.negociacao_id::text, t.status_pago, n.empresa_id::text, n.cod_duplicata "
                "FROM public.transacoes t JOIN public.negociacoes n ON n.id = t.negociacao_id WHERE t.tipo::text = %s AND t.cod_itens_duplicata IS NOT NULL",
                (tipo,),
            )
            db = pd.DataFrame(cur.fetchall(), columns=["cod", "neg", "status_pago", "emp_id", "cod_dup"])
            m = d.merge(db, left_on=["cod", "status"], right_on=["cod", "status_pago"], how="inner")
            m["emp_sistema"] = m["emp_id"].map(emp)
            g = m.groupby("neg").agg(planilha=("empresa", lambda s: sorted(set(s))), sistema=("emp_sistema", "first"), parcelas=("cod", "size"), cod_dup=("cod_dup", "first")).reset_index()
            g["tipo"] = tipo
            amb = g[g["planilha"].map(len) > 1]
            for _, r in amb.iterrows():
                ambiguas.append({"tipo": tipo, "negociacao": r["neg"], "cod_duplicata": r["cod_dup"], "empresa_sistema": r["sistema"], "empresas_planilha": ", ".join(r["planilha"]), "parcelas": r["parcelas"]})
            uni = g[g["planilha"].map(len) == 1].copy()
            uni["alvo"] = uni["planilha"].map(lambda x: x[0])
            uni = uni[uni["alvo"] != uni["sistema"]]
            vistos: set[tuple] = set()
            for _, r in uni.iterrows():
                chave = (inv[r["alvo"]], r["cod_dup"], tipo)
                cur.execute(
                    "SELECT 1 FROM public.negociacoes WHERE empresa_id::text = %s AND cod_duplicata = %s AND tipo::text = %s AND id::text <> %s",
                    (chave[0], chave[1], tipo, r["neg"]),
                )
                if cur.fetchone() or chave in vistos:
                    colisoes.append({"tipo": tipo, "negociacao": r["neg"], "cod_duplicata": r["cod_dup"], "empresa_sistema": r["sistema"], "empresa_planilha": r["alvo"], "parcelas": r["parcelas"]})
                    continue
                vistos.add(chave)
                mudar.append({"tipo": tipo, "negociacao": r["neg"], "cod_duplicata": r["cod_dup"], "empresa_antes": r["sistema"], "empresa_depois": r["alvo"], "parcelas": int(r["parcelas"]),
                              "empresa_id_antes": inv[r["sistema"]], "empresa_id_depois": inv[r["alvo"]]})

        dm = pd.DataFrame(mudar)
        print(f"Negociações a corrigir: {len(dm)} ({int(dm['parcelas'].sum()) if len(dm) else 0} parcelas) | ambíguas puladas: {len(ambiguas)} | colisões puladas: {len(colisoes)}")
        if len(dm):
            print(dm.groupby(["tipo", "empresa_antes", "empresa_depois"]).size().to_string())

        saida = ROOT / "scripts" / "logs" / "conferencia_financeiro"
        saida.mkdir(parents=True, exist_ok=True)
        xlsx = saida / f"correcao_empresa_negociacoes_{datetime.now():%Y%m%d_%H%M%S}{'' if args.aplicar else '_dryrun'}.xlsx"
        with pd.ExcelWriter(xlsx) as w:
            dm.to_excel(w, sheet_name="corrigidas", index=False)
            pd.DataFrame(ambiguas).to_excel(w, sheet_name="ambiguas_puladas", index=False)
            pd.DataFrame(colisoes).to_excel(w, sheet_name="colisoes_puladas", index=False)
        print("Excel:", xlsx)

        if len(dm):
            cur.execute("SELECT (SELECT count(*) FROM public.transacoes), (SELECT count(*) FROM public.negociacoes), (SELECT coalesce(sum(vl_parcela),0) FROM public.transacoes)")
            antes = cur.fetchone()
            tabela = f"_bkp_negociacoes_empresa_{datetime.now():%Y%m%d_%H%M%S}"  # com hora: nunca sobrescreve o backup da rodada anterior
            cur.execute("CREATE SCHEMA IF NOT EXISTS backup")
            cur.execute(f"CREATE TABLE backup.{tabela} (negociacao_id uuid PRIMARY KEY, tipo text, cod_duplicata integer, empresa_id_antes uuid, empresa_id_depois uuid, parcelas integer, criado_em timestamptz DEFAULT now())")
            psycopg2.extras.execute_values(
                cur, f"INSERT INTO backup.{tabela} (negociacao_id, tipo, cod_duplicata, empresa_id_antes, empresa_id_depois, parcelas) VALUES %s",
                [(r.negociacao, r.tipo, int(r.cod_duplicata), r.empresa_id_antes, r.empresa_id_depois, r.parcelas) for r in dm.itertuples()],
                template="(%s::uuid, %s, %s, %s::uuid, %s::uuid, %s)", page_size=500)
            psycopg2.extras.execute_values(
                cur, "UPDATE public.negociacoes n SET empresa_id = v.novo::uuid FROM (VALUES %s) AS v(id, novo) WHERE n.id = v.id::uuid",
                [(r.negociacao, r.empresa_id_depois) for r in dm.itertuples()], page_size=500)
            cur.execute("SELECT (SELECT count(*) FROM public.transacoes), (SELECT count(*) FROM public.negociacoes), (SELECT coalesce(sum(vl_parcela),0) FROM public.transacoes)")
            depois = cur.fetchone()
            print("Transações / negociações / soma das parcelas antes:", antes, "| depois:", depois, "->", "IGUAL" if antes == depois else "DIFERENTE")
            if antes != depois:
                raise SystemExit("ABORTADO: contagens ou valores mudaram; nada foi gravado.")
            print(f"Backup: backup.{tabela} ({len(dm)} negociações)")

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
