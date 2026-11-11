"""Varredura do que um visitante vê no DevTools (Sources/Network) de cada site. Nunca imprime segredo inteiro."""
import base64, json, re, sys, urllib.request, urllib.parse
from concurrent.futures import ThreadPoolExecutor

CF = ["adm-bancaria", "cadastro", "central", "compras", "contas-pagar", "contas-receber", "crm",
      "dashboard", "financeiro", "garantia", "logistica", "memoria", "movimentacao", "producao", "rh", "separacao",
      "showroom", "solicitacoes", "vendas"]
SKIP = ["gestao-financeira-clone-544cb", "gestaofinanceiralucenera", "dashboard-empresa-40d7d", "pagina-em-branco-cdd79",
        "dashboard-rh-lucenera-5fe9c", "lucenera-crm-3bd29", "catalogo-pecas-ubiqua-e6fa0", "cadastro-lucenera-b86fe",
        "central-lucenera-dashboard-1c9ba", "central-de-solicitacoes-cc2ec", "memoria-lucenera-2e074",
        "separacao-parcial-dff01", "tela-showroom-522b1", "lucenera-logistics-b7cd1", "pagina-de-vendas-9549c",
        "pagina-em-branco-e9c45", "pagina-em-branco-b044c"]
SITES = [f"https://{h}-lucenera.pages.dev" for h in CF] + ["https://catalogo-ubiqua.pages.dev"] + [f"https://{h}.goskip.app" for h in SKIP]

PATS = {
    "jwt": r"eyJ[A-Za-z0-9_-]{10,}\.eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}",
    "sb_secret": r"sb_secret_[A-Za-z0-9_-]{10,}",
    "sb_publishable": r"sb_publishable_[A-Za-z0-9_-]{10,}",
    "supabase_url": r"https://[a-z0-9]{20}\.supabase\.co",
    "google_key": r"AIza[0-9A-Za-z_-]{35}",
    "resend": r"\bre_[A-Za-z0-9]{20,}",
    "stripe": r"\b[sr]k_(live|test)_[A-Za-z0-9]{10,}",
    "openai": r"\bsk-[A-Za-z0-9_-]{20,}",
    "anthropic": r"sk-ant-[A-Za-z0-9_-]{10,}",
    "github": r"gh[pousr]_[A-Za-z0-9]{30,}",
    "aws": r"AKIA[0-9A-Z]{16}",
    "slack_teams_webhook": r"https://[a-z0-9.-]*(webhook\.office\.com|hooks\.slack\.com|logic\.azure\.com|powerautomate|flow\.microsoft)[^\"'\s]*",
    "focus_nfe": r"(?i)focusnfe[^\"'\s]{0,80}",
    "senha_literal": r"(?i)(password|senha|secret|token|api_?key)\s*[:=]\s*[\"'][^\"'\s]{6,}[\"']",
    "email": r"[A-Za-z0-9._%+-]+@(?!example)[A-Za-z0-9.-]+\.(com|br|com\.br)\b",
    "sourcemap": r"sourceMappingURL=([^\s*]+)",
}

def get(url, t=20):
    try:
        r = urllib.request.urlopen(urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"}), timeout=t)
        return r.status, dict(r.headers), r.read().decode("utf-8", "replace")
    except urllib.error.HTTPError as e:
        return e.code, dict(e.headers), ""
    except Exception as e:
        return 0, {}, str(e)

def jwt_role(tok):
    try:
        p = tok.split(".")[1]; p += "=" * (-len(p) % 4)
        d = json.loads(base64.urlsafe_b64decode(p))
        return d.get("role"), d.get("ref")
    except Exception:
        return None, None

def mask(s):
    return s[:12] + "…" + s[-4:] if len(s) > 20 else s[:4] + "…"

def scan(site):
    st, hd, html = get(site)
    out = {"site": site, "status": st, "achados": {}, "headers_faltando": [], "maps": [], "assets": 0}
    if st != 200:
        return out
    for h in ["content-security-policy", "x-frame-options", "strict-transport-security", "x-content-type-options",
              "referrer-policy"]:
        if h not in {k.lower() for k in hd}:
            out["headers_faltando"].append(h)
    assets = set(re.findall(r'(?:src|href)="([^"]+\.(?:js|css))"', html))
    texts = [("index.html", html)]
    seen = set()
    queue = [urllib.parse.urljoin(site + "/", a) for a in assets]
    while queue and len(seen) < 60:
        u = queue.pop()
        if u in seen or not u.startswith(site):
            continue
        seen.add(u)
        s, _, body = get(u)
        if s != 200:
            continue
        texts.append((u, body))
        if u.endswith(".js"):  # chunks importados dinamicamente
            for m in re.findall(r'["\'](\.{0,2}/?assets/[A-Za-z0-9_.-]+\.js)["\']', body):
                queue.append(urllib.parse.urljoin(u, m))
            for m in re.findall(r'["\']\./([A-Za-z0-9_-]+-[A-Za-z0-9_-]{6,}\.js)["\']', body):
                queue.append(urllib.parse.urljoin(u, m))
    out["assets"] = len(texts) - 1
    for u, body in texts:
        for name, pat in PATS.items():
            for m in set(re.findall(pat, body) if name != "slack_teams_webhook" else [x.group(0) for x in re.finditer(pat, body)]):
                m = m if isinstance(m, str) else m[0]
                if name == "sourcemap":
                    mu = urllib.parse.urljoin(u, m)
                    s, _, mb = get(mu)
                    out["maps"].append((mu.rsplit("/", 1)[-1], s, len(mb)))
                    continue
                key = name
                val = m
                if name == "jwt":
                    role, ref = jwt_role(m)
                    key = f"jwt role={role} ref={ref}"
                    val = mask(m)
                elif name in ("sb_secret", "sb_publishable", "google_key", "resend", "stripe", "openai", "anthropic", "github", "aws", "senha_literal"):
                    val = mask(m)
                out["achados"].setdefault(key, set()).add(val)
        if u.endswith(".js"):  # teste de .map adivinhado
            s, _, mb = get(u + ".map", 10)
            if s == 200 and mb.lstrip().startswith("{"):
                out["maps"].append((u.rsplit("/", 1)[-1] + ".map", s, len(mb)))
    return out

with ThreadPoolExecutor(8) as ex:
    res = list(ex.map(scan, SITES))
for r in res:
    r["achados"] = {k: sorted(v) for k, v in r["achados"].items()}
json.dump(res, open(sys.argv[1], "w", encoding="utf-8"), ensure_ascii=False, indent=1)
for r in res:
    print(f"\n== {r['site']} [{r['status']}] assets={r['assets']}")
    if r["status"] != 200:
        continue
    print("  headers faltando:", ",".join(r["headers_faltando"]))
    if r["maps"]:
        print("  SOURCE MAPS:", r["maps"][:5], "total", len(r["maps"]))
    for k, v in r["achados"].items():
        print(f"  {k}: {v[:6]}{' (+%d)' % (len(v)-6) if len(v) > 6 else ''}")
