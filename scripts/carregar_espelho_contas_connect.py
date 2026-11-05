"""
SPEC-245 — ESPELHO das planilhas do financeiro no Supabase (resposta a "onde está a planilha no Supabase" e a "o nome da pessoa está null").

Copia, linha a linha e com as 50 colunas, a ContaReceber_*.xlsx e a ContaPagar_*.xlsx mais recentes para `public.connect_contas_espelho`
(chave: tipo + cod_itens_duplicata) e atualiza `negociacoes.nome_pessoa` / `razao_pessoa` com o nome COMO A PLANILHA DIZ (as telas mostram esse nome primeiro).

  * Troca o espelho de cada tipo numa transação só (apaga o do tipo e insere o do dia) e CONFERE antes de gravar: nº de linhas, soma da parcela, soma em aberto,
    soma paga e nº de linhas em aberto do espelho têm que ser IGUAIS às da planilha. Se qualquer uma diferir, nada é gravado.
  * Não altera transações, valores, contatos, estoque nem vendas (só o espelho e as duas colunas de nome).
  * Rodar DEPOIS de importar_contas_pagar_receber.py (o nome é ligado pela parcela, cod_itens_duplicata).

Uso:  python scripts/carregar_espelho_contas_connect.py            # DRY-RUN (cria a tabela dentro da transação se a migration 283 ainda não existir e DESFAZ)
      python scripts/carregar_espelho_contas_connect.py --aplicar  # grava (exige a migration 283 aplicada)
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

import pandas as pd
import psycopg2
import psycopg2.extras

if sys.stdout.encoding and sys.stdout.encoding.lower() != "utf-8":
    sys.stdout.reconfigure(encoding="utf-8")

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "scripts"))
from _supabase_client import SUPABASE_DB_URL, para_pooler  # noqa: E402
from sync_connect_common import descobrir_planilha_mais_recente  # noqa: E402

PASTA = ROOT / "01-Documento" / "01 - Planilhas"
MIGRATION = ROOT / "supabase" / "db" / "migrations" / "20261105_283_spec245_espelho_contas_connect" / "up.sql"
CASOS = [("ContaReceber_", "receita"), ("ContaPagar_", "despesa")]

INTS = ["cod_empresa", "cod_duplicata", "cod_itens_duplicata", "acordo", "tipo_nota", "cod_venda", "num_nota", "dev_troca", "cod_saida_pgto", "cod_apropriacao",
        "cod_grupo", "cod_sub_grupo", "cod_conta", "num_parc", "total_parc", "cod_pessoa", "pago", "lancamento"]
NUMS = ["antecipacao", "vl_duplicata", "vl_parcela", "vl_desconto", "vl_juros", "vl_pago", "vl_frete", "vl_ipi", "vl_st"]
DATAS = ["dt_emissao", "dt_vencimento", "dt_ultimo_pgto"]
DATAHORAS = ["dt_pagamento", "data_baixa"]
TEXTOS = ["tipo_operacao", "nm_empresa", "desc_perfil_empresa", "n_documento", "desc_apropriacao", "desc_grupo", "desc_sub_grupo", "desc_conta", "desc_condpagto",
          "tipo_pagamento", "nome_pessoa", "razao_pessoa", "tel_pessoa", "email_financeiro", "nm_funcionario", "layout_boleto", "nosso_numero", "observacao"]
COLUNAS = ["tipo"] + INTS + NUMS + DATAS + DATAHORAS + TEXTOS + ["arquivo_origem"]


def limpo(v):
    """Converte para tipos nativos do Python (o psycopg2 não adapta numpy/pandas) e NaN/NA/NaT para None."""
    if v is None or v is pd.NA or v is pd.NaT:
        return None
    if isinstance(v, float) and pd.isna(v):
        return None
    if isinstance(v, pd.Timestamp):
        return v.to_pydatetime()
    if hasattr(v, "item"):  # numpy.int64 / float64 / bool_
        v = v.item()
        if isinstance(v, float) and pd.isna(v):
            return None
    return v


def preparar(arq: Path, tipo: str) -> pd.DataFrame:
    d = pd.read_excel(arq, sheet_name="Financeiro")
    d.columns = [c.strip() for c in d.columns]
    d = d.rename(columns={"TipoOperacao": "tipo_operacao", "obs_conta_pagar": "observacao"})
    if "observacao" not in d.columns:
        d["observacao"] = None
    for c in INTS:
        d[c] = pd.to_numeric(d.get(c), errors="coerce").round().astype("Int64")
    for c in NUMS:
        d[c] = pd.to_numeric(d.get(c), errors="coerce").round(2)
    for c in DATAS:
        d[c] = pd.to_datetime(d.get(c), dayfirst=True, errors="coerce").dt.date
    for c in DATAHORAS:
        d[c] = pd.to_datetime(d.get(c), dayfirst=True, errors="coerce")
    for c in TEXTOS:
        d[c] = d[c].astype(object).where(d[c].notna(), None) if c in d.columns else None
        if c in d.columns:
            d[c] = d[c].map(lambda x: None if x is None else (str(x).strip() or None))
    d["tipo"] = tipo
    d["arquivo_origem"] = arq.name
    d = d.dropna(subset=["cod_itens_duplicata"])
    if d["cod_itens_duplicata"].duplicated().any():
        raise SystemExit(f"{arq.name}: cod_itens_duplicata repetido na planilha; abortado.")
    return d[COLUNAS]


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--aplicar", action="store_true")
    args = ap.parse_args()
    con = psycopg2.connect(para_pooler(SUPABASE_DB_URL), connect_timeout=30)
    cur = con.cursor()
    try:
        cur.execute("SELECT to_regclass('public.connect_contas_espelho') IS NOT NULL")
        existe = cur.fetchone()[0]
        if not existe:
            if args.aplicar:
                sys.exit("A tabela connect_contas_espelho não existe: aplique a migration 283 antes de rodar com --aplicar.")
            print("(dry-run) migration 283 ainda não aplicada: criando a tabela DENTRO da transação, que será desfeita.")
            sql = "\n".join(l for l in MIGRATION.read_text(encoding="utf-8").splitlines() if l.strip() not in ("BEGIN;", "COMMIT;"))
            cur.execute(sql)

        for prefixo, tipo in CASOS:
            arq = descobrir_planilha_mais_recente(PASTA, prefixo)
            d = preparar(arq, tipo)
            n = len(d)
            esperado = (n, round(float(d["vl_parcela"].fillna(0).sum()), 2), int((d["pago"] == 0).sum()), round(float(d.loc[d["pago"] == 0, "vl_parcela"].fillna(0).sum()), 2),
                        round(float(d["vl_pago"].fillna(0).sum()), 2))
            cur.execute("DELETE FROM public.connect_contas_espelho WHERE tipo = %s", (tipo,))
            cols = ", ".join(COLUNAS)
            linhas = [tuple(limpo(v) for v in r) for r in d.itertuples(index=False, name=None)]
            psycopg2.extras.execute_values(cur, f"INSERT INTO public.connect_contas_espelho ({cols}) VALUES %s", linhas, page_size=1000)
            cur.execute("SELECT count(*), coalesce(sum(vl_parcela),0), count(*) FILTER (WHERE pago = 0), coalesce(sum(vl_parcela) FILTER (WHERE pago = 0),0), coalesce(sum(vl_pago),0) "
                        "FROM public.connect_contas_espelho WHERE tipo = %s", (tipo,))
            got = cur.fetchone()
            obtido = (int(got[0]), round(float(got[1]), 2), int(got[2]), round(float(got[3]), 2), round(float(got[4]), 2))
            print(f"{arq.name} -> espelho '{tipo}': linhas {obtido[0]} | soma parcela {obtido[1]:,.2f} | em aberto {obtido[2]} (R$ {obtido[3]:,.2f}) | soma paga {obtido[4]:,.2f}")
            if obtido != esperado:
                raise SystemExit(f"ABORTADO: o espelho '{tipo}' não é igual à planilha. planilha={esperado} espelho={obtido}. Nada foi gravado.")
            print("   confere com a planilha: IGUAL")

        # nome da pessoa como a planilha diz, ligado pela parcela
        cur.execute(
            """UPDATE public.negociacoes n SET nome_pessoa = x.nome_pessoa, razao_pessoa = x.razao_pessoa
                 FROM (SELECT DISTINCT ON (t.negociacao_id) t.negociacao_id, e.nome_pessoa, e.razao_pessoa
                         FROM public.transacoes t JOIN public.connect_contas_espelho e ON e.tipo = t.tipo::text AND e.cod_itens_duplicata = t.cod_itens_duplicata
                        WHERE t.cod_itens_duplicata IS NOT NULL ORDER BY t.negociacao_id, t.status_pago, t.cod_itens_duplicata) x
                WHERE n.id = x.negociacao_id AND (n.nome_pessoa IS DISTINCT FROM x.nome_pessoa OR n.razao_pessoa IS DISTINCT FROM x.razao_pessoa)"""
        )
        print("negociações com o nome da pessoa atualizado:", cur.rowcount)
        cur.execute("SELECT tipo::text, count(*), count(*) FILTER (WHERE nome_pessoa IS NULL AND razao_pessoa IS NULL), "
                    "count(*) FILTER (WHERE nome_pessoa IS NULL AND razao_pessoa IS NULL AND contato_id IS NULL) FROM public.negociacoes GROUP BY 1")
        for t, tot, sem_nome, sem_nada in cur.fetchall():
            print(f"  {t}: negociações {tot} | sem o nome da planilha {sem_nome} (as da planilha de hoje têm todas) | sem nome da planilha e sem cadastro: {sem_nada}")

        if args.aplicar:
            con.commit()
            print("GRAVADO.")
        else:
            con.rollback()
            print("DRY-RUN: tudo desfeito, nada foi gravado.")
    except BaseException:
        con.rollback()
        raise
    finally:
        con.close()


if __name__ == "__main__":
    main()
