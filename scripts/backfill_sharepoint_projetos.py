"""
SPEC-130 — Item 9: backfill inicial da lista SharePoint "Organizacao Projetos" para
`public.projetos`. Roda uma vez (fora do cron/Edge Function) porque a lista tem ~3.800
itens: a primeira leitura completa estoura o timeout de 5s do pg_net usado pelo cron
(achado de 2026-09-11, ver SPEC-130). Este script não tem esse limite.

Usa a mesma RPC que o pull incremental usa em produção (`aplicar_pull_sharepoint`), então
o comportamento é idêntico ao que o cron vai fazer depois — sem lógica duplicada. Ao
terminar, salva o `@odata.deltaLink` final em `sharepoint_sync_state` (chave `delta_link`),
que é o ponto de partida do cron incremental daí pra frente.

SharePoint é tratado como fonte de verdade nesta fase (decisão do usuário, 2026-09-11):
todo item processado é aplicado, sem checagem de conflito.

Uso:
  python scripts/backfill_sharepoint_projetos.py --dry-run
  python scripts/backfill_sharepoint_projetos.py --dry-run --limit 50
  python scripts/backfill_sharepoint_projetos.py            # grava de verdade

Credenciais lidas do .env na raiz do repo: SHAREPOINT_TENANT_ID, SHAREPOINT_CLIENT_ID,
SHAREPOINT_CLIENT_SECRET (app "Lucenera CRM"), SUPABASE_DB_URL.
"""

import argparse
import hashlib
import json
import os
import re
import time

import psycopg2
import psycopg2.extras
import requests

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ENV_PATH = os.path.join(ROOT, ".env")

SITE_PATH = "lucenera.sharepoint.com:/sites/LUCENERAPROJETOS345"
LIST_DISPLAY_NAME = "Organização Projetos"


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


def get_graph_token(tenant_id, client_id, client_secret):
    resp = requests.post(
        f"https://login.microsoftonline.com/{tenant_id}/oauth2/v2.0/token",
        data={
            "client_id": client_id,
            "client_secret": client_secret,
            "scope": "https://graph.microsoft.com/.default",
            "grant_type": "client_credentials",
        },
        timeout=30,
    )
    if not resp.ok:
        raise SystemExit(f"Falha ao autenticar no Microsoft Graph: {resp.status_code} {resp.text}")
    return resp.json()["access_token"]


def resolve_site_and_list(cur, token):
    cur.execute(
        "select chave, valor from public.sharepoint_sync_state where chave in ('site_id','list_id')"
    )
    cache = dict(cur.fetchall())
    if cache.get("site_id") and cache.get("list_id"):
        return cache["site_id"], cache["list_id"]

    headers = {"Authorization": f"Bearer {token}"}
    site_resp = requests.get(
        f"https://graph.microsoft.com/v1.0/sites/{SITE_PATH}", headers=headers, timeout=30
    )
    if not site_resp.ok:
        raise SystemExit(f"Falha ao resolver o site: {site_resp.status_code} {site_resp.text}")
    site_id = site_resp.json()["id"]

    lists_resp = requests.get(
        f"https://graph.microsoft.com/v1.0/sites/{site_id}/lists"
        f"?$filter=displayName eq '{LIST_DISPLAY_NAME}'",
        headers=headers,
        timeout=30,
    )
    if not lists_resp.ok:
        raise SystemExit(f"Falha ao resolver a lista: {lists_resp.status_code} {lists_resp.text}")
    lista = lists_resp.json()["value"][0]
    list_id = lista["id"]

    cur.execute(
        """
        insert into public.sharepoint_sync_state (chave, valor, updated_at)
        values ('site_id', %s, now()), ('list_id', %s, now())
        on conflict (chave) do update set valor = excluded.valor, updated_at = now()
        """,
        (site_id, list_id),
    )
    return site_id, list_id


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


def sync_hash(payload: dict) -> str:
    return hashlib.sha256(json.dumps(payload, sort_keys=True, default=str).encode("utf-8")).hexdigest()


