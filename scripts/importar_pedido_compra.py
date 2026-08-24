"""
Importa a planilha PedidoCompra_AAAA-MM-DD.xlsx (export "Connect", aba
"Financeiro") para as tabelas `staging_pedido_compra` e `pedido_compra`.

Contexto (grounded em supabase/db/current/01_schema_full.sql): as duas
tabelas já existiam no banco (desenhadas para essa planilha, colunas batem
exatamente), mas nunca tinham sido populadas nem referenciadas por nenhum
código do ecossistema (04-Sistemas/, dashboard/, scripts/, supabase/functions/
— confirmado por busca antes de escrever este script). NÃO têm relação com a
tela "Necessidade de Compra" (compras-lucenera), que usa uma arquitetura
separada (`pedidos_compra` plural + `pedido_compra_itens`, granular por
produto/quantidade) — decisão explícita do usuário em 2026-07-22, ciente de
que este import é só o lado financeiro (pedido -> fornecedor -> parcelas),
sem efeito nos campos Pendente/Status do Pedido/Entrega Prevista daquela
tela, que exigem item de produto (dado que não existe nesta planilha).

Modelo dos dados de origem: cada linha do Excel é uma parcela (duplicata) de
um pedido. `vl_nota` é constante entre as linhas do mesmo `codigo_pedido`
(valor total do pedido); `num_parc`/`dt_vencimento`/`vl_duplicata` variam por
parcela. `pedido_compra` só guarda 1 linha por `codigo_pedido` (UNIQUE no
schema real) — não cabe representar N parcelas nela:
  - pedido com 0 ou 1 linha de parcela na planilha: numero_parcela/
    data_vencimento/valor_duplicata preenchidos normalmente (ou NULL se o
    pedido não tem parcela lançada ainda).
  - pedido com 2+ parcelas: esses 3 campos ficam NULL em `pedido_compra`
    (não é possível escolher 1 sem perder as outras) — o detalhe completo de
    todas as parcelas fica preservado em `staging_pedido_compra` (1 linha por
    linha de Excel, sem essa limitação), que existe exatamente para isso
    ("dados brutos do Excel PedidoCompra (antes de transformação)").

Rerun-safe: `staging_pedido_compra` é limpa e recarregada para os
codigo_pedido presentes na planilha a cada execução (tabela sem unique key,
sem consumidor hoje). `pedido_compra` faz upsert por `codigo_pedido`
(UNIQUE): insere pedido novo, atualiza campos se algo mudou.

Uso:
  python scripts/importar_pedido_compra.py --dry-run
  python scripts/importar_pedido_compra.py
"""

import argparse
import sys
from datetime import datetime
from pathlib import Path

import pandas as pd

if sys.stdout.encoding and sys.stdout.encoding.lower() != "utf-8":
    sys.stdout.reconfigure(encoding="utf-8")

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "scripts"))

from _supabase_client import get_client, SUPABASE_URL  # noqa: E402

PLANILHA_PADRAO = ROOT / "01-Documento" / "01 - Planilhas" / "PedidoCompra_2026-08-24.xlsx"

BATCH_SIZE = 200


def to_iso_date(value: str) -> str | None:
    if value is None or (isinstance(value, float) and pd.isna(value)) or str(value).strip() in ("", "nan", "NaT"):
        return None
    return datetime.strptime(str(value).strip(), "%d/%m/%Y").strftime("%Y-%m-%d")


def carregar_planilha(path: Path) -> pd.DataFrame:
    df = pd.read_excel(path, sheet_name="Financeiro")
    df.columns = [c.strip() for c in df.columns]

    df["codigo_pedido"] = pd.to_numeric(df["codigo_pedido"], errors="coerce").astype("Int64")
    df["cod_fornecedor"] = pd.to_numeric(df["cod_fornecedor"], errors="coerce").astype("Int64")
    df["nm_fornecedor"] = df["nm_fornecedor"].astype(str).str.strip()
    df["vl_nota"] = pd.to_numeric(df["vl_nota"], errors="coerce")
    df["vl_duplicata"] = pd.to_numeric(df["vl_duplicata"], errors="coerce")
    df["num_parc"] = pd.to_numeric(df["num_parc"], errors="coerce").astype("Int64")

    df = df.dropna(subset=["codigo_pedido", "cod_fornecedor", "vl_nota"])
    df["linha_excel"] = df.index + 2  # +2: header do Excel ocupa a linha 1

    return df


def montar_staging(df: pd.DataFrame) -> list[dict]:
    registros = []
    for row in df.to_dict("records"):
        registros.append(
            {
                "codigo_pedido": int(row["codigo_pedido"]),
                "cod_fornecedor": int(row["cod_fornecedor"]),
                "nm_fornecedor": row["nm_fornecedor"],
                "emissao_pedido": row["emissao_pedido"],
                "vl_nota": float(row["vl_nota"]),
                "num_parc": int(row["num_parc"]) if pd.notna(row["num_parc"]) else None,
                "dt_vencimento": row["dt_vencimento"] if pd.notna(row["dt_vencimento"]) else None,
                "vl_duplicata": float(row["vl_duplicata"]) if pd.notna(row["vl_duplicata"]) else None,
                "processado": True,
                "linha_excel": int(row["linha_excel"]),
            }
        )
    return registros


