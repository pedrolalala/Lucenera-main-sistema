"""
Sincroniza produtos/estoque_itens a partir da planilha Produtos__AAAA-MM-DD.xlsx
(export "Estoque" do sistema legado).

Mapeamento (grounded no schema real, supabase/db/current/01_schema_full.sql):
  CodProduto  -> produtos.codigo_produto (chave única de match)
  EstoqueTotal, Showroom, Disponivel -> produtos.estoque_total / estoque_showroom / estoque_disponivel
  CustoTotal  -> produtos.custo_total (é o custo UNITÁRIO, confirmado por amostragem — não mexe em
                 preco_custo/preco_venda para não disparar o trigger fn_atualizar_preco_venda)
  ValorVenda  -> produtos.valor_venda (coluna nunca foi sincronizada antes — hoje 100% zerada)
  Lucro       -> produtos.percentual_lucro

  estoque_itens: NAO e tocado diretamente por este script. Desde a migration
  20260716_046 existe um trigger (fn_sync_estoque_itens_from_produtos) em
  produtos que mantem estoque_itens(local='Estoque') sempre igual --
  quantidade = estoque_total, quantidade - quantidade_reservada = estoque_disponivel --
  automaticamente a cada UPDATE de produtos.estoque_total/estoque_disponivel,
  inclusive os que este script faz. Link permanente pedido pelo usuario em 2026-07-16.

Só ATUALIZA produtos que já existem no banco (match por codigo_produto). Não cria produto novo
(exigiria resolver marca_id/categoria_id, fora do escopo de uma sincronização de estoque).

Uso:
  python scripts/importar_produtos_estoque.py --dry-run
  python scripts/importar_produtos_estoque.py
"""

import argparse
import sys
from pathlib import Path

import pandas as pd

if sys.stdout.encoding and sys.stdout.encoding.lower() != "utf-8":
    sys.stdout.reconfigure(encoding="utf-8")

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "scripts"))

from _supabase_client import get_client, SUPABASE_URL  # noqa: E402

PLANILHA_PADRAO = ROOT / "01-Documento" / "01 - Planilhas" / "Produtos__2026-08-31.xlsx"

BATCH_SIZE = 200
PAGE_SIZE = 1000


def to_numeric_br(series: pd.Series) -> pd.Series:
    """Converte string em formato BR ("1.409,76") ou US ("3709.9") para float.

    Bug corrigido em 2026-09-01: a versão antiga fazia `.replace(",", ".")` sem
    tirar o separador de milhar, então "1.409,76" virava "1.409.76" -> NaN -> 0.
    Na planilha Produtos o `CustoTotal` vem em BR com milhar e o `ValorVenda`
    em US — resultado: todo produto com custo >= R$ 1.000 ficou com
    `custo_total = 0` no banco (e o Dashboard de Estoque / Necessidade de
    Compra subestimados). Agora: se tem vírgula é BR (tira '.', troca ',' por
    '.'); senão assume que já é número.
    """

    def _parse(v: object) -> object:
        s = str(v).strip()
        if s in ("", "nan", "NaN", "None", "NaT"):
            return None
        if "," in s:
            s = s.replace(".", "").replace(",", ".")
        return s

    return pd.to_numeric(series.map(_parse), errors="coerce")


def carregar_planilha(path: Path) -> pd.DataFrame:
    df = pd.read_excel(path, sheet_name="Estoque", dtype=str)
    df.columns = [c.strip() for c in df.columns]

    df["codigo_produto"] = pd.to_numeric(df["CodProduto"], errors="coerce").astype("Int64")
    df = df.dropna(subset=["codigo_produto"])

    df["estoque_total"] = to_numeric_br(df["EstoqueTotal"]).fillna(0)
    df["estoque_showroom"] = to_numeric_br(df["Showroom"]).fillna(0)
    df["estoque_disponivel"] = to_numeric_br(df["Disponivel"]).fillna(0)
    df["custo_total"] = to_numeric_br(df["CustoTotal"]).fillna(0)
    df["valor_venda"] = to_numeric_br(df["ValorVenda"]).fillna(0)
    df["percentual_lucro"] = to_numeric_br(df["Lucro"]).fillna(0)

    return df[
        [
            "codigo_produto",
            "estoque_total",
            "estoque_showroom",
            "estoque_disponivel",
            "custo_total",
            "valor_venda",
            "percentual_lucro",
        ]
    ]


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


