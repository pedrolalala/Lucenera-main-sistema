"""
Fábrica de cliente Supabase para os scripts de import em scripts/.

Antes esses scripts importavam de dashboard/config.py, mas a pasta
dashboard/ foi removida da working tree (mudança pré-existente, não feita
por este script) — este módulo reproduz só o get_client()/SUPABASE_URL
necessários, lendo o .env da raiz do repositório central em vez do
.env que existia dentro de dashboard/.
"""

import os
import re
from functools import lru_cache
from pathlib import Path

from dotenv import load_dotenv
from supabase import Client, create_client

_ROOT = Path(__file__).resolve().parent.parent
load_dotenv(dotenv_path=_ROOT / ".env", override=True)

SUPABASE_URL = os.getenv("SUPABASE_URL", "")
SUPABASE_SERVICE_KEY = os.getenv("SUPABASE_SERVICE_ROLE_KEY", "")

# O host direto db.<ref>.supabase.co só tem IPv6 (não resolve nesta rede): troca pelo session
# pooler IPv4 da região do projeto. São Paulo é o banco oficial desde 14/10/2026 (SPEC-198).
_POOLER_POR_PROJETO = {
    "bgtfrcbipuxnsexbppsh": "aws-1-sa-east-1.pooler.supabase.com",  # São Paulo (oficial)
    "vcvcwzmbiftcawncibke": "aws-1-us-east-2.pooler.supabase.com",  # Ohio (reserva)
}


def para_pooler(db_url: str) -> str:
    m = re.search(r"//postgres:.*@db\.([a-z0-9]+)\.supabase\.co:5432", db_url)
    if not m or m.group(1) not in _POOLER_POR_PROJETO:
        return db_url
    ref = m.group(1)
    return db_url.replace("//postgres:", f"//postgres.{ref}:", 1).replace(
        f"db.{ref}.supabase.co:5432", f"{_POOLER_POR_PROJETO[ref]}:5432"
    )


SUPABASE_DB_URL = para_pooler(os.getenv("SUPABASE_DB_URL", ""))


@lru_cache(maxsize=1)
def get_client() -> Client:
    if not SUPABASE_URL or not SUPABASE_SERVICE_KEY:
        raise RuntimeError(
            "Configure SUPABASE_URL e SUPABASE_SERVICE_ROLE_KEY no .env da raiz do repositório."
        )
    return create_client(SUPABASE_URL, SUPABASE_SERVICE_KEY)
