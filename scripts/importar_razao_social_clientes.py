"""
Importa/atualiza razao_social em contatos a partir da planilha Clientes.xlsx.

Mapeamento:
  codCliente  → contatos.codigo_legado  (chave de join)
  rzCliente   → contatos.razao_social

Uso:
  cd "c:/script python/ADAPTA-PASS-Lucenera-main"
  python scripts/importar_razao_social_clientes.py

  # Dry-run (não grava nada):
  python scripts/importar_razao_social_clientes.py --dry-run

  # Planilha alternativa:
  python scripts/importar_razao_social_clientes.py --xlsx "caminho/outro.xlsx"
"""

import argparse
import sys
from pathlib import Path

import pandas as pd

# Adiciona o diretório raiz ao path para importar config do dashboard
ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "dashboard"))

from config import get_client, SUPABASE_URL  # noqa: E402

PLANILHA_PADRAO = ROOT / "01-Documento" / "01 - Planilhas" / "Planilhas atualizadas e novas" / "Clientes.xlsx"

BATCH_SIZE = 200  # registros por requisição ao Supabase


def carregar_planilha(xlsx_path: Path) -> pd.DataFrame:
    df = pd.read_excel(xlsx_path, dtype=str)
    df.columns = [c.strip() for c in df.columns]

    colunas_necessarias = {"codCliente", "rzCliente"}
    faltando = colunas_necessarias - set(df.columns)
    if faltando:
        raise ValueError(f"Colunas não encontradas na planilha: {faltando}\nColunas presentes: {list(df.columns)}")

    df["codCliente"] = pd.to_numeric(df["codCliente"], errors="coerce")
    df = df.dropna(subset=["codCliente", "rzCliente"])
    df["codCliente"] = df["codCliente"].astype(int)
    df["rzCliente"] = df["rzCliente"].str.strip()
    df = df[df["rzCliente"] != ""]

    return df[["codCliente", "rzCliente"]].drop_duplicates(subset=["codCliente"])


def importar(xlsx_path: Path, dry_run: bool) -> None:
    print(f"Supabase: {SUPABASE_URL}")
    print(f"Planilha: {xlsx_path}")
    print(f"Modo:     {'DRY-RUN (sem gravação)' if dry_run else 'GRAVAÇÃO REAL'}\n")

    df = carregar_planilha(xlsx_path)
    print(f"Linhas carregadas da planilha: {len(df)}")

    client = get_client()

    # Busca todos os contatos que têm codigo_legado (em lotes para não estourar)
    print("Buscando contatos com codigo_legado no Supabase…")
    rows = []
    batch = 1000
    offset = 0
    while True:
        resp = (
            client.table("contatos")
            .select("id,codigo_legado,razao_social")
            .not_.is_("codigo_legado", "null")
            .range(offset, offset + batch - 1)
            .execute()
        )
        data = resp.data or []
        rows.extend(data)
        if len(data) < batch:
            break
        offset += batch

    print(f"Contatos com codigo_legado encontrados: {len(rows)}\n")

    db_df = pd.DataFrame(rows)
    db_df["codigo_legado"] = pd.to_numeric(db_df["codigo_legado"], errors="coerce").astype("Int64")

    merged = df.merge(
        db_df,
        left_on="codCliente",
        right_on="codigo_legado",
        how="inner",
    )

    codigos_com_match = set(merged["codCliente"].unique())
    codigos_planilha = set(df["codCliente"].unique())
    sem_match = codigos_planilha - codigos_com_match

    print(f"Correspondências encontradas: {len(merged)} registros ({len(codigos_com_match)} códigos únicos)")
    if sem_match:
        print(f"Clientes da planilha SEM correspondência em contatos: {len(sem_match)} códigos")

    # Filtra apenas os que precisam de atualização
    precisa_update = merged[
        merged["rzCliente"].fillna("") != merged["razao_social"].fillna("")
    ]
    print(f"Registros que precisam de atualização: {len(precisa_update)}\n")

    if precisa_update.empty:
        print("Nada a atualizar. razao_social já está sincronizado.")
        return

    if dry_run:
        print("=== DRY-RUN: primeiros 20 registros que seriam atualizados ===")
        print(precisa_update[["codCliente", "id", "razao_social", "rzCliente"]].head(20).to_string(index=False))
        return

    # Atualiza em lotes
    total_ok = 0
    total_erro = 0
    registros = precisa_update[["id", "rzCliente"]].to_dict("records")

    for i in range(0, len(registros), BATCH_SIZE):
        lote = registros[i : i + BATCH_SIZE]
        for rec in lote:
            try:
                client.table("contatos").update(
                    {"razao_social": rec["rzCliente"]}
                ).eq("id", rec["id"]).execute()
                total_ok += 1
            except Exception as exc:
                print(f"  ERRO ao atualizar id={rec['id']}: {exc}")
                total_erro += 1

        pct = min(i + BATCH_SIZE, len(registros))
        print(f"  Progresso: {pct}/{len(registros)}", end="\r")

    print(f"\nConcluído: {total_ok} atualizados, {total_erro} erros.")


def main() -> None:
    parser = argparse.ArgumentParser(description="Importa rzCliente → contatos.razao_social")
    parser.add_argument("--xlsx", type=Path, default=PLANILHA_PADRAO, help="Caminho da planilha")
    parser.add_argument("--dry-run", action="store_true", help="Apenas mostra o que seria feito")
    args = parser.parse_args()

    if not args.xlsx.exists():
        print(f"Planilha não encontrada: {args.xlsx}")
        sys.exit(1)

    importar(args.xlsx, args.dry_run)


if __name__ == "__main__":
    main()
