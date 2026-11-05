"""
SPEC-243 — Cria em `contatos` os CLIENTES novos da Connect (planilha "Clientes*.xlsx", export do Connect) que ainda não existem
no sistema, para as vendas deles poderem virar orçamento (importar_reserva_entrega_futura_connect.py).

REGRAS
  * Só INSERE o que não existe (chave: contatos.codigo_legado = codCliente). Nunca altera contato já cadastrado.
  * tipo = 'cliente'; nome = nmCliente; razao_social só quando difere do nome; endereço/bairro/telefone/e-mails como vieram.
  * "RIBEIRAO PRETO SP" -> cidade "RIBEIRAO PRETO" + estado "SP" (o campo cidCliente da Connect junta os dois).
  * CPF/CNPJ (coluna ÚNICA em contatos): gravado só com dígitos; se o documento JÁ pertence a outro contato (mesma pessoa com outro
    código na Connect) ou repete dentro da própria planilha, o cliente é criado SEM documento e entra no relatório de duplicados.
  * tipo_pessoa: 11 dígitos = fisica, 14 = juridica, sem documento = vazio.
  * Cadastro novo não vira orçamento nem mexe em estoque/financeiro.

Uso:
  python scripts/importar_clientes_connect.py            # DRY-RUN (roda e desfaz; mostra os números reais)
  python scripts/importar_clientes_connect.py --aplicar  # grava
Depois de gravar, rodar de novo scripts/importar_reserva_entrega_futura_connect.py --aplicar para ligar as vendas desses clientes.
"""

from __future__ import annotations

import argparse
import re
import sys
from datetime import datetime
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
    validar_chave_unica,
    validar_minimo_linhas,
)

PASTA = ROOT / "01-Documento" / "01 - Planilhas"
LOG_DIR = ROOT / "scripts" / "logs" / "reserva_connect"
COLUNAS = ["codCliente", "docCliente", "nmCliente", "rzCliente", "endCliente", "brCliente", "cidCliente",
           "telCliente", "emailCliente", "emailFinanceiro", "emailAlternativo"]
RE_UF = re.compile(r"^(.*?)[\s,-]+([A-Za-z]{2})$")


def limpo(v) -> str | None:
    t = str(v if v is not None else "").strip()
    return None if t == "" or t.lower() == "nan" else t


def digitos(v) -> str:
    return re.sub(r"\D", "", str(v or ""))


def cidade_uf(v) -> tuple[str | None, str | None]:
    t = limpo(v)
    if not t:
        return None, None
    m = RE_UF.match(t)
    if m and m.group(1).strip():
        return m.group(1).strip(), m.group(2).upper()
    if len(t) == 2:  # só a UF ("SP")
        return None, t.upper()
    return t, None


