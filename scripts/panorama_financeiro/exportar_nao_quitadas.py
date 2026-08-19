"""
Exporta uma planilha .xlsx com todas as transacoes (contas a pagar e a
receber) genuinamente em aberto (status_pago = 0) — pra mandar pra quem
cobra/paga. Pedido do usuario, 2026-08-18, junto com a correcao do bug
de status_pago=2 (cancelado) sendo contado como em aberto.

status_pago: 0=ABERTO, 1=PAGO, 2=CANCELADO. Esta planilha usa SOMENTE
status_pago=0 - nem pago, nem cancelado entram aqui.

Uso:
  python scripts/panorama_financeiro/exportar_nao_quitadas.py --out arquivo.xlsx
"""

import argparse
import re
import sys
from pathlib import Path

import pandas as pd
import psycopg2
import psycopg2.extras

if sys.stdout.encoding and sys.stdout.encoding.lower() != "utf-8":
    sys.stdout.reconfigure(encoding="utf-8")

ROOT = Path(__file__).resolve().parent.parent.parent


def get_db_url():
    import os

    url = os.environ.get("SUPABASE_DB_URL")
    if url:
        return url.strip()
    env_path = ROOT / ".env"
    if env_path.exists():
        text = env_path.read_text(encoding="utf-8")
        m = re.search(r"SUPABASE_DB_URL=(.+)", text)
        if m:
            return m.group(1).strip()
    raise RuntimeError("SUPABASE_DB_URL nao encontrada (nem env var, nem .env local)")


def buscar_nao_quitadas():
    conn = psycopg2.connect(get_db_url())
    conn.set_client_encoding("UTF8")
    cur = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
    cur.execute("""
        select
            e.nome as empresa,
            case when t.tipo = 'despesa' then 'A Pagar' else 'A Receber' end as tipo,
            coalesce(pc.nome, 'Sem categoria') as categoria,
            coalesce(c.nome, '(sem contato vinculado)') as pessoa,
            t.descricao,
            t.valor,
            t.dt_emissao,
            t.dt_vencimento,
            case when t.dt_vencimento < current_date
                 then (current_date - t.dt_vencimento)
                 else 0 end as dias_atraso,
            n.cod_duplicata,
            t.num_parc,
            t.total_parc as parcelas_total
        from transacoes t
        join negociacoes n on n.id = t.negociacao_id
        join empresas e on e.id = n.empresa_id
        left join contatos c on c.id = n.contato_id
        left join plano_de_contas pc on pc.id = n.plano_contas_id
        where t.status_pago = 0
        order by t.tipo, dias_atraso desc, t.dt_vencimento
    """)
    rows = cur.fetchall()
    cur.close()
    conn.close()
    return rows


def montar_planilha(rows, out_path: Path):
    df = pd.DataFrame(rows)
    df = df.rename(columns={
        "empresa": "Empresa",
        "tipo": "Tipo",
        "categoria": "Categoria",
        "pessoa": "Pessoa",
        "descricao": "Descrição",
        "valor": "Valor",
        "dt_emissao": "Emissão",
        "dt_vencimento": "Vencimento",
        "dias_atraso": "Dias em Atraso",
        "cod_duplicata": "Nº Duplicata",
        "num_parc": "Parcela",
        "parcelas_total": "Total Parcelas",
    })

    out_path.parent.mkdir(parents=True, exist_ok=True)
    with pd.ExcelWriter(out_path, engine="openpyxl") as writer:
        for tipo, aba in (("A Pagar", "Contas a Pagar"), ("A Receber", "Contas a Receber")):
            sub = df[df["Tipo"] == tipo].drop(columns=["Tipo"])
            if sub.empty:
                sub = pd.DataFrame(columns=[c for c in df.columns if c != "Tipo"])
            sub.to_excel(writer, sheet_name=aba, index=False)

        resumo = pd.DataFrame([
            {"Tipo": "A Pagar", "Qtd": len(df[df["Tipo"] == "A Pagar"]), "Total (R$)": df[df["Tipo"] == "A Pagar"]["Valor"].sum()},
            {"Tipo": "A Receber", "Qtd": len(df[df["Tipo"] == "A Receber"]), "Total (R$)": df[df["Tipo"] == "A Receber"]["Valor"].sum()},
        ])
        resumo.to_excel(writer, sheet_name="Resumo", index=False)

        for sheet in writer.sheets.values():
            for col_cells in sheet.columns:
                length = max(len(str(c.value)) if c.value is not None else 0 for c in col_cells)
                sheet.column_dimensions[col_cells[0].column_letter].width = min(max(length + 2, 10), 45)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", required=True)
    args = ap.parse_args()

    print("Buscando transações em aberto (status_pago = 0)...")
    rows = buscar_nao_quitadas()
    print(f"{len(rows)} transações em aberto encontradas.")

    out_path = Path(args.out)
    montar_planilha(rows, out_path)
    print(f"Planilha gerada: {out_path}")


if __name__ == "__main__":
    main()
