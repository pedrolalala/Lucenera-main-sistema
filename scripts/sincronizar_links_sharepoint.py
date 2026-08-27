"""
SPEC-046 (a registrar): sincroniza projetos.link_sharepoint lendo as pastas reais
dos sites de projetos no SharePoint (um site por responsável, ex. "PROJETOS MARINA"),
via Microsoft Graph API (client credentials), e casando pelo código no início do
nome da pasta (ex.: "26.180 NOME DO CLIENTE" -> código "26.180").

Regra de ouro: só preenche projetos com link_sharepoint vazio. Nunca sobrescreve
um link já existente (pode ter sido corrigido manualmente).

Uso:
  python scripts/sincronizar_links_sharepoint.py --min 26.170 --max 26.180
  python scripts/sincronizar_links_sharepoint.py --min 26.170 --max 26.180 --dry-run

Credenciais lidas do .env na raiz do repo: SHAREPOINT_TENANT_ID,
SHAREPOINT_CLIENT_ID, SHAREPOINT_CLIENT_SECRET, SUPABASE_DB_URL.
"""

import argparse
import os
import re
import unicodedata

import psycopg2
import psycopg2.extras
import requests

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ENV_PATH = os.path.join(ROOT, ".env")

CODE_RE = re.compile(r"^(\d{2}\.\d{3})")


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


def strip_accents(s):
    return "".join(c for c in unicodedata.normalize("NFKD", s) if not unicodedata.combining(c))


def site_name_for_responsavel(nome):
    if not nome:
        return None
    clean = strip_accents(nome).upper().strip()
    clean = re.sub(r"[^A-Z0-9]", "", clean)
    if not clean:
        return None
    return f"PROJETOS{clean}"


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


def list_site_project_folders(token, site_name):
    """Retorna (dict codigo->webUrl, erro) para as pastas de um site."""
    headers = {"Authorization": f"Bearer {token}"}

    site_resp = requests.get(
        f"https://graph.microsoft.com/v1.0/sites/lucenera.sharepoint.com:/sites/{site_name}",
        headers=headers,
        timeout=30,
    )
    if site_resp.status_code == 404:
        return None, f"site '{site_name}' não encontrado (404)"
    if not site_resp.ok:
        return None, f"erro ao resolver site '{site_name}': {site_resp.status_code} {site_resp.text[:200]}"
    site_id = site_resp.json()["id"]

    folders = {}
    url = f"https://graph.microsoft.com/v1.0/sites/{site_id}/drive/root/children"
    while url:
        r = requests.get(url, headers=headers, timeout=30)
        if not r.ok:
            return None, f"erro ao listar pastas de '{site_name}': {r.status_code} {r.text[:200]}"
        data = r.json()
        for item in data.get("value", []):
            if "folder" not in item:
                continue
            m = CODE_RE.match(item.get("name", ""))
            if not m:
                continue
            folders[m.group(1)] = item.get("webUrl")
        url = data.get("@odata.nextLink")

    return folders, None


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--min", required=True, help="código mínimo (ex.: 26.170)")
    parser.add_argument("--max", required=True, help="código máximo (ex.: 26.180)")
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="só mostra o relatório, não grava nada no banco",
    )
    args = parser.parse_args()

    env = load_env(ENV_PATH)
    tenant_id = env["SHAREPOINT_TENANT_ID"]
    client_id = env["SHAREPOINT_CLIENT_ID"]
    client_secret = env["SHAREPOINT_CLIENT_SECRET"]
    db_url = env["SUPABASE_DB_URL"]

    conn = psycopg2.connect(db_url)
    conn.autocommit = False
    cur = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
    cur.execute(
        """
        select id, codigo, nome, responsavel_nome, link_sharepoint
        from projetos
        where codigo >= %s and codigo <= %s
        order by codigo
        """,
        (args.min, args.max),
    )
    projetos = cur.fetchall()
    print(f"{len(projetos)} projetos encontrados na faixa {args.min}-{args.max}\n")

    if not projetos:
        cur.close()
        conn.close()
        return

    token = get_graph_token(tenant_id, client_id, client_secret)

    by_site = {}
    for p in projetos:
        site = site_name_for_responsavel(p["responsavel_nome"])
        by_site.setdefault(site, []).append(p)

    site_folders_cache = {}
    updates = []
    report = []

    for site, projs in by_site.items():
        if site is None:
            for p in projs:
                report.append(
                    (p["codigo"], p["nome"], "-", "SEM responsavel_nome -> não sei em qual site procurar")
                )
            continue

        if site not in site_folders_cache:
            site_folders_cache[site] = list_site_project_folders(token, site)
        folders, err = site_folders_cache[site]

        if err:
            for p in projs:
                report.append((p["codigo"], p["nome"], site, f"ERRO: {err}"))
            continue

        for p in projs:
            web_url = folders.get(p["codigo"])
            if not web_url:
                report.append((p["codigo"], p["nome"], site, "pasta não encontrada nesse site"))
                continue
            if p["link_sharepoint"]:
                report.append(
                    (p["codigo"], p["nome"], site, f"já tinha link (NÃO sobrescrito): {p['link_sharepoint']}")
                )
                continue
            updates.append((p["id"], p["codigo"], p["nome"], web_url))
            report.append((p["codigo"], p["nome"], site, f"MATCH -> {web_url}"))

    print("=== RELATÓRIO ===")
    for codigo, nome, site, status in report:
        print(f"{codigo} | {nome[:40]:<40} | site={site:<25} | {status}")

    print(f"\n{len(updates)} projeto(s) seriam atualizados.")

    if args.dry_run:
        print("\n--dry-run ativado: nada foi gravado no banco.")
        cur.close()
        conn.close()
        return

    if not updates:
        print("\nNada para gravar.")
        cur.close()
        conn.close()
        return

    for pid, codigo, nome, web_url in updates:
        cur.execute(
            "update projetos set link_sharepoint = %s where id = %s",
            (web_url, pid),
        )
    conn.commit()
    print(f"\n{len(updates)} projeto(s) atualizados com sucesso.")

    cur.close()
    conn.close()


if __name__ == "__main__":
    main()
