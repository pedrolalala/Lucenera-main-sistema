"""
Fábrica de cliente Supabase para os scripts de import em scripts/.

Antes esses scripts importavam de dashboard/config.py, mas a pasta
dashboard/ foi removida da working tree (mudança pré-existente, não feita
por este script) — este módulo reproduz só o get_client()/SUPABASE_URL
necessários, lendo o .env da raiz do repositório central em vez do
.env que existia dentro de dashboard/.
"""

import os
from functools import lru_cache
from pathlib import Path

from dotenv import load_dotenv
from supabase import Client, create_client

_ROOT = Path(__file__).resolve().parent.parent
load_dotenv(dotenv_path=_ROOT / ".env", override=True)

SUPABASE_URL = os.getenv("SUPABASE_URL", "")
SUPABASE_SERVICE_KEY = os.getenv("SUPABASE_SERVICE_ROLE_KEY", "")


@lru_cache(maxsize=1)
def get_client() -> Client:
    if not SUPABASE_URL or not SUPABASE_SERVICE_KEY:
        raise RuntimeError(
            "Configure SUPABASE_URL e SUPABASE_SERVICE_ROLE_KEY no .env da raiz do repositório."
        )
    return create_client(SUPABASE_URL, SUPABASE_SERVICE_KEY)
