import os
from functools import lru_cache
from pathlib import Path
from dotenv import load_dotenv
from supabase import create_client, Client
import pandas as pd

# Carrega o .env da mesma pasta deste arquivo, independente do diretório de execução
_env_path = Path(__file__).parent / ".env"
load_dotenv(dotenv_path=_env_path, override=True)

SUPABASE_URL = os.getenv("SUPABASE_URL", "")
SUPABASE_SERVICE_KEY = os.getenv("SUPABASE_SERVICE_ROLE_KEY", "")

LUCENERA_VERDE = "#2E7D32"
LUCENERA_VERDE_CLARO = "#4CAF50"
LUCENERA_CINZA = "#F5F5F5"


@lru_cache(maxsize=1)
def get_client() -> Client:
    if not SUPABASE_URL or not SUPABASE_SERVICE_KEY:
        raise RuntimeError(
            "Configure SUPABASE_URL e SUPABASE_SERVICE_KEY no arquivo .env"
        )
    return create_client(SUPABASE_URL, SUPABASE_SERVICE_KEY)


def fetch_all(table: str, columns: str = "*", filters: dict | None = None, order: str | None = None) -> pd.DataFrame:
    """Busca todos os registros com paginação automática (lotes de 1000)."""
    client = get_client()
    rows = []
    batch = 1000
    offset = 0

    while True:
        q = client.table(table).select(columns)
        if filters:
            for col, val in filters.items():
                q = q.eq(col, val)
        if order:
            q = q.order(order)
        resp = q.range(offset, offset + batch - 1).execute()
        data = resp.data or []
        rows.extend(data)
        if len(data) < batch:
            break
        offset += batch

    return pd.DataFrame(rows)


def fetch_view(view: str, columns: str = "*") -> pd.DataFrame:
    """Busca view completa com paginação."""
    return fetch_all(view, columns)
