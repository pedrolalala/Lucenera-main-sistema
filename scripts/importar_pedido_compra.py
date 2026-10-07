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
from sync_connect_common import (  # noqa: E402
    ImportacaoAbortada,
    RelatorioModulo,
    descobrir_planilha_mais_recente,
    imprimir_resumo_final,
    salvar_log,
    validar_cabecalho,
    validar_chave_unica,
    validar_minimo_linhas,
)

PASTA_PLANILHAS = ROOT / "01-Documento" / "01 - Planilhas"
PREFIXO_ARQUIVO = "PedidoCompra_"

# SPEC-157: piso de seguranca (NUNCA expectativa de volume). A planilha so
# traz pedidos VIGENTES (nao e' historico), entao o volume normal e' bem
# menor que os outros modulos.
MIN_LINHAS = 10
COLUNAS_ESPERADAS = [
    "codigo_pedido",
    "cod_fornecedor",
    "nm_fornecedor",
    "emissao_pedido",
    "vl_nota",
    "num_parc",
    "dt_vencimento",
    "vl_duplicata",
]

BATCH_SIZE = 200


def to_iso_date(value: str) -> str | None:
    if value is None or (isinstance(value, float) and pd.isna(value)) or str(value).strip() in ("", "nan", "NaT"):
        return None
    return datetime.strptime(str(value).strip(), "%d/%m/%Y").strftime("%Y-%m-%d")


def carregar_planilha(path: Path) -> pd.DataFrame:
    df = pd.read_excel(path, sheet_name="Financeiro")
    df.columns = [c.strip() for c in df.columns]

    validar_cabecalho(df.columns.tolist(), COLUNAS_ESPERADAS, origem=path.name)
    validar_minimo_linhas(len(df), MIN_LINHAS, origem=path.name)

    df["codigo_pedido"] = pd.to_numeric(df["codigo_pedido"], errors="coerce").astype("Int64")
    df["cod_fornecedor"] = pd.to_numeric(df["cod_fornecedor"], errors="coerce").astype("Int64")
    df["nm_fornecedor"] = df["nm_fornecedor"].astype(str).str.strip()
    df["vl_nota"] = pd.to_numeric(df["vl_nota"], errors="coerce")
    df["vl_duplicata"] = pd.to_numeric(df["vl_duplicata"], errors="coerce")
    # SPEC-157: num_parc vazio normalizado para 1 (a maioria dos pedidos vem
    # sem num_parc) -- nunca deixar NULL, senao a chave natural
    # (codigo_pedido, num_parc) nao pega duplicata real (UNIQUE do Postgres
    # trata varios NULL como distintos entre si).
    df["num_parc"] = pd.to_numeric(df["num_parc"], errors="coerce").fillna(1).astype(int)

    df = df.dropna(subset=["codigo_pedido", "cod_fornecedor", "vl_nota"])
    validar_chave_unica(df, ["codigo_pedido", "num_parc"], origem=path.name)
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
                "num_parc": int(row["num_parc"]),
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


def _coluna_vigente_existe(client) -> bool:
    """A migration 20260922_159 (SPEC-157) que adiciona pedido_compra.vigente
    e' um RASCUNHO ainda nao aplicado no Supabase real -- detecta em runtime
    pra nao quebrar o script enquanto o usuario nao aplica manualmente."""
    try:
        client.table("pedido_compra").select("vigente").limit(1).execute()
        return True
    except Exception:
        return False


