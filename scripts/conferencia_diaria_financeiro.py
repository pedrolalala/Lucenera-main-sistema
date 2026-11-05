"""
SPEC-245 (reunião 04, Filippo): CONFERÊNCIA DIÁRIA AUTOMÁTICA do Contas a Receber / Contas a Pagar — "tem que baixar a planilha e conferir já, sem esperar
alguém dizer que há diferença". Gera um RELATÓRIO DE UMA PÁGINA: BATE / NÃO BATE, o que mudou e o que precisa de decisão.

Três modos:
  python scripts/conferencia_diaria_financeiro.py            # só confere (leitura) e gera o relatório
  python scripts/conferencia_diaria_financeiro.py --ensaio   # roda a cadeia de carga em ENSAIO (nada é gravado) e depois confere
  python scripts/conferencia_diaria_financeiro.py --carregar # roda a cadeia de carga GRAVANDO e depois confere (rotina diária)

Cadeia de carga (para no primeiro erro):
  1 importar_contas_pagar_receber.py -> 2 carregar_espelho_contas_connect.py -> 3 corrigir_empresa_negociacoes_financeiro.py ->
  4 corrigir_pessoas_financeiro.py -> 5 corrigir_campos_financeiro_planilha.py

VEREDITO "BATE" exige: (a) planilhas com a data de hoje; (b) nenhuma linha da planilha ausente do sistema; (c) EM ABERTO igual no total e por empresa;
(d) espelho igual à planilha; (e) 0 diferenças em status, valor da parcela, valor pago, emissão, vencimento e pagamento.
Código de saída: 0 = BATE, 1 = NÃO BATE, 2 = a carga falhou.
"""

from __future__ import annotations

import argparse
import re
import subprocess
import sys
from datetime import date, datetime
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
CASOS = [("ContaReceber_", "receita", "Contas a Receber"), ("ContaPagar_", "despesa", "Contas a Pagar")]
NORMAL_EMPRESA = {"LUCE NERA": "MANOELLA"}
CADEIA = [
    ("1. Carga das planilhas", "importar_contas_pagar_receber.py", [], ["--dry-run"]),
    ("2. Espelho da planilha", "carregar_espelho_contas_connect.py", ["--aplicar"], []),
    ("3. Empresa das duplicatas", "corrigir_empresa_negociacoes_financeiro.py", ["--aplicar"], []),
    ("4. Pessoa das duplicatas", "corrigir_pessoas_financeiro.py", ["--aplicar"], []),
    ("5. Campos de cadastro", "corrigir_campos_financeiro_planilha.py", ["--aplicar"], []),
]


def brl(v: float) -> str:
    return f"R$ {v:,.2f}".replace(",", "X").replace(".", ",").replace("X", ".")


def rodar_cadeia(modo: str) -> list[dict]:
    resultados = []
    for nome, script, args_grava, args_ensaio in CADEIA:
        args = args_grava if modo == "carregar" else args_ensaio
        cmd = [sys.executable, str(ROOT / "scripts" / script)] + args
        print(f"\n>>> {nome}: {' '.join(['python', 'scripts/' + script] + args)}")
        p = subprocess.run(cmd, cwd=ROOT, capture_output=True, text=True, encoding="utf-8", errors="replace")
        saida = (p.stdout or "") + (p.stderr or "")
        chave = [l for l in saida.splitlines() if re.search(
            r"(Transações novas|a atualizar|Negociações a corrigir|Alterações|GRAVADO|DRY-RUN|IGUAL|ABORT|Traceback|Error|erro|confere com|negociações com o nome|RECUSADO)", l)]
        for l in chave[-6:]:
            print("   ", l.strip()[:170])
        resultados.append({"passo": nome, "ok": p.returncode == 0, "resumo": chave[-3:]})
        if p.returncode != 0:
            print(f"   !!! {nome} FALHOU (código {p.returncode}); a cadeia foi interrompida e NADA depois dele rodou.")
            print("   " + "\n   ".join(saida.strip().splitlines()[-8:])[:900])
            break
    return resultados


def dia(v):
    t = pd.to_datetime(v, dayfirst=True, errors="coerce")
    return None if pd.isna(t) else t.date()


