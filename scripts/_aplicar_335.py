"""Aplica a migration 335 (SPEC-282: historico de preco da peca) em Sao Paulo. Uso unico; pode apagar depois."""
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

arq = RAIZ / "supabase/db/migrations/20261111_335_spec282_historico_preco_peca/up.sql"
c = psycopg2.connect(para_pooler(os.environ["SUPABASE_DB_URL"]))
c.autocommit = True
c.cursor().execute(arq.read_text(encoding="utf-8"))
cur = c.cursor()
cur.execute("select count(*) from public.produto_preco_historico")
print("ok migration 335 aplicada; linhas no historico (retroativo):", cur.fetchone()[0])
