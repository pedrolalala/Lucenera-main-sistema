"""
Sincroniza planilha "Organização Projetos.xlsx" -> public.projetos (Supabase).

Uso:
    python importar_projetos.py            # executa a importacao completa
    python importar_projetos.py --dry-run  # apenas mostra o que seria feito

Estrategia de dois passes para contornar bug no trigger gerenciar_fluxo_projeto
(compara NEW.status com 'Aprovado' que nao existe no enum projeto_status):

  PASSE 1 — INSERT de projetos NOVOS (nao existem no banco):
            envia todos os campos incluindo status.
            Trigger so dispara em UPDATE, portanto sem erro.

  PASSE 2 — UPDATE de projetos EXISTENTES:
            envia todos os campos EXCETO status para que
            NEW.status = OLD.status e o trigger nao dispare.

Trigger trg_sync_equipe_por_responsavel preenche equipe_id e
equipe_responsavel_obra_id automaticamente ao gravar responsavel_nome.

PENDENCIA: aplicar migration 20260701_013 no Supabase Dashboard para
corrigir o trigger definitivamente (ver supabase/db/migrations/20260701_013_*).
"""

import os
import sys
import math

# Forca UTF-8 no terminal Windows
if sys.stdout.encoding and sys.stdout.encoding.lower() != "utf-8":
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")

import pandas as pd
from pathlib import Path
from dotenv import load_dotenv
from supabase import create_client

# -- Caminhos e config --------------------------------------------------------
BASE = Path(__file__).parent
PLANILHA = BASE / "01-Documento/01 - Planilhas/Planilhas atualizadas e novas/Organização Projetos.xlsx"
ENV_PATH = BASE / "dashboard/.env"

load_dotenv(dotenv_path=ENV_PATH)
SUPABASE_URL = os.getenv("SUPABASE_URL", "")
SUPABASE_KEY = os.getenv("SUPABASE_SERVICE_ROLE_KEY", "")

BATCH_SIZE = 200

NIVEL_MAP = {"Nível 1": "1", "Nível 2": "2", "Nível 3": "3", "Nível 4": "4"}
VAZIOS = {"-", ".", "--", "NaN", "nan", ""}


def clean_str(val) -> str | None:
    if val is None:
        return None
    if isinstance(val, float) and math.isnan(val):
        return None
    s = str(val).strip()
    return None if s in VAZIOS else s


def to_bool(val) -> bool:
    if val is None or (isinstance(val, float) and math.isnan(val)):
        return False
    return bool(val)


def buscar_codigos_existentes(sb) -> set[str]:
    """Retorna todos os codigos ja presentes em projetos (paginado)."""
    codigos = set()
    offset = 0
    while True:
        resp = sb.table("projetos").select("codigo").range(offset, offset + 999).execute()
        for row in resp.data:
            codigos.add(str(row["codigo"]).strip())
        if len(resp.data) < 1000:
            break
        offset += 1000
    return codigos


def preparar_registros(df: pd.DataFrame, codigos_existentes: set[str]):
    """
    Retorna (novos, existentes, ignorados).
    novos      -> dict com todos os campos (INSERT)
    existentes -> dict sem 'status' (UPDATE seguro contra trigger bug)
    ignorados  -> linhas sem Codigo
    """
    sem_codigo = df[df["Codigo"].isna()].copy()
    df = df[df["Codigo"].notna()].copy()

    novos = []
    existentes = []

    for _, row in df.iterrows():
        codigo = str(row["Codigo"]).strip()
        nivel_raw = clean_str(row.get("Nível Estratégico"))
        status_val = str(row["Status"]).strip()
        data_entrada = None
        if pd.notna(row["Data Entrada"]):
            try:
                data_entrada = pd.to_datetime(row["Data Entrada"]).strftime("%Y-%m-%d")
            except Exception:
                pass

        # Campos comuns (sem status)
        base = {
            "codigo":            codigo,
            "nome":              str(row["Projeto"]).strip(),
            "responsavel_nome":  clean_str(row["Responsável "]),
            "data_entrada":      data_entrada,
            "nivel_estrategico": NIVEL_MAP.get(nivel_raw) if nivel_raw else None,
            "Nome Arquiteto":    clean_str(row["Arquiteto Responsável "]),
            "cidade":            clean_str(row.get("Cidade")),
            "estado":            clean_str(row.get("Estado")),
            "arquivado":         to_bool(row.get("Arquivado")),
        }
        # Remove Nones exceto campos obrigatorios
        sempre = {"codigo", "nome", "responsavel_nome", "arquivado"}
        base = {k: v for k, v in base.items() if v is not None or k in sempre}

        if codigo in codigos_existentes:
            existentes.append(base)
        else:
            # Novo: inclui status para INSERT
            base["status"] = status_val
            novos.append(base)

    return novos, existentes, sem_codigo.to_dict("records")


