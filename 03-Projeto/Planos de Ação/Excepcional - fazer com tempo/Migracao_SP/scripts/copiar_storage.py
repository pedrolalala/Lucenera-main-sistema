# Copia os arquivos do Storage de Ohio para São Paulo (mesmo bucket/caminho/tipo). Idempotente: pula o que já existe
# em SP com o mesmo tamanho. Lê a lista em storage.objects de Ohio; baixa/sobe pela API de Storage (service role).
import sys,json,urllib.request,urllib.parse,psycopg2; sys.path.insert(0,__import__("os").path.dirname(__import__("os").path.abspath(__file__)))
from envs import SP,OH
def req(E,method,path,data=None,ctype=None):
    h={"Authorization":"Bearer "+E["SUPABASE_SERVICE_ROLE_KEY"],"apikey":E["SUPABASE_SERVICE_ROLE_KEY"],"User-Agent":"lucenera-mig"}
    if ctype: h["Content-Type"]=ctype; h["x-upsert"]="true"
    r=urllib.request.Request(E["SUPABASE_URL"]+"/storage/v1/"+path,data=data,method=method,headers=h)
    return urllib.request.urlopen(r,timeout=180)
def lista(E):
    cn=psycopg2.connect(E["POOLER_URL"],connect_timeout=20); cur=cn.cursor()
    cur.execute("select bucket_id,name,coalesce((metadata->>'size')::bigint,0),coalesce(metadata->>'mimetype','application/octet-stream') from storage.objects where name not like '%.emptyFolderPlaceholder' order by 1,2")
    r=cur.fetchall(); cn.close(); return r
oh=lista(OH); sp={(b,n):s for b,n,s,_ in lista(SP)}
ok=pul=err=0; erros=[]
for b,n,s,mt in oh:
    if sp.get((b,n))==s: pul+=1; continue
    p=urllib.parse.quote(n)
    try:
        dados=req(OH,"GET",f"object/{b}/{p}").read()
        req(SP,"POST",f"object/{b}/{p}",data=dados,ctype=mt).read(); ok+=1
    except Exception as e:
        err+=1; erros.append((b,n,str(e)[:120]))
print(f"copiados {ok} | já existiam {pul} | erros {err} | total Ohio {len(oh)}")
for x in erros[:15]: print("  ERRO",x)