def close_enough(a: float, b: float, tol: float = 0.005) -> bool:
    return abs((a or 0) - (b or 0)) <= tol


def processar(dry_run: bool) -> None:
    print(f"Supabase: {SUPABASE_URL}")
    print(f"Modo:     {'DRY-RUN (sem gravação)' if dry_run else 'GRAVAÇÃO REAL'}\n")

    planilha = carregar_planilha(PLANILHA_PADRAO)
    print(f"Linhas na planilha, após limpeza: {len(planilha)}")

    client = get_client()

    print("Buscando produtos existentes…")
    produtos = buscar_paginado(
        client,
        "produtos",
        "id,codigo_produto,estoque_total,estoque_showroom,estoque_disponivel,custo_total,valor_venda,percentual_lucro",
    )
    produtos["codigo_produto"] = pd.to_numeric(produtos["codigo_produto"], errors="coerce").astype(
        "Int64"
    )
    print(f"  {len(produtos)} produtos no banco\n")
    produtos_map = produtos.set_index("codigo_produto").to_dict("index")

    updates_produtos = []
    sem_match = []
    inalterados = 0

    for row in planilha.to_dict("records"):
        cod = row["codigo_produto"]
        existente = produtos_map.get(cod)

        if existente is None:
            sem_match.append(cod)
            continue

        mudou = (
            not close_enough(existente["estoque_total"], row["estoque_total"])
            or not close_enough(existente["estoque_showroom"], row["estoque_showroom"])
            or not close_enough(existente["estoque_disponivel"], row["estoque_disponivel"])
            or not close_enough(existente["custo_total"], row["custo_total"])
            or not close_enough(existente["valor_venda"], row["valor_venda"])
            or not close_enough(existente["percentual_lucro"], row["percentual_lucro"])
        )

        if mudou:
            updates_produtos.append(
                {
                    "id": existente["id"],
                    "estoque_total": row["estoque_total"],
                    "estoque_showroom": row["estoque_showroom"],
                    "estoque_disponivel": row["estoque_disponivel"],
                    "custo_total": row["custo_total"],
                    "valor_venda": row["valor_venda"],
                    "percentual_lucro": row["percentual_lucro"],
                }
            )
        else:
            inalterados += 1

    print("=== RESUMO ===")
    print(f"Produtos a atualizar:               {len(updates_produtos)}")
    print(f"Produtos já sincronizados:           {inalterados}")
    print(f"CodProduto da planilha sem match no banco: {len(sem_match)}")
    print("(estoque_itens é atualizado automaticamente pelo trigger em produtos)")
    if sem_match:
        print(f"  Exemplos: {sem_match[:15]}")

    if dry_run:
        print("\n=== DRY-RUN: nada foi gravado ===")
        if updates_produtos:
            print("\nAmostra de update em produtos:")
            print(updates_produtos[0])
        return

    total_ok, total_erro = 0, 0
    for i in range(0, len(updates_produtos), BATCH_SIZE):
        lote = updates_produtos[i : i + BATCH_SIZE]
        for rec in lote:
            try:
                client.table("produtos").update(
                    {k: v for k, v in rec.items() if k != "id"}
                ).eq("id", rec["id"]).execute()
                total_ok += 1
            except Exception as exc:
                print(f"  ERRO ao atualizar produto id={rec['id']}: {exc}")
                total_erro += 1
        print(f"  Produtos atualizados: {min(i+BATCH_SIZE, len(updates_produtos))}/{len(updates_produtos)}", end="\r")
    print(f"\nUpdate de produtos concluído: {total_ok} ok, {total_erro} erros.")
    print("estoque_itens sincronizado automaticamente pelo trigger (fn_sync_estoque_itens_from_produtos).")


def main():
    parser = argparse.ArgumentParser(description="Sincroniza planilha Produtos/Estoque com Supabase")
    parser.add_argument("--dry-run", action="store_true", help="Apenas mostra o que seria feito")
    args = parser.parse_args()
    processar(args.dry_run)


if __name__ == "__main__":
    main()
