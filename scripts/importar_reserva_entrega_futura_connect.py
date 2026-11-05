"""
SPEC-243 — Importa as planilhas da Connect "ReservaxAmbiente" e "EntregaFuturaxAmbiente" e gera, no sistema, os
orçamentos "Connect" (origem = 'connect') com os itens por L e os saldos de Reserva / Entrega Futura.

O QUE FAZ
  1. Lê as 2 planilhas (a mais recente de cada) e, só para descobrir a EMPRESA de cada venda, o ContaReceber e o
     ContaPagar mais recentes (colunas cod_venda e nm_empresa). Regra fixa: LUCE NERA = MANOELLA (AGENTS.md).
  2. Resolve os vínculos: peça (produtos.codigo_produto), cliente (contatos.codigo_legado), projeto (projetos.codigo,
     extraído do campo Nome), digitador (funcionarios.nm_connect) e equipe (Marina / Thairine / Thais; qualquer outra
     pessoa = Administração, sem mexer no cadastro do funcionário).
  3. Grava o ESPELHO (connect_reserva_ambiente) com TODAS as linhas — inclusive as sem vínculo, com o motivo — e chama
     public.carregar_connect_reserva_ambiente(lote), que gera orçamento + projeto_itens + saldos das linhas que têm
     empresa + projeto + cliente + peça.

O QUE NUNCA FAZ
  * Não altera estoque_itens, transacoes, projeto_parcelas, boletos nem vendas (a função confere e se desfaz se mudar).
  * Não importa as linhas de "produto especial" (Produto = 0): a reunião de 04/11 mandou deixar de fora.
  * Não grava preço: o valor da Connect fica só no espelho (visível só para Administração).

REIMPORTAR
  Cada execução substitui o lote anterior: remove os orçamentos Connect do lote velho (recusa se alguém já separou/entregou
  algo neles), faz backup do espelho no schema backup e carrega o novo. O que foi "tratado" (connect_reserva_tratamento)
  sobrevive pela chave tipo+venda+peça+L e não volta.

Uso:
  python scripts/importar_reserva_entrega_futura_connect.py            # DRY-RUN: roda tudo e DESFAZ no fim (mostra os números reais)
  python scripts/importar_reserva_entrega_futura_connect.py --aplicar  # grava

Ordem da rodada: Produtos -> (Produtos novos) -> Pedido de Compra -> Contas -> ESTE script.
"""

from __future__ import annotations

import argparse
import re
import sys
import unicodedata
import uuid
from datetime import date, datetime
from pathlib import Path

import pandas as pd
import psycopg2
import psycopg2.extras

if sys.stdout.encoding and sys.stdout.encoding.lower() != "utf-8":
    sys.stdout.reconfigure(encoding="utf-8")

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "scripts"))

from _supabase_client import SUPABASE_DB_URL, SUPABASE_URL  # noqa: E402
from sync_connect_common import (  # noqa: E402
    ImportacaoAbortada,
    RelatorioModulo,
    descobrir_planilha_mais_recente,
    imprimir_resumo_final,
    salvar_log,
    validar_cabecalho,
    validar_minimo_linhas,
)

PASTA = ROOT / "01-Documento" / "01 - Planilhas"
LOG_DIR = ROOT / "scripts" / "logs" / "reserva_connect"

LIMITE_VENDA_ANTIGA = 2477  # última venda de 30/06/2025 (reunião 04/11/2026)
EQUIPES_PROJETOS = {"MARINA": "Marina", "THAIRINE": "Thairine", "THAIS": "Thais"}
EQUIPE_PADRAO = "Administra"  # prefixo de "Administração" (evita problema de acento na comparação)
EMPRESA_CONNECT_PARA_BANCO = {  # AGENTS.md — Regras fixas de negócio
    "LUCE NERA": "MANOELLA",
    "ISLIGHT": "ISLIGHT",
    "FOCO ILUMINACAO": "FOCO ILUMINACAO",
}

COLUNAS = ["orcamento", "venda", "cliente", "nome", "produto", "referencia", "descricao", "qtd",
           "ambiente", "data entrega", "funcionario", "valor venda", "observacao", "adicional"]


