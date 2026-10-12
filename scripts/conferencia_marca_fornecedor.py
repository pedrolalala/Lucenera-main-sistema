"""
SPEC-193 B2 — lista de conferência "a marca manda no fornecedor" (decisão de 09/10/2026).

O fornecedor de uma peça é sempre o `marcas.fornecedor_id` da marca dela. O import NÃO grava
fornecedor por produto. Este script só LÊ a planilha Produtos__AAAA-MM-DD.xlsx (CodFornecedor/
nmFornecedor) e o banco, e gera uma planilha de conferência para alguém decidir à mão:

  1. Marcas sem fornecedor  — marcas do banco sem `fornecedor_id`, com o fornecedor que a planilha
                              sugere (o mais frequente entre as peças da marca) e se ele já existe em
                              `contatos` (tipo fornecedor).
  2. Marca x planilha       — marcas com fornecedor cadastrado, mas cujo fornecedor mais frequente na
                              planilha é outro.
  3. Peças com outro fornec. — peças em que a planilha diz um fornecedor diferente do da marca.

NADA é gravado no banco (conexão aberta em modo somente leitura).

Casamentos:
  - peça: planilha CodProduto = produtos.codigo_produto; a marca é a do banco (produtos.marca_id).
  - fornecedor: `contatos` não tem o código da Connect, então o nmFornecedor é casado pelo nome
    (nome ou razão social), sem acento, maiúsculo e sem LTDA/EPP/ME/S.A./pontuação.

Uso:
  python scripts/conferencia_marca_fornecedor.py
  (também roda no fim de scripts/importar_produtos_estoque.py)
"""

import re
import sys
import unicodedata
from collections import Counter
from pathlib import Path

import pandas as pd
import psycopg2

if sys.stdout.encoding and sys.stdout.encoding.lower() != "utf-8":
    sys.stdout.reconfigure(encoding="utf-8")

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "scripts"))

from _supabase_client import SUPABASE_DB_URL  # noqa: E402
from sync_connect_common import descobrir_planilha_mais_recente  # noqa: E402

PASTA_PLANILHAS = ROOT / "01-Documento" / "01 - Planilhas"
PREFIXO_ARQUIVO = "Produtos__"
PASTA_SAIDA = ROOT / "scripts" / "logs" / "conferencia_fornecedor"

SUFIXOS_EMPRESA = {"LTDA", "EPP", "ME", "EIRELI", "SA", "S/A", "CIA", "COMERCIO", "INDUSTRIA", "E"}


def normalizar_nome(v: object) -> str:
    if v is None or (isinstance(v, float) and pd.isna(v)):
        return ""
    s = unicodedata.normalize("NFKD", str(v)).encode("ascii", "ignore").decode().upper()
    s = re.sub(r"[^A-Z0-9 ]", " ", s)
    palavras = [p for p in s.split() if p not in SUFIXOS_EMPRESA]
    return " ".join(palavras)


def carregar_planilha(path: Path) -> pd.DataFrame:
    df = pd.read_excel(path, sheet_name="Estoque", dtype=str)
    df.columns = [c.strip() for c in df.columns]
    df["codigo_produto"] = pd.to_numeric(df["CodProduto"], errors="coerce").astype("Int64")
    df = df.dropna(subset=["codigo_produto"])
    df["nm_fornecedor"] = df["nmFornecedor"].fillna("").str.strip()
    df["cod_fornecedor"] = df["CodFornecedor"].fillna("").str.strip()
    return df[["codigo_produto", "Referencia", "DescProduto", "cod_fornecedor", "nm_fornecedor"]]


def conectar():
    """Host direto; se o DNS falhar (o host direto só tem IPv6 nesta rede), usa o session pooler IPv4."""
    try:
        return psycopg2.connect(SUPABASE_DB_URL, connect_timeout=20)
    except psycopg2.OperationalError as exc:
        m = re.search(r"//postgres:.*@db\.([a-z0-9]+)\.supabase\.co:5432", SUPABASE_DB_URL)
        if "translate host name" not in str(exc) or not m:
            raise
        ref = m.group(1)
        url = SUPABASE_DB_URL.replace("//postgres:", f"//postgres.{ref}:", 1).replace(
            f"db.{ref}.supabase.co:5432", "aws-1-us-east-2.pooler.supabase.com:5432"
        )
        print("  (host direto sem DNS — usando o session pooler)")
        return psycopg2.connect(url, connect_timeout=20)


