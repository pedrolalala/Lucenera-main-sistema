"""
Cria pedidos_compra (plural) — a tabela real usada pela tela "Pedidos de
Compra" do sistema compras-lucenera-3o23t98ee — a partir dos 60 pedidos
históricos importados de PedidoCompra_2026-07-22.xlsx (ver
scripts/importar_pedido_compra.py, que gravou o dado bruto em
pedido_compra/staging_pedido_compra, tabelas órfãs sem consumidor).

Decisão explícita do usuário (2026-07-22): esses pedidos devem aparecer na
tela real de Pedidos, mas SEM item de produto vinculado — de propósito.
Um pedido sem pedido_compra_itens não entra em nenhum cálculo de
vw_necessidade_compra (que agrega só via item->produto), então não reduz
"Pendente" de nenhum produto — correto, já que pedidos antigos (alguns de
abril/2025) não devem mexer no déficit de necessidade de compra atual.

Escolhas de modelagem (confirmadas com o usuário):
  - numero: 'PC-LEGADO-<codigo_pedido>' — não usa o formato PC-<ano>-NNNN
    (reservado para pedidos criados pelo fluxo real de Necessidade de Compra)
    para deixar visualmente claro que é dado histórico importado.
  - status: 'enviado' ("Pedido Emitido") para todos — mesmo default que
    criar_pedido_compra_lote/criar_pedido_compra_de_necessidade usam quando
    um pedido é criado de verdade hoje. Não há sinal de pago/recebido na
    planilha para diferenciar.
  - empresa_id: EMPRESA_LUCE_NERA_ID, mesmo padrão já usado em
    importar_contas_pagar_receber.py para dado legado Connect sem
    diferenciação de empresa real (ISLIGHT/FOCO/MANOELLA).
  - pedido_compra_parcelas: gravadas com o valor/vencimento REAIS da planilha
    (vl_duplicata/dt_vencimento/num_parc), não pela divisão automática de
    gerar_parcelas_pedido_compra — mais preciso. status='pendente' (sem sinal
    de pagamento na planilha). Pedidos sem parcela lançada na planilha (4 de
    60) ficam sem parcela — dá pra gerar depois pela tela se necessário.

Fornecedor (pedidos_compra.fornecedor_id -> contatos.id): não há
codigo_fornecedor em contatos (só em clientes via codigo_legado) — match por
nome exato (normalizado, maiúsculo). 9 dos 60 pedidos foram propositalmente
DEIXADOS DE FORA desta importação porque o nome do fornecedor é ambíguo ou
não existe em contatos (achado documentado no CHANGELOG/estoque_compras.md):
  - STELLA (5 pedidos: 646, 1699, 1700, 1713, 1714): 2 contatos com o mesmo
    nome, CNPJs de filiais diferentes (SC .../0003-70 vs RS .../0001-09) —
    planilha não traz CNPJ pra desambiguar.
  - TENSOFLEX (3 pedidos: 1702, 1709, 1723): mesma situação, 2 CNPJs
    diferentes, ambos Rio de Janeiro.
  - METALURGICA IL INDUSTRIA DE ILUMINAÇÃO LTDA (1 pedido: 1659): não existe
    em contatos (differente de "METALURGICA AVER METAIS LTDA").

Uso:
  python scripts/criar_pedidos_compra_legado.py --dry-run
  python scripts/criar_pedidos_compra_legado.py
"""

import argparse
import sys
import unicodedata
from datetime import datetime
from pathlib import Path

import pandas as pd

if sys.stdout.encoding and sys.stdout.encoding.lower() != "utf-8":
    sys.stdout.reconfigure(encoding="utf-8")

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "dashboard"))

from config import get_client, SUPABASE_URL  # noqa: E402

