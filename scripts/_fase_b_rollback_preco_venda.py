"""
SPEC-132 Fase B — reparo do preco_venda.

O import fiscal disparou o trigger trg_calculo_preco_venda (BEFORE UPDATE em
TODAS as colunas — eu tinha visto só o trg_atualizar_preco_venda, que é
column-scoped). Por isso a regravação inline do preco_venda não colou: ela
mesma redisparava o cálculo. ~2120 produtos ficaram com preco_venda inflado
(fórmula × 2.5 recalculada já com o IPI/despesas novos).

Este script restaura preco_venda a partir de scripts/../scratch_preco_venda_snapshot.json
(snapshot dos 4726 produtos, feito ~40-60s após o início do import — os ~200
produtos gravados nesse intervalo podem ter o valor do snapshot levemente
defasado; são listados no fim para revisão).

Roda com os 2 triggers de preço DESLIGADOS dentro de UMA transação (se algo
falhar, ROLLBACK e os triggers voltam sozinhos).

JÁ RODADO com sucesso em 2026-09-10 (2.120 produtos restaurados, 0 divergentes
no pós-reparo, triggers religados). Não roda de novo sem o snapshot — foi
movido pra fora do repo (era artefato temporário) depois de usado. Fica aqui
só como registro do incidente e do reparo, não é reutilizável como está.

    python scripts/_fase_b_rollback_preco_venda.py --dry-run
    python scripts/_fase_b_rollback_preco_venda.py
"""

import argparse
import json
import re
import sys
from pathlib import Path

import psycopg2
from psycopg2.extras import execute_batch

ROOT = Path(__file__).resolve().parent.parent
SNAP = ROOT / "scratch_preco_venda_snapshot.json"


def _dsn() -> str:
    env = {}
    for line in (ROOT / ".env").read_text(encoding="utf-8").splitlines():
        m = re.match(r"^([A-Z_]+)=(.*)$", line.strip())
        if m:
            env.setdefault(m.group(1), m.group(2))
    return env["SUPABASE_DB_URL"]


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()

    snap = json.loads(SNAP.read_text())
    c = psycopg2.connect(_dsn())
    cur = c.cursor()
    cur.execute("select id::text, codigo_produto, preco_venda from public.produtos")
    alvo = []
    for id_, cod, pv in cur.fetchall():
        old = snap.get(id_)
        o = None if old is None or str(old) == "nan" else float(old)
        cp = None if pv is None else float(pv)
        if o is None and cp is None:
            continue
        if o is None or cp is None or abs(o - cp) > 0.01:
            alvo.append((id_, cod, o))

    print(f"produtos a restaurar preco_venda: {len(alvo)}")
    if args.dry_run:
        for i, cd, v in alvo[:20]:
            print(f"  cod {cd}: -> {v}")
        print("DRY-RUN: nada gravado")
        return

    try:
        cur.execute("BEGIN")
        cur.execute("ALTER TABLE public.produtos DISABLE TRIGGER trg_calculo_preco_venda")
        cur.execute("ALTER TABLE public.produtos DISABLE TRIGGER trg_atualizar_preco_venda")
        execute_batch(
            cur,
            "UPDATE public.produtos SET preco_venda = %s WHERE id = %s::uuid",
            [(v, i) for (i, _cd, v) in alvo],
            page_size=500,
        )
        cur.execute("ALTER TABLE public.produtos ENABLE TRIGGER trg_calculo_preco_venda")
        cur.execute("ALTER TABLE public.produtos ENABLE TRIGGER trg_atualizar_preco_venda")
        cur.execute("COMMIT")
    except Exception as exc:  # noqa: BLE001
        cur.execute("ROLLBACK")
        print("FALHOU — transação revertida, triggers intactos:", exc)
        raise

    cur.execute("select id::text, preco_venda from public.produtos")
    bad = 0
    for id_, pv in cur.fetchall():
        old = snap.get(id_)
        o = None if old is None or str(old) == "nan" else float(old)
        cp = None if pv is None else float(pv)
        if (o is None) != (cp is None) or (o is not None and cp is not None and abs(o - cp) > 0.01):
            bad += 1
    cur.execute(
        """select tgname, tgenabled from pg_trigger t join pg_class cl on cl.oid=t.tgrelid
        where cl.relname='produtos' and tgname in
        ('trg_calculo_preco_venda','trg_atualizar_preco_venda')"""
    )
    print(f"pós-reparo: {bad} ainda diferentes do snapshot; triggers: {cur.fetchall()} (O=enabled)")
    c.close()


if __name__ == "__main__":
    main()