def carregar_banco() -> tuple[pd.DataFrame, pd.DataFrame, pd.DataFrame]:
    conn = conectar()
    try:
        conn.set_session(readonly=True)
        marcas = pd.read_sql(
            "select m.id::text as marca_id, m.codigo_legado as cod_marca, m.nome as marca, "
            "m.fornecedor_id::text as fornecedor_id, c.nome as fornecedor_marca "
            "from public.marcas m left join public.contatos c on c.id = m.fornecedor_id",
            conn,
        )
        contatos = pd.read_sql(
            "select id::text as id, nome, razao_social from public.contatos where tipo = 'fornecedor'",
            conn,
        )
        produtos = pd.read_sql(
            "select codigo_produto, nome, referencia, marca_id::text as marca_id, ativo "
            "from public.produtos where codigo_produto is not null",
            conn,
        )
    finally:
        conn.close()
    produtos["codigo_produto"] = produtos["codigo_produto"].astype("Int64")
    return marcas, contatos, produtos


def indexar_contatos(contatos: pd.DataFrame) -> dict[str, list[tuple[str, str]]]:
    """nome normalizado -> [(id, nome)]; nome e razão social contam os dois."""
    idx: dict[str, list[tuple[str, str]]] = {}
    for r in contatos.itertuples():
        for campo in (r.nome, r.razao_social):
            chave = normalizar_nome(campo)
            if chave:
                lista = idx.setdefault(chave, [])
                if (r.id, r.nome) not in lista:
                    lista.append((r.id, r.nome))
    return idx


