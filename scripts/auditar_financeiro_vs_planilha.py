"""
SPEC-245 — AUDITORIA campo a campo (SÓ LEITURA): cada linha das planilhas ContaReceber/ContaPagar do dia × o que está no Supabase.

Para CADA linha da planilha (chave cod_itens_duplicata; quando o código se repete no sistema, usa a linha com o mesmo status e valor) compara:
  status | valor da parcela | valor pago | desconto | juros | vencimento | emissão | pagamento | nº da parcela | total de parcelas | cod. da duplicata |
  cod. da venda | nº da nota | empresa | PESSOA (nome ou razão social) | plano de contas | forma de pagamento.
Mostra quantas linhas divergem em cada campo e grava o detalhe em Excel (scripts/logs/conferencia_financeiro/auditoria_*.xlsx). Não altera nada.

Uso:  python scripts/auditar_financeiro_vs_planilha.py
"""

from __future__ import annotations

import sys
import unicodedata
from datetime import datetime
from pathlib import Path

import pandas as pd
import psycopg2

if sys.stdout.encoding and sys.stdout.encoding.lower() != "utf-8":
    sys.stdout.reconfigure(encoding="utf-8")

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "scripts"))
from _supabase_client import SUPABASE_DB_URL, para_pooler  # noqa: E402
from sync_connect_common import descobrir_planilha_mais_recente  # noqa: E402

PASTA = ROOT / "01-Documento" / "01 - Planilhas"
NORMAL_EMPRESA = {"LUCE NERA": "MANOELLA"}
CASOS = [("ContaReceber_", "receita", "Contas a Receber"), ("ContaPagar_", "despesa", "Contas a Pagar")]


def norm(x) -> str:
    s = unicodedata.normalize("NFD", str(x if x is not None and str(x) != "nan" else "")).encode("ascii", "ignore").decode().upper()
    for ch in ".,;:-/()&":
        s = s.replace(ch, " ")
    return " ".join(s.split())


def dia(v):
    if v is None or (isinstance(v, float) and pd.isna(v)) or v is pd.NaT:
        return None
    t = pd.to_datetime(v, dayfirst=True, errors="coerce")
    return None if pd.isna(t) else t.date()


def num(v):
    n = pd.to_numeric(v, errors="coerce")
    return 0.0 if pd.isna(n) else round(float(n), 2)


def ival(v) -> int:
    n = pd.to_numeric(v, errors="coerce")
    return 0 if pd.isna(n) else int(n)