# --------------------------------------------------------------------------------------------------------------
# utilidades
# --------------------------------------------------------------------------------------------------------------
def norm(s) -> str:
    """Sem acento, maiúsculo, espaços simples. Aguenta 'Ç' quebrado (U+FFFD) trocando por 'C'."""
    if s is None or (isinstance(s, float) and pd.isna(s)):
        return ""
    t = str(s).replace("�", "C")
    t = unicodedata.normalize("NFKD", t).encode("ascii", "ignore").decode()
    return re.sub(r"\s+", " ", t).strip().upper()


def parse_num(s) -> float | None:
    """'1,001.54' (milhar com vírgula, decimal com ponto) e '12,5' (decimal com vírgula) e '6'."""
    t = str(s).strip() if s is not None else ""
    if t == "" or t.lower() == "nan":
        return None
    if "," in t and "." in t:
        t = t.replace(",", "")
    elif "," in t:
        t = t.replace(",", ".")
    try:
        return float(t)
    except ValueError:
        return None


def parse_int(s) -> int | None:
    n = parse_num(s)
    return int(n) if n is not None and float(n).is_integer() else None


def parse_data(s) -> date | None:
    t = str(s).strip() if s is not None else ""
    if not t or t.lower() == "nan":
        return None
    try:
        return datetime.strptime(t[:10], "%d/%m/%Y").date()
    except ValueError:
        return None


RE_COD_INICIO = re.compile(r"^\s*(?:PROJ\.?\s*)?(\d{2}\.\d{3})\b\s*[-–]?\s*(.*)$", re.I)
RE_COD_MEIO = re.compile(r"\b(\d{2}\.\d{3})\b")
RE_LEGADO = re.compile(r"^\s*(?:PROJ\.?\s*)?(\d{4,6})\b")  # "23131 CASA AFFONSO" -> projetos.codigo_legado


def extrair_projeto(nome: str) -> tuple[str | None, str]:
    """('24.365', 'MARIANA MEIRELLES') a partir de '24.365 MARIANA MEIRELLES'; também 'PROJ. 18.235 LOARA E JOÃO'."""
    nome = (nome or "").strip()
    m = RE_COD_INICIO.match(nome)
    if m:
        return m.group(1), m.group(2).strip() or nome
    m = RE_COD_MEIO.search(nome)
    if m:
        return m.group(1), nome
    return None, nome


# --------------------------------------------------------------------------------------------------------------
# leitura das planilhas
# --------------------------------------------------------------------------------------------------------------
def ler_planilha_ambiente(path: Path, tipo: str) -> pd.DataFrame:
    df = pd.read_excel(path, dtype=str).fillna("")
    cab = [norm(c).lower() for c in df.columns]
    validar_cabecalho(cab, COLUNAS, f"{tipo} ({path.name})")
    df.columns = cab
    df = df[COLUNAS].copy()
    df["linha_planilha"] = range(2, len(df) + 2)  # linha no Excel (cabeçalho = 1)
    df["tipo"] = tipo
    return df


def mapa_empresas_por_venda(arquivos: list[Path]) -> dict[int, set[str]]:
    """cod_venda -> {empresas do banco} lendo ContaReceber/ContaPagar (fonte confiável de empresa)."""
    mapa: dict[int, set[str]] = {}
    for p in arquivos:
        df = pd.read_excel(p, dtype=str).fillna("")
        df.columns = [str(c).strip() for c in df.columns]
        validar_cabecalho(list(df.columns), ["cod_venda", "nm_empresa"], p.name)
        sub = df[["cod_venda", "nm_empresa"]].drop_duplicates()
        for cv, emp in zip(sub["cod_venda"], sub["nm_empresa"]):
            v = parse_int(cv)
            nome = EMPRESA_CONNECT_PARA_BANCO.get(norm(emp))
            if v is None or nome is None:
                continue
            mapa.setdefault(v, set()).add(nome)
    return mapa