def gerar_conferencia(planilha_path: Path | None = None) -> Path:
    if planilha_path is None:
        planilha_path = descobrir_planilha_mais_recente(PASTA_PLANILHAS, PREFIXO_ARQUIVO)
    print(f"\n=== Conferência marca x fornecedor (SPEC-193 B2) — {planilha_path.name} ===")
    planilha = carregar_planilha(planilha_path)
    marcas, contatos, produtos = carregar_banco()
    idx = indexar_contatos(contatos)

    def casar(nm: str) -> tuple[set[str], str]:
        """ids dos contatos com esse nome (pode haver cadastro duplicado) e o texto para a lista."""
        achados = idx.get(normalizar_nome(nm), [])
        if len(achados) == 1:
            return {achados[0][0]}, achados[0][1]
        if len(achados) > 1:
            return {i for i, _ in achados}, "cadastro duplicado: " + "; ".join(n for _, n in achados)
        return set(), "não cadastrado"

    def igual(ids: set[str], nm: str, fornecedor_id, fornecedor_marca) -> bool:
        if ids:
            return fornecedor_id in ids
        return normalizar_nome(nm) == normalizar_nome(fornecedor_marca)

    base = planilha.merge(produtos, on="codigo_produto", how="inner").merge(
        marcas, on="marca_id", how="left"
    )
    base = base[base["nm_fornecedor"] != ""]

    # Fornecedor da planilha casado com contatos (uma vez por nome).
    casamentos = {nm: casar(nm) for nm in base["nm_fornecedor"].unique()}
    base["fornecedor_planilha_cadastro"] = base["nm_fornecedor"].map(lambda n: casamentos[n][1])

    def mesmo_fornecedor(r) -> bool:
        return igual(casamentos[r.nm_fornecedor][0], r.nm_fornecedor, r.fornecedor_id, r.fornecedor_marca)

    # 1 e 2: por marca, o fornecedor mais frequente na planilha.
    linhas_marca_sem, linhas_marca_dif = [], []
    for marca_id, grupo in base[base["marca_id"].notna()].groupby("marca_id"):
        cont = Counter(grupo["nm_fornecedor"])
        nm_top, qtd_top = cont.most_common(1)[0]
        m = grupo.iloc[0]
        cad_ids, cad_txt = casamentos[nm_top]
        linha = {
            "Cód. marca (Connect)": m.cod_marca,
            "Marca": m.marca,
            "Peças da marca na planilha": len(grupo),
            "Fornecedor sugerido pela planilha": nm_top,
            "Peças com esse fornecedor": qtd_top,
            "Outros fornecedores na planilha": "; ".join(
                f"{n} ({q})" for n, q in cont.most_common() if n != nm_top
            ),
            "Cadastro do fornecedor sugerido": cad_txt,
        }
        if pd.isna(m.fornecedor_id):
            linhas_marca_sem.append(linha)
        else:
            if not igual(cad_ids, nm_top, m.fornecedor_id, m.fornecedor_marca):
                linhas_marca_dif.append({**linha, "Fornecedor da marca no sistema": m.fornecedor_marca})

    # Marcas sem fornecedor que nem aparecem na planilha também entram (sugestão vazia).
    marcas_na_lista = {r["Marca"] for r in linhas_marca_sem}
    for m in marcas[marcas["fornecedor_id"].isna()].itertuples():
        if m.marca not in marcas_na_lista:
            n_pecas = int((produtos["marca_id"] == m.marca_id).sum())
            linhas_marca_sem.append(
                {
                    "Cód. marca (Connect)": m.cod_marca,
                    "Marca": m.marca,
                    "Peças da marca na planilha": 0,
                    "Fornecedor sugerido pela planilha": "",
                    "Peças com esse fornecedor": 0,
                    "Outros fornecedores na planilha": "",
                    "Cadastro do fornecedor sugerido": f"marca sem peça na planilha ({n_pecas} no sistema)",
                }
            )

    # 3: peça a peça, só onde a marca já tem fornecedor.
    com_forn = base[base["fornecedor_id"].notna()]
    divergentes = com_forn[~com_forn.apply(mesmo_fornecedor, axis=1)]
    linhas_pecas = [
        {
            "Código": int(r.codigo_produto),
            "Referência": r.referencia,
            "Peça": r.nome,
            "Ativa": "sim" if r.ativo else "não",
            "Marca": r.marca,
            "Fornecedor da marca (sistema)": r.fornecedor_marca,
            "Fornecedor na planilha": r.nm_fornecedor,
            "Cadastro do fornecedor da planilha": r.fornecedor_planilha_cadastro,
        }
        for r in divergentes.sort_values(["marca", "codigo_produto"]).itertuples()
    ]

    sem_marca = int(base["marca_id"].isna().sum())

    PASTA_SAIDA.mkdir(parents=True, exist_ok=True)
    saida = PASTA_SAIDA / f"conferencia_marca_fornecedor_{planilha_path.stem.replace(PREFIXO_ARQUIVO, '')}.xlsx"
    with pd.ExcelWriter(saida) as w:
        pd.DataFrame(
            [
                {"Item": "Planilha", "Valor": planilha_path.name},
                {"Item": "Marcas sem fornecedor no sistema", "Valor": len(linhas_marca_sem)},
                {"Item": "Marcas cujo fornecedor na planilha é outro", "Valor": len(linhas_marca_dif)},
                {"Item": "Peças com fornecedor diferente do da marca", "Valor": len(linhas_pecas)},
                {"Item": "Peças da planilha sem marca no sistema (fora da conferência)", "Valor": sem_marca},
                {
                    "Item": "Regra",
                    "Valor": "O fornecedor da peça é o da marca (decisão 09/10). Nada foi gravado: "
                    "corrigir à mão no Cadastro (marca) ou na Connect.",
                },
            ]
        ).to_excel(w, sheet_name="Resumo", index=False)
        pd.DataFrame(linhas_marca_sem).sort_values(
            "Peças da marca na planilha", ascending=False
        ).to_excel(w, sheet_name="Marcas sem fornecedor", index=False)
        pd.DataFrame(linhas_marca_dif).to_excel(w, sheet_name="Marca x planilha", index=False)
        pd.DataFrame(linhas_pecas).to_excel(w, sheet_name="Peças com outro fornecedor", index=False)

    print(f"  Marcas sem fornecedor no sistema:            {len(linhas_marca_sem)}")
    print(f"  Marcas cujo fornecedor na planilha é outro:  {len(linhas_marca_dif)}")
    print(f"  Peças com fornecedor diferente do da marca:  {len(linhas_pecas)}")
    print(f"  Nada gravado no banco. Lista: {saida}")
    return saida


if __name__ == "__main__":
    gerar_conferencia()