PLANILHA_PADRAO = ROOT / "01-Documento" / "01 - Planilhas" / "PedidoCompra_2026-07-22.xlsx"
EMPRESA_LUCE_NERA_ID = "2470fa14-1a00-4952-92e2-7e8cf61f8943"
NUMERO_PREFIXO = "PC-LEGADO-"

BATCH_SIZE = 100

# Fornecedores propositalmente pulados (ambíguo ou sem cadastro) — ver docstring.
CODIGOS_PEDIDO_PULADOS = {646, 1699, 1700, 1713, 1714, 1702, 1709, 1723, 1659}


def normalizar_nome(nome: str) -> str:
    s = unicodedata.normalize("NFKD", nome).encode("ascii", "ignore").decode()
    return s.upper().strip()


def to_iso_date(value) -> str | None:
    if value is None or (isinstance(value, float) and pd.isna(value)) or str(value).strip() in ("", "nan", "NaT"):
        return None
    return datetime.strptime(str(value).strip(), "%d/%m/%Y").strftime("%Y-%m-%d")


def carregar_planilha(path: Path) -> pd.DataFrame:
    df = pd.read_excel(path, sheet_name="Financeiro")
    df.columns = [c.strip() for c in df.columns]
    df["codigo_pedido"] = pd.to_numeric(df["codigo_pedido"], errors="coerce").astype("Int64")
    df["nm_fornecedor"] = df["nm_fornecedor"].astype(str).str.strip()
    df["vl_nota"] = pd.to_numeric(df["vl_nota"], errors="coerce")
    df["vl_duplicata"] = pd.to_numeric(df["vl_duplicata"], errors="coerce")
    df["num_parc"] = pd.to_numeric(df["num_parc"], errors="coerce").astype("Int64")
    df = df.dropna(subset=["codigo_pedido", "nm_fornecedor", "vl_nota"])
    df = df[~df["codigo_pedido"].isin(CODIGOS_PEDIDO_PULADOS)]
    return df