def processar_item(cur, item, mapa_contatos, mapa_usuarios, mapa_status_reverso, dry_run, contadores):
    fields = item.get("fields") or {}
    sharepoint_item_id = str(item["id"])

    nome = valor_ou_nulo(fields.get("Title"))
    codigo = valor_ou_nulo(fields.get("field_0"))
    responsavel_nome = valor_ou_nulo(fields.get("field_9"))
    cidade = valor_ou_nulo(fields.get("field_4"))
    arquivado_raw = fields.get("Arquivado")
    arquivado = arquivado_raw if isinstance(arquivado_raw, bool) else None
    nivel = extrair_nivel(fields.get("N_x00ed_velEstrat_x00e9_gico"))
    status_sp = valor_ou_nulo(fields.get("field_10"))
    status = mapa_status_reverso.get(status_sp) if status_sp else None
    nome_arquiteto = valor_ou_nulo(fields.get("field_2"))
    nome_resp_obra = valor_ou_nulo(fields.get("Respons_x00e1_veldaObra"))
    arquiteto_id = mapa_contatos.get(nome_arquiteto.lower()) if nome_arquiteto else None
    responsavel_obra_id = mapa_usuarios.get(nome_resp_obra.lower()) if nome_resp_obra else None

    payload_hash = sync_hash(
        {
            "nome": nome,
            "codigo": codigo,
            "responsavel_nome": responsavel_nome,
            "cidade": cidade,
            "arquivado": arquivado,
            "nivel": nivel,
            "status": status,
            "arquiteto_id": arquiteto_id,
            "responsavel_obra_id": responsavel_obra_id,
        }
    )

    if dry_run:
        cur.execute(
            "select id from public.projetos where sharepoint_item_id = %s",
            (sharepoint_item_id,),
        )
        existente = cur.fetchone()
        if not existente and codigo:
            cur.execute(
                "select id from public.projetos where codigo = %s and sharepoint_item_id is null",
                (codigo,),
            )
            existente = cur.fetchone()
        contadores["atualizaria" if existente else "criaria"] += 1
        return

    changed_by_sharepoint = (
        (item.get("lastModifiedBy") or {}).get("user", {}).get("displayName")
        or (item.get("lastModifiedBy") or {}).get("application", {}).get("displayName")
    )

    cur.execute(
        """
        select * from public.aplicar_pull_sharepoint(
            p_sharepoint_item_id => %s, p_nome => %s, p_codigo => %s,
            p_responsavel_nome => %s, p_cidade => %s, p_arquivado => %s,
            p_data_entrada => null, p_nivel_estrategico => %s, p_status => %s,
            p_arquiteto_id => %s, p_responsavel_obra_id => %s, p_sync_hash => %s
        )
        """,
        (
            sharepoint_item_id, nome, codigo, responsavel_nome, cidade, arquivado,
            nivel, status, arquiteto_id, responsavel_obra_id, payload_hash,
        ),
    )
    projeto_id, acao = cur.fetchone()
    contadores["criados" if acao == "create" else "atualizados"] += 1

    cur.execute(
        """
        insert into public.sharepoint_sync_log
            (projeto_id, sharepoint_item_id, direction, action, source,
             changed_by_sharepoint, campos_alterados, payload_hash, resultado)
        values (%s, %s, 'pull', %s, 'sharepoint', %s, %s, %s, 'ok (backfill)')
        """,
        (
            projeto_id, sharepoint_item_id, acao, changed_by_sharepoint,
            json.dumps(fields, default=str), payload_hash,
        ),
    )


