# Virada SPEC-192: troca links de arquivos de Ohio pelos de São Paulo em todas as colunas de texto/json (public, memoria).
# Triggers desligados (session_replication_role=replica): não recalcula preço nem dispara SharePoint.
import sys,psycopg2; sys.path.insert(0,__import__("os").path.dirname(__import__("os").path.abspath(__file__)))
from envs import SP
A="https://vcvcwzmbiftcawncibke.supabase.co"; B="https://bgtfrcbipuxnsexbppsh.supabase.co"
cn=psycopg2.connect(SP["POOLER_URL"],connect_timeout=20); cur=cn.cursor()
cur.execute("set session_replication_role = replica")
cur.execute("""select table_schema,table_name,column_name,data_type,udt_name from information_schema.columns c join information_schema.tables t using(table_schema,table_name)
 where table_schema in ('public','memoria') and t.table_type='BASE TABLE' and data_type in ('text','character varying','jsonb','json','ARRAY')""")
tot=0
for s,t,c,dt,udt in cur.fetchall():
    if dt=="ARRAY":
        if udt not in ("_text","_varchar"): continue
        setx=f'"{c}" = array(select replace(x,%s,%s) from unnest("{c}") x)'
    elif dt in ("jsonb","json"): setx=f'"{c}" = replace("{c}"::text,%s,%s)::{dt}'
    else: setx=f'"{c}" = replace("{c}",%s,%s)'
    cur.execute(f'update "{s}"."{t}" set {setx} where "{c}"::text like %s',(A,B,"%vcvcwzmbiftcawncibke%")); 
    if cur.rowcount: print(f"{s}.{t}.{c}: {cur.rowcount}"); tot+=cur.rowcount
cur.execute("set session_replication_role = origin")
print("total trocado:",tot)
if "--real" in sys.argv: cn.commit(); print("COMMIT")
else: cn.rollback(); print("ROLLBACK (teste)")