def processar(dry_run: bool) -> None:
    print(f"Supabase: {SUPABASE_URL}")
    print(f"Modo:     {'DRY-RUN (sem gravação)' if dry_run else 'GRAVAÇÃO REAL'}\n")

    relatorio = RelatorioModulo(nome="Pedido de compra")
    try:
        planilha_path = descobrir_planilha_mais_recente(PASTA_PLANILHAS, PREFIXO_ARQUIVO)
        relatorio.arquivo_origem = planilha_path.name
        print(f"Planilha: {planilha_path.name}")
        df = carregar_planilha(planilha_path)
    except ImportacaoAbortada as exc:
        relatorio.abortado = str(exc)
        relatorio.finalizar()
        print(f"\nABORTADO: {exc}")
        relatorio.imprimir()
        log_path = salvar_log([relatorio], dry_run)
        imprimir_resumo_final([relatorio], dry_run, log_path)
        return
    print(f"Linhas na planilha, após limpeza: {len(df)}")

    staging_novo = montar_staging(df)
    headers_novos = montar_headers(df)
    for rec in headers_novos:
        rec["vigente"] = True
    multi_parcela = sum(1 for _, g in df.groupby("codigo_pedido") if len(g) > 1)
    codigos_planilha = {r["codigo_pedido"] for r in headers_novos}

    print(f"Pedidos únicos: {len(headers_novos)}")
    print(f"  com exatamente 1 parcela na planilha: {len(headers_novos) - multi_parcela}")
    print(f"  com 2+ parcelas (numero_parcela/data_vencimento/valor_duplicata ficam NULL no header): {multi_parcela}")

    client = get_client()
    coluna_vigente_existe = _coluna_vigente_existe(client)
    if not coluna_vigente_existe:
        print(
            "\n⚠️  Coluna pedido_compra.vigente ainda não existe no banco — aplique a migration "
            "20260922_159_sync_connect_reconciliacao antes do próximo run real. Por ora, o script "
            "segue SEM marcar pedidos ausentes como não vigentes (comportamento anterior à SPEC-157)."
        )

    colunas_select = "id,codigo_pedido,cod_fornecedor,nome_fornecedor,valor_nota,data_emissao,numero_parcela,data_vencimento,valor_duplicata"
    if coluna_vigente_existe:
        colunas_select += ",vigente"

    print("\nBuscando pedido_compra existentes…")
    existentes_resp = client.table("pedido_compra").select(colunas_select).execute()
    existentes = {r["codigo_pedido"]: r for r in (existentes_resp.data or [])}
    print(f"  {len(existentes)} pedidos já no banco")

    novos, atualizacoes, inalterados = [], [], 0
    n_reativado = 0
    for rec in headers_novos:
        existente = existentes.get(rec["codigo_pedido"])
        if existente is None:
            if not coluna_vigente_existe:
                rec = {k: v for k, v in rec.items() if k != "vigente"}
            novos.append(rec)
            continue
        reativar = coluna_vigente_existe and existente.get("vigente") is False
        # valor_nota/valor_duplicata são numeric(,2) no banco e a planilha manda
        # 3 casas (3344.591 vira 3344.59): comparar sem arredondar deixava o
        # pedido "alterado" em todo run (achado no sync de 29/09/2026).
        def _cmp(v):
            if isinstance(v, (int, float)) and not isinstance(v, bool):
                return round(float(v), 2) or None
            return v or None

        mudou = reativar or any(
            _cmp(existente.get(campo)) != _cmp(rec.get(campo))
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
            rec_final = {**rec, "id": existente["id"]}
            if not coluna_vigente_existe:
                rec_final = {k: v for k, v in rec_final.items() if k != "vigente"}
            if reativar:
                n_reativado += 1
            atualizacoes.append(rec_final)
        else:
            inalterados += 1

    # SPEC-157: pedido que estava vigente e saiu do export atual -- marca
    # vigente=false. NUNCA DELETE (a planilha nao traz historico).
    nao_vigentes_ids = []
    if coluna_vigente_existe:
        nao_vigentes_ids = [
            r["id"]
            for cod, r in existentes.items()
            if r.get("vigente") is not False and cod not in codigos_planilha
        ]

    print("\n=== RESUMO pedido_compra ===")
    print(f"Novos:       {len(novos)}")
    print(f"Atualizar:   {len(atualizacoes)}")
    print(f"  dos quais reativados (vigente false->true): {n_reativado}")
    print(f"Marcar como não vigente (saiu do export, NUNCA deletado): {len(nao_vigentes_ids)}")
    print(f"Inalterados: {inalterados}")

    print("\n=== RESUMO staging_pedido_compra ===")
    print(f"Linhas a recarregar (delete + insert): {len(staging_novo)}")

    relatorio.inseridos = len(novos)
    relatorio.atualizados = len(atualizacoes)
    relatorio.reativados = n_reativado
    relatorio.inativados = len(nao_vigentes_ids)
    relatorio.ignorados = inalterados

    if dry_run:
        print("\n=== DRY-RUN: nada foi gravado ===")
        if novos:
            print("\nAmostra de pedido novo:")
            print(novos[0])
        if atualizacoes:
            print("\nAmostra de atualização:")
            print(atualizacoes[0])
        relatorio.finalizar()
        log_path = salvar_log([relatorio], dry_run)
        imprimir_resumo_final([relatorio], dry_run, log_path)
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
            relatorio.registrar_erro(f"staging lote {i}: {exc}")
    print(f"  staging_pedido_compra: {total_ok} ok, {total_erro} erros.")

    if novos:
        print(f"\nInserindo {len(novos)} pedidos novos…")
        total_ok, total_erro = 0, 0
        for i in range(0, len(novos), BATCH_SIZE):
            lote = novos[i : i + BATCH_SIZE]
            try:
                # ON CONFLICT (codigo_pedido) DO NOTHING -- upsert defensivo,
                # ja existe UNIQUE no schema (pedido_compra_codigo_pedido_key).
                client.table("pedido_compra").upsert(
                    lote, on_conflict="codigo_pedido", ignore_duplicates=True
                ).execute()
                total_ok += len(lote)
            except Exception as exc:
                print(f"  ERRO ao inserir pedido_compra lote {i}-{i+len(lote)}: {exc}")
                total_erro += len(lote)
                relatorio.registrar_erro(f"pedido_compra insert lote {i}: {exc}")
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
                relatorio.registrar_erro(f"pedido_compra update id={rec['id']}: {exc}")
        print(f"  pedido_compra update: {total_ok} ok, {total_erro} erros.")

    if nao_vigentes_ids:
        print(f"\nMarcando {len(nao_vigentes_ids)} pedidos como não vigentes…")
        total_ok, total_erro = 0, 0
        for i in range(0, len(nao_vigentes_ids), BATCH_SIZE):
            lote = nao_vigentes_ids[i : i + BATCH_SIZE]
            try:
                client.table("pedido_compra").update({"vigente": False}).in_("id", lote).execute()
                total_ok += len(lote)
            except Exception as exc:
                print(f"  ERRO ao marcar não vigente lote {i}: {exc}")
                total_erro += len(lote)
                relatorio.registrar_erro(f"vigente=false lote {i}: {exc}")
        print(f"  pedido_compra vigente=false: {total_ok} ok, {total_erro} erros.")

    relatorio.finalizar()
    log_path = salvar_log([relatorio], dry_run)
    imprimir_resumo_final([relatorio], dry_run, log_path)


def main():
    parser = argparse.ArgumentParser(description="Importa planilha PedidoCompra (Financeiro) para pedido_compra/staging_pedido_compra")
    parser.add_argument("--dry-run", action="store_true", help="Apenas mostra o que seria feito")
    args = parser.parse_args()
    processar(args.dry_run)


if __name__ == "__main__":
    main()