def main() -> None:
    ap = argparse.ArgumentParser(description="SPEC-243: clientes novos da Connect -> contatos")
    ap.add_argument("--aplicar", action="store_true", help="grava (sem isso roda e DESFAZ no fim)")
    args = ap.parse_args()
    aplicar = args.aplicar
    print(f"Supabase: {SUPABASE_URL}")
    print(f"Modo:     {'GRAVAÇÃO REAL' if aplicar else 'DRY-RUN (roda e desfaz no fim)'}\n")
    rel = RelatorioModulo(nome="Clientes novos da Connect (SPEC-243)")

    try:
        arq = descobrir_planilha_mais_recente(PASTA, "Clientes")
        rel.arquivo_origem = arq.name
        df = pd.read_excel(arq, dtype=str).fillna("")
        df.columns = [str(c).strip() for c in df.columns]
        validar_cabecalho(list(df.columns), COLUNAS, arq.name)
        validar_minimo_linhas(len(df), 500, arq.name)
        df["cod"] = pd.to_numeric(df["codCliente"], errors="coerce")
        df = df[df["cod"].notna()].copy()
        df["cod"] = df["cod"].astype(int)
        validar_chave_unica(df, ["cod"], arq.name)
    except ImportacaoAbortada as e:
        rel.abortado = str(e)
        rel.finalizar()
        rel.imprimir()
        imprimir_resumo_final([rel], not aplicar, salvar_log([rel], not aplicar))
        sys.exit(1)

    conn = psycopg2.connect(SUPABASE_DB_URL, connect_timeout=30)
    cur = conn.cursor()
    try:
        cur.execute("select codigo_legado from public.contatos where codigo_legado is not null")
        existentes = {int(r[0]) for r in cur.fetchall()}
        cur.execute("select regexp_replace(cpf_cnpj, '\\D', '', 'g'), codigo_legado, nome from public.contatos where cpf_cnpj is not null")
        doc_banco: dict[str, tuple] = {}
        for d, c, n in cur.fetchall():
            if d:
                doc_banco.setdefault(d, (c, n))

        novos = df[~df["cod"].isin(existentes)].sort_values("cod")
        print(f"Planilha: {arq.name} — {len(df)} clientes; já no sistema: {len(df) - len(novos)}; NOVOS: {len(novos)}")

        linhas, conflitos, vistos = [], [], set()
        for _, r in novos.iterrows():
            doc = digitos(r["docCliente"])
            doc_final = doc or None
            motivo = None
            if doc and len(doc) not in (11, 14):
                doc_final, motivo = None, f"documento com {len(doc)} dígitos (não é CPF/CNPJ)"
            elif doc in doc_banco:
                doc_final, motivo = None, f"documento já é do contato {doc_banco[doc][0]} — {doc_banco[doc][1]}"
            elif doc and doc in vistos:
                doc_final, motivo = None, "documento repetido na própria planilha"
            if doc_final:
                vistos.add(doc_final)
            if motivo:
                conflitos.append((int(r["cod"]), limpo(r["nmCliente"]), doc, motivo))
            nome = limpo(r["nmCliente"]) or limpo(r["rzCliente"]) or f"Cliente Connect {int(r['cod'])}"
            razao = limpo(r["rzCliente"])
            cidade, uf = cidade_uf(r["cidCliente"])
            linhas.append((
                int(r["cod"]), "cliente", nome, razao if razao and razao != nome else None, doc_final,
                {11: "fisica", 14: "juridica"}.get(len(doc_final or "")), limpo(r["endCliente"]), limpo(r["brCliente"]),
                cidade, uf, limpo(r["telCliente"]), limpo(r["emailCliente"]), limpo(r["emailFinanceiro"]),
                limpo(r["emailAlternativo"]), True,
            ))

        psycopg2.extras.execute_values(cur, """
            insert into public.contatos
              (codigo_legado, tipo, nome, razao_social, cpf_cnpj, tipo_pessoa, endereco, bairro, cidade, estado,
               telefone, email, email_financeiro, email_alternativo, ativo)
            values %s on conflict (codigo_legado, tipo) do nothing""", linhas, page_size=200)
        cur.execute("select count(*) from public.contatos where codigo_legado = any(%s)", ([l[0] for l in linhas],))
        criados = cur.fetchone()[0]
        rel.inseridos = criados
        print(f"Clientes criados: {criados} de {len(linhas)}")
        print(f"  sem CPF/CNPJ na planilha: {sum(1 for l in linhas if l[4] is None) - len(conflitos)}")
        print(f"  criados SEM documento por conflito: {len(conflitos)}")
        for c, n, d, m in conflitos[:12]:
            print(f"     {c} {n}: {m}")

        # prova de que só cliente novo entrou e nada mais mudou
        cur.execute("select count(*) from public.contatos where tipo = 'cliente'")
        print("contatos tipo cliente depois:", cur.fetchone()[0])

        LOG_DIR.mkdir(parents=True, exist_ok=True)
        xlsx = LOG_DIR / f"clientes_connect_{datetime.now():%Y%m%d_%H%M%S}{'' if aplicar else '_dryrun'}.xlsx"
        with pd.ExcelWriter(xlsx) as xw:
            pd.DataFrame(linhas, columns=["codigo_legado", "tipo", "nome", "razao_social", "cpf_cnpj", "tipo_pessoa", "endereco",
                                          "bairro", "cidade", "estado", "telefone", "email", "email_financeiro", "email_alternativo",
                                          "ativo"]).to_excel(xw, sheet_name="criados", index=False)
            pd.DataFrame(conflitos, columns=["codigo", "nome", "documento", "motivo"]).to_excel(xw, sheet_name="sem_documento_por_conflito", index=False)
        print("Excel de conferência:", xlsx)

        rel.ignorados = len(df) - len(novos)
        if aplicar:
            conn.commit()
            print("\nGRAVADO.")
        else:
            conn.rollback()
            print("\nDRY-RUN: tudo desfeito, nada foi gravado.")
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