def montar_headers(df: pd.DataFrame) -> list[dict]:
    headers = []
    for codigo_pedido, grupo in df.groupby("codigo_pedido"):
        primeira = grupo.iloc[0]
        rec = {
            "codigo_pedido": int(codigo_pedido),
            "cod_fornecedor": int(primeira["cod_fornecedor"]),
            "nome_fornecedor": primeira["nm_fornecedor"],
            "valor_nota": float(primeira["vl_nota"]),
            "data_emissao": to_iso_date(primeira["emissao_pedido"]),
            "numero_parcela": None,
            "data_vencimento": None,
            "valor_duplicata": None,
        }
        if len(grupo) == 1:
            unica = grupo.iloc[0]
            rec["numero_parcela"] = int(unica["num_parc"]) if pd.notna(unica["num_parc"]) else None
            rec["data_vencimento"] = to_iso_date(unica["dt_vencimento"])
            rec["valor_duplicata"] = float(unica["vl_duplicata"]) if pd.notna(unica["vl_duplicata"]) else None
        headers.append(rec)
    return headers


def processar(dry_run: bool) -> None:
    print(f"Supabase: {SUPABASE_URL}")
    print(f"Modo:     {'DRY-RUN (sem gravação)' if dry_run else 'GRAVAÇÃO REAL'}\n")

    df = carregar_planilha(PLANILHA_PADRAO)
    print(f"Linhas na planilha, após limpeza: {len(df)}")

    staging_novo = montar_staging(df)
    headers_novos = montar_headers(df)
    multi_parcela = sum(1 for _, g in df.groupby("codigo_pedido") if len(g) > 1)

    print(f"Pedidos únicos: {len(headers_novos)}")
    print(f"  com exatamente 1 parcela na planilha: {len(headers_novos) - multi_parcela}")
    print(f"  com 2+ parcelas (numero_parcela/data_vencimento/valor_duplicata ficam NULL no header): {multi_parcela}")

    client = get_client()

    print("\nBuscando pedido_compra existentes…")
    existentes_resp = client.table("pedido_compra").select(
        "id,codigo_pedido,cod_fornecedor,nome_fornecedor,valor_nota,data_emissao,numero_parcela,data_vencimento,valor_duplicata"
    ).execute()
    existentes = {r["codigo_pedido"]: r for r in (existentes_resp.data or [])}
    print(f"  {len(existentes)} pedidos já no banco")

    novos, atualizacoes, inalterados = [], [], 0
    for rec in headers_novos:
        existente = existentes.get(rec["codigo_pedido"])
        if existente is None:
            novos.append(rec)
            continue
        mudou = any(
            (existente.get(campo) or None) != (rec.get(campo) or None)
            for campo in (
                "cod_fornecedor",
                "nome_fornecedor",
                "valor_nota",
                "data_emissao",
                "numero_parcela",
                "data_vencimento",
                "valor_duplicata",
            )
        )
        if mudou:
            atualizacoes.append({**rec, "id": existente["id"]})
        else:
            inalterados += 1

    print("\n=== RESUMO pedido_compra ===")
    print(f"Novos:       {len(novos)}")
    print(f"Atualizar:   {len(atualizacoes)}")
    print(f"Inalterados: {inalterados}")

    print("\n=== RESUMO staging_pedido_compra ===")
    print(f"Linhas a recarregar (delete + insert): {len(staging_novo)}")

    if dry_run:
        print("\n=== DRY-RUN: nada foi gravado ===")
        if novos:
            print("\nAmostra de pedido novo:")
            print(novos[0])
        if atualizacoes:
            print("\nAmostra de atualização:")
            print(atualizacoes[0])
        return

    codigos = sorted({r["codigo_pedido"] for r in staging_novo})
    print(f"\nLimpando staging_pedido_compra para {len(codigos)} codigo_pedido…")
    for i in range(0, len(codigos), BATCH_SIZE):
        client.table("staging_pedido_compra").delete().in_("codigo_pedido", codigos[i : i + BATCH_SIZE]).execute()

    print("Inserindo staging_pedido_compra…")
    total_ok, total_erro = 0, 0
    for i in range(0, len(staging_novo), BATCH_SIZE):
        lote = staging_novo[i : i + BATCH_SIZE]
        try:
            client.table("staging_pedido_compra").insert(lote).execute()
            total_ok += len(lote)
        except Exception as exc:
            print(f"  ERRO ao inserir staging lote {i}-{i+len(lote)}: {exc}")
            total_erro += len(lote)
    print(f"  staging_pedido_compra: {total_ok} ok, {total_erro} erros.")

    if novos:
        print(f"\nInserindo {len(novos)} pedidos novos…")
        total_ok, total_erro = 0, 0
        for i in range(0, len(novos), BATCH_SIZE):
            lote = novos[i : i + BATCH_SIZE]
            try:
                client.table("pedido_compra").insert(lote).execute()
                total_ok += len(lote)
            except Exception as exc:
                print(f"  ERRO ao inserir pedido_compra lote {i}-{i+len(lote)}: {exc}")
                total_erro += len(lote)
        print(f"  pedido_compra insert: {total_ok} ok, {total_erro} erros.")

    if atualizacoes:
        print(f"\nAtualizando {len(atualizacoes)} pedidos…")
        total_ok, total_erro = 0, 0
        for rec in atualizacoes:
            try:
                client.table("pedido_compra").update(
                    {k: v for k, v in rec.items() if k != "id"}
                ).eq("id", rec["id"]).execute()
                total_ok += 1
            except Exception as exc:
                print(f"  ERRO ao atualizar pedido_compra id={rec['id']}: {exc}")
                total_erro += 1
        print(f"  pedido_compra update: {total_ok} ok, {total_erro} erros.")


def main():
    parser = argparse.ArgumentParser(description="Importa planilha PedidoCompra (Financeiro) para pedido_compra/staging_pedido_compra")
    parser.add_argument("--dry-run", action="store_true", help="Apenas mostra o que seria feito")
    args = parser.parse_args()
    processar(args.dry_run)


if __name__ == "__main__":
    main()
