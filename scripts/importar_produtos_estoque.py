"""
Sincroniza produtos/estoque_itens a partir da planilha Produtos__AAAA-MM-DD.xlsx
(export "Estoque" do sistema legado).

Mapeamento (grounded no schema real, supabase/db/current/01_schema_full.sql):
  CodProduto   -> produtos.codigo_produto (chave única de match)
  EstoqueTotal, Showroom, Disponivel -> produtos.estoque_total / estoque_showroom / estoque_disponivel
  vlCustoTotal -> produtos.custo_total (é o custo UNITÁRIO, confirmado por amostragem — não mexe em
                  preco_custo/preco_venda para não disparar o trigger fn_atualizar_preco_venda).
                  ATÉ 2026-09-08 essa coluna da planilha se chamava `CustoTotal`; o export
                  Connect de 2026-09-10 renomeou para `vlCustoTotal` (mesmo dado, formato BR).
  ValorVenda   -> produtos.valor_venda (coluna nunca foi sincronizada antes — hoje 100% zerada)
  Lucro        -> produtos.percentual_lucro
  ncm          -> produtos.ncm  (SPEC "Fase A" 2026-09-10: coluna já existia, só ~372/4726
                  preenchidos; a planilha 09-10 traz 4.496. Texto de 8 dígitos.)
  cest         -> produtos.cest (idem; ~2 preenchidos hoje, planilha traz 1.249. Texto de
                  7 dígitos, PODE ter zero à esquerda — nunca converter para número.)

  ncm/cest: só GRAVA quando a planilha traz valor. Se a planilha vier vazia para um
  produto que já tem ncm/cest no banco, NÃO apaga (o export Connect pode estar
  incompleto; não destruir dado num "talvez").

  SPEC-132 Fase B (percentuais fiscais, "igual à planilha", SEM mexer no preço):
    icmsST   -> produtos.porc_st          (campo "% ST" do PecaForm; NÃO está no trigger)
    ipi      -> produtos.ipi_entrada      (está no trigger trg_atualizar_preco_venda)
    despesas -> produtos.porc_despesas    (está no trigger)
    desconto -> produtos.porc_desconto    (está no trigger)
    frete    -> produtos.porc_frete       (sempre 0 na planilha; NÃO está no trigger)
    GrupoFiscalNContribuinte -> produtos.grupo_fiscal_nao_contribuinte (text, migration 131)
    GrupoFiscalRevenda       -> produtos.grupo_fiscal_revenda          (text, migration 131)

  Preço congelado — DESLIGANDO os 2 triggers de preço durante a gravação real:
  `produtos` tem DOIS triggers que chamam fn_atualizar_preco_venda (custo_total x 2.5):
  trg_atualizar_preco_venda (column-scoped: preco_custo/porc_desconto/icms_entrada/
  ipi_entrada/porc_despesas) E trg_calculo_preco_venda (SEM filtro de coluna — dispara
  em QUALQUER update da linha). Incidente 2026-09-10: a 1ª versão deste script tentava
  "gravar o campo fiscal e depois regravar preco_venda de volta" — não funcionou porque
  a PRÓPRIA regravação redisparava trg_calculo_preco_venda (ele não olha quais colunas
  mudaram). ~2.120 produtos ficaram com preco_venda inflado até o reparo manual
  (scripts/_fase_b_rollback_preco_venda.py). A partir desta versão, a gravação real
  roda numa única transação via psycopg2 (SUPABASE_DB_URL) com os 2 triggers
  DESLIGADOS do início ao fim — preco_venda nunca é recalculado, ponto. custo_total /
  valor_venda continuam vindo direto da Connect.

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
import psycopg2
from psycopg2.extras import execute_batch

if sys.stdout.encoding and sys.stdout.encoding.lower() != "utf-8":
    sys.stdout.reconfigure(encoding="utf-8")

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "scripts"))

from _supabase_client import get_client, SUPABASE_URL, SUPABASE_DB_URL  # noqa: E402
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

# SPEC-157: piso de seguranca (NUNCA expectativa de volume -- so pra travar
# um export vazio/truncado de disparar inativacao em massa).
MIN_LINHAS = 500
COLUNAS_ESPERADAS = ["CodProduto", "EstoqueTotal", "Showroom", "Disponivel", "vlCustoTotal", "ValorVenda"]
CHAVE_NATURAL = ["codigo_produto"]

BATCH_SIZE = 200
PAGE_SIZE = 1000

# Os 2 triggers de preço em produtos (ver docstring do módulo — incidente 2026-09-10).
# Desligados durante toda a gravação real para que preco_venda NUNCA seja recalculado.
TRIGGERS_PRECO = ["trg_calculo_preco_venda", "trg_atualizar_preco_venda"]


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


def limpar_codigo_fiscal(series: pd.Series) -> pd.Series:
    """NCM/CEST: código numérico que é TEXTO (pode ter zero à esquerda — CEST
    '0900100'). Nunca passar por to_numeric. Retorna string limpa ou None.

    Usa .apply (não .map): .map pula os NaN sem chamar a função, e a planilha
    entrega célula vazia como float NaN mesmo com dtype=str.
    """

    def _parse(v: object) -> object:
        if v is None or (isinstance(v, float) and pd.isna(v)):
            return None
        s = str(v).strip()
        if s in ("", "nan", "NaN", "None", "NaT", "0"):
            return None
        if s.endswith(".0") and s[:-2].isdigit():  # Excel às vezes entrega "85392190.0"
            s = s[:-2]
        return s

    return series.apply(_parse)


def limpar_texto(series: pd.Series) -> pd.Series:
    """Texto simples (grupos fiscais): string limpa ou None."""

    def _parse(v: object) -> object:
        if v is None or (isinstance(v, float) and pd.isna(v)):
            return None
        s = str(v).strip()
        return s or None

    return series.apply(_parse)


# SPEC-132: campos fiscais percentuais. Os 3 primeiros disparam
# trg_atualizar_preco_venda -> exigem o restore de preco_venda.
FISCAL_NUM_TRIGGER = ["ipi_entrada", "porc_despesas", "porc_desconto"]
FISCAL_NUM_SAFE = ["porc_st", "porc_frete"]
FISCAL_TXT = ["grupo_fiscal_nao_contribuinte", "grupo_fiscal_revenda"]


def carregar_planilha(path: Path) -> pd.DataFrame:
    df = pd.read_excel(path, sheet_name="Estoque", dtype=str)
    df.columns = [c.strip() for c in df.columns]

    validar_cabecalho(df.columns.tolist(), COLUNAS_ESPERADAS, origem=path.name)
    validar_minimo_linhas(len(df), MIN_LINHAS, origem=path.name)

    df["codigo_produto"] = pd.to_numeric(df["CodProduto"], errors="coerce").astype("Int64")
    df = df.dropna(subset=["codigo_produto"])
    validar_chave_unica(df, CHAVE_NATURAL, origem=path.name)

    df["estoque_total"] = to_numeric_br(df["EstoqueTotal"]).fillna(0)
    df["estoque_showroom"] = to_numeric_br(df["Showroom"]).fillna(0)
    df["estoque_disponivel"] = to_numeric_br(df["Disponivel"]).fillna(0)
    # 2026-09-10: coluna renomeada de "CustoTotal" para "vlCustoTotal" no export Connect.
    df["custo_total"] = to_numeric_br(df["vlCustoTotal"]).fillna(0)
    df["valor_venda"] = to_numeric_br(df["ValorVenda"]).fillna(0)
    df["percentual_lucro"] = to_numeric_br(df["Lucro"]).fillna(0)
    df["ncm"] = limpar_codigo_fiscal(df["ncm"])
    df["cest"] = limpar_codigo_fiscal(df["cest"])

    # SPEC-132 Fase B — percentuais fiscais (formato US, sem milhar).
    df["porc_st"] = to_numeric_br(df["icmsST"])
    df["ipi_entrada"] = to_numeric_br(df["ipi"])
    df["porc_despesas"] = to_numeric_br(df["despesas"])
    df["porc_desconto"] = to_numeric_br(df["desconto"])
    df["porc_frete"] = to_numeric_br(df["frete"])
    df["grupo_fiscal_nao_contribuinte"] = limpar_texto(df["GrupoFiscalNContribuinte"])
    df["grupo_fiscal_revenda"] = limpar_texto(df["GrupoFiscalRevenda"])

    return df[
        [
            "codigo_produto",
            "estoque_total",
            "estoque_showroom",
            "estoque_disponivel",
            "custo_total",
            "valor_venda",
            "percentual_lucro",
            "ncm",
            "cest",
            *FISCAL_NUM_TRIGGER,
            *FISCAL_NUM_SAFE,
            *FISCAL_TXT,
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
    # NaN-safe: pandas .to_dict transforma NULL de coluna numérica em NaN, e
    # `NaN or 0` == NaN (NaN é truthy) — sem esse guard todo campo nulo parecia
    # "diferente" de 0 e o script gravava 0 em tudo.
    a = 0.0 if pd.isna(a) else float(a)
    b = 0.0 if pd.isna(b) else float(b)
    # Folga de ponto flutuante: percentual_lucro é numeric(,2) no banco e a
    # planilha manda 3 casas (152.075 vira 152.08); a diferença "exata" de
    # 0.005 sai 0.0050000000000x e o produto parecia alterado em todo run.
    return abs(a - b) <= tol + 1e-9


def processar(dry_run: bool) -> None:
    print(f"Supabase: {SUPABASE_URL}")
    print(f"Modo:     {'DRY-RUN (sem gravação)' if dry_run else 'GRAVAÇÃO REAL'}\n")

    relatorio = RelatorioModulo(nome="Produtos (estoque)")
    try:
        planilha_path = descobrir_planilha_mais_recente(PASTA_PLANILHAS, PREFIXO_ARQUIVO)
        relatorio.arquivo_origem = planilha_path.name
        print(f"Planilha: {planilha_path.name}")
        planilha = carregar_planilha(planilha_path)
    except ImportacaoAbortada as exc:
        relatorio.abortado = str(exc)
        relatorio.finalizar()
        print(f"\nABORTADO: {exc}")
        relatorio.imprimir()
        log_path = salvar_log([relatorio], dry_run)
        imprimir_resumo_final([relatorio], dry_run, log_path)
        return
    print(f"Linhas na planilha, após limpeza: {len(planilha)}")
    codigos_planilha = set(planilha["codigo_produto"].astype(int))

    client = get_client()

    print("Buscando produtos existentes…")
    produtos = buscar_paginado(
        client,
        "produtos",
        "id,codigo_produto,estoque_total,estoque_showroom,estoque_disponivel,"
        "custo_total,valor_venda,percentual_lucro,ncm,cest,preco_venda,ativo,"
        + ",".join(FISCAL_NUM_TRIGGER + FISCAL_NUM_SAFE + FISCAL_TXT),
    )
    produtos["codigo_produto"] = pd.to_numeric(produtos["codigo_produto"], errors="coerce").astype(
        "Int64"
    )
    print(f"  {len(produtos)} produtos no banco\n")
    produtos_map = produtos.set_index("codigo_produto").to_dict("index")

    updates_produtos = []
    sem_match = []
    inalterados = 0
    n_num = 0
    n_ncm = 0
    n_cest = 0
    n_fiscal = 0
    n_reativado = 0

    def _norm_cod_fiscal(v: object) -> object:
        s = str(v).strip() if v is not None else ""
        return s if s not in ("", "nan", "None", "NaT", "0") else None

    def _norm_txt(v: object) -> object:
        s = str(v).strip() if v is not None else ""
        return s if s not in ("", "nan", "None", "NaT") else None

    for row in planilha.to_dict("records"):
        cod = row["codigo_produto"]
        existente = produtos_map.get(cod)

        if existente is None:
            sem_match.append(cod)
            continue

        mudou_num = (
            not close_enough(existente["estoque_total"], row["estoque_total"])
            or not close_enough(existente["estoque_showroom"], row["estoque_showroom"])
            or not close_enough(existente["estoque_disponivel"], row["estoque_disponivel"])
            or not close_enough(existente["custo_total"], row["custo_total"])
            or not close_enough(existente["valor_venda"], row["valor_venda"])
            or not close_enough(existente["percentual_lucro"], row["percentual_lucro"])
        )

        # ncm/cest: só grava quando a planilha traz valor E é diferente do banco.
        # Planilha vazia NÃO apaga o que já existe (export Connect pode estar incompleto).
        ncm_novo = None if pd.isna(row["ncm"]) else str(row["ncm"]).strip() or None
        cest_novo = None if pd.isna(row["cest"]) else str(row["cest"]).strip() or None
        mudou_ncm = ncm_novo is not None and ncm_novo != _norm_cod_fiscal(existente.get("ncm"))
        mudou_cest = cest_novo is not None and cest_novo != _norm_cod_fiscal(existente.get("cest"))

        # SPEC-132 — percentuais fiscais. close_enough trata None==0 (não grava
        # onde a planilha traz 0 e o banco está nulo). Pula valor ausente (NaN).
        fiscal_num_alt = {}
        for campo in FISCAL_NUM_TRIGGER + FISCAL_NUM_SAFE:
            val = row[campo]
            if pd.isna(val):
                continue
            if not close_enough(existente.get(campo), val):
                fiscal_num_alt[campo] = float(val)
        fiscal_txt_alt = {}
        for campo in FISCAL_TXT:
            novo = _norm_txt(row[campo])
            if novo is not None and novo != _norm_txt(existente.get(campo)):
                fiscal_txt_alt[campo] = novo
        mudou_fiscal = bool(fiscal_num_alt or fiscal_txt_alt)

        # SPEC-157: produto que tinha sido inativado (ativo=false, porque saiu
        # de um export anterior) e voltou a aparecer no export atual -- a
        # planilha e' a fonte de verdade, reativa.
        reativar = existente.get("ativo") is False

        if mudou_num or mudou_ncm or mudou_cest or mudou_fiscal or reativar:
            rec = {"id": existente["id"]}
            if reativar:
                rec["ativo"] = True
                n_reativado += 1
            # Só manda os campos numéricos quando algum deles mudou de verdade —
            # evita ~4 mil UPDATEs redundantes de estoque_total (que disparam o
            # trigger fn_sync_estoque_itens_from_produtos) durante o backfill de ncm/cest.
            if mudou_num:
                n_num += 1
                rec.update(
                    {
                        "estoque_total": row["estoque_total"],
                        "estoque_showroom": row["estoque_showroom"],
                        "estoque_disponivel": row["estoque_disponivel"],
                        "custo_total": row["custo_total"],
                        "valor_venda": row["valor_venda"],
                        "percentual_lucro": row["percentual_lucro"],
                    }
                )
            if mudou_ncm:
                rec["ncm"] = ncm_novo
                n_ncm += 1
            if mudou_cest:
                rec["cest"] = cest_novo
                n_cest += 1
            if mudou_fiscal:
                rec.update(fiscal_num_alt)
                rec.update(fiscal_txt_alt)
                n_fiscal += 1
            updates_produtos.append(rec)
        else:
            inalterados += 1

    # SPEC-157: espelho com SOFT DELETE — produto que estava ativo no banco e
    # saiu do export atual e' inativado (ativo=false). NUNCA apagado
    # fisicamente (vendas/NF-e referenciam produtos.id).
    inativar_ids = [
        p["id"]
        for cod, p in produtos_map.items()
        if p.get("ativo") is True and int(cod) not in codigos_planilha
    ]
    for pid in inativar_ids:
        updates_produtos.append({"id": pid, "ativo": False})

    print("=== RESUMO ===")
    print(f"Produtos a atualizar:               {len(updates_produtos)}")
    print(f"  com estoque/custo/valor alterado: {n_num}")
    print(f"  com ncm novo/alterado:            {n_ncm}")
    print(f"  com cest novo/alterado:           {n_cest}")
    print(f"  com campo fiscal (SPEC-132):      {n_fiscal}")
    print(f"  reativados (ativo=false -> true): {n_reativado}")
    print(f"  inativados (ativo=true -> false, soft delete): {len(inativar_ids)}")
    print(f"Produtos já sincronizados:           {inalterados}")
    print(f"CodProduto da planilha sem match no banco: {len(sem_match)}")
    print("(estoque_itens é atualizado automaticamente pelo trigger em produtos)")
    print("(preco_venda NÃO muda — os 2 triggers de preço ficam desligados durante a gravação)")
    if sem_match:
        print(f"  Exemplos: {sem_match[:15]}")

    relatorio.atualizados = len(updates_produtos) - n_reativado - len(inativar_ids)
    relatorio.reativados = n_reativado
    relatorio.inativados = len(inativar_ids)
    relatorio.ignorados = len(sem_match) + inalterados

    if dry_run:
        print("\n=== DRY-RUN: nada foi gravado ===")
        if updates_produtos:
            print("\nAmostra de update em produtos:")
            print(updates_produtos[0])
            amostra_fiscal = next(
                (r for r in updates_produtos if any(c in r for c in FISCAL_NUM_TRIGGER)), None
            )
            if amostra_fiscal:
                print("Amostra com campo fiscal do trigger:")
                print(amostra_fiscal)
        relatorio.finalizar()
        log_path = salvar_log([relatorio], dry_run)
        imprimir_resumo_final([relatorio], dry_run, log_path)
        return

    if not SUPABASE_DB_URL:
        raise RuntimeError("Configure SUPABASE_DB_URL no .env — necessário p/ desligar os triggers de preço.")

    # Snapshot de preco_venda ANTES de gravar, só para o print de conferência no final
    # (os triggers ficam desligados, então preco_venda não deveria sequer ser tocado).
    ids_afetados = [rec["id"] for rec in updates_produtos]
    conn = psycopg2.connect(SUPABASE_DB_URL)
    try:
        conn.autocommit = False
        cur = conn.cursor()
        cur.execute(
            "select id::text, preco_venda from public.produtos where id = any(%s::uuid[])",
            (ids_afetados,),
        )
        preco_venda_antes = dict(cur.fetchall())

        cur.execute("BEGIN")
        for trg in TRIGGERS_PRECO:
            cur.execute(f"ALTER TABLE public.produtos DISABLE TRIGGER {trg}")

        total_ok = 0
        for rec in updates_produtos:
            cols = [k for k in rec if k != "id"]
            set_clause = ", ".join(f"{c} = %s" for c in cols)
            cur.execute(
                f"UPDATE public.produtos SET {set_clause} WHERE id = %s::uuid",
                [rec[c] for c in cols] + [rec["id"]],
            )
            total_ok += 1
            if total_ok % 500 == 0:
                print(f"  Produtos atualizados: {total_ok}/{len(updates_produtos)}", end="\r")

        for trg in TRIGGERS_PRECO:
            cur.execute(f"ALTER TABLE public.produtos ENABLE TRIGGER {trg}")
        conn.commit()
        print(f"\nUpdate de produtos concluído: {total_ok} ok (transação única, triggers de preço desligados).")

        cur.execute(
            "select id::text, preco_venda from public.produtos where id = any(%s::uuid[])",
            (ids_afetados,),
        )
        preco_venda_depois = dict(cur.fetchall())
        mudou_preco = [
            pid
            for pid in ids_afetados
            if not close_enough(preco_venda_antes.get(pid), preco_venda_depois.get(pid))
        ]
        if mudou_preco:
            print(
                f"  ⚠️ ATENÇÃO: preco_venda mudou em {len(mudou_preco)} produtos mesmo com os "
                f"triggers desligados — investigar antes de confiar no resultado. IDs: {mudou_preco[:10]}"
            )
        else:
            print(f"  Conferido: preco_venda idêntico em todos os {len(ids_afetados)} produtos tocados.")
    except Exception as exc:
        conn.rollback()
        print("\nFALHOU — transação revertida por completo (nenhum update ficou gravado, triggers intactos).")
        relatorio.registrar_erro(str(exc))
        relatorio.finalizar()
        log_path = salvar_log([relatorio], dry_run)
        imprimir_resumo_final([relatorio], dry_run, log_path)
        raise
    finally:
        conn.close()

    print("estoque_itens sincronizado automaticamente pelo trigger (fn_sync_estoque_itens_from_produtos).")
    relatorio.finalizar()
    log_path = salvar_log([relatorio], dry_run)
    imprimir_resumo_final([relatorio], dry_run, log_path)


def main():
    parser = argparse.ArgumentParser(description="Sincroniza planilha Produtos/Estoque com Supabase")
    parser.add_argument("--dry-run", action="store_true", help="Apenas mostra o que seria feito")
    args = parser.parse_args()
    processar(args.dry_run)


if __name__ == "__main__":
    main()