def enviar_lotes(sb, registros: list[dict], descricao: str, dry_run: bool,
                 on_conflict: str | None = None) -> int:
    total_lotes = max(1, math.ceil(len(registros) / BATCH_SIZE))
    total_ok = 0

    for i in range(0, len(registros), BATCH_SIZE):
        lote = registros[i: i + BATCH_SIZE]
        num_lote = i // BATCH_SIZE + 1

        if dry_run:
            print(f"  [DRY] {descricao} lote {num_lote}/{total_lotes}: {len(lote)} registros")
            total_ok += len(lote)
            continue

        if on_conflict:
            resp = sb.table("projetos").upsert(lote, on_conflict=on_conflict).execute()
        else:
            resp = sb.table("projetos").insert(lote).execute()
        n = len(resp.data)
        total_ok += n
        print(f"  {descricao} lote {num_lote}/{total_lotes}: {len(lote)} enviados -> {n} confirmados")

    return total_ok


def diagnostico(sb) -> dict:
    total = sb.table("projetos").select("id", count="exact").execute()
    sem_resp = sb.table("projetos").select("id", count="exact").is_("responsavel_nome", "null").execute()
    return {"total": total.count, "sem_responsavel": sem_resp.count}


def main():
    dry_run = "--dry-run" in sys.argv

    if not SUPABASE_URL or not SUPABASE_KEY:
        print("ERRO: SUPABASE_URL ou SUPABASE_SERVICE_ROLE_KEY nao configurados.")
        sys.exit(1)

    sb = create_client(SUPABASE_URL, SUPABASE_KEY)

    # -- Pre-diagnostico ------------------------------------------------------
    print("\n-- Estado ANTES da importacao ----------------------------------")
    pre = diagnostico(sb)
    print(f"  Projetos no banco:      {pre['total']}")
    print(f"  Sem responsavel_nome:   {pre['sem_responsavel']}")

    # -- Codigos existentes ---------------------------------------------------
    print("\n-- Buscando codigos existentes no banco -------------------------")
    codigos_existentes = buscar_codigos_existentes(sb)
    print(f"  {len(codigos_existentes)} codigos encontrados")

    # -- Planilha -------------------------------------------------------------
    print("\n-- Processando planilha -----------------------------------------")
    df = pd.read_excel(PLANILHA)
    print(f"  {len(df)} linhas carregadas")

    novos, existentes, ignorados = preparar_registros(df, codigos_existentes)
    print(f"  Novos (INSERT com status): {len(novos)}")
    print(f"  Existentes (UPDATE s/ status): {len(existentes)}")
    if ignorados:
        print(f"  Ignorados (sem Codigo):    {len(ignorados)}")
        for r in ignorados:
            print(f"    - {r.get('Projeto','?')} ({r.get('Responsável ','?')})")

    # -- Passe 1: INSERT novos ------------------------------------------------
    total_ok = 0
    if novos:
        print(f"\n-- PASSE 1: INSERT {len(novos)} projetos novos ------------------")
        total_ok += enviar_lotes(sb, novos, "INSERT", dry_run, on_conflict=None)

    # -- Passe 2: UPDATE existentes (sem status) ------------------------------
    if existentes:
        print(f"\n-- PASSE 2: UPDATE {len(existentes)} projetos existentes -----------")
        total_ok += enviar_lotes(sb, existentes, "UPDATE", dry_run, on_conflict="codigo")

    if dry_run:
        print(f"\n[DRY-RUN] {total_ok} registros seriam processados. Nenhum dado alterado.")
        return

    print(f"\n  Total confirmado: {total_ok} registros")

    # -- Pos-diagnostico ------------------------------------------------------
    print("\n-- Estado APOS a importacao ------------------------------------")
    pos = diagnostico(sb)
    novos_banco = pos["total"] - pre["total"]
    print(f"  Projetos no banco:      {pos['total']} (+{novos_banco} novos)")
    print(f"  Sem responsavel_nome:   {pos['sem_responsavel']}")

    # Projetos com responsavel de equipe mas sem vinculo
    equipes = {"thais", "marina", "thairine"}
    r = sb.table("projetos").select("codigo, responsavel_nome").not_.is_("responsavel_nome", "null").is_("equipe_responsavel_obra_id", "null").execute()
    problemas = [p for p in r.data if (p.get("responsavel_nome") or "").lower().strip() in equipes]
    if problemas:
        print(f"\n  ATENCAO: {len(problemas)} projetos com equipe sem vinculo (equipe_responsavel_obra_id NULL):")
        for p in problemas:
            print(f"    - {p['codigo']} | {p['responsavel_nome']}")
    else:
        print("\n  OK: todos os responsaveis de equipe estao vinculados.")

    sem_resp_apos = sb.table("projetos").select("codigo, nome, responsavel_nome").is_("responsavel_nome", "null").limit(20).execute()
    if sem_resp_apos.data:
        print(f"\n  Projetos AINDA sem responsavel_nome (primeiros 20):")
        for p in sem_resp_apos.data:
            print(f"    - {p['codigo']:10} {p['nome']}")

    print("\n-- Concluido ---------------------------------------------------\n")
    print("PENDENCIA: aplicar migration 20260701_013 no Supabase Dashboard")
    print("  SQL: supabase/db/migrations/20260701_013_fix_gerenciar_fluxo_projeto/001_fix_status_cast.sql")
    print("  Isso libera atualizacao de STATUS de projetos via API/dashboard.\n")


if __name__ == "__main__":
    main()
