"""
Classifica em lote as despesas de SÃO PAULO no livro-caixa (`transacoes.perfil`).

Contexto (decisão do usuário, 03/09/2026): o "perfil" Ribeirão/São Paulo é só
um rótulo de visualização (SPEC-064). Marcar `perfil = 'sao_paulo'` NÃO cria
lançamento, NÃO muda valor e NÃO tira nada do total da empresa — apenas permite
o filtro "São Paulo" nas telas do Dashboard. Zero duplicação por construção.

Fonte: `01-Documento/01 - Planilhas/Custos - São Paulo .xlsx`, aba "Planilha5"
("Pagamentos - SÃO PAULO"). As abas 1-4 são transferências entre contas, não
despesa — ficam de fora.

Regras de match (todas em `transacoes`, tipo despesa):
  - descricao IN ('ALUGUEL SÃO PAULO', 'CONDOMINIO - SÃO PAULO')  -> todas as parcelas
  - descricao = 'IPTU'                        AND vl_parcela ~= 3228.21
  - descricao = 'SEGURO PATRIMONIAL - CERTO'  AND vl_parcela ~= 1118.86
  - descricao = 'REFORMAS'                    AND vl_parcela ~= 11746.35

Idempotente: só grava onde `perfil` ainda não é 'sao_paulo'. Rerun-safe — se um
import futuro do Connect trouxer novas parcelas dos mesmos itens, é só rodar de
novo.

Uso:
  python scripts/classificar_perfil_sao_paulo.py            # dry-run
  python scripts/classificar_perfil_sao_paulo.py --aplicar  # grava
"""

import argparse
import sys

if sys.stdout.encoding and sys.stdout.encoding.lower() != "utf-8":
    sys.stdout.reconfigure(encoding="utf-8")

sys.path.insert(0, "scripts")
from _supabase_client import get_client, SUPABASE_URL  # noqa: E402

PERFIL = "sao_paulo"

DESC_SEMPRE = {"ALUGUEL SÃO PAULO", "CONDOMINIO - SÃO PAULO"}
DESC_POR_VALOR = {
    ("IPTU", 3228.21),
    ("SEGURO PATRIMONIAL - CERTO", 1118.86),
    ("REFORMAS", 11746.35),
}
TOL = 0.02


def near(a, b, tol=TOL):
    return abs((a or 0) - (b or 0)) <= tol


def buscar_todas(client):
    rows = []
    frm = 0
    while True:
        resp = (
            client.table("transacoes")
            .select("id,descricao,tipo,dt_vencimento,dt_pagamento,vl_parcela,vl_pago,status_pago,perfil")
            .range(frm, frm + 999)
            .execute()
        )
        data = resp.data or []
        rows.extend(data)
        if len(data) < 1000:
            break
        frm += 1000
    return rows


def alvo(r):
    d = (r.get("descricao") or "").strip()
    if d in DESC_SEMPRE:
        return True
    for desc, val in DESC_POR_VALOR:
        if d == desc and near(r.get("vl_parcela"), val):
            return True
    return False


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--aplicar", action="store_true", help="grava (senão, dry-run)")
    args = ap.parse_args()

    print(f"Supabase: {SUPABASE_URL}")
    print(f"Modo:     {'GRAVAÇÃO REAL' if args.aplicar else 'DRY-RUN'}\n")

    client = get_client()
    todas = buscar_todas(client)
    print(f"{len(todas)} transacoes no banco\n")

    alvos = [r for r in todas if alvo(r)]
    ja_ok = [r for r in alvos if r.get("perfil") == PERFIL]
    a_gravar = [r for r in alvos if r.get("perfil") != PERFIL]

    # resumo por grupo
    grupos = {}
    for r in alvos:
        d = (r.get("descricao") or "").strip()
        chave = d if d in DESC_SEMPRE else f"{d} ~= valor"
        g = grupos.setdefault(chave, {"n": 0, "soma": 0.0, "pagas": 0})
        g["n"] += 1
        g["soma"] += r.get("vl_parcela") or 0
        if r.get("status_pago") == 1:
            g["pagas"] += 1

    print("=== ALVOS (Planilha5 — Pagamentos SÃO PAULO) ===")
    for chave, g in sorted(grupos.items()):
        print(f"  {g['n']:3}x  {chave:38}  pagas={g['pagas']}  Σ vl_parcela = R$ {g['soma']:,.2f}")
    print(f"\n  total alvos: {len(alvos)}  |  já em '{PERFIL}': {len(ja_ok)}  |  a gravar: {len(a_gravar)}")

    if not args.aplicar:
        print("\n=== DRY-RUN: nada gravado. Rode com --aplicar para gravar. ===")
        return

    ids = [r["id"] for r in a_gravar]
    ok = 0
    for i in range(0, len(ids), 100):
        lote = ids[i : i + 100]
        client.table("transacoes").update({"perfil": PERFIL}).in_("id", lote).execute()
        ok += len(lote)
        print(f"  gravadas {ok}/{len(ids)}", end="\r")
    print(f"\nConcluído: {ok} linhas -> perfil = '{PERFIL}'.")


if __name__ == "__main__":
    main()