# --------------------------------------------------------------------------------------------------------------
# principal
# --------------------------------------------------------------------------------------------------------------
def main() -> None:
    ap = argparse.ArgumentParser(description="SPEC-243: herança Connect (Reserva/Entrega Futura × Ambiente)")
    ap.add_argument("--aplicar", action="store_true", help="grava (sem isso roda tudo e DESFAZ no fim)")
    ap.add_argument("--limite-venda-antiga", type=int, default=LIMITE_VENDA_ANTIGA)
    args = ap.parse_args()
    aplicar = args.aplicar
    if aplicar:
        # SPEC-244: com a operação em paralelo iniciada, a herança é operada no sistema novo e não pode mais ser recarregada
        from sync_connect_common import exigir_sem_operacao_paralela

        exigir_sem_operacao_paralela("Recarregar a Reserva e a Entrega Futura da Connect")

    print(f"Supabase: {SUPABASE_URL}")
    print(f"Modo:     {'GRAVAÇÃO REAL' if aplicar else 'DRY-RUN (roda tudo e desfaz no fim)'}\n")
    rel = RelatorioModulo(nome="Reserva/Entrega Futura × Ambiente (SPEC-243)")

    try:
        p_res = descobrir_planilha_mais_recente(PASTA, "ReservaxAmbiente")
        p_ef = descobrir_planilha_mais_recente(PASTA, "EntregaFuturaxAmbiente")
        p_cr = descobrir_planilha_mais_recente(PASTA, "ContaReceber_")
        p_cp = descobrir_planilha_mais_recente(PASTA, "ContaPagar_")
        rel.arquivo_origem = f"{p_res.name} + {p_ef.name}"
        print("Planilhas:", p_res.name, "|", p_ef.name, "| empresa por:", p_cr.name, "+", p_cp.name)

        res = ler_planilha_ambiente(p_res, "reserva")
        ef = ler_planilha_ambiente(p_ef, "entrega_futura")
        validar_minimo_linhas(len(res), 100, p_res.name)
        validar_minimo_linhas(len(ef), 50, p_ef.name)
        empresas_venda = mapa_empresas_por_venda([p_cr, p_cp])
    except ImportacaoAbortada as e:
        rel.abortado = str(e)
        rel.finalizar()
        rel.imprimir()
        imprimir_resumo_final([rel], not aplicar, salvar_log([rel], not aplicar))
        sys.exit(1)

    # ---- descarta "produto especial" (Produto = 0) -------------------------------------------------------------
    todas = pd.concat([res, ef], ignore_index=True)
    especial = todas[todas["produto"].str.strip().isin(["0", ""])]
    todas = todas.drop(especial.index).reset_index(drop=True)
    print(f"Linhas lidas: Reserva {len(res)} + Entrega Futura {len(ef)}; descartadas (produto especial/sem produto): {len(especial)}")
    for _, r in especial.iterrows():
        print(f"   descartada [{r['tipo']} linha {r['linha_planilha']}] orç {r['orcamento']} venda {r['venda']} — {r['descricao']}")

    lote = uuid.uuid4()
    conn = psycopg2.connect(SUPABASE_DB_URL, connect_timeout=30)
    cur = conn.cursor()
    cur.execute("set local statement_timeout = '10min'")

    try:
        # ---- tabelas de apoio ---------------------------------------------------------------------------------
        cod_prod = sorted({parse_int(x) for x in todas["produto"] if parse_int(x) is not None})
        cur.execute("select codigo_produto, id from public.produtos where codigo_produto = any(%s)", (cod_prod,))
        produtos = dict(cur.fetchall())

        cod_cli = sorted({parse_int(x) for x in todas["cliente"] if parse_int(x) is not None})
        cur.execute("select codigo_legado, id from public.contatos where codigo_legado = any(%s)", (cod_cli,))
        clientes = dict(cur.fetchall())

        cur.execute("select codigo, id::text from public.projetos where codigo is not null")
        projetos: dict[str, list[str]] = {}
        for c, i in cur.fetchall():
            projetos.setdefault(c, []).append(i)

        cur.execute("select codigo_legado, id::text from public.projetos where codigo_legado is not null")
        projetos_legado: dict[int, list[str]] = {}
        for c, i in cur.fetchall():
            projetos_legado.setdefault(int(c), []).append(i)
        cur.execute("select cliente_id::text, array_agg(codigo) from public.projetos where cliente_id is not null group by 1")
        projetos_do_cliente = {c: list(v) for c, v in cur.fetchall()}
        sugestoes: dict[tuple, tuple] = {}  # (orc, venda) -> (nome, cliente_id, projeto único do cliente) — só sugestão

        cur.execute("select id, equipes from public.equipes_projetos")
        equipes = {i: n for i, n in cur.fetchall()}
        equipe_admin = next((i for i, n in equipes.items() if norm(n).startswith(EQUIPE_PADRAO.upper())), None)
        equipe_por_nome = {norm(n): i for i, n in equipes.items()}
        if equipe_admin is None:
            raise ImportacaoAbortada("Equipe 'Administração' não existe em equipes_projetos.")

        cur.execute("select id, usuario_id, equipe_id, nm_connect from public.funcionarios where nm_connect is not null")
        funcionarios = {norm(nm): (fid, uid, eid) for fid, uid, eid, nm in cur.fetchall()}

        cur.execute("select id, nome from public.empresas")
        empresas_id = {norm(n): i for i, n in cur.fetchall()}

        # ---- monta as linhas do espelho -----------------------------------------------------------------------
        linhas = []
        digitadores: dict[str, tuple] = {}
        for _, r in todas.iterrows():
            motivos: list[str] = []
            cod_orc = parse_int(r["orcamento"])
            cod_venda = parse_int(r["venda"])
            cod_cli_r = parse_int(r["cliente"])
            cod_prod_r = parse_int(r["produto"])
            proj_cod, nome_cli = extrair_projeto(r["nome"])
            qtd = parse_num(r["qtd"])
            if qtd is None or qtd < 0:
                rel.registrar_erro(f"{r['tipo']} linha {r['linha_planilha']}: quantidade inválida '{r['qtd']}'")
                rel.ignorados += 1
                continue

            produto_id = produtos.get(cod_prod_r)
            if produto_id is None:
                motivos.append("peca_nao_cadastrada")
            cliente_id = clientes.get(cod_cli_r)
            if cliente_id is None:
                motivos.append("cliente_nao_cadastrado")

            projeto_id = None
            if proj_cod is None:
                mleg = RE_LEGADO.match(r["nome"])
                ids_leg = projetos_legado.get(int(mleg.group(1)), []) if mleg else []
                if len(ids_leg) == 1:
                    projeto_id = ids_leg[0]
                    motivos.append("projeto_por_codigo_legado")  # informativo: o orçamento É gerado
                else:
                    motivos.append("nome_sem_codigo_projeto")
                    if cliente_id is not None and len(projetos_do_cliente.get(cliente_id, [])) == 1:
                        sugestoes[(cod_orc, cod_venda)] = (r["nome"], cliente_id, projetos_do_cliente[cliente_id][0])
            else:
                ids = projetos.get(proj_cod)
                if not ids:
                    motivos.append("projeto_nao_encontrado")
                elif len(ids) > 1:
                    motivos.append("projeto_codigo_duplicado")
                else:
                    projeto_id = ids[0]

            emp_set = empresas_venda.get(cod_venda, set()) if cod_venda is not None else set()
            empresa_id = None
            if cod_venda is None or not emp_set:
                motivos.append("empresa_nao_deduzida")
                if cod_venda is None or cod_venda not in empresas_venda:
                    motivos.append("venda_sem_titulo")
            elif len(emp_set) > 1:
                motivos.append("empresa_ambigua")
            else:
                empresa_id = empresas_id.get(norm(next(iter(emp_set))))
                if empresa_id is None:
                    motivos.append("empresa_nao_deduzida")

            nome_func = r["funcionario"].strip()
            f = funcionarios.get(norm(nome_func))
            if f is None:
                funcionario_id = digitado_por = None
                equipe_id = equipe_admin
                if nome_func:
                    motivos.append("digitador_nao_encontrado")
                digitadores[nome_func] = (None, "NÃO ENCONTRADO", "Administração")
            else:
                funcionario_id, digitado_por, eq_func = f
                nome_eq = equipes.get(eq_func)
                if nome_eq is not None and norm(nome_eq) in EQUIPES_PROJETOS:
                    equipe_id = eq_func
                else:
                    equipe_id = equipe_admin
                digitadores[nome_func] = (funcionario_id, "sem usuário" if digitado_por is None else "com usuário",
                                          equipes.get(equipe_id))

            data_entrega = parse_data(r["data entrega"])
            linhas.append((
                r["tipo"], str(lote), int(r["linha_planilha"]), cod_orc, cod_venda, cod_cli_r,
                r["nome"].strip(), proj_cod, nome_cli, cod_prod_r, r["referencia"].strip() or None,
                r["descricao"].strip() or None, qtd, r["ambiente"].strip() or None, data_entrega,
                (r["tipo"] == "reserva" and data_entrega is None),
                nome_func or None, parse_num(r["valor venda"]), r["observacao"].strip() or None,
                r["adicional"].strip() or None, (cod_venda is not None and cod_venda <= args.limite_venda_antiga),
                empresa_id, funcionario_id, digitado_por, equipe_id, projeto_id, cliente_id, produto_id,
                ",".join(motivos) or None,
            ))

        # ---- substitui o lote anterior (backup antes; recusa se já houve separação/entrega) ------------------
        cur.execute("create schema if not exists backup")
        cur.execute("select count(*) from public.connect_reserva_ambiente")
        antes = cur.fetchone()[0]
        if antes:
            cur.execute(f"create table backup._bkp_connect_reserva_ambiente_{date.today():%Y%m%d}_{datetime.now():%H%M%S} "
                        "as select * from public.connect_reserva_ambiente")
            cur.execute("select distinct connect_lote from public.orcamentos where origem = 'connect' and connect_lote is not null")
            for (lote_velho,) in cur.fetchall():
                cur.execute("select public.remover_connect_lote(%s)", (lote_velho,))
                print("  lote anterior removido:", cur.fetchone()[0])
            cur.execute("delete from public.connect_reserva_ambiente")
            print(f"  espelho anterior: {antes} linhas (backup feito e substituído)")

        # ---- grava o espelho e carrega ------------------------------------------------------------------------
        psycopg2.extras.execute_values(cur, """
            insert into public.connect_reserva_ambiente
              (tipo, lote_importacao, linha_planilha, cod_orcamento_connect, cod_venda_connect, cod_cliente_connect,
               nome_bruto, projeto_codigo, nome_cliente, produto_codigo, referencia, descricao, quantidade, ambiente,
               data_entrega, aviso_data, vendedor_nome, valor_venda, observacao, adicional, venda_antiga,
               empresa_id, funcionario_id, digitado_por, equipe_id, projeto_id, cliente_id, produto_id, motivo_sem_vinculo)
            values %s""", linhas, page_size=500)
        rel.inseridos = len(linhas)

        cur.execute("select public.carregar_connect_reserva_ambiente(%s::uuid)", (str(lote),))
        carga = cur.fetchone()[0]
        print("\nCARGA:", carga)

        # ---- relatórios ---------------------------------------------------------------------------------------
        cur.execute("""select coalesce(motivo_sem_vinculo, '(ok)') as motivo, tipo, count(*)
                         from public.connect_reserva_ambiente where lote_importacao = %s group by 1, 2 order by 3 desc""", (str(lote),))
        print("\nLinhas por motivo (pode haver mais de um motivo por linha):")
        for m, t, n in cur.fetchall():
            print(f"   {n:5d}  {t:15s}  {m}")

        cur.execute("""select tipo, count(*), count(orcamento_id), count(*) filter (where aviso_data), count(*) filter (where venda_antiga),
                              round(sum(quantidade), 1) from public.connect_reserva_ambiente where lote_importacao = %s group by 1""", (str(lote),))
        print("\nPor tipo: (linhas, vinculadas a orçamento, sem data de entrega, venda antiga, soma da quantidade)")
        for row in cur.fetchall():
            print("  ", row)

        cur.execute("select count(*) from public.orcamentos where origem = 'connect' and connect_lote = %s", (str(lote),))
        print("Orçamentos Connect deste lote:", cur.fetchone()[0])

        print("\nDigitadores da planilha -> funcionário -> equipe do orçamento:")
        for nome, (fid, situ, eq) in sorted(digitadores.items()):
            print(f"   {nome:22s} {'achado' if fid else '------':7s} {situ:15s} {eq}")

        # herança por peça depois da carga (critério 12: nunca negativa)
        cur.execute("""
            with reservado as (
              select produto_id, sum(quantidade_reservada) as res from public.estoque_itens where local = 'Estoque' group by 1),
            sistema as (
              select pi.produto_id, sum(s.q_reserva + s.q_entrega_futura + s.q_separado) as sis
                from public.estoque_saldos_projeto_item s join public.projeto_itens pi on pi.id = s.projeto_item_id group by 1)
            select p.codigo_produto, r.res, coalesce(sa.sis, 0), r.res - coalesce(sa.sis, 0) as heranca
              from reservado r join public.produtos p on p.id = r.produto_id left join sistema sa on sa.produto_id = r.produto_id
             where r.res - coalesce(sa.sis, 0) < -0.0001 order by 4""")
        negativas = cur.fetchall()
        print(f"\nPeças com herança NEGATIVA depois da carga: {len(negativas)} (reconciliação, critério 12)")
        for cp, res_, sis, h in negativas[:15]:
            print(f"   peça {cp}: reservado {res_} − Connect/sistema {sis} = {h}")

        # ---- Excel de conferência -----------------------------------------------------------------------------
        LOG_DIR.mkdir(parents=True, exist_ok=True)
        xlsx = LOG_DIR / f"reserva_connect_{datetime.now():%Y%m%d_%H%M%S}{'' if aplicar else '_dryrun'}.xlsx"
        cur.execute("""select tipo, linha_planilha, cod_orcamento_connect, cod_venda_connect, nome_bruto, produto_codigo, ambiente,
                              quantidade, vendedor_nome, motivo_sem_vinculo
                         from public.connect_reserva_ambiente where lote_importacao = %s and motivo_sem_vinculo is not null
                        order by motivo_sem_vinculo, cod_venda_connect""", (str(lote),))
        cols = [d[0] for d in cur.description]
        sem = pd.DataFrame(cur.fetchall(), columns=cols)
        with pd.ExcelWriter(xlsx) as xw:
            sem.to_excel(xw, sheet_name="com_motivo", index=False)
            pd.DataFrame(negativas, columns=["peca", "reservado", "connect_mais_sistema", "heranca"]).to_excel(xw, sheet_name="heranca_negativa", index=False)
            especial[["tipo", "linha_planilha", "orcamento", "venda", "nome", "descricao", "qtd"]].to_excel(xw, sheet_name="descartadas", index=False)
            pd.DataFrame([(k, *v[1:]) for k, v in digitadores.items()], columns=["planilha", "usuario", "equipe_do_orcamento"]).to_excel(xw, sheet_name="digitadores", index=False)
            pd.DataFrame([(o, v, *x) for (o, v), x in sugestoes.items()],
                         columns=["orcamento", "venda", "nome_na_planilha", "cliente_id", "projeto_unico_do_cliente"]).to_excel(
                xw, sheet_name="sugestao_projeto", index=False)
        print(f"\nExcel de conferência: {xlsx}")
        print(f"Sugestões de projeto (cliente com um único projeto, NÃO aplicadas): {len(sugestoes)}")

        rel.atualizados = 0
        rel.inseridos = int(carga.get("orcamentos_criados", 0))
        rel.ignorados += int(carga.get("linhas_so_no_espelho", 0))

        if aplicar:
            conn.commit()
            print("\nGRAVADO.")
        else:
            conn.rollback()
            print("\nDRY-RUN: tudo desfeito, nada foi gravado.")
    except ImportacaoAbortada as e:
        conn.rollback()
        rel.abortado = str(e)
    except Exception as e:  # noqa: BLE001
        conn.rollback()
        rel.registrar_erro(f"{type(e).__name__}: {e}")
        print(f"\nERRO — tudo desfeito: {e}")
    finally:
        conn.close()

    rel.finalizar()
    rel.imprimir()
    imprimir_resumo_final([rel], not aplicar, salvar_log([rel], not aplicar))
    if rel.erros or rel.abortado:
        sys.exit(1)


if __name__ == "__main__":
    main()
