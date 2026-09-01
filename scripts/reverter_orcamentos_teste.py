"""
SPEC-126 Escopo 2A — reverte os orçamentos de TESTE feitos dentro do sistema
novo (Orçamentos/Projetos), para o Dashboard e o estoque pararem de contar
dados que não são reais.

Critério (usuário, 01/09/2026): *todo* orçamento criado dentro do sistema e
aprovado (que passou pelo processo interno) é teste. O resto da informação
financeira vem do import das planilhas do Connect (`transacoes`/`negociacoes`),
que este script NÃO toca.

Estado medido em 01/09 no Supabase real:
  - 22 orçamentos no total: 19 `status='Orçamento Aprovado'` (teste) + 3 rascunho
  - 40 projeto_itens (100% da tabela), 41 projeto_parcelas, 36 boletos
    (9 "Remessa Enviada", 26 "pendente_registro", 1 "Pago"), 72
    estoque_movimentos_projeto_item, 18 separacao_itens em 11 separações,
    2 entregas, 6 entregas_pendentes.
  - boletos NÃO têm FK para negociacoes/transacoes — a "relação bancária" desses
    orçamentos É a própria tabela `boletos`.

O RPC `cancelar_orcamento` NÃO resolve sozinho: ele só roda a reversão quando
`status = 'aprovado'` literal; aqui o status é `'Orçamento Aprovado'`. Por isso
este script replica a lógica dele (passos 3a/3b/3c/3d/3e) + a parte de
separação/logística que o RPC não cobre.

O que faz por orçamento (CANCELA, não apaga — preserva histórico):
  1. Libera `estoque_itens.quantidade_reservada` pelo saldo aberto real.
  2. Registra movimento 'cancelamento' em estoque_movimentos_projeto_item.
  3. `estoque_saldos_projeto_item` -> status 'cancelado', zera posições abertas.
  4. separacao_itens -> estornado; separacoes/entregas -> 'Cancelado';
     entregas_pendentes das separações de teste -> removidas.
  5. boletos -> 'cancelado'  (todos, inclusive "Pago"/"Remessa Enviada").
  6. projeto_parcelas -> 'cancelada'.
  7. projeto_itens -> validado = false.
  8. orcamentos -> 'cancelado' + linha em historico_status_orcamentos.
Os 3 rascunhos ficam como estão (nunca aprovados, sem efeito colateral).

Uso:
  python scripts/reverter_orcamentos_teste.py            # DRY-RUN (padrão)
  python scripts/reverter_orcamentos_teste.py --aplicar  # grava
"""

import argparse
import sys
from pathlib import Path

if sys.stdout.encoding and sys.stdout.encoding.lower() != "utf-8":
    sys.stdout.reconfigure(encoding="utf-8")

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "scripts"))

from _supabase_client import get_client, SUPABASE_URL  # noqa: E402

STATUS_TESTE = "Orçamento Aprovado"
MOTIVO = "Reversão de orçamento de teste — SPEC-126 Escopo 2A"
POS_ABERTAS = ("q_reserva", "q_entrega_futura", "q_ag_separar", "q_separado")


def allrows(client, table, columns):
    out, off = [], 0
    while True:
        r = client.table(table).select(columns).range(off, off + 999).execute()
        d = r.data or []
        out += d
        if len(d) < 1000:
            break
        off += 1000
    return out


