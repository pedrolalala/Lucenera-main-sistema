"""
Cria em `produtos` os produtos que já existem no export Connect (planilha
Produtos__AAAA-MM-DD.xlsx) mas nunca foram cadastrados no banco -- achado ao
rodar `importar_produtos_estoque.py --dry-run` em 2026-09-21 (158 CodProduto
"sem match", excluindo o CodProduto=0 "PRODUTO ESPCIAL", que é lixo
conhecido do export e nunca deve ser criado).

Diferente de `importar_produtos_estoque.py` (só ATUALIZA produto existente,
nunca cria -- ver docstring de lá), este script resolve marca_id/
categoria_id e faz o INSERT. Roda uma única vez por leva de produtos novos
(mas é idempotente: pula qualquer codigo_produto que já exista no banco, sem
duplicar se rodado de novo).

Mapeamento (mesmo grounding do script de sync, validado por amostragem
manual reproduzindo o cálculo do trigger fn_atualizar_preco_venda com
vlCusto/desconto/icmsST/ipi/despesas -> bateu exatamente com
vlCustoIndireto/vlCustoTotal da planilha):

  CodProduto      -> produtos.codigo_produto (EXPLÍCITO -- é a chave que o
                     sync semanal usa pra combinar com a Connect; NUNCA
                     deixar o DEFAULT nextval(produtos_codigo_produto_seq)
                     gerar um código próprio aqui, senão este produto nunca
                     mais teria match nos syncs seguintes)
  DescProduto     -> produtos.nome (NOT NULL)
  Referencia      -> produtos.referencia
  CodMarca        -> produtos.marca_id (via marcas.codigo_legado)
  CodCategoria    -> produtos.categoria_id (via categorias_produto.codigo_connect)
  vlCusto         -> produtos.preco_custo (formato misto BR/US, to_numeric_br
                     trata os dois -- é o "custo base" que alimenta o
                     trigger de preço, equivalente ao NEW.preco_custo)
  vlCustoTotal    -> produtos.custo_total (mesmo mapeamento do script de sync)
  ValorVenda      -> produtos.valor_venda (idem)
  Lucro           -> produtos.percentual_lucro (idem)
  EstoqueTotal/Showroom/Disponivel -> estoque_total/estoque_showroom/estoque_disponivel (idem)
  Unidade         -> produtos.unidade
  ncm/cest        -> produtos.ncm/cest (idem, texto, nunca vira número)
  icmsST          -> produtos.porc_st E produtos.icms_entrada -- as duas
                     colunas normalmente DIVERGEM neste sistema por design
                     (porc_st é só display/sync, icms_entrada alimenta o
                     trigger e o script de sync nunca a toca pra não pisar
                     em edição manual via PecaForm -- ver AGENTS.md). Pra um
                     produto NOVO não existe edição manual prévia nenhuma
                     pra proteger, então as duas nascem iguais (mesmo valor
                     real da Connect) -- só assim o trigger calcula um
                     preco_venda coerente já na criação.
  ipi             -> produtos.ipi_entrada
  despesas        -> produtos.porc_despesas
  desconto        -> produtos.porc_desconto
  frete           -> produtos.porc_frete
  GrupoFiscalNContribuinte/GrupoFiscalRevenda -> idem

  sku, fornecedor_principal_id, categoria (texto legado): deixados NULL --
  sku é opcional e único (risco de colisão sem necessidade real);
  fornecedor_principal_id não é populado por nenhum fluxo real deste sistema
  (confirmado: só 1 produto de teste no banco inteiro tem isso preenchido --
  o fornecedor de fato é resolvido via marca.fornecedor_id, não aqui);
  categoria (coluna texto legada) está 100% vazia em todo o banco hoje
  (0/4726), mantém assim.

  preco_venda: NÃO é escrito por este script -- ao contrário do script de
  sync (que desliga os 2 triggers de preço pra proteger preco_venda
  existente numa UPDATE), aqui o INSERT roda com os triggers LIGADOS
  (comportamento padrão) -- é exatamente o que aconteceria se alguém
  cadastrasse este produto manualmente via PecaForm com os mesmos valores.
  estoque_itens também é criado automaticamente (trigger
  trg_sync_estoque_itens_from_produtos cobre AFTER INSERT, confirmado via
  pg_get_triggerdef antes de escrever este script).

Uso:
  python scripts/importar_produtos_novos.py --dry-run
  python scripts/importar_produtos_novos.py
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
PREFIXO_ARQUIVO = "Produtos__"
MIN_LINHAS = 500
COLUNAS_ESPERADAS = ["CodProduto", "DescProduto", "EstoqueTotal", "Showroom", "Disponivel"]

# CodProduto=0 ("PRODUTO ESPCIAL") é lixo conhecido do export Connect --
# nunca criar como produto real.
CODIGOS_IGNORADOS = {0}


def to_numeric_br(series: pd.Series) -> pd.Series:
    """Mesma função de importar_produtos_estoque.py -- trata BR ("1.409,76")
    e US ("3709.9") -- ver docstring de lá pro incidente que motivou isso."""

    def _parse(v: object) -> object:
        s = str(v).strip()
        if s in ("", "nan", "NaN", "None", "NaT"):
            return None
        if "," in s:
            s = s.replace(".", "").replace(",", ".")
        return s

    return pd.to_numeric(series.map(_parse), errors="coerce")


def limpar_codigo_fiscal(series: pd.Series) -> pd.Series:
    def _parse(v: object) -> object:
        if v is None or (isinstance(v, float) and pd.isna(v)):
            return None
        s = str(v).strip()
        if s in ("", "nan", "NaN", "None", "NaT", "0"):
            return None
        if s.endswith(".0") and s[:-2].isdigit():
            s = s[:-2]
        return s

    return series.apply(_parse)


def limpar_texto(series: pd.Series) -> pd.Series:
    def _parse(v: object) -> object:
        if v is None or (isinstance(v, float) and pd.isna(v)):
            return None
        s = str(v).strip()
        return s or None

    return series.apply(_parse)


def _num(v: object, default: float = 0.0) -> float:
    """Converte pra float nativo do Python (nunca numpy.float64 -- não é
    JSON-serializável pelo client do Supabase) com NaN tratado como
    ausente. `v or default` NÃO detecta NaN (NaN é truthy em Python) -- é a
    mesma classe de bug já documentada em AGENTS.md pro `close_enough`."""
    if v is None or (isinstance(v, float) and pd.isna(v)) or pd.isna(v):
        return default
    return float(v)


def _int(v: object, default: int = 0) -> int:
    return int(_num(v, default))


def buscar_paginado(client, table: str, columns: str) -> pd.DataFrame:
    rows = []
    offset = 0
    while True:
        resp = client.table(table).select(columns).range(offset, offset + 999).execute()
        data = resp.data or []
        rows.extend(data)
        if len(data) < 1000:
            break
        offset += 1000
    return pd.DataFrame(rows)


def processar(dry_run: bool) -> None:
    print(f"Supabase: {SUPABASE_URL}")
    print(f"Modo:     {'DRY-RUN (sem gravação)' if dry_run else 'GRAVAÇÃO REAL'}\n")

    relatorio = RelatorioModulo(nome="Produtos (novos)")
    try:
        planilha_path = descobrir_planilha_mais_recente(PASTA_PLANILHAS, PREFIXO_ARQUIVO)
        relatorio.arquivo_origem = planilha_path.name
        print(f"Planilha: {planilha_path.name}")

        df = pd.read_excel(planilha_path, sheet_name="Estoque", dtype=str)
        df.columns = [c.strip() for c in df.columns]
        validar_cabecalho(df.columns.tolist(), COLUNAS_ESPERADAS, origem=planilha_path.name)
        validar_minimo_linhas(len(df), MIN_LINHAS, origem=planilha_path.name)

        df["codigo_produto"] = pd.to_numeric(df["CodProduto"], errors="coerce").astype("Int64")
        df = df.dropna(subset=["codigo_produto"])
        validar_chave_unica(df, ["codigo_produto"], origem=planilha_path.name)
        df = df[~df["codigo_produto"].isin(CODIGOS_IGNORADOS)]
    except ImportacaoAbortada as exc:
        relatorio.abortado = str(exc)
        relatorio.finalizar()
        print(f"\nABORTADO: {exc}")
        relatorio.imprimir()
        log_path = salvar_log([relatorio], dry_run)
        imprimir_resumo_final([relatorio], dry_run, log_path)
        return

    client = get_client()

    print("Buscando produtos existentes (codigo_produto)...")
    existentes = buscar_paginado(client, "produtos", "codigo_produto")
    existentes_set = set(existentes["codigo_produto"].dropna().astype(int)) if len(existentes) else set()
    print(f"  {len(existentes_set)} produtos já no banco\n")

    novos_df = df[~df["codigo_produto"].isin(existentes_set)].copy()
    print(f"Produtos novos a criar: {len(novos_df)}")
    if novos_df.empty:
        print("Nada a fazer.")
        relatorio.ignorados = len(existentes_set)
        relatorio.finalizar()
        log_path = salvar_log([relatorio], dry_run)
        imprimir_resumo_final([relatorio], dry_run, log_path)
        return

    print("Buscando marcas (codigo_legado -> id)...")
    marcas = buscar_paginado(client, "marcas", "id,codigo_legado")
    marca_map = {
        int(r["codigo_legado"]): r["id"] for r in marcas.to_dict("records") if r["codigo_legado"] is not None
    }
    print("Buscando categorias_produto (codigo_connect -> id)...")
    cats = buscar_paginado(client, "categorias_produto", "id,codigo_connect")
    cat_map = {
        int(r["codigo_connect"]): r["id"] for r in cats.to_dict("records") if r["codigo_connect"] is not None
    }

    novos_df["CodMarcaNum"] = pd.to_numeric(novos_df["CodMarca"], errors="coerce")
    novos_df["CodCategoriaNum"] = pd.to_numeric(novos_df["CodCategoria"], errors="coerce")

    marcas_faltando = sorted(
        {
            (int(r["CodMarcaNum"]), r["DescMarca"])
            for r in novos_df.to_dict("records")
            if pd.notna(r["CodMarcaNum"]) and int(r["CodMarcaNum"]) not in marca_map
        }
    )
    if marcas_faltando:
        print(f"\nMarcas novas a criar antes do produto: {marcas_faltando}")
        if not dry_run:
            for cod, nome in marcas_faltando:
                resp = (
                    client.table("marcas")
                    .insert({"nome": nome, "codigo_legado": cod, "ativo": True})
                    .execute()
                )
                marca_map[cod] = resp.data[0]["id"]
                print(f"  Marca criada: {nome} (codigo_legado={cod}) -> {resp.data[0]['id']}")
        else:
            print("  (dry-run: marca(s) seriam criadas antes do produto)")

    categorias_faltando = sorted(
        {
            (int(r["CodCategoriaNum"]), r["DescCategoria"])
            for r in novos_df.to_dict("records")
            if pd.notna(r["CodCategoriaNum"]) and int(r["CodCategoriaNum"]) not in cat_map
        }
    )
    if categorias_faltando:
        print(f"\n⚠️  Categorias sem match, produto ficaria sem categoria_id: {categorias_faltando}")

    def _bn(v: object) -> float | None:
        """to_numeric_br pra um valor solto (não Series) -- devolve float
        nativo ou None (NaN-safe)."""
        parsed = to_numeric_br(pd.Series([v])).iloc[0]
        return None if pd.isna(parsed) else float(parsed)

    registros = []
    for r in novos_df.to_dict("records"):
        cod_marca = int(r["CodMarcaNum"]) if pd.notna(r["CodMarcaNum"]) else None
        cod_cat = int(r["CodCategoriaNum"]) if pd.notna(r["CodCategoriaNum"]) else None
        icms_st = _num(_bn(r["icmsST"]))
        nome_limpo = limpar_texto(pd.Series([r.get("DescProduto")])).iloc[0]
        registro = {
            "codigo_produto": _int(r["codigo_produto"]),
            "nome": nome_limpo or f"Produto {int(r['codigo_produto'])}",
            "referencia": limpar_texto(pd.Series([r.get("Referencia")])).iloc[0],
            "marca_id": marca_map.get(cod_marca),
            "categoria_id": cat_map.get(cod_cat),
            "preco_custo": _num(_bn(r["vlCusto"])),
            "custo_total": _num(_bn(r["vlCustoTotal"])),
            "valor_venda": _num(_bn(r["ValorVenda"])),
            "percentual_lucro": _num(_bn(r["Lucro"])),
            "estoque_total": _num(_bn(r["EstoqueTotal"])),
            "estoque_showroom": _int(_bn(r["Showroom"])),
            "estoque_disponivel": _num(_bn(r["Disponivel"])),
            "unidade": limpar_texto(pd.Series([r.get("Unidade")])).iloc[0] or "UN",
            "ncm": limpar_codigo_fiscal(pd.Series([r.get("ncm")])).iloc[0],
            "cest": limpar_codigo_fiscal(pd.Series([r.get("cest")])).iloc[0],
            "porc_st": icms_st,
            "icms_entrada": icms_st,
            "ipi_entrada": _num(_bn(r["ipi"])),
            "porc_despesas": _num(_bn(r["despesas"])),
            "porc_desconto": _num(_bn(r["desconto"])),
            "porc_frete": _num(_bn(r.get("frete"))),
            "grupo_fiscal_nao_contribuinte": limpar_texto(pd.Series([r.get("GrupoFiscalNContribuinte")])).iloc[0],
            "grupo_fiscal_revenda": limpar_texto(pd.Series([r.get("GrupoFiscalRevenda")])).iloc[0],
            "ativo": True,
        }
        registros.append(registro)

    print(f"\n=== RESUMO ===")
    print(f"Produtos a criar: {len(registros)}")
    sem_categoria = sum(1 for r in registros if r["categoria_id"] is None)
    sem_marca = sum(1 for r in registros if r["marca_id"] is None)
    print(f"  sem categoria_id resolvido: {sem_categoria}")
    print(f"  sem marca_id resolvido:     {sem_marca}")

    relatorio.ignorados = len(existentes_set)

    if dry_run:
        print("\n=== DRY-RUN: nada foi gravado ===")
        print("\nAmostra de produto novo:")
        print(registros[0])
        relatorio.finalizar()
        log_path = salvar_log([relatorio], dry_run)
        imprimir_resumo_final([relatorio], dry_run, log_path)
        return

    # SPEC-157: upsert com ON CONFLICT (codigo_produto) DO NOTHING em vez de
    # insert simples -- rodar o script 2x (ou em paralelo com outro import)
    # nao duplica produto; o segundo run so "perde" a corrida sem erro.
    total_ok, total_erro = 0, 0
    for i in range(0, len(registros), 100):
        lote = registros[i : i + 100]
        try:
            client.table("produtos").upsert(
                lote, on_conflict="codigo_produto", ignore_duplicates=True
            ).execute()
            total_ok += len(lote)
        except Exception as exc:
            print(f"  ERRO no lote {i}: {exc}")
            total_erro += len(lote)
            relatorio.registrar_erro(f"lote {i}: {exc}")
    print(f"\nCriação concluída: {total_ok} ok, {total_erro} erros.")
    relatorio.inseridos = total_ok
    relatorio.finalizar()
    log_path = salvar_log([relatorio], dry_run)
    imprimir_resumo_final([relatorio], dry_run, log_path)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Cria produtos novos vindos do export Connect")
    parser.add_argument("--dry-run", action="store_true", help="Apenas mostra o que seria feito")
    args = parser.parse_args()
    processar(dry_run=args.dry_run)
