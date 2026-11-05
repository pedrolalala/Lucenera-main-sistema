"""
SPEC-226 — Importa para a Logística (tabela `separacoes`) as separações exportadas do sistema Lovable (CSV `separacoes-export-*.csv`).

Regras:
  * SÓ INSERE o que ainda não existe (pelo `id`). Quem já está no banco NÃO é alterado: o sistema novo pode ter mudado depois da primeira carga.
  * status `em_separacao` do Lovable -> 'Em separação' do sistema novo; os demais status têm o mesmo nome.
  * vazio vira NULL; `separacoes_parciais` e `material_conteudo` viram jsonb; `numero_venda` fica como texto (igual às linhas já importadas).
  * Insere com o status final (sem UPDATE), então os gatilhos que movimentam saldo/estoque ao mudar o status (finalizar, ficar pronto) NÃO disparam.
  * Anexos e fotos NÃO vêm no CSV (ficam no storage do Lovable).
  * Confere antes×depois: estoque, saldos, itens de separação e entregas não podem mudar.

Uso:
  python scripts/importar_separacoes_lovable.py [arquivo.csv]            # DRY-RUN (transação desfeita)
  python scripts/importar_separacoes_lovable.py [arquivo.csv] --aplicar  # grava
"""

from __future__ import annotations

import argparse
import glob
import json
import sys
from pathlib import Path

import pandas as pd
import psycopg2
import psycopg2.extras

if sys.stdout.encoding and sys.stdout.encoding.lower() != "utf-8":
    sys.stdout.reconfigure(encoding="utf-8")

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "scripts"))
from _supabase_client import SUPABASE_DB_URL, para_pooler  # noqa: E402

PASTA = ROOT / "01-Documento" / "01 - Planilhas"
BOOLS = {"inclui_garantia", "order_in_route", "inclui_devolucao"}
JSONS = {"separacoes_parciais", "material_conteudo"}

FOTO = """
SELECT concat_ws('|',
  (SELECT coalesce(sum(quantidade),0) || '/' || coalesce(sum(quantidade_reservada),0) FROM public.estoque_itens),
  (SELECT coalesce(sum(q_reserva),0) || '/' || coalesce(sum(q_entrega_futura),0) || '/' || coalesce(sum(q_ag_separar),0) || '/' || coalesce(sum(q_separado),0) || '/' || coalesce(sum(q_entregue),0) FROM public.estoque_saldos_projeto_item),
  (SELECT count(*) FROM public.separacao_itens), (SELECT count(*) FROM public.entregas), (SELECT count(*) FROM public.separacao_arquivos),
  (SELECT count(*) FROM public.transacoes), (SELECT count(*) FROM public.vendas))
"""


def valor(col: str, v: str):
    v = (v or "").strip()
    if v == "":
        return None
    if col in BOOLS:
        return v.lower() == "true"
    if col in JSONS:
        try:
            return psycopg2.extras.Json(json.loads(v))
        except ValueError:
            return None
    return v


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("arquivo", nargs="?")
    ap.add_argument("--aplicar", action="store_true")
    args = ap.parse_args()
    arq = args.arquivo or sorted(glob.glob(str(PASTA / "separacoes-export-*.csv")))[-1]
    df = pd.read_csv(arq, sep=";", encoding="utf-8-sig", dtype=str, keep_default_na=False)
    print(f"Arquivo: {Path(arq).name} | {len(df)} linhas | colunas: {len(df.columns)}")

    con = psycopg2.connect(para_pooler(SUPABASE_DB_URL), connect_timeout=30)
    cur = con.cursor()
    try:
        cur.execute("SELECT column_name FROM information_schema.columns WHERE table_schema='public' AND table_name='separacoes'")
        tabela = {r[0] for r in cur.fetchall()}
        extra = [c for c in df.columns if c not in tabela]
        if extra:
            sys.exit(f"Colunas do CSV que não existem na tabela: {extra}")
        cur.execute("SELECT enumlabel FROM pg_enum e JOIN pg_type t ON t.oid = e.enumtypid WHERE t.typname = 'separacao_status'")
        labels = {r[0] for r in cur.fetchall()}
        em_sep = next(l for l in labels if l.lower().startswith("em separa"))

        cur.execute("SELECT id::text FROM public.separacoes")
        existentes = {r[0] for r in cur.fetchall()}
        novos = df[~df["id"].isin(existentes)].copy()
        ja = df[df["id"].isin(existentes)]
        print(f"Já no banco (não mexo): {len(ja)} | novos a inserir: {len(novos)}")

        novos["status"] = novos["status"].map(lambda s: em_sep if s == "em_separacao" else s)
        ruins = sorted(set(novos["status"]) - labels)
        if ruins:
            sys.exit(f"Status sem correspondência no banco: {ruins}")
        print("Novos por status:", novos["status"].value_counts().to_dict())

        cur.execute(FOTO)
        antes = cur.fetchone()[0]
        cur.execute("SELECT count(*) FROM public.separacoes")
        total_antes = cur.fetchone()[0]
        cols = list(novos.columns)
        linhas = [tuple(valor(c, r[c]) for c in cols) for _, r in novos.iterrows()]
        sql = f"INSERT INTO public.separacoes ({', '.join(cols)}) VALUES %s ON CONFLICT (id) DO NOTHING"
        psycopg2.extras.execute_values(cur, sql, linhas, page_size=100, template="(" + ", ".join(
            "%s::separacao_status" if c == "status" else "%s" for c in cols) + ")")
        cur.execute("SELECT count(*) FROM public.separacoes")
        inseridos = cur.fetchone()[0] - total_antes  # rowcount do execute_values só vale para a última página
        cur.execute(FOTO)
        depois = cur.fetchone()[0]
        igual = antes == depois
        print(f"Inseridos: {inseridos}")
        print("Fotografia antes :", antes)
        print("Fotografia depois:", depois)
        print("Estoque, saldos, itens, entregas, anexos, financeiro e vendas IGUAIS:", "SIM" if igual else "NÃO")
        cur.execute("SELECT status::text, count(*) FROM public.separacoes GROUP BY 1 ORDER BY 2 DESC")
        print("Banco depois, por status:", dict(cur.fetchall()))
        cur.execute("SELECT count(*), count(*) FILTER (WHERE numero_entrega IS NULL) FROM public.separacoes")
        print("Total / sem número de entrega:", cur.fetchone())

        if not igual or inseridos != len(novos):
            print("ABORTADO: uma conferência falhou; nada foi gravado.")
            con.rollback()
            sys.exit(1)
        if args.aplicar:
            con.commit()
            print("GRAVADO.")
        else:
            con.rollback()
            print("DRY-RUN: tudo desfeito, nada foi gravado.")
    except SystemExit:
        con.rollback()
        raise
    except Exception:
        con.rollback()
        raise
    finally:
        con.close()


if __name__ == "__main__":
    main()
