"""Visitante sem login: GET em cada tabela/view com a chave anon pública. Só leitura, limit=1, nada é gravado.
Uso: python -I probe_rest.py nomes_all.txt front.json saida.json"""
import json, re, sys, urllib.request, urllib.error
from concurrent.futures import ThreadPoolExecutor

nomes = [l.strip() for l in open(sys.argv[1], encoding="utf-8") if l.strip()]
front = json.load(open(sys.argv[2], encoding="utf-8"))
UA = {"User-Agent": "Mozilla/5.0"}

def fetch(u):
    return urllib.request.urlopen(urllib.request.Request(u, headers=UA), timeout=30).read().decode("utf-8", "replace")

keys = {}
for site in ["https://cadastro-lucenera.pages.dev", "https://cadastro-lucenera-b86fe.goskip.app"]:
    html = fetch(site)
    for a in re.findall(r'src="([^"]+\.js)"', html):
        body = fetch(site + a if a.startswith("/") else a)
        u = re.search(r"https://[a-z0-9]{20}\.supabase\.co", body)
        k = re.search(r"eyJ[A-Za-z0-9_-]{10,}\.eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}", body)
        if u and k:
            keys[u.group(0)] = k.group(0)

def probe(args):
    base, key, schema, n = args
    h = {"apikey": key, "Authorization": "Bearer " + key, "Prefer": "count=exact", "Accept-Profile": schema, **UA}
    try:
        r = urllib.request.urlopen(urllib.request.Request(f"{base}/rest/v1/{n}?select=*&limit=1", headers=h), timeout=40)
        cr = r.headers.get("Content-Range", "")
        d = json.loads(r.read() or b"[]")
        return n, schema, 200, cr.split("/")[-1], list(d[0].keys()) if d else []
    except urllib.error.HTTPError as e:
        b = e.read().decode("utf-8", "replace")
        try:
            b = json.loads(b).get("code") or b[:60]
        except Exception:
            b = b[:60]
        return n, schema, e.code, b, []
    except Exception as e:
        return n, schema, 0, str(e)[:60], []

out = {}
for base, key in keys.items():
    jobs = [(base, key, s, n) for s in ("public", "memoria") for n in nomes]
    with ThreadPoolExecutor(6) as ex:
        res = list(ex.map(probe, jobs))
    ref = base.split("//")[1].split(".")[0]
    out[ref] = [dict(zip(["nome", "schema", "status", "info", "colunas"], r)) for r in res]
    abertas = [r for r in out[ref] if r["status"] == 200]
    print(f"\n#### {ref}: {len(abertas)} objetos respondem 200 para visitante")
    for r in sorted(abertas, key=lambda r: -(int(r["info"]) if str(r["info"]).isdigit() else 0)):
        print(f"  {r['schema']}.{r['nome']}: {r['info']} linhas | {', '.join(r['colunas'][:14])}")
    from collections import Counter
    print("  outros status:", Counter((r["status"], r["info"]) for r in out[ref] if r["status"] != 200).most_common(6))
json.dump(out, open(sys.argv[3], "w", encoding="utf-8"), ensure_ascii=False, indent=1)
