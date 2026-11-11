"""Catálogo + teste real como anon e como 'logado sem cadastro' (conta criada pelo signup aberto).
Tudo numa transação READ ONLY que termina em ROLLBACK. Uso: python -I scan_db.py <.env> <saida.json>"""
import json, sys, uuid
import psycopg2

env = {}
for line in open(sys.argv[1], encoding="utf-8"):
    line = line.strip()
    if line and not line.startswith("#") and "=" in line:
        k, v = line.split("=", 1); env[k] = v.strip().strip('"').strip("'")
conn = psycopg2.connect(env["SUPABASE_DB_URL"])
conn.set_session(readonly=True, autocommit=False)
cur = conn.cursor()
cur.execute("select current_database(), (select setting from pg_settings where name='cluster_name')")
SCHEMAS = ("public", "memoria", "auditoria", "backup", "storage")

cur.execute("""
select n.nspname, c.relname, c.relkind, c.relrowsecurity, pg_get_userbyid(c.relowner),
       has_table_privilege('anon', c.oid, 'SELECT'), has_table_privilege('anon', c.oid, 'INSERT'),
       has_table_privilege('anon', c.oid, 'UPDATE'), has_table_privilege('anon', c.oid, 'DELETE'),
       has_table_privilege('authenticated', c.oid, 'SELECT'), has_table_privilege('authenticated', c.oid, 'INSERT'),
       has_table_privilege('authenticated', c.oid, 'UPDATE'), has_table_privilege('authenticated', c.oid, 'DELETE'),
       coalesce((select array_agg(o) from unnest(c.reloptions) o), '{}')
from pg_class c join pg_namespace n on n.oid = c.relnamespace
where n.nspname = any(%s) and c.relkind in ('r','v','m','p','f')
order by 1, 2""", (list(SCHEMAS),))
rels = [dict(zip(["schema", "nome", "tipo", "rls", "dono", "a_sel", "a_ins", "a_upd", "a_del",
                  "u_sel", "u_ins", "u_upd", "u_del", "opts"], r)) for r in cur.fetchall()]

cur.execute("""
select schemaname, tablename, policyname, cmd, roles::text, qual, with_check from pg_policies
where schemaname = any(%s)""", (list(SCHEMAS),))
pols = {}
for s, t, p, cmd, roles, q, w in cur.fetchall():
    pols.setdefault(f"{s}.{t}", []).append({"nome": p, "cmd": cmd, "roles": roles, "using": q, "check": w})

cur.execute("""
select n.nspname, p.proname, pg_get_function_identity_arguments(p.oid), p.prosecdef,
       has_function_privilege('anon', p.oid, 'EXECUTE'), has_function_privilege('authenticated', p.oid, 'EXECUTE'),
       p.provolatile
from pg_proc p join pg_namespace n on n.oid = p.pronamespace
where n.nspname in ('public','memoria') and p.prokind = 'f'
  and not exists (select 1 from pg_depend d where d.objid = p.oid and d.deptype = 'e')
order by 1, 2""")
funcs = [dict(zip(["schema", "nome", "args", "secdef", "anon", "auth", "vol"], r)) for r in cur.fetchall()]

cur.execute("select id, public, file_size_limit, allowed_mime_types from storage.buckets order by id")
buckets = [dict(zip(["id", "public", "limite", "mimes"], r)) for r in cur.fetchall()]

def contar(role_sql, alvo):
    out = {}
    for r in rels:
        if r["schema"] == "storage" and r["nome"] != "objects":
            continue
        if not r[alvo]:
            continue
        q = f'select count(*) from "{r["schema"]}"."{r["nome"]}"'
        cur.execute("savepoint s")
        try:
            cur.execute(role_sql)
            cur.execute("set local statement_timeout = '20s'")
            cur.execute(q)
            out[f'{r["schema"]}.{r["nome"]}'] = cur.fetchone()[0]
        except Exception as e:
            out[f'{r["schema"]}.{r["nome"]}'] = "ERRO: " + str(e).splitlines()[0][:120]
        cur.execute("rollback to savepoint s")
    return out

anon = contar("set local role anon; select set_config('request.jwt.claims', '{\"role\":\"anon\"}', true)", "a_sel")
fake = str(uuid.uuid4())
claims = json.dumps({"role": "authenticated", "sub": fake, "email": "teste-signup@exemplo.invalid", "aud": "authenticated"})
novo = contar(f"set local role authenticated; select set_config('request.jwt.claims', '{claims}', true); "
              f"select set_config('request.jwt.claim.sub', '{fake}', true)", "u_sel")
conn.rollback()
json.dump({"rels": rels, "pols": pols, "funcs": funcs, "buckets": buckets, "anon": anon, "novo": novo},
          open(sys.argv[2], "w", encoding="utf-8"), ensure_ascii=False, indent=1, default=str)
print("ok", len(rels), "relacoes", len(funcs), "funcoes", len(buckets), "buckets")