def main() -> None:
    con = psycopg2.connect(para_pooler(SUPABASE_DB_URL), connect_timeout=30)
    cur = con.cursor()
    cur.execute("SELECT id::text, nome FROM public.empresas")
    emp = dict(cur.fetchall())
    cur.execute("SELECT id::text, nome FROM public.plano_de_contas")
    plano = dict(cur.fetchall())
    cur.execute("SELECT id::text, nome, razao_social, nome_empresa FROM public.contatos")
    contatos = {i: {norm(n) for n in (a, b, c) if norm(n)} for i, a, b, c in cur.fetchall()}

    saida = ROOT / "scripts" / "logs" / "conferencia_financeiro"
    saida.mkdir(parents=True, exist_ok=True)
    xlsx = saida / f"auditoria_financeiro_{datetime.now():%Y%m%d_%H%M%S}.xlsx"
    resumo, abas = [], {}

    for prefixo, tipo, titulo in CASOS:
        arq = descobrir_planilha_mais_recente(PASTA, prefixo)
        d = pd.read_excel(arq)
        d["cod"] = pd.to_numeric(d["cod_itens_duplicata"], errors="coerce").astype("Int64")
        print(f"\n=== {titulo}: {Path(arq).name} — {len(d)} linhas na planilha ===")
        cur.execute(
            """SELECT t.id::text, t.cod_itens_duplicata, t.status_pago, t.vl_parcela, t.vl_pago, t.vl_desconto, t.vl_juros, t.dt_vencimento, t.dt_emissao,
                      t.dt_pagamento, t.num_parc, t.tipo_pagamento, n.total_parc, n.cod_duplicata, n.cod_venda, n.num_nota, n.empresa_id::text, n.contato_id::text,
                      n.plano_contas_id::text, n.cod_pessoa
                 FROM public.transacoes t JOIN public.negociacoes n ON n.id = t.negociacao_id
                WHERE t.tipo::text = %s AND t.cod_itens_duplicata IS NOT NULL""",
            (tipo,),
        )
        cols = ["tid", "cod", "status_db", "vl_parcela_db", "vl_pago_db", "desc_db", "juros_db", "venc_db", "emis_db", "pag_db", "parc_db", "tpag_db", "total_db",
                "dup_db", "venda_db", "nota_db", "emp_db", "contato_db", "plano_db", "codpessoa_db"]
        db = pd.DataFrame(cur.fetchall(), columns=cols)
        db["cod"] = db["cod"].astype("Int64")
        sem_db = d[~d["cod"].isin(set(db["cod"].dropna()))]
        # linha do sistema com o mesmo código: prefere mesmo status e mesmo valor
        d["status_pl"] = pd.to_numeric(d["pago"], errors="coerce")
        m = d.merge(db, on="cod", how="left")
        m["_pref"] = ((m["status_db"] == m["status_pl"]).astype(int) * 2) + ((m["vl_parcela_db"].astype(float) - pd.to_numeric(m["vl_parcela"], errors="coerce")).abs() < 0.01).astype(int)
        m = m.sort_values(["cod", "_pref"], ascending=[True, False]).drop_duplicates("cod", keep="first")
        m = m[m["tid"].notna()]

        achados: dict[str, list] = {}

        def marca(campo, linha, planilha, sistema):
            achados.setdefault(campo, []).append({"cod_itens_duplicata": int(linha["cod"]), "cod_duplicata": linha["cod_duplicata"], "pessoa_planilha": linha["nome_pessoa"],
                                                  "vl_parcela_planilha": num(linha["vl_parcela"]), "planilha": planilha, "sistema": sistema})

        for r in m.itertuples(index=False):
            l = r._asdict()
            if ival(l["status_pl"]) != ival(l["status_db"]):
                marca("status", l, ival(l["status_pl"]), ival(l["status_db"]))
            if abs(num(l["vl_parcela"]) - num(l["vl_parcela_db"])) > 0.01:
                marca("valor_parcela", l, num(l["vl_parcela"]), num(l["vl_parcela_db"]))
            if abs(num(l["vl_pago"]) - num(l["vl_pago_db"])) > 0.01:
                marca("valor_pago", l, num(l["vl_pago"]), num(l["vl_pago_db"]))
            if abs(num(l["vl_desconto"]) - num(l["desc_db"])) > 0.01:
                marca("desconto", l, num(l["vl_desconto"]), num(l["desc_db"]))
            if abs(num(l["vl_juros"]) - num(l["juros_db"])) > 0.01:
                marca("juros", l, num(l["vl_juros"]), num(l["juros_db"]))
            for campo, a, b in (("vencimento", "dt_vencimento", "venc_db"), ("emissao", "dt_emissao", "emis_db"), ("pagamento", "dt_pagamento", "pag_db")):
                if dia(l[a]) != dia(l[b]):
                    marca(campo, l, str(dia(l[a])), str(dia(l[b])))
            if ival(l["num_parc"]) != ival(l["parc_db"]):
                marca("num_parcela", l, ival(l["num_parc"]), ival(l["parc_db"]))
            if ival(l["total_parc"]) != ival(l["total_db"]):
                marca("total_parcelas", l, ival(l["total_parc"]), ival(l["total_db"]))
            if ival(l["cod_duplicata"]) != ival(l["dup_db"]):
                marca("cod_duplicata", l, ival(l["cod_duplicata"]), ival(l["dup_db"]))
            vp, vd = ival(l["cod_venda"]), ival(l["venda_db"])
            if vp != vd:
                marca("cod_venda", l, vp, vd)
            npl, nd = ival(l["num_nota"]), ival(l["nota_db"])
            if max(npl, 0) != max(nd, 0):
                marca("num_nota", l, npl, nd)
            ep = NORMAL_EMPRESA.get(str(l["nm_empresa"]).strip().upper(), str(l["nm_empresa"]).strip().upper())
            if ep != emp.get(l["emp_db"], "?"):
                marca("empresa", l, ep, emp.get(l["emp_db"], "?"))
            nomes = {norm(l["nome_pessoa"]), norm(l["razao_pessoa"])} - {""}
            if not l["contato_db"]:
                marca("pessoa_SEM_CONTATO", l, " / ".join(sorted(nomes)), "(sem contato)")
            elif not (contatos.get(l["contato_db"], set()) & nomes):
                marca("pessoa_DIFERENTE", l, " / ".join(sorted(nomes)), " / ".join(sorted(contatos.get(l["contato_db"], set()))))
            pl_nome, pl_db = norm(l["desc_apropriacao"]), norm(plano.get(l["plano_db"], ""))
            if pl_nome != pl_db:
                marca("plano_de_contas", l, pl_nome, pl_db)
            if norm(l["tipo_pagamento"]) != norm(l["tpag_db"]):
                marca("forma_pagamento", l, norm(l["tipo_pagamento"]), norm(l["tpag_db"]))

        total = len(m)
        print(f"Linhas da planilha: {len(d)} | achadas no sistema: {total} | AUSENTES do sistema: {len(sem_db)}")
        linhas_com_diferenca = set()
        for campo, lst in sorted(achados.items(), key=lambda kv: -len(kv[1])):
            print(f"  divergência em {campo:20s}: {len(lst):6d}")
            linhas_com_diferenca |= {x["cod_itens_duplicata"] for x in lst}
            abas[f"{tipo[:3]}_{campo}"[:31]] = pd.DataFrame(lst)
        print(f"Linhas 100% iguais em todos os campos: {total - len(linhas_com_diferenca)} de {total}  ({(total - len(linhas_com_diferenca)) / max(total, 1):.1%})")
        abas[f"{tipo[:3]}_ausentes"] = sem_db[["cod", "cod_duplicata", "nome_pessoa", "vl_parcela", "pago"]]
        resumo.append({"sistema": titulo, "linhas_planilha": len(d), "ausentes_do_sistema": len(sem_db), "iguais_100pct": total - len(linhas_com_diferenca),
                       **{f"dif_{k}": len(v) for k, v in achados.items()}})

    con.close()
    with pd.ExcelWriter(xlsx) as w:
        pd.DataFrame(resumo).to_excel(w, sheet_name="resumo", index=False)
        for nome, df in abas.items():
            df.to_excel(w, sheet_name=nome[:31], index=False)
    print(f"\nExcel: {xlsx}")


if __name__ == "__main__":
    main()