def conferir(cur, hoje: date) -> dict:
    cur.execute("SELECT id::text, nome FROM public.empresas")
    emp = dict(cur.fetchall())
    cur.execute("SELECT codigo_connect FROM public.plano_de_contas WHERE codigo_connect IS NOT NULL")
    planos = {int(c) for (c,) in cur.fetchall()}
    r = {"tipos": []}
    for prefixo, tipo, titulo in CASOS:
        arq = descobrir_planilha_mais_recente(PASTA, prefixo)
        m = re.search(r"(\d{4}-\d{2}-\d{2})", arq.name)
        dt_arq = datetime.strptime(m.group(1), "%Y-%m-%d").date() if m else None
        d = pd.read_excel(arq)
        d["cod"] = pd.to_numeric(d["cod_itens_duplicata"], errors="coerce").astype("Int64")
        d["abre"] = pd.to_numeric(d["pago"], errors="coerce") == 0
        d["empresa"] = d["nm_empresa"].astype(str).str.strip().str.upper().replace(NORMAL_EMPRESA)
        t = {"titulo": titulo, "arquivo": arq.name, "data_arquivo": dt_arq, "linhas": len(d), "problemas": []}
        t["abertas_pl"] = (int(d.abre.sum()), round(float(d.loc[d.abre, "vl_parcela"].sum()), 2))
        t["pl_emp"] = {k: (int(len(g)), round(float(g.vl_parcela.sum()), 2)) for k, g in d[d.abre].groupby("empresa")}
        if dt_arq != hoje:
            t["problemas"].append(f"a planilha é de {dt_arq:%d/%m/%Y}, não de hoje ({hoje:%d/%m/%Y})")

        cur.execute(
            """SELECT t.cod_itens_duplicata, t.status_pago, t.vl_parcela, t.vl_pago, t.dt_vencimento, t.dt_emissao, t.dt_pagamento, n.empresa_id::text, n.contato_id IS NOT NULL OR n.nome_pessoa IS NOT NULL,
                      n.plano_contas_id IS NOT NULL, t.conta_id IS NOT NULL, n.cod_venda, n.projeto_id IS NOT NULL
                 FROM public.transacoes t JOIN public.negociacoes n ON n.id = t.negociacao_id WHERE t.tipo::text = %s AND t.cod_itens_duplicata IS NOT NULL""", (tipo,))
        db = pd.DataFrame(cur.fetchall(), columns=["cod", "st", "vl", "pago_db", "venc", "emis", "pgto", "emp", "tem_pessoa", "tem_plano", "tem_conta", "venda", "tem_proj"])
        db["cod"] = db["cod"].astype("Int64")
        # abertas no sistema por empresa
        ab = db[db.st == 0].copy()
        ab["empresa"] = ab["emp"].map(emp).fillna("(sem empresa)")
        t["abertas_db"] = (int(len(ab)), round(float(ab.vl.astype(float).sum()), 2))
        t["db_emp"] = {k: (int(len(g)), round(float(g.vl.astype(float).sum()), 2)) for k, g in ab.groupby("empresa")}
        total_ok = t["abertas_pl"][0] == t["abertas_db"][0] and abs(t["abertas_pl"][1] - t["abertas_db"][1]) < 0.01
        emp_ok = all(t["pl_emp"].get(k, (0, 0))[0] == t["db_emp"].get(k, (0, 0))[0] and abs(t["pl_emp"].get(k, (0, 0))[1] - t["db_emp"].get(k, (0, 0))[1]) < 0.01
                     for k in set(t["pl_emp"]) | set(t["db_emp"]))
        t["total_ok"], t["empresa_ok"] = total_ok, emp_ok
        if not total_ok:
            t["problemas"].append(f"EM ABERTO não fecha no total: planilha {t['abertas_pl'][0]} · {brl(t['abertas_pl'][1])} × sistema {t['abertas_db'][0]} · {brl(t['abertas_db'][1])}")
        elif not emp_ok:
            t["problemas"].append("EM ABERTO fecha no total mas NÃO por empresa")

        # linhas ausentes e campos críticos
        ausentes = d[~d["cod"].isin(set(db["cod"].dropna()))]
        t["ausentes"] = len(ausentes)
        if len(ausentes):
            t["problemas"].append(f"{len(ausentes)} linha(s) da planilha ausentes do sistema")
        mm = d.merge(db, on="cod", how="inner")
        mm["_p"] = (mm["st"] == pd.to_numeric(mm["pago"], errors="coerce")).astype(int) * 2 + ((mm["vl"].astype(float) - pd.to_numeric(mm["vl_parcela"], errors="coerce")).abs() < 0.01).astype(int)
        mm = mm.sort_values(["cod", "_p"], ascending=[True, False]).drop_duplicates("cod")
        dif = {
            "status": int((pd.to_numeric(mm["pago"], errors="coerce") != mm["st"]).sum()),
            "valor da parcela": int(((pd.to_numeric(mm["vl_parcela"], errors="coerce").fillna(0) - mm["vl"].astype(float).fillna(0)).abs() > 0.01).sum()),
            "valor pago": int(((pd.to_numeric(mm["vl_pago"], errors="coerce").fillna(0) - mm["pago_db"].astype(float).fillna(0)).abs() > 0.01).sum()),
            "vencimento": int(sum(dia(a) != b for a, b in zip(mm["dt_vencimento"], mm["venc"]))),
            "emissão": int(sum(dia(a) != b for a, b in zip(mm["dt_emissao"], mm["emis"]))),
            "pagamento": int(sum(dia(a) != (b.date() if hasattr(b, "date") else b) for a, b in zip(mm["dt_pagamento"], mm["pgto"]))),
        }
        t["dif_campos"] = dif
        for k, v in dif.items():
            if v:
                t["problemas"].append(f"{v} linha(s) com {k} diferente da planilha")

        # espelho
        cur.execute("SELECT count(*), coalesce(sum(vl_parcela),0), count(*) FILTER (WHERE pago = 0), coalesce(sum(vl_parcela) FILTER (WHERE pago = 0),0) FROM public.connect_contas_espelho WHERE tipo = %s", (tipo,))
        e = cur.fetchone()
        esp_ok = int(e[0]) == len(d) and abs(float(e[1]) - float(pd.to_numeric(d.vl_parcela).sum())) < 0.01 and int(e[2]) == t["abertas_pl"][0]
        t["espelho"] = (int(e[0]), round(float(e[1]), 2), esp_ok)
        if not esp_ok:
            t["problemas"].append(f"o espelho no Supabase ({e[0]} linhas) NÃO é igual à planilha ({len(d)} linhas): rode a carga do espelho")

        # cobertura nas linhas EM ABERTO e pendências
        a = db[db.st == 0]
        n_ab = max(len(a), 1)
        t["cobertura"] = {"pessoa": int(a.tem_pessoa.sum()), "plano de contas": int(a.tem_plano.sum()), "conta bancária": int(a.tem_conta.sum()), "n": int(len(a))}
        if tipo == "receita":
            t["cobertura"]["projeto"] = int(a.tem_proj.sum())
            t["cobertura"]["venda"] = int((a.venda.fillna(0) > 0).sum())
        ab_pl = d[d.abre]
        cp = pd.to_numeric(ab_pl["cod_apropriacao"], errors="coerce")
        sem_plano = ab_pl[cp.notna() & ~cp.astype("Int64").isin(planos)]
        t["pendencias"] = {
            "abertas sem conta no plano de contas": len(sem_plano),
            "abertas com vencimento antes da emissão (dado da Connect)": int((pd.to_datetime(ab_pl.dt_vencimento, dayfirst=True, errors="coerce") < pd.to_datetime(ab_pl.dt_emissao, dayfirst=True, errors="coerce")).sum()),
            "abertas de pessoa sem nome na planilha": int(ab_pl["nome_pessoa"].isna().sum()),
        }
        r["tipos"].append(t)
    cur.execute("SELECT count(*) FROM public.contatos WHERE observacoes LIKE 'PRÉ-CADASTRO criado ao corrigir%%' AND created_at::date = %s", (hoje,))
    r["precadastros_hoje"] = cur.fetchone()[0]
    cur.execute("SELECT count(*) FROM public.contatos WHERE observacoes LIKE 'PRÉ-CADASTRO criado ao corrigir%%'")
    r["precadastros_total"] = cur.fetchone()[0]
    return r


