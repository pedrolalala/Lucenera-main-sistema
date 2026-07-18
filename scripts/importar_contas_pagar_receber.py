"""
Sincroniza transacoes (contas a pagar/receber) a partir das planilhas
ContaPagar_*.xlsx e ContaReceber_*.xlsx (export do sistema legado "Connect").

Modelo relacional (grounded em supabase/db/current/01_schema_full.sql):
  negociacoes  (1) -- (N) transacoes
  chave natural negociacoes:  UNIQUE (empresa_id, cod_duplicata, tipo)
  chave natural transacoes:   UNIQUE (negociacao_id, cod_itens_duplicata)

A planilha NAO diferencia ISLIGHT/FOCO/MANOELLA (cod_empresa/nm_empresa são
constantes em todas as linhas = "LUCE NERA"). Duplicatas cujo (cod_duplicata,
tipo) já existe em negociacoes (criadas por uma empresa real) são só
sincronizadas normalmente. Duplicatas GENUINAMENTE NOVAS (nunca importadas)
são criadas sob a empresa "LUCE NERA" (grupo/holding, ver decisão do usuário
em 2026-07-15) — nunca sob ISLIGHT/FOCO/MANOELLA, que exigiriam um dado que
não existe nesta planilha.

Combinações (cod_duplicata, tipo) AMBÍGUAS (já existem em mais de uma empresa
real) são puladas e reportadas — não são criadas sob LUCE NERA para não
arriscar duplicar uma negociação que já pertence a uma das 3 empresas reais.

Resolução de negociacoes novas:
  plano_contas_id  ← plano_de_contas.codigo_connect = cod_apropriacao
  funcionario_id   ← funcionarios.nm_connect        = nm_funcionario (upper/trim)
  contato_id       ← contatos.codigo_legado         = cod_pessoa

Uso:
  python scripts/importar_contas_pagar_receber.py --dry-run
  python scripts/importar_contas_pagar_receber.py
"""

import argparse
import sys
from pathlib import Path

import pandas as pd

if sys.stdout.encoding and sys.stdout.encoding.lower() != "utf-8":
    sys.stdout.reconfigure(encoding="utf-8")

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "dashboard"))

from config import get_client, SUPABASE_URL  # noqa: E402

CP_PADRAO = ROOT / "01-Documento" / "01 - Planilhas" / "ContaPagar_2026-07-14.xlsx"
CR_PADRAO = ROOT / "01-Documento" / "01 - Planilhas" / "ContaReceber_2026-07-14.xlsx"

EMPRESA_LUCE_NERA_ID = "2470fa14-1a00-4952-92e2-7e8cf61f8943"

BATCH_SIZE = 200
PAGE_SIZE = 1000

COLUNAS_TRANSACAO = [
    "dt_emissao",
    "dt_vencimento",
    "dt_pagamento",
    "vl_parcela",
    "vl_desconto",
    "vl_juros",
    "vl_pago",
    "vl_frete",
    "vl_ipi",
    "pago",
    "num_parc",
    "total_parc",
    "acordo",
    "tipo_pagamento",
    "cod_itens_duplicata",
    "cod_duplicata",
    "desc_apropriacao",
    "cod_apropriacao",
    "cod_venda",
    "cod_pessoa",
    "nm_funcionario",
    "dev_troca",
]


def carregar_planilha(path: Path, tipo: str) -> pd.DataFrame:
    df = pd.read_excel(path, sheet_name="Financeiro")
    df.columns = [c.strip() for c in df.columns]
    df = df[COLUNAS_TRANSACAO].copy()
    df["tipo"] = tipo

    for col in ["dt_emissao", "dt_vencimento", "dt_pagamento"]:
        df[col] = pd.to_datetime(df[col], dayfirst=True, errors="coerce")

    for col in ["vl_parcela", "vl_desconto", "vl_juros", "vl_pago", "vl_frete", "vl_ipi"]:
        df[col] = pd.to_numeric(df[col], errors="coerce").fillna(0.0)

    df["status_pago"] = pd.to_numeric(df["pago"], errors="coerce").fillna(0).astype(int)
    df["cod_itens_duplicata"] = pd.to_numeric(df["cod_itens_duplicata"], errors="coerce").astype("Int64")
    df["cod_duplicata"] = pd.to_numeric(df["cod_duplicata"], errors="coerce").astype("Int64")
    df["cod_apropriacao"] = pd.to_numeric(df["cod_apropriacao"], errors="coerce").astype("Int64")
    df["cod_pessoa"] = pd.to_numeric(df["cod_pessoa"], errors="coerce").astype("Int64")
    df["num_parc"] = pd.to_numeric(df["num_parc"], errors="coerce").fillna(1).astype(int)
    df["total_parc"] = pd.to_numeric(df["total_parc"], errors="coerce").fillna(1).astype(int)
    df["acordo"] = pd.to_numeric(df["acordo"], errors="coerce").fillna(0).astype(int)
    df["cod_venda"] = pd.to_numeric(df["cod_venda"], errors="coerce").astype("Int64")
    df["dev_troca"] = df["dev_troca"].fillna(0).astype(int).astype(bool)
    df["nm_funcionario"] = df["nm_funcionario"].astype(str).str.strip().str.upper()
    df.loc[df["nm_funcionario"].isin(["NAN", "NONE", ""]), "nm_funcionario"] = None
    df = df.dropna(subset=["cod_itens_duplicata", "cod_duplicata"])

    df["data_transacao"] = df["dt_pagamento"].fillna(df["dt_vencimento"]).fillna(df["dt_emissao"])
    df["descricao"] = df["desc_apropriacao"].fillna("SEM DESCRICAO").str.strip()
    df["valor"] = df["vl_parcela"]

    return df


