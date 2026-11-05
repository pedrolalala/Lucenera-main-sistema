"""Aplica o up.sql (ou o rollback.sql) de uma migration em supabase/db/migrations/<pasta>. O arquivo já traz BEGIN/COMMIT.
Uso:  python aplicar_migration_sql.py 20261105_284_spec246_financeiro_definitivo            (aplica up.sql)
      python aplicar_migration_sql.py 20261105_284_spec246_financeiro_definitivo --dry-run  (roda dry_run.sql, termina em ROLLBACK)
      python aplicar_migration_sql.py 20261105_284_spec246_financeiro_definitivo --rollback (desfaz)
"""
import argparse, os, sys
import psycopg2
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from _supabase_client import para_pooler, SUPABASE_DB_URL

ap = argparse.ArgumentParser(); ap.add_argument("pasta"); g = ap.add_mutually_exclusive_group()
g.add_argument("--dry-run", action="store_true"); g.add_argument("--rollback", action="store_true")
a = ap.parse_args()
arq = "dry_run.sql" if a.dry_run else "rollback.sql" if a.rollback else "up.sql"
p = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "supabase", "db", "migrations", a.pasta, arq)
sql = open(p, encoding="utf-8").read()
c = psycopg2.connect(para_pooler(SUPABASE_DB_URL)); c.autocommit = True
cur = c.cursor(); cur.execute("set statement_timeout=0")
cur.execute(sql)
for n in c.notices: print(n.strip())
print(f"{arq} executado em {a.pasta}.")