def relatorio(r: dict, cadeia: list[dict], hoje: date) -> tuple[str, bool]:
    problemas = [f"{t['titulo']}: {p}" for t in r["tipos"] for p in t["problemas"]]
    falhou = any(not c["ok"] for c in cadeia)
    bate = not problemas and not falhou
    L = [f"# Conferência diária do financeiro — {hoje:%d/%m/%Y} ({datetime.now():%H:%M})", ""]
    L.append(f"## VEREDITO: {'✅ BATE' if bate else '❌ NÃO BATE'}")
    if cadeia:
        L += ["", "**Carga de hoje:** " + " → ".join(f"{'✅' if c['ok'] else '❌'} {c['passo']}" for c in cadeia)]
    if not bate:
        L += ["", "**O que não bate (precisa de decisão ou de nova carga):**"] + [f"- {p}" for p in problemas]
        if falhou:
            L.append("- a carga falhou em algum passo (ver acima)")
    for t in r["tipos"]:
        L += ["", f"### {t['titulo']} — {t['arquivo']} ({t['linhas']} linhas)",
              f"- **Em aberto:** planilha {t['abertas_pl'][0]} · {brl(t['abertas_pl'][1])} | sistema {t['abertas_db'][0]} · {brl(t['abertas_db'][1])} → **{'FECHA' if t['total_ok'] else 'NÃO FECHA'}**"]
        for k in sorted(set(t["pl_emp"]) | set(t["db_emp"])):
            a, b = t["pl_emp"].get(k, (0, 0)), t["db_emp"].get(k, (0, 0))
            L.append(f"  - {k}: planilha {a[0]} · {brl(a[1])} | sistema {b[0]} · {brl(b[1])} {'✓' if a == b or (a[0] == b[0] and abs(a[1] - b[1]) < 0.01) else '✗'}")
        L.append(f"- **Linhas da planilha ausentes do sistema:** {t['ausentes']}")
        L.append("- **Diferenças campo a campo (status, valor, valor pago, emissão, vencimento, pagamento):** " + ", ".join(f"{k} {v}" for k, v in t["dif_campos"].items()))
        L.append(f"- **Espelho no Supabase:** {t['espelho'][0]} linhas · {brl(t['espelho'][1])} → {'igual à planilha' if t['espelho'][2] else 'DIFERENTE da planilha'}")
        c = t["cobertura"]
        L.append(f"- **Ligações das {c['n']} linhas em aberto:** " + ", ".join(f"{k} {v}/{c['n']}" for k, v in c.items() if k != "n"))
        L.append("- **Pendências conhecidas:** " + "; ".join(f"{k}: {v}" for k, v in t["pendencias"].items()))
    L += ["", f"**Pré-cadastros de pessoas:** {r['precadastros_hoje']} criados hoje; {r['precadastros_total']} no total — a equipe precisa completar CPF/CNPJ, contato e endereço."]
    return "\n".join(L), bate