def buscar_paginado(client, table: str, columns: str) -> pd.DataFrame:
    rows = []
    offset = 0
    while True:
        resp = client.table(table).select(columns).range(offset, offset + PAGE_SIZE - 1).execute()
        data = resp.data or []
        rows.extend(data)
        if len(data) < PAGE_SIZE:
            break
        offset += PAGE_SIZE
    return pd.DataFrame(rows)


def to_date_str(x):
    if pd.isna(x):
        return None
    return x.strftime("%Y-%m-%d")


def processar(dry_run: bool) -> None:
    print(f"Supabase: {SUPABASE_URL}")
    print(f"Modo:     {'DRY-RUN (sem gravação)' if dry_run else 'GRAVAÇÃO REAL'}\n")

    cp = carregar_planilha(CP_PADRAO, "despesa")
    cr = carregar_planilha(CR_PADRAO, "receita")
    planilha = pd.concat([cp, cr], ignore_index=True)
    print(f"Linhas na planilha (CP+CR), após limpeza: {len(planilha)}")

    client = get_client()

    chaves_vigentes = sorted({(int(cd), t) for cd, t in zip(planilha["cod_duplicata"], planilha["tipo"])})
    if dry_run:
        print(f"(dry-run) stg_duplicatas_vigentes seria atualizada com {len(chaves_vigentes)} chaves")
    else:
        print(f"Atualizando stg_duplicatas_vigentes ({len(chaves_vigentes)} chaves)…")
        client.table("stg_duplicatas_vigentes").delete().neq("cod_duplicata", -1).execute()
        registros_stg = [{"cod_duplicata": cd, "tipo": t} for cd, t in chaves_vigentes]
        for i in range(0, len(registros_stg), BATCH_SIZE):
            client.table("stg_duplicatas_vigentes").insert(registros_stg[i : i + BATCH_SIZE]).execute()

    print("Buscando negociacoes existentes…")
    neg = buscar_paginado(client, "negociacoes", "id,empresa_id,cod_duplicata,tipo")
    neg["cod_duplicata"] = pd.to_numeric(neg["cod_duplicata"], errors="coerce").astype("Int64")
    print(f"  {len(neg)} negociacoes no banco")

    # Verifica se (cod_duplicata, tipo) é uma chave suficiente (sem ambiguidade de empresa)
    dup_key_counts = neg.groupby(["cod_duplicata", "tipo"]).size()
    ambiguous_keys = dup_key_counts[dup_key_counts > 1]
    if len(ambiguous_keys) > 0:
        print(
            f"  AVISO: {len(ambiguous_keys)} combinações (cod_duplicata,tipo) têm mais de uma "
            f"negociacao (empresas diferentes) — essas serão tratadas como AMBÍGUAS e puladas."
        )
    neg_unicas = neg[~neg.set_index(["cod_duplicata", "tipo"]).index.isin(ambiguous_keys.index)]
    neg_map = neg_unicas.set_index(["cod_duplicata", "tipo"])["id"].to_dict()
    ambiguous_set = set(ambiguous_keys.index)

    print("Buscando plano_de_contas (codigo_connect -> id)...")
    pc = buscar_paginado(client, "plano_de_contas", "id,codigo_connect")
    pc_map = pc.set_index("codigo_connect")["id"].to_dict()

    print("Buscando funcionarios (nm_connect -> id)...")
    func = buscar_paginado(client, "funcionarios", "id,nm_connect")
    func["nm_connect"] = func["nm_connect"].astype(str).str.strip().str.upper()
    func_map = func.dropna(subset=["nm_connect"]).set_index("nm_connect")["id"].to_dict()

    print("Buscando contatos (codigo_legado -> id)...")
    contatos_df = buscar_paginado(client, "contatos", "id,codigo_legado")
    contatos_df["codigo_legado"] = pd.to_numeric(contatos_df["codigo_legado"], errors="coerce").astype("Int64")
    contato_map = contatos_df.dropna(subset=["codigo_legado"]).set_index("codigo_legado")["id"].to_dict()

    # Duplicatas genuinamente novas: (cod_duplicata, tipo) não existe em nenhuma
    # empresa e não é ambíguo — vão para a empresa "LUCE NERA" (grupo).
    novas_chaves = sorted(
        {
            (row["cod_duplicata"], row["tipo"])
            for row in planilha.to_dict("records")
            if (row["cod_duplicata"], row["tipo"]) not in neg_map
            and (row["cod_duplicata"], row["tipo"]) not in ambiguous_set
        }
    )
    print(f"\nDuplicatas novas (sem negociacao em nenhuma empresa): {len(novas_chaves)}")

    primeira_linha_por_chave = {}
    for row in planilha.to_dict("records"):
        chave = (row["cod_duplicata"], row["tipo"])
        if chave in novas_chaves and chave not in primeira_linha_por_chave:
            primeira_linha_por_chave[chave] = row

    novas_negociacoes = []
    sem_plano_contas = 0
    for chave in novas_chaves:
        row = primeira_linha_por_chave[chave]
        plano_contas_id = pc_map.get(int(row["cod_apropriacao"])) if pd.notna(row["cod_apropriacao"]) else None
        if plano_contas_id is None:
            sem_plano_contas += 1
        funcionario_id = func_map.get(row["nm_funcionario"]) if row["nm_funcionario"] else None
        contato_id = contato_map.get(int(row["cod_pessoa"])) if pd.notna(row["cod_pessoa"]) else None
        novas_negociacoes.append(
            {
                "empresa_id": EMPRESA_LUCE_NERA_ID,
                "contato_id": contato_id,
                "funcionario_id": funcionario_id,
                "plano_contas_id": plano_contas_id,
                "tipo": row["tipo"],
                "cod_duplicata": int(row["cod_duplicata"]),
                "cod_venda": int(row["cod_venda"]) if pd.notna(row["cod_venda"]) else None,
                "total_parc": int(row["total_parc"]),
                "dev_troca": bool(row["dev_troca"]),
                "cod_pessoa": int(row["cod_pessoa"]) if pd.notna(row["cod_pessoa"]) else None,
            }
        )
    if novas_chaves:
        print(f"  Sem plano_contas_id resolvido (cod_apropriacao não encontrado): {sem_plano_contas}")

    if dry_run:
        for chave, rec in zip(novas_chaves, novas_negociacoes):
            neg_map[chave] = f"DRY-RUN-{rec['cod_duplicata']}-{rec['tipo']}"
    elif novas_negociacoes:
        print(f"Criando {len(novas_negociacoes)} negociacoes novas sob empresa LUCE NERA…")
        for i in range(0, len(novas_negociacoes), BATCH_SIZE):
            lote_chaves = novas_chaves[i : i + BATCH_SIZE]
            lote = novas_negociacoes[i : i + BATCH_SIZE]
            resp = client.table("negociacoes").insert(lote).execute()
            for chave, criado in zip(lote_chaves, resp.data):
                neg_map[chave] = criado["id"]
            print(f"  Negociacoes criadas: {min(i+BATCH_SIZE, len(novas_negociacoes))}/{len(novas_negociacoes)}", end="\r")
        print()

    print("Buscando transacoes existentes…")
    trans = buscar_paginado(
        client,
        "transacoes",
        "id,negociacao_id,cod_itens_duplicata,status_pago,vl_pago,dt_pagamento,vl_desconto,vl_juros",
    )
    print(f"  {len(trans)} transacoes no banco\n")
    trans_map = {
        (r["negociacao_id"], r["cod_itens_duplicata"]): r
        for r in trans.to_dict("records")
        if r["negociacao_id"] is not None and r["cod_itens_duplicata"] is not None
    }

    novas_transacoes = []
    atualizacoes = []
    sem_negociacao = []
    inalteradas = 0

    for row in planilha.to_dict("records"):
        chave_neg = (row["cod_duplicata"], row["tipo"])
        negociacao_id = neg_map.get(chave_neg)

        if negociacao_id is None:
            sem_negociacao.append(row)
            continue

        chave_trans = (negociacao_id, row["cod_itens_duplicata"])
        existente = trans_map.get(chave_trans)

        if existente is None:
            novas_transacoes.append(
                {
                    "negociacao_id": negociacao_id,
                    "tipo": row["tipo"],
                    "descricao": row["descricao"],
                    "valor": float(row["valor"]),
                    "data_transacao": to_date_str(row["data_transacao"]),
                    "cod_itens_duplicata": int(row["cod_itens_duplicata"]),
                    "num_parc": int(row["num_parc"]),
                    "dt_emissao": to_date_str(row["dt_emissao"]),
                    "dt_vencimento": to_date_str(row["dt_vencimento"]),
                    "dt_pagamento": to_date_str(row["dt_pagamento"]),
                    "vl_parcela": float(row["vl_parcela"]),
                    "vl_desconto": float(row["vl_desconto"]),
                    "vl_juros": float(row["vl_juros"]),
                    "vl_pago": float(row["vl_pago"]),
                    "vl_frete": float(row["vl_frete"]),
                    "vl_ipi": float(row["vl_ipi"]),
                    "status_pago": int(row["status_pago"]),
                    "tipo_pagamento": row["tipo_pagamento"] if pd.notna(row["tipo_pagamento"]) else None,
                    "acordo": int(row["acordo"]),
                    "cod_venda": int(row["cod_venda"]) if pd.notna(row["cod_venda"]) else None,
                }
            )
            continue

        novo_dt_pagamento = to_date_str(row["dt_pagamento"])
        mudou = (
            existente["status_pago"] != row["status_pago"]
            or round(float(existente["vl_pago"] or 0), 2) != round(float(row["vl_pago"]), 2)
            or (existente["dt_pagamento"] or None) != (novo_dt_pagamento or None)
            or round(float(existente["vl_desconto"] or 0), 2) != round(float(row["vl_desconto"]), 2)
            or round(float(existente["vl_juros"] or 0), 2) != round(float(row["vl_juros"]), 2)
        )
        if mudou:
            atualizacoes.append(
                {
                    "id": existente["id"],
                    "status_pago": int(row["status_pago"]),
                    "vl_pago": float(row["vl_pago"]),
                    "dt_pagamento": novo_dt_pagamento,
                    "vl_desconto": float(row["vl_desconto"]),
                    "vl_juros": float(row["vl_juros"]),
                }
            )
        else:
            inalteradas += 1

    print("\n=== RESUMO ===")
    print(f"Negociacoes novas (empresa LUCE NERA): {len(novas_negociacoes)}")
    print(f"Transações novas a inserir:        {len(novas_transacoes)}")
    print(f"Transações a atualizar (status):   {len(atualizacoes)}")
    print(f"Transações já sincronizadas (nada a fazer): {inalteradas}")
    print(f"Linhas AMBÍGUAS puladas (cod_duplicata,tipo em >1 empresa): {len(sem_negociacao)}")

    if sem_negociacao:
        codes = sorted({(r["cod_duplicata"], r["tipo"]) for r in sem_negociacao})
        print(f"  Exemplos de (cod_duplicata, tipo) ambíguos: {codes[:15]}")

    if dry_run:
        print("\n=== DRY-RUN: nada foi gravado ===")
        if novas_transacoes:
            print("\nAmostra de transação nova:")
            print(novas_transacoes[0])
        if atualizacoes:
            print("\nAmostra de atualização:")
            print(atualizacoes[0])
        return

    total_ok, total_erro = 0, 0
    for i in range(0, len(novas_transacoes), BATCH_SIZE):
        lote = novas_transacoes[i : i + BATCH_SIZE]
        try:
            client.table("transacoes").insert(lote).execute()
            total_ok += len(lote)
        except Exception as exc:
            print(f"  ERRO ao inserir lote {i}-{i+len(lote)}: {exc}")
            total_erro += len(lote)
        print(f"  Inserindo: {min(i+BATCH_SIZE, len(novas_transacoes))}/{len(novas_transacoes)}", end="\r")
    print(f"\nInsert concluído: {total_ok} ok, {total_erro} erros.")

    total_ok2, total_erro2 = 0, 0
    for rec in atualizacoes:
        try:
            client.table("transacoes").update(
                {
                    "status_pago": rec["status_pago"],
                    "vl_pago": rec["vl_pago"],
                    "dt_pagamento": rec["dt_pagamento"],
                    "vl_desconto": rec["vl_desconto"],
                    "vl_juros": rec["vl_juros"],
                }
            ).eq("id", rec["id"]).execute()
            total_ok2 += 1
        except Exception as exc:
            print(f"  ERRO ao atualizar id={rec['id']}: {exc}")
            total_erro2 += 1
    print(f"Update concluído: {total_ok2} ok, {total_erro2} erros.")


def main():
    parser = argparse.ArgumentParser(description="Sincroniza ContaPagar/ContaReceber com transacoes")
    parser.add_argument("--dry-run", action="store_true", help="Apenas mostra o que seria feito")
    args = parser.parse_args()
    processar(args.dry_run)


if __name__ == "__main__":
    main()
