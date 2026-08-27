"""
Reproduz o formato de "ContaPagar_..._NAO_QUITADAS.xlsx" (analise pre-
existente no projeto, formato bruto Connect + 2 colunas de classificacao),
mas com a regra corrigida: status_pago (coluna "pago" na planilha bruta)
so conta como "nao quitada" quando = 0 (ABERTO). O arquivo original
tratava pago=2 ("Duplicata gerada, nao paga") como nao quitada tambem -
errado, confirmado pelo usuario 2026-08-19: pago=2 = CANCELADO, nunca
deve contar como divida em aberto (mesma correcao ja aplicada na
migration 20260819_121 / view v_financeiro_realizado).

Le a planilha bruta original (ContaPagar/ContaReceber_AAAA-MM-DD.xlsx,
aba "Financeiro") em vez do banco - reproduz o metodo do arquivo de
referencia (Linha_na_Planilha_Raiz = numero da linha na planilha bruta).

Uso:
  python scripts/panorama_financeiro/exportar_nao_quitadas_formato_connect.py \
      --entrada "01-Documento/01 - Planilhas/ContaPagar_2026-08-17.xlsx" \
      --saida "01-Documento/01 - Planilhas/ContaPagar_2026-08-17_NAO_QUITADAS_v3.xlsx"
"""

import argparse
from pathlib import Path

import pandas as pd


def processar(entrada: Path, saida: Path):
    df = pd.read_excel(entrada, sheet_name="Financeiro")
    df.columns = [c.strip() for c in df.columns]

    # Linha_na_Planilha_Raiz: numero da linha no Excel original (+2: header
    # ocupa a linha 1, index 0-based vira linha 2).
    df["Linha_na_Planilha_Raiz"] = df.index + 2

    pago = pd.to_numeric(df["pago"], errors="coerce").fillna(-1).astype(int)

    # So pago=0 (ABERTO) conta como "nao quitada". pago=2 (CANCELADO) fica
    # de fora inteiramente - nao aparece nem como nao quitada nem em
    # nenhum total. pago=1 (PAGO) tambem fica de fora, obviamente.
    nao_quitadas = df[pago == 0].copy()
    nao_quitadas["Status_Nao_Quitado"] = "Em aberto"

    cols = ["Linha_na_Planilha_Raiz", "Status_Nao_Quitado"] + [
        c for c in df.columns if c not in ("Linha_na_Planilha_Raiz",)
    ]
    nao_quitadas = nao_quitadas[cols]

    dev_troca = pd.to_numeric(nao_quitadas["dev_troca"], errors="coerce").fillna(0).astype(int)
    normal = nao_quitadas[dev_troca == 0]
    troca = nao_quitadas[dev_troca != 0]

    saida.parent.mkdir(parents=True, exist_ok=True)
    with pd.ExcelWriter(saida, engine="openpyxl") as writer:
        normal.to_excel(writer, sheet_name="Nao Quitadas - Normal", index=False)
        troca.to_excel(writer, sheet_name="Nao Quitadas - Dev Troca", index=False)

    print(f"Total nao quitadas (pago=0 apenas): {len(nao_quitadas)}")
    print(f"  Normal: {len(normal)}")
    print(f"  Dev Troca: {len(troca)}")
    print(f"Planilha gerada: {saida}")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--entrada", required=True)
    ap.add_argument("--saida", required=True)
    args = ap.parse_args()
    processar(Path(args.entrada), Path(args.saida))


if __name__ == "__main__":
    main()