def main() -> None:
    ap = argparse.ArgumentParser()
    g = ap.add_mutually_exclusive_group()
    g.add_argument("--ensaio", action="store_true")
    g.add_argument("--carregar", action="store_true")
    args = ap.parse_args()
    hoje = date.today()
    cadeia: list[dict] = []
    if args.ensaio or args.carregar:
        from sync_connect_common import exigir_financeiro_aberto  # SPEC-246
        exigir_financeiro_aberto('A cadeia de carga da planilha')
        cadeia = rodar_cadeia("carregar" if args.carregar else "ensaio")
        if any(not c["ok"] for c in cadeia):
            print("\nA carga falhou: confira o relatório abaixo antes de qualquer decisão.")
    con = psycopg2.connect(para_pooler(SUPABASE_DB_URL), connect_timeout=30)
    try:
        r = conferir(con.cursor(), hoje)
    finally:
        con.close()
    texto, bate = relatorio(r, cadeia, hoje)
    saida = ROOT / "scripts" / "logs" / "conferencia_financeiro"
    saida.mkdir(parents=True, exist_ok=True)
    arq = saida / f"relatorio_diario_{datetime.now():%Y%m%d_%H%M%S}.md"
    arq.write_text(texto, encoding="utf-8")
    print("\n" + "=" * 100 + "\n" + texto + "\n" + "=" * 100)
    print(f"Relatório salvo em: {arq}")
    sys.exit(2 if any(not c["ok"] for c in cadeia) else (0 if bate else 1))


if __name__ == "__main__":
    main()