def processar(dry_run: bool) -> None:
    print(f"Supabase: {SUPABASE_URL}")
    print(f"Modo:     {'DRY-RUN (sem gravação)' if dry_run else 'GRAVAÇÃO REAL'}\n")

    df = carregar_planilha(PLANILHA_PADRAO)
    pedidos_unicos = sorted(df["codigo_pedido"].unique())
    print(f"Pedidos a considerar (excluindo os {len(CODIGOS_PEDIDO_PULADOS)} com fornecedor ambíguo/sem match): {len(pedidos_unicos)}")

    client = get_client()

    print("Buscando contatos (fornecedor)…")
    contatos_resp = client.table("contatos").select("id,nome").eq("tipo", "fornecedor").execute()
    nome_para_id: dict[str, list[str]] = {}
    for row in contatos_resp.data or []:
        chave = normalizar_nome(row["nome"])
        nome_para_id.setdefault(chave, []).append(row["id"])
    print(f"  {len(contatos_resp.data or [])} contatos fornecedor no banco\n")

    print("Buscando pedidos_compra já importados (numero PC-LEGADO-*)…")
    existentes_resp = client.table("pedidos_compra").select("id,numero").like("numero", f"{NUMERO_PREFIXO}%").execute()
    codigos_ja_importados = {int(r["numero"].replace(NUMERO_PREFIXO, "")) for r in (existentes_resp.data or [])}
    print(f"  {len(codigos_ja_importados)} já importados anteriormente\n")

    headers = []
    sem_match_fornecedor = []
    for codigo_pedido, grupo in df.groupby("codigo_pedido"):
        codigo_pedido = int(codigo_pedido)
        if codigo_pedido in codigos_ja_importados:
            continue
        primeira = grupo.iloc[0]
        chave_nome = normalizar_nome(primeira["nm_fornecedor"])
        candidatos = nome_para_id.get(chave_nome, [])
        if len(candidatos) != 1:
            sem_match_fornecedor.append((codigo_pedido, primeira["nm_fornecedor"], len(candidatos)))
            continue
        headers.append(
            {
                "codigo_pedido": codigo_pedido,
                "numero": f"{NUMERO_PREFIXO}{codigo_pedido}",
                "fornecedor_id": candidatos[0],
                "status": "enviado",
                "data_emissao": to_iso_date(primeira["emissao_pedido"]),
                "valor_total": float(primeira["vl_nota"]),
                "observacao": (
                    f"Legado Connect — importado de PedidoCompra_2026-07-22.xlsx "
                    f"(codigo_pedido original {codigo_pedido}). Sem item de produto "
                    f"vinculado por decisão do usuário — não conta na Necessidade de Compra."
                ),
                "empresa_id": EMPRESA_LUCE_NERA_ID,
                "grupo": grupo,
            }
        )

    print("=== RESUMO ===")
    print(f"Pedidos a criar em pedidos_compra: {len(headers)}")
    print(f"Sem match de fornecedor (inesperado, reportar): {len(sem_match_fornecedor)}")
    if sem_match_fornecedor:
        for cod, nome, n in sem_match_fornecedor:
            print(f"  - codigo_pedido {cod}: '{nome}' -> {n} candidato(s)")

    total_parcelas = sum(int(h["grupo"]["num_parc"].notna().sum()) for h in headers)
    print(f"Parcelas reais a gravar em pedido_compra_parcelas: {total_parcelas}")

    if dry_run:
        print("\n=== DRY-RUN: nada foi gravado ===")
        if headers:
            amostra = {k: v for k, v in headers[0].items() if k != "grupo"}
            print("\nAmostra de pedido novo:")
            print(amostra)
        return

    if not headers:
        print("\nNada para gravar.")
        return

    print(f"\nInserindo {len(headers)} pedidos em pedidos_compra…")
    total_ok, total_erro = 0, 0
    id_por_codigo = {}
    for h in headers:
        rec = {k: v for k, v in h.items() if k not in ("grupo", "codigo_pedido")}
        try:
            resp = client.table("pedidos_compra").insert(rec).execute()
            id_por_codigo[h["codigo_pedido"]] = resp.data[0]["id"]
            total_ok += 1
        except Exception as exc:
            print(f"  ERRO ao inserir pedido codigo_pedido={h['codigo_pedido']}: {exc}")
            total_erro += 1
    print(f"  pedidos_compra: {total_ok} ok, {total_erro} erros.")

    parcelas = []
    for h in headers:
        pedido_id = id_por_codigo.get(h["codigo_pedido"])
        if pedido_id is None:
            continue
        for row in h["grupo"].to_dict("records"):
            if pd.isna(row["num_parc"]):
                continue
            parcelas.append(
                {
                    "pedido_id": pedido_id,
                    "numero_parcela": int(row["num_parc"]),
                    "valor": float(row["vl_duplicata"]),
                    "data_vencimento": to_iso_date(row["dt_vencimento"]),
                    "status": "pendente",
                }
            )

    if parcelas:
        print(f"\nInserindo {len(parcelas)} parcelas em pedido_compra_parcelas…")
        total_ok, total_erro = 0, 0
        for i in range(0, len(parcelas), BATCH_SIZE):
            lote = parcelas[i : i + BATCH_SIZE]
            try:
                client.table("pedido_compra_parcelas").insert(lote).execute()
                total_ok += len(lote)
            except Exception as exc:
                print(f"  ERRO ao inserir lote de parcelas {i}-{i+len(lote)}: {exc}")
                total_erro += len(lote)
        print(f"  pedido_compra_parcelas: {total_ok} ok, {total_erro} erros.")


def main():
    parser = argparse.ArgumentParser(description="Cria pedidos_compra (header, sem item) a partir do legado PedidoCompra")
    parser.add_argument("--dry-run", action="store_true", help="Apenas mostra o que seria feito")
    args = parser.parse_args()
    processar(args.dry_run)


if __name__ == "__main__":
    main()
