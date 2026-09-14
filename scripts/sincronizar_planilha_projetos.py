"""
SPEC-130 — reconcilia `public.projetos` a partir de um export local da lista SharePoint
"Organização Projetos" (planilha, sem ID de item do Graph). Usado quando o usuário fornece
uma planilha mais recente/confiável do que o que o pull incremental já trouxe, ou pra
conferir que não há divergência. Casa só por `codigo` (nunca mexe em `sharepoint_item_id`
já vinculado) via a RPC `aplicar_planilha_projetos` (migration 017).

Colunas esperadas (na ordem): Codigo, Nível Estratégico, Projeto, Responsável, Data Entrada,
Status, Arquiteto Responsável, Responsável da Obra, Cidade, Estado, Arquivado, Tipo de Item,
Caminho. Linha sem código é ignorada.

Uso:
  python scripts/sincronizar_planilha_projetos.py "01-Documento/01 - Planilhas/Planilha de projetos.xlsx" --dry-run
  python scripts/sincronizar_planilha_projetos.py "01-Documento/01 - Planilhas/Planilha de projetos.xlsx"
"""

import argparse
import os
import re

import openpyxl
import psycopg2

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ENV_PATH = os.path.join(ROOT, ".env")


def load_env(path):
    env = {}
    with open(path, encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            k, v = line.split("=", 1)
            env[k.strip()] = v.strip().strip('"').strip("'")
    return env


def valor_ou_nulo(v):
    if v is None:
        return None
    s = str(v).strip()
    return None if s in ("", ".") else s


def extrair_nivel(v):
    s = valor_ou_nulo(v)
    if not s:
        return None
    m = re.search(r"\d+", s)
    return m.group(0) if m else None


def connect(db_url):
    conn = psycopg2.connect(db_url)
    conn.autocommit = True
    return conn, conn.cursor()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("planilha", help="Caminho do .xlsx exportado da lista")
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    env = load_env(ENV_PATH)
    db_url = env["SUPABASE_DB_URL"]

    wb = openpyxl.load_workbook(args.planilha, data_only=True)
    ws = wb.worksheets[0]
    linhas = list(ws.iter_rows(min_row=2, values_only=True))
    print(f"Planilha: {len(linhas)} linhas (aba '{ws.title}')")

    conn, cur = connect(db_url)

    cur.execute("select id, nome from public.contatos")
    mapa_contatos = {nome.strip().lower(): id_ for id_, nome in cur.fetchall() if nome}
    cur.execute("select id, nome from public.usuarios")
    mapa_usuarios = {nome.strip().lower(): id_ for id_, nome in cur.fetchall() if nome}
    cur.execute("select projeto_status, sharepoint_valor from public.sharepoint_status_map")
    mapa_status_reverso = {valor.strip(): status for status, valor in cur.fetchall()}

    contadores = {"criados": 0, "atualizados": 0, "criaria": 0, "atualizaria": 0, "sem_codigo": 0, "erros": 0}

    for i, row in enumerate(linhas, start=2):
        codigo = valor_ou_nulo(row[0])
        if not codigo:
            contadores["sem_codigo"] += 1
            continue

        nivel = extrair_nivel(row[1])
        nome = valor_ou_nulo(row[2])
        responsavel_nome = valor_ou_nulo(row[3])
        data_entrada = row[4].date() if row[4] else None
        status_sp = valor_ou_nulo(row[5])
        status = mapa_status_reverso.get(status_sp) if status_sp else None
        nome_arquiteto = valor_ou_nulo(row[6])
        nome_resp_obra = valor_ou_nulo(row[7])
        cidade = valor_ou_nulo(row[8])
        estado = valor_ou_nulo(row[9])
        estado = estado.strip().upper()[:2] if estado else None
        arquivado = row[10] if isinstance(row[10], bool) else None
        arquiteto_id = mapa_contatos.get(nome_arquiteto.lower()) if nome_arquiteto else None
        responsavel_obra_id = mapa_usuarios.get(nome_resp_obra.lower()) if nome_resp_obra else None

        if args.dry_run:
            cur.execute("select id from public.projetos where codigo = %s", (codigo,))
            contadores["atualizaria" if cur.fetchone() else "criaria"] += 1
            continue

        try:
            cur.execute(
                """
                select * from public.aplicar_planilha_projetos(
                    p_codigo => %s, p_nome => %s, p_responsavel_nome => %s, p_cidade => %s,
                    p_arquivado => %s, p_data_entrada => %s, p_nivel_estrategico => %s,
                    p_status => %s, p_arquiteto_id => %s, p_responsavel_obra_id => %s,
                    p_estado => %s
                )
                """,
                (
                    codigo, nome, responsavel_nome, cidade, arquivado, data_entrada,
                    nivel, status, arquiteto_id, responsavel_obra_id, estado,
                ),
            )
            _, acao = cur.fetchone()
            contadores["criados" if acao == "create" else "atualizados"] += 1
        except (psycopg2.OperationalError, psycopg2.InterfaceError) as exc:
            print(f"Conexão caiu na linha {i} ({codigo}): {exc}. Reconectando...")
            try:
                conn.close()
            except Exception:  # noqa: BLE001
                pass
            conn, cur = connect(db_url)
        except Exception as exc:  # noqa: BLE001
            contadores["erros"] += 1
            print(f"Erro na linha {i} (codigo {codigo}): {exc}")

        if i % 500 == 0:
            print(f"  ... linha {i}/{len(linhas) + 1}")

    print("\n--- Resumo ---")
    print(contadores)

    cur.close()
    conn.close()


if __name__ == "__main__":
    main()
