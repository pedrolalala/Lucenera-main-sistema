"""Aplica a migration 336 (SPEC-282: Debora tambem reajusta precos) em Sao Paulo. Uso unico; pode apagar depois."""
import os
import sys
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent
for l in (RAIZ / ".env").read_text(encoding="utf-8").splitlines():
    if "=" in l and not l.startswith("#"):
        k, v = l.split("=", 1)
        os.environ.setdefault(k.strip(), v.strip().strip("\"'"))

sys.path.insert(0, str(RAIZ / "scripts"))
import psycopg2
from _supabase_client import para_pooler

arq = RAIZ / "supabase/db/migrations/20261111_336_spec282_reajuste_autorizados/up.sql"
c = psycopg2.connect(para_pooler(os.environ["SUPABASE_DB_URL"]))
c.autocommit = True
c.cursor().execute(arq.read_text(encoding="utf-8"))
cur = c.cursor()
cur.execute("select email from public.produto_reajuste_autorizados")
print("ok migration 336 aplicada; autorizados alem do admin:", [r[0] for r in cur.fetchall()])
