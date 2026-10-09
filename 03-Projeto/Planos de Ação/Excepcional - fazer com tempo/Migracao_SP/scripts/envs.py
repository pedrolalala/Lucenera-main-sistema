# Lê os dois blocos do .env separadamente (nomes repetidos): SP = bloco "NOVO SUPABASE SÃO PAULO", OH = "supabase antigo ohio".
import re
def _bloco(ini, fim):
    L=open(r"C:\script python\ADAPTA-PASS-Lucenera-main\.env",encoding="utf-8").read().splitlines()
    i=next(n for n,l in enumerate(L) if ini in l.lower()); out={}
    for l in L[i+1:]:
        if l.startswith("#") and fim in l.lower(): break
        if "=" in l and not l.startswith("#"):
            k,v=l.split("=",1); out.setdefault(k.strip(), v.strip().strip('"'))
    return out
SP=_bloco("novo supabase", "ohio"); OH=_bloco("antigo ohio", "sharepoint")
SP["REF"]="bgtfrcbipuxnsexbppsh"; OH["REF"]="vcvcwzmbiftcawncibke"
SP["POOLER_URL"]=re.sub(r"//postgres:", "//postgres.bgtfrcbipuxnsexbppsh:", SP["SUPABASE_DB_URL"],count=1).replace("db.bgtfrcbipuxnsexbppsh.supabase.co:5432","aws-1-sa-east-1.pooler.supabase.com:5432")
OH["POOLER_URL"]=re.sub(r"//postgres:", "//postgres.vcvcwzmbiftcawncibke:", OH["SUPABASE_DB_URL"],count=1).replace("db.vcvcwzmbiftcawncibke.supabase.co:5432","aws-1-us-east-2.pooler.supabase.com:5432")
import json,urllib.request
def api(E, path, method="GET", body=None):
    r=urllib.request.Request("https://api.supabase.com/v1/"+path, method=method, data=None if body is None else json.dumps(body).encode(),
        headers={"Authorization":"Bearer "+E["SUPABASE_ACCESS_TOKEN"],"User-Agent":"lucenera-cli","Content-Type":"application/json"})
    try: return json.loads(urllib.request.urlopen(r,timeout=120).read() or b"null")
    except urllib.error.HTTPError as e: return f"HTTP {e.code}: {e.read()[:300]}"