def processar(aplicar: bool) -> None:
    print(f"Supabase: {SUPABASE_URL}")
    print(f"Modo:     {'GRAVAÇÃO REAL' if aplicar else 'DRY-RUN (nada gravado)'}\n")
    c = get_client()

    orc = allrows(c, "orcamentos", "id,numero,status,projeto_id")
    teste = [o for o in orc if o["status"] == STATUS_TESTE]
    orc_ids = {o["id"] for o in teste}
    proj_ids = {o["projeto_id"] for o in teste if o.get("projeto_id")}
    print(f"Orçamentos de teste (status {STATUS_TESTE!r}): {len(teste)}")
    print("  " + ", ".join(sorted(o["numero"] or o["id"][:8] for o in teste)))
    rascunhos = [o for o in orc if o["status"] == "rascunho"]
    print(f"Rascunhos deixados intactos: {len(rascunhos)}\n")
    if not teste:
        print("Nada a fazer.")
        return

    pit = [r for r in allrows(c, "projeto_itens", "id,orcamento_id,validado") if r.get("orcamento_id") in orc_ids]
    pit_ids = {r["id"] for r in pit}
    saldos = [r for r in allrows(
        c, "estoque_saldos_projeto_item",
        "projeto_item_id,status_operacional," + ",".join(POS_ABERTAS),
    ) if r.get("projeto_item_id") in pit_ids and r.get("status_operacional") == "ativo"]
    parc = [r for r in allrows(c, "projeto_parcelas", "id,orcamento_id,status") if r.get("orcamento_id") in orc_ids]
    bol = [r for r in allrows(c, "boletos", "id,orcamento_id,status,nosso_numero") if r.get("orcamento_id") in orc_ids]

    # separação / logística
    si_all = allrows(c, "separacao_itens", "id,separacao_id,projeto_item_id,quantidade,quantidade_estornada,separado,entregue")
    si = [r for r in si_all if r.get("projeto_item_id") in pit_ids]
    sep_ids = sorted({r["separacao_id"] for r in si if r.get("separacao_id")})
    sep = [r for r in allrows(c, "separacoes", "id,status") if r["id"] in sep_ids]
    ent = [r for r in allrows(c, "entregas", "id,separacao_id,status") if r.get("separacao_id") in sep_ids]
    entp = [r for r in allrows(c, "entregas_pendentes", "id,separacao_id") if r.get("separacao_id") in sep_ids]

    # saldo aberto por produto (via projeto_item) para liberar reserva
    pit_produto = {r["id"]: None for r in pit}
    for r in allrows(c, "projeto_itens", "id,produto_id"):
        if r["id"] in pit_produto:
            pit_produto[r["id"]] = r.get("produto_id")
    aberto_por_produto: dict[str, float] = {}
    aberto_por_item: dict[str, float] = {}
    for s in saldos:
        q = sum(float(s.get(k) or 0) for k in POS_ABERTAS)
        aberto_por_item[s["projeto_item_id"]] = q
        prod = pit_produto.get(s["projeto_item_id"])
        if prod and q > 0:
            aberto_por_produto[prod] = aberto_por_produto.get(prod, 0) + q

    ei = allrows(c, "estoque_itens", "id,produto_id,local,quantidade_reservada")
    ei_estoque = {r["produto_id"]: r for r in ei if r.get("local") == "Estoque"}
    liberacoes = []
    for prod, qtd in aberto_por_produto.items():
        row = ei_estoque.get(prod)
        if not row:
            continue
        atual = float(row.get("quantidade_reservada") or 0)
        novo = max(0.0, atual - qtd)
        if abs(novo - atual) > 1e-9:
            liberacoes.append((row["id"], prod, atual, novo, qtd))

    from collections import Counter
    print("=== O QUE SERÁ REVERTIDO ===")
    print(f"1. estoque_itens.quantidade_reservada: {len(liberacoes)} linhas liberadas "
          f"(total {sum(a - n for _, _, a, n, _ in liberacoes):.2f} un.)")
    print(f"2. estoque_movimentos_projeto_item: {sum(1 for v in aberto_por_item.values() if v > 0)} "
          f"movimentos 'cancelamento' inseridos")
    print(f"3. estoque_saldos_projeto_item: {len(saldos)} -> 'cancelado' (posições abertas zeradas)")
    print(f"4. separacao_itens: {len(si)} estornados | separacoes: {len(sep)} -> 'Cancelado' "
          f"(já cancelado: {sum(1 for s in sep if s['status'] == 'Cancelado')}) | "
          f"entregas: {len(ent)} -> 'Cancelado' | entregas_pendentes: {len(entp)} removidas")
    print(f"5. boletos: {len(bol)} -> 'cancelado'  (status atuais: {dict(Counter(b['status'] for b in bol))})")
    print(f"6. projeto_parcelas: {len(parc)} -> 'cancelada'  "
          f"(status atuais: {dict(Counter(p['status'] for p in parc))})")
    print(f"7. projeto_itens: {sum(1 for r in pit if r.get('validado'))} -> validado=false")
    print(f"8. orcamentos: {len(teste)} -> 'cancelado' + {len(teste)} linhas em historico_status_orcamentos")
    print()

    if not aplicar:
        print("=== DRY-RUN: nada foi gravado. Rode com --aplicar para executar. ===")
        return

    print("Aplicando…")
    # 1 + 2 + 3
    for s in saldos:
        pi_id = s["projeto_item_id"]
        q = aberto_por_item.get(pi_id, 0)
        if q > 0:
            c.table("estoque_movimentos_projeto_item").insert({
                "projeto_item_id": pi_id, "tipo": "cancelamento", "quantidade": q,
                "origem": "reverter_orcamentos_teste", "observacao": MOTIVO,
            }).execute()
        c.table("estoque_saldos_projeto_item").update({
            "status_operacional": "cancelado",
            **{k: 0 for k in POS_ABERTAS},
        }).eq("projeto_item_id", pi_id).eq("status_operacional", "ativo").execute()
    for ei_id, _prod, _atual, novo, _q in liberacoes:
        c.table("estoque_itens").update({"quantidade_reservada": novo}).eq("id", ei_id).execute()
    print(f"  estoque: {len(saldos)} saldos, {len(liberacoes)} reservas liberadas.")

    # 4
    for r in si:
        c.table("separacao_itens").update({
            "quantidade_estornada": r.get("quantidade") or 0, "separado": False, "entregue": False,
        }).eq("id", r["id"]).execute()
    for r in sep:
        if r["status"] != "Cancelado":
            c.table("separacoes").update({"status": "Cancelado"}).eq("id", r["id"]).execute()
    for r in ent:
        c.table("entregas").update({"status": "Cancelado"}).eq("id", r["id"]).execute()
    for r in entp:
        c.table("entregas_pendentes").delete().eq("id", r["id"]).execute()
    print(f"  separação: {len(si)} itens, {len(sep)} separações, {len(ent)} entregas, {len(entp)} pendentes.")

    # 5
    for b in bol:
        c.table("boletos").update({"status": "cancelado"}).eq("id", b["id"]).execute()
    # 6
    for p in parc:
        c.table("projeto_parcelas").update({"status": "cancelada"}).eq("id", p["id"]).execute()
    # 7
    for r in pit:
        if r.get("validado"):
            c.table("projeto_itens").update({"validado": False}).eq("id", r["id"]).execute()
    print(f"  boletos: {len(bol)} | parcelas: {len(parc)} | itens invalidados.")

    # 8 — data_inicio_pagamento=None junto: a CHECK constraint
    # `orcamentos_data_inicio_pagamento_check` (NOT VALID) rejeita qualquer UPDATE
    # se data_inicio_pagamento < hoje; como é orçamento de teste sendo cancelado,
    # zerar a data é inócuo e destrava o cancelamento.
    for o in teste:
        c.table("orcamentos").update(
            {"status": "cancelado", "data_inicio_pagamento": None}
        ).eq("id", o["id"]).execute()
        c.table("historico_status_orcamentos").insert({
            "orcamento_id": o["id"], "status_anterior": STATUS_TESTE, "status_novo": "cancelado",
            "usuario": "sistema-reversao-teste", "observacao": MOTIVO,
        }).execute()
    print(f"  orcamentos: {len(teste)} cancelados + histórico.\n")
    print("=== CONCLUÍDO ===")


def main():
    ap = argparse.ArgumentParser(description="Reverte orçamentos de teste (SPEC-126 Escopo 2A)")
    ap.add_argument("--aplicar", action="store_true", help="Grava de verdade (padrão é dry-run)")
    processar(ap.parse_args().aplicar)


if __name__ == "__main__":
    main()
