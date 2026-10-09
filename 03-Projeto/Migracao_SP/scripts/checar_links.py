import sys,re,psycopg2,urllib.request,concurrent.futures as cf; sys.path.insert(0,__import__("os").path.dirname(__import__("os").path.abspath(__file__)))
from envs import SP
PAT=re.compile('https://bgtfrcbipuxnsexbppsh[.]supabase[.]co/storage/v1/[^ "<>,]+')
cn=psycopg2.connect(SP["POOLER_URL"],connect_timeout=20); cur=cn.cursor()
urls=set()
for t,c in [("configuracao_empresa_ubiqua","logo_url"),("producao_pedidos","pdf_pedido_url"),("producao_pedidos","pdf_desenho_url"),("produtos","imagem_showroom_url"),("revenda_ubiqua","imagem_catalogo_url"),("showroom_import_pecas","imagem_url"),("quotes","items")]:
    cur.execute(f'select "{c}"::text from {t} where "{c}"::text like %s',("%bgtfrcbipuxnsexbppsh%",))
    for (v,) in cur.fetchall(): urls|=set(PAT.findall(v))
cn.close()
def head(u):
    try: return urllib.request.urlopen(urllib.request.Request(u,method="HEAD",headers={"User-Agent":"x"}),timeout=60).status
    except urllib.error.HTTPError as e: return e.code
    except Exception: return "erro"
with cf.ThreadPoolExecutor(8) as ex: res=dict(zip(urls,ex.map(head,list(urls))))
from collections import Counter; print("links distintos:",len(urls),"| respostas:",Counter(res.values()))
for u,s in [(u,s) for u,s in res.items() if s!=200][:15]: print(" ",s,u[60:])
