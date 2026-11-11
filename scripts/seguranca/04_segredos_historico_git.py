"""Etapa 7: procura segredo no histórico inteiro (todas as versões) de cada repositório local. Nunca imprime o valor.
Uso: python -I 04_segredos_historico_git.py <pasta_repo> [<pasta_repo> ...]"""
import base64, json, re, subprocess, sys

PATS = {
    "jwt": rb"eyJ[A-Za-z0-9_-]{10,}\.eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}",
    "sb_secret": rb"sb_secret_[A-Za-z0-9_-]{10,}",
    "postgres_url_com_senha": rb"postgres(?:ql)?://[^:\s'\"]+:[^@\s'\"]{6,}@[^\s'\"]+",
    "google_key": rb"AIza[0-9A-Za-z_-]{35}",
    "resend": rb"\bre_[A-Za-z0-9]{8,}_[A-Za-z0-9]{8,}",
    "openai_anthropic": rb"\bsk-(?:ant-)?[A-Za-z0-9_-]{20,}",
    "github": rb"gh[pousr]_[A-Za-z0-9]{30,}",
    "supabase_access_token": rb"sbp_[a-f0-9]{30,}",
    "gmail_app_password": rb"(?i)GMAIL_APP_PASSWORD\s*[=:]\s*['\"]?[a-z]{4}\s?[a-z]{4}\s?[a-z]{4}\s?[a-z]{4}",
    "client_secret": rb"(?i)client_?secret\s*[=:]\s*['\"]?[A-Za-z0-9~._-]{20,}",
    "focus_token": rb"(?i)FOCUS_NFE_TOKEN\s*[=:]\s*['\"]?[A-Za-z0-9]{20,}",
}

def role(tok: bytes):
    try:
        p = tok.split(b".")[1]; p += b"=" * (-len(p) % 4)
        return json.loads(base64.urlsafe_b64decode(p)).get("role")
    except Exception:
        return "?"

for repo in sys.argv[1:]:
    achados = {}
    envs = subprocess.run(["git", "-C", repo, "log", "--all", "--pretty=format:", "--name-only", "--diff-filter=A"],
                          capture_output=True).stdout.decode("utf-8", "replace").splitlines()
    env_files = sorted({f for f in envs if re.search(r"(^|/)\.env(\.|$)", f) and not f.endswith(".example")})
    log = subprocess.run(["git", "-C", repo, "log", "--all", "-p", "--no-color", "--unified=0"], capture_output=True).stdout
    for nome, pat in PATS.items():
        for m in set(re.findall(pat, log)):
            chave = nome
            if nome == "jwt":
                r = role(m)
                if r == "anon":
                    continue  # chave pública, esperado
                chave = f"jwt role={r}"
            achados[chave] = achados.get(chave, 0) + 1
    print(f"== {repo}")
    print(f"   .env commitado no histórico: {env_files or 'não'}")
    print(f"   segredos (tipos distintos): {achados or 'nenhum'}")