def connect(db_url):
    conn = psycopg2.connect(db_url)
    conn.autocommit = True
    return conn, conn.cursor()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--limit", type=int, default=None, help="parar depois de N itens (teste)")
    args = parser.parse_args()

    env = load_env(ENV_PATH)
    tenant_id = env["SHAREPOINT_TENANT_ID"]
    client_id = env["SHAREPOINT_CLIENT_ID"]
    client_secret = env["SHAREPOINT_CLIENT_SECRET"]
    db_url = env["SUPABASE_DB_URL"]

    token = get_graph_token(tenant_id, client_id, client_secret)

    # Conexão longa (o crawl inteiro leva vários minutos) — no dry-run de 2026-09-11 o
    # servidor derrubou a conexão no meio (~2000 itens), e como o cursor não é reaberto
    # sozinho, TODOS os itens seguintes falhavam com "cursor already closed". Por isso o
    # loop principal reconecta automaticamente (uma vez) sempre que detecta isso, em vez de
    # deixar o resto da varredura inteira se perder.
    conn, cur = connect(db_url)

    site_id, list_id = resolve_site_and_list(cur, token)

    cur.execute("select id, nome from public.contatos")
    mapa_contatos = {nome.strip().lower(): id_ for id_, nome in cur.fetchall() if nome}
    cur.execute("select id, nome from public.usuarios")
    mapa_usuarios = {nome.strip().lower(): id_ for id_, nome in cur.fetchall() if nome}
    cur.execute("select projeto_status, sharepoint_valor from public.sharepoint_status_map")
    mapa_status_reverso = {valor.strip(): status for status, valor in cur.fetchall()}

    contadores = {"criados": 0, "atualizados": 0, "criaria": 0, "atualizaria": 0, "erros": 0}

    url = (
        f"https://graph.microsoft.com/v1.0/sites/{site_id}/lists/{list_id}"
        f"/items/delta?$expand=fields"
    )
    headers = {"Authorization": f"Bearer {token}"}
    processados = 0
    pagina_n = 0
    delta_link_final = None

    print(f"Iniciando backfill (dry_run={args.dry_run}, limit={args.limit})...")

    while url:
        pagina_n += 1
        resp = requests.get(url, headers=headers, timeout=60)
        if resp.status_code == 429:
            espera = int(resp.headers.get("Retry-After", "10"))
            print(f"Throttled pelo Graph, esperando {espera}s...")
            time.sleep(espera)
            continue
        if not resp.ok:
            raise SystemExit(f"Falha na consulta delta (página {pagina_n}): {resp.status_code} {resp.text}")
        pagina = resp.json()

        for item in pagina.get("value", []):
            if item.get("@removed"):
                continue
            try:
                processar_item(cur, item, mapa_contatos, mapa_usuarios, mapa_status_reverso, args.dry_run, contadores)
            except (psycopg2.OperationalError, psycopg2.InterfaceError) as exc:
                print(f"Conexão com o banco caiu no item {item.get('id')} ({exc}). Reconectando...")
                try:
                    conn.close()
                except Exception:  # noqa: BLE001
                    pass
                conn, cur = connect(db_url)
                try:
                    processar_item(cur, item, mapa_contatos, mapa_usuarios, mapa_status_reverso, args.dry_run, contadores)
                except Exception as exc2:  # noqa: BLE001
                    contadores["erros"] += 1
                    print(f"Erro no item {item.get('id')} mesmo após reconectar: {exc2}")
            except Exception as exc:  # noqa: BLE001
                contadores["erros"] += 1
                print(f"Erro no item {item.get('id')}: {exc}")
            processados += 1
            if processados % 200 == 0:
                print(f"  ... {processados} itens processados (página {pagina_n})")
            if args.limit and processados >= args.limit:
                url = None
                break

        if url is None:
            break
        if "@odata.nextLink" in pagina:
            url = pagina["@odata.nextLink"]
        else:
            delta_link_final = pagina.get("@odata.deltaLink")
            url = None

    print("\n--- Resumo ---")
    print(json.dumps({"processados": processados, **contadores}, ensure_ascii=False, indent=2))

    if not args.dry_run and not args.limit and delta_link_final:
        cur.execute(
            """
            insert into public.sharepoint_sync_state (chave, valor, updated_at)
            values ('delta_link', %s, now())
            on conflict (chave) do update set valor = excluded.valor, updated_at = now()
            """,
            (delta_link_final,),
        )
        print("deltaLink inicial salvo em sharepoint_sync_state — cron incremental pode ser reativado.")
    elif not args.dry_run and args.limit:
        print("Rodou com --limit: deltaLink NÃO salvo de propósito (varredura parcial). Rode sem --limit para fechar.")

    cur.close()
    conn.close()


if __name__ == "__main__":
    main()
