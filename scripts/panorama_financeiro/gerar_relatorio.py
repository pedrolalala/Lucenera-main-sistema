"""
Gera o relatorio "Panorama Financeiro Lucenera" (HTML + opcionalmente PDF)
a partir do banco Supabase real. Pensado para rodar tanto localmente quanto
em CI (GitHub Actions, toda sexta-feira) sem intervencao humana.

IMPORTANTE: o texto descritivo aqui e gerado por template (algumas frases
fixas com os numeros calculados encaixados, e uns poucos pontos de decisao
condicional - ex.: qual empresa tem a melhor margem, qual semana da previsao
e a pior). Nao e uma analise nova escrita a cada rodada como a primeira
versao (feita a mao em 2026-08-17) - e o trade-off aceito pelo usuario pra
poder automatizar 100% via GitHub Actions, sem depender de um agente de IA
no loop. Ver memoria do projeto "project_panorama_financeiro_pipeline" pro
historico completo.

Envio de e-mail (opcional, --email-to): reusa o mesmo provedor ja usado nas
Edge Functions do projeto (Resend, ver supabase/functions/welcome-email) -
nao introduz um provedor novo. Precisa de RESEND_API_KEY no ambiente. O
corpo do e-mail e um resumo estatico (sem os graficos em canvas/JS, que nao
rodam em cliente de e-mail); o HTML interativo completo e o PDF vao como
anexo.

Uso:
  python scripts/panorama_financeiro/gerar_relatorio.py --out-html out.html
  python scripts/panorama_financeiro/gerar_relatorio.py --out-html out.html --pdf out.pdf --chrome "/path/to/chrome"
  python scripts/panorama_financeiro/gerar_relatorio.py --out-html out.html --pdf out.pdf --chrome "/path/to/chrome" --email-to pedro@lucenera.com.br
"""

import argparse
import base64
import datetime
import json
import re
import subprocess
import sys
import urllib.request
from pathlib import Path

import psycopg2
import psycopg2.extras

if sys.stdout.encoding and sys.stdout.encoding.lower() != "utf-8":
    sys.stdout.reconfigure(encoding="utf-8")

ROOT = Path(__file__).resolve().parent.parent.parent
TEMPLATE_PATH = Path(__file__).resolve().parent / "template.html"

MOJIBAKE_FIXES = {
    "PR�MIO DE VENDAS": "PRÊMIO DE VENDAS",
    "VENDAS � VISTA": "VENDAS À VISTA",
    "INDUSTRIALIZA��O": "INDUSTRIALIZAÇÃO",
    "IMPORTA��O": "IMPORTAÇÃO",
}

MES_ABR = {1: "jan", 2: "fev", 3: "mar", 4: "abr", 5: "mai", 6: "jun", 7: "jul", 8: "ago", 9: "set", 10: "out", 11: "nov", 12: "dez"}

# empresas.nome nao tem acento no banco (ex.: "FOCO ILUMINACAO") - usado so
# pra exibicao no texto/legendas, nunca pra bater com o banco.
EMPRESA_DISPLAY = {
    "FOCO ILUMINACAO": "Foco Iluminação",
    "ISLIGHT": "Islight",
    "MANOELLA": "Manoella",
}


def empresa_nome(raw):
    return EMPRESA_DISPLAY.get(raw, raw.title())


def fix_mojibake(s):
    return MOJIBAKE_FIXES.get(s, s)


def num(x):
    return float(x) if x is not None else 0.0


def brl(v, decimals=0):
    s = f"{abs(v):,.{decimals}f}".replace(",", "§").replace(".", ",").replace("§", ".")
    sign = "− " if v < 0 else ""
    return f"{sign}R$ {s}"


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


def run_queries():
    conn = psycopg2.connect(get_db_url())
    conn.set_client_encoding("UTF8")
    cur = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
    out = {}

    cur.execute("""
        select to_char(date_trunc('month', t.dt_pagamento), 'YYYY-MM') as mes, t.tipo, sum(t.vl_pago) as total
        from transacoes t
        where t.status_pago = 1 and t.dt_pagamento is not null
          and t.dt_pagamento >= (current_date - interval '13 months')
        group by 1, 2 order by 1
    """)
    out["fluxo_mensal_realizado"] = cur.fetchall()

    # "nao pago" = status_pago != 1 (0 = pendente normal, 2 = "Duplicata Gerada"
    # no Connect - sem dt_pagamento/vl_pago, tambem nao pago). NUNCA usar
    # status_pago = 0 isolado - ver achado documentado na memoria do projeto.
    cur.execute("""
        select t.tipo,
               case when t.status_pago = 1 then 'pago'
                    when t.dt_vencimento < current_date then 'vencido'
                    else 'a_vencer' end as situacao,
               count(*) as qtd, sum(t.valor) as total
        from transacoes t
        group by 1, 2 order by 1, 2
    """)
    out["situacao_atual"] = cur.fetchall()

    cur.execute("""
        select e.nome as empresa, t.tipo, sum(t.vl_pago) as total
        from transacoes t
        join negociacoes n on n.id = t.negociacao_id
        join empresas e on e.id = n.empresa_id
        where t.status_pago = 1 and t.dt_pagamento is not null
          and t.dt_pagamento >= (current_date - interval '13 months')
        group by 1, 2 order by 1, 2
    """)
    out["por_empresa"] = cur.fetchall()

    cur.execute("""
        select coalesce(pc.nome, 'Sem categoria') as categoria, t.tipo, sum(t.vl_pago) as total
        from transacoes t
        join negociacoes n on n.id = t.negociacao_id
        left join plano_de_contas pc on pc.id = n.plano_contas_id
        where t.status_pago = 1 and t.dt_pagamento is not null
          and t.dt_pagamento >= (current_date - interval '13 months')
        group by 1, 2 order by total desc limit 24
    """)
    out["top_categorias"] = cur.fetchall()

    cur.execute("select count(*) as qtd, sum(valor_nota) as total from pedido_compra")
    out["pedidos_compra_resumo"] = cur.fetchall()

    cur.execute("""
        select nome_fornecedor, count(*) as qtd, sum(valor_nota) as total
        from pedido_compra group by 1 order by total desc limit 10
    """)
    out["pedidos_compra_top_fornecedor"] = cur.fetchall()

    cur.execute("""
        select coalesce(m.nome, 'Sem marca') as marca,
               sum(p.estoque_total) as qtd_estoque,
               sum(p.custo_total * p.estoque_total) as valor_custo,
               sum(p.valor_venda * p.estoque_total) as valor_venda
        from produtos p left join marcas m on m.id = p.marca_id
        where p.ativo = true
        group by 1 order by valor_custo desc nulls last limit 15
    """)
    out["estoque_por_marca"] = cur.fetchall()

    cur.execute("""
        select sum(p.estoque_total) as qtd_total,
               sum(p.custo_total * p.estoque_total) as valor_custo_total,
               sum(p.valor_venda * p.estoque_total) as valor_venda_total,
               count(*) filter (where p.ativo) as produtos_ativos
        from produtos p
    """)
    out["estoque_resumo"] = cur.fetchall()

    cur.execute("""
        select to_char(date_trunc('week', t.dt_vencimento), 'YYYY-MM-DD') as semana, t.tipo, sum(t.valor) as total
        from transacoes t
        where t.status_pago != 1
          and t.dt_vencimento between current_date and (current_date + interval '60 days')
        group by 1, 2 order by 1
    """)
    out["previsao_60_dias"] = cur.fetchall()

    cur.execute("""
        select t.tipo,
               case when current_date - t.dt_vencimento <= 30 then '1_ate_30d'
                    when current_date - t.dt_vencimento <= 90 then '2_31_90d'
                    when current_date - t.dt_vencimento <= 365 then '3_91_365d'
                    else '4_mais_365d' end as faixa,
               count(*) as qtd, sum(t.valor) as total
        from transacoes t
        where t.status_pago != 1 and t.dt_vencimento < current_date
        group by 1, 2 order by 1, 2
    """)
    out["aging_vencidos"] = cur.fetchall()

    cur.execute("select count(*) as n from transacoes")
    out["total_transacoes"] = cur.fetchone()["n"]
    cur.execute("select count(*) as n from negociacoes")
    out["total_negociacoes"] = cur.fetchone()["n"]

    cur.close()
    conn.close()
    return out


def compute(data, hoje):
    meses = {}
    for r in data["fluxo_mensal_realizado"]:
        meses.setdefault(r["mes"], {"receita": 0.0, "despesa": 0.0})
        meses[r["mes"]][r["tipo"]] = num(r["total"])
    meses_ordenados = sorted(meses.keys())
    fluxo, acumulado = [], 0.0
    for mes in meses_ordenados:
        receita, despesa = meses[mes]["receita"], meses[mes]["despesa"]
        saldo = receita - despesa
        acumulado += saldo
        fluxo.append({"mes": mes, "receita": round(receita, 2), "despesa": round(despesa, 2), "saldo": round(saldo, 2), "acumulado": round(acumulado, 2)})

    hoje_mes = hoje.strftime("%Y-%m")
    meses_completos = [f for f in fluxo if f["mes"] != hoje_mes]
    mes_parcial = next((f for f in fluxo if f["mes"] == hoje_mes), None)
    total_receita = sum(f["receita"] for f in meses_completos)
    total_despesa = sum(f["despesa"] for f in meses_completos)
    saldo_13m = total_receita - total_despesa
    media_saldo = saldo_13m / len(meses_completos) if meses_completos else 0
    meses_positivos = sum(1 for f in meses_completos if f["saldo"] > 0)
    melhor_mes = max(meses_completos, key=lambda f: f["saldo"]) if meses_completos else None

    sit = {}
    for r in data["situacao_atual"]:
        sit.setdefault(r["tipo"], {})[r["situacao"]] = {"qtd": r["qtd"], "total": num(r["total"])}
    for tipo in ("receita", "despesa"):
        sit.setdefault(tipo, {})
        for k in ("pago", "a_vencer", "vencido"):
            sit[tipo].setdefault(k, {"qtd": 0, "total": 0.0})

    receber_aberto = sit["receita"]["a_vencer"]["total"] + sit["receita"]["vencido"]["total"]
    pagar_aberto = sit["despesa"]["a_vencer"]["total"] + sit["despesa"]["vencido"]["total"]

    aging = {"receita": {}, "despesa": {}}
    for r in data["aging_vencidos"]:
        aging[r["tipo"]][r["faixa"]] = {"qtd": r["qtd"], "total": num(r["total"])}
    for tipo in ("receita", "despesa"):
        for f in ("1_ate_30d", "2_31_90d", "3_91_365d", "4_mais_365d"):
            aging[tipo].setdefault(f, {"qtd": 0, "total": 0.0})

    despesa_vencido_total = sit["despesa"]["vencido"]["total"]
    despesa_vencido_antigo = aging["despesa"]["4_mais_365d"]["total"]
    pct_vencido_antigo_despesa = (despesa_vencido_antigo / despesa_vencido_total * 100) if despesa_vencido_total else 0

    empresa = {}
    for r in data["por_empresa"]:
        empresa.setdefault(r["empresa"], {"receita": 0.0, "despesa": 0.0})[r["tipo"]] = num(r["total"])
    por_empresa = [
        {"empresa": k, "receita": round(v["receita"], 2), "despesa": round(v["despesa"], 2), "saldo": round(v["receita"] - v["despesa"], 2),
         "razao": (v["despesa"] / v["receita"] * 100) if v["receita"] else 0}
        for k, v in empresa.items()
    ]
    por_empresa.sort(key=lambda x: x["receita"], reverse=True)
    melhor_empresa = min(por_empresa, key=lambda x: x["razao"]) if por_empresa else None
    outras_saldo = sum(e["saldo"] for e in por_empresa if melhor_empresa and e["empresa"] != melhor_empresa["empresa"])

    top_receita = sorted([{"categoria": fix_mojibake(r["categoria"]), "total": num(r["total"])} for r in data["top_categorias"] if r["tipo"] == "receita"], key=lambda x: x["total"], reverse=True)[:8]
    top_despesa = sorted([{"categoria": fix_mojibake(r["categoria"]), "total": num(r["total"])} for r in data["top_categorias"] if r["tipo"] == "despesa"], key=lambda x: x["total"], reverse=True)[:8]

    prev = {}
    for r in data["previsao_60_dias"]:
        prev.setdefault(r["semana"], {"receita": 0.0, "despesa": 0.0})[r["tipo"]] = num(r["total"])
    previsao = [{"semana": k, "receita": round(v.get("receita", 0), 2), "despesa": round(v.get("despesa", 0), 2), "saldo": round(v.get("receita", 0) - v.get("despesa", 0), 2)} for k, v in sorted(prev.items())]
    semana_pior = min(previsao, key=lambda x: x["saldo"]) if previsao else None
    total_receita_60d = sum(p["receita"] for p in previsao)
    total_despesa_60d = sum(p["despesa"] for p in previsao)

    estoque_marcas = [{"marca": r["marca"], "qtd": num(r["qtd_estoque"]), "valor_custo": round(num(r["valor_custo"]), 2), "valor_venda": round(num(r["valor_venda"]), 2)} for r in data["estoque_por_marca"]]
    er = data["estoque_resumo"][0]
    estoque_resumo = {"qtd_total": num(er["qtd_total"]), "valor_custo_total": round(num(er["valor_custo_total"]), 2), "valor_venda_total": round(num(er["valor_venda_total"]), 2), "produtos_ativos": er["produtos_ativos"]}
    margem_potencial = estoque_resumo["valor_venda_total"] - estoque_resumo["valor_custo_total"]
    top2_marcas_pct = (sum(m["valor_custo"] for m in estoque_marcas[:2]) / estoque_resumo["valor_custo_total"] * 100) if estoque_resumo["valor_custo_total"] else 0

    pcr = data["pedidos_compra_resumo"][0]
    pc_resumo = {"qtd": pcr["qtd"], "total": round(num(pcr["total"]), 2)}
    pc_fornecedores = [{"fornecedor": r["nome_fornecedor"], "qtd": r["qtd"], "total": round(num(r["total"]), 2)} for r in data["pedidos_compra_top_fornecedor"]]
    top2_forn_total = sum(f["total"] for f in pc_fornecedores[:2])
    top2_forn_pct = (top2_forn_total / pc_resumo["total"] * 100) if pc_resumo["total"] else 0

    return {
        "fluxo_mensal": fluxo, "mes_parcial": mes_parcial, "meses_completos": meses_completos,
        "total_receita_13m": total_receita, "total_despesa_13m": total_despesa, "saldo_13m": saldo_13m,
        "media_saldo_mensal": media_saldo, "meses_positivos": meses_positivos, "meses_total": len(meses_completos),
        "melhor_mes": melhor_mes,
        "sit": sit, "receber_aberto": receber_aberto, "pagar_aberto": pagar_aberto,
        "aging": aging, "despesa_vencido_total": despesa_vencido_total, "despesa_vencido_antigo": despesa_vencido_antigo,
        "pct_vencido_antigo_despesa": pct_vencido_antigo_despesa,
        "receita_vencido_total": sit["receita"]["vencido"]["total"],
        "por_empresa": por_empresa, "melhor_empresa": melhor_empresa, "outras_saldo": outras_saldo,
        "top_receita": top_receita, "top_despesa": top_despesa,
        "previsao_60_dias": previsao, "semana_pior": semana_pior,
        "previsao_total_receita": total_receita_60d, "previsao_total_despesa": total_despesa_60d,
        "estoque_marcas": estoque_marcas, "estoque_resumo": estoque_resumo, "margem_potencial": margem_potencial,
        "top2_marcas_pct": top2_marcas_pct,
        "pc_resumo": pc_resumo, "pc_fornecedores": pc_fornecedores, "top2_forn_pct": top2_forn_pct, "top2_forn_total": top2_forn_total,
        "total_transacoes": data["total_transacoes"], "total_negociacoes": data["total_negociacoes"],
    }


def gerar_prosa(c, hoje):
    p = {}

    # 01 fluxo
    if c["saldo_13m"] >= 0:
        titulo_fluxo = f"{c['meses_positivos']} de {c['meses_total']} meses no positivo" if c["meses_positivos"] < c["meses_total"] else f"{c['meses_total']} meses seguidos no positivo"
    else:
        titulo_fluxo = "Saldo do período fechou negativo"
    par1 = (
        f'<p class="prose">Nos últimos {c["meses_total"]} meses fechados, o grupo movimentou '
        f'<span class="fig">{brl(c["total_receita_13m"])}</span> em receitas realizadas contra '
        f'<span class="fig">{brl(c["total_despesa_13m"])}</span> em despesas pagas — um saldo acumulado de '
        f'<span class="fig {"pos" if c["saldo_13m"] >= 0 else "neg"}">{brl(c["saldo_13m"])}</span>, '
        f'média de <span class="fig {"pos" if c["media_saldo_mensal"] >= 0 else "neg"}">{"+" if c["media_saldo_mensal"] >= 0 else ""}{brl(c["media_saldo_mensal"])}</span> por mês. '
        f'{c["meses_positivos"]} dos {c["meses_total"]} meses fecharam com saldo positivo'
        + (f'; o melhor foi {MES_ABR[int(c["melhor_mes"]["mes"].split("-")[1])]}/{c["melhor_mes"]["mes"].split("-")[0]}, com saldo de <span class="fig pos">{brl(c["melhor_mes"]["saldo"])}</span>.' if c["melhor_mes"] else ".")
        + "</p>"
    )
    par2 = ""
    if c["mes_parcial"]:
        par2 = (
            f'<p class="prose">O mês corrente ({MES_ABR[hoje.month]}/{hoje.year}) aparece incompleto no gráfico (dado até dia {hoje.day}) — '
            f'despesas como aluguel e folha tendem a se concentrar no início do mês, então o saldo parcial mostrado '
            f'(<span class="fig {"pos" if c["mes_parcial"]["saldo"] >= 0 else "neg"}">{brl(c["mes_parcial"]["saldo"])}</span>) '
            f"não deve ser lido como tendência fechada.</p>"
        )
    p["fluxo"] = (titulo_fluxo, par1 + par2)

    # 02 aberto
    saldo_aberto = c["receber_aberto"] - c["pagar_aberto"]
    titulo_aberto = "A pagar supera a receber" if saldo_aberto < 0 else "A receber supera a pagar"
    titulo_aberto += f", {c['pct_vencido_antigo_despesa']:.0f}% do atraso é herança antiga" if c["pct_vencido_antigo_despesa"] >= 40 else ""
    par1 = (
        f'<p class="prose">Em valores absolutos, há <span class="fig">{brl(c["pagar_aberto"])}</span> a pagar em aberto contra '
        f'<span class="fig">{brl(c["receber_aberto"])}</span> a receber — diferença de '
        f'<span class="fig {"neg" if saldo_aberto < 0 else "pos"}">{brl(saldo_aberto)}</span>. '
    )
    if c["pct_vencido_antigo_despesa"] >= 30:
        par1 += (
            f'Olhando o detalhe do "vencido": dos <span class="fig">{brl(c["despesa_vencido_total"])}</span> em despesas vencidas, '
            f'<span class="fig neg">{brl(c["despesa_vencido_antigo"])} ({c["pct_vencido_antigo_despesa"]:.0f}%)</span> têm mais de 365 dias de atraso — '
            f"passivo antigo, que vale reconciliar separado da pressão de caixa do trimestre atual."
        )
    else:
        par1 += "A maior parte do valor vencido é recente, o que pede atenção mais direta no curto prazo."
    par1 += "</p>"
    p["aberto"] = (titulo_aberto, par1)

    # 03 empresa
    if c["melhor_empresa"]:
        me = c["melhor_empresa"]
        titulo_empresa = f'{empresa_nome(me["empresa"])} tem a margem mais larga do grupo'
        maior_receita = c["por_empresa"][0]
        par = (
            f'<p class="prose">{empresa_nome(maior_receita["empresa"])} é a maior operação em volume '
            f'(<span class="fig">{brl(maior_receita["receita"])}</span> em receita realizada). '
            f'Em proporção, {empresa_nome(me["empresa"])} converte mais receita em saldo: suas despesas somam '
            f'<span class="fig">{me["razao"]:.0f}%</span> da receita, resultando em saldo de '
            f'<span class="fig pos">{brl(me["saldo"])}</span>'
            + (f', mais do que as outras empresas somadas (<span class="fig pos">{brl(c["outras_saldo"])}</span>).' if c["outras_saldo"] < me["saldo"] else ".")
            + "</p>"
        )
    else:
        titulo_empresa = "Desempenho por empresa"
        par = '<p class="prose">Sem dados suficientes no período para comparar empresas.</p>'
    p["empresa"] = (titulo_empresa, par)

    # 04 categorias
    if c["top_receita"] and c["top_despesa"]:
        titulo_cat = f'{c["top_receita"][0]["categoria"].title()} e {c["top_despesa"][0]["categoria"].title()} concentram o movimento'
        par = (
            f'<p class="prose">"{c["top_receita"][0]["categoria"].title()}" é a maior fonte de receita '
            f'(<span class="fig">{brl(c["top_receita"][0]["total"])}</span>), e "{c["top_despesa"][0]["categoria"].title()}" é o maior custo '
            f'(<span class="fig">{brl(c["top_despesa"][0]["total"])}</span>).</p>'
        )
    else:
        titulo_cat = "Centros de receita e custo"
        par = '<p class="prose">Sem dados suficientes no período.</p>'
    p["categorias"] = (titulo_cat, par)

    # 05 previsao
    saldo_prev = c["previsao_total_receita"] - c["previsao_total_despesa"]
    titulo_prev = "Próximas 8 semanas pedem atenção" if saldo_prev < 0 else "Próximas 8 semanas com saldo previsto positivo"
    par = (
        f'<p class="prose">Somando os títulos já lançados com vencimento nos próximos 60 dias, a previsão é de '
        f'<span class="fig">{brl(c["previsao_total_receita"])}</span> a receber contra '
        f'<span class="fig">{brl(c["previsao_total_despesa"])}</span> a pagar — saldo previsto de '
        f'<span class="fig {"neg" if saldo_prev < 0 else "pos"}">{brl(saldo_prev)}</span>.'
    )
    if c["semana_pior"] and c["semana_pior"]["saldo"] < 0:
        sp = c["semana_pior"]
        d = sp["semana"].split("-")
        par += (
            f' A semana mais crítica do período é a de <span class="fig">{d[2]}/{d[1]}</span>, com déficit previsto de '
            f'<span class="fig neg">{brl(abs(sp["saldo"]))}</span> — vale confirmar cobertura de caixa com antecedência.'
        )
    par += "</p>"
    p["previsao"] = (titulo_prev, par)

    # 06 estoque
    er, mp = c["estoque_resumo"], c["margem_potencial"]
    titulo_est = f'{brl(er["valor_custo_total"])} em estoque, com margem potencial de {brl(mp)}'
    par = (
        f'<p class="prose">O catálogo ativo tem <span class="fig">{er["produtos_ativos"]:,}</span>'.replace(",", ".")
        + f' produtos, somando <span class="fig">{er["qtd_total"]:,.0f}</span>'.replace(",", ".")
        + f' unidades em estoque. Ao custo, isso representa <span class="fig">{brl(er["valor_custo_total"])}</span> imobilizados; '
        f'ao preço de venda cadastrado, o mesmo estoque valeria <span class="fig">{brl(er["valor_venda_total"])}</span> — margem potencial de '
        f'<span class="fig pos">{brl(mp)}</span>.'
    )
    if c["estoque_marcas"] and c["top2_marcas_pct"] >= 30:
        par += f' {c["estoque_marcas"][0]["marca"].title()} e {c["estoque_marcas"][1]["marca"].title()} respondem por <span class="fig">{c["top2_marcas_pct"]:.0f}%</span> do valor de custo em estoque.'
    par += "</p>"
    p["estoque"] = (titulo_est, par)

    # 07 compras
    pcr, pcf = c["pc_resumo"], c["pc_fornecedores"]
    if pcf:
        titulo_compras = f'{pcf[0]["fornecedor"].title()} concentra o maior volume' if len(pcf) < 2 else f'{pcf[0]["fornecedor"].title()} e {pcf[1]["fornecedor"].title()} concentram o volume'
        par = (
            f'<p class="prose">Há <span class="fig">{pcr["qtd"]}</span> pedidos de compra registrados, somando '
            f'<span class="fig">{brl(pcr["total"])}</span>.'
        )
        if len(pcf) >= 2:
            par += (
                f' Os dois maiores fornecedores — {pcf[0]["fornecedor"].title()} e {pcf[1]["fornecedor"].title()} — respondem juntos por '
                f'<span class="fig">{brl(c["top2_forn_total"])}</span>, {c["top2_forn_pct"]:.0f}% do total pedido.'
            )
        par += "</p>"
    else:
        titulo_compras = "Pedidos de compra"
        par = '<p class="prose">Sem pedidos de compra registrados no período.</p>'
    p["compras"] = (titulo_compras, par)

    return p


def gerar_sintese(c):
    itens = []
    if c["meses_positivos"] == c["meses_total"] and c["meses_total"] > 0:
        itens.append(f'<li><strong>Operação saudável:</strong> {c["meses_total"]} de {c["meses_total"]} meses fechados no positivo, saldo médio de {"+" if c["media_saldo_mensal"]>=0 else ""}{brl(c["media_saldo_mensal"])}/mês.</li>')
    elif c["meses_positivos"] < c["meses_total"]:
        itens.append(f'<li><strong>Atenção ao fluxo de caixa:</strong> só {c["meses_positivos"]} de {c["meses_total"]} meses fecharam no positivo — vale investigar os meses negativos.</li>')

    if c["pct_vencido_antigo_despesa"] >= 40:
        itens.append(f'<li><strong>Backlog de despesas vencidas antigo precisa de triagem:</strong> {brl(c["despesa_vencido_antigo"])} ({c["pct_vencido_antigo_despesa"]:.0f}% do total vencido) tem mais de um ano de atraso — vale reconciliar título a título antes de tratar como pressão de caixa atual.</li>')

    if c["semana_pior"] and c["semana_pior"]["saldo"] < -100000:
        d = c["semana_pior"]["semana"].split("-")
        itens.append(f'<li><strong>Semana de atenção no curto prazo:</strong> {d[2]}/{d[1]} concentra despesa prevista bem acima da receita lançada — vale confirmar cobertura de caixa com antecedência.</li>')

    if c["melhor_empresa"]:
        itens.append(f'<li><strong>{empresa_nome(c["melhor_empresa"]["empresa"])} é a operação mais eficiente:</strong> converte receita em saldo a uma taxa maior que as demais — vale entender o que está funcionando lá e se é replicável.</li>')

    if c["margem_potencial"] > 0:
        itens.append(f'<li><strong>Estoque com margem em aberto:</strong> {brl(c["margem_potencial"])} de margem potencial parado em estoque.</li>')

    return "\n".join(itens)


def fmt_periodo(fluxo):
    if not fluxo:
        return ""
    ini, fim = fluxo[0]["mes"], fluxo[-1]["mes"]
    ini_y, ini_m = ini.split("-")
    fim_y, fim_m = fim.split("-")
    return f"{MES_ABR[int(ini_m)]}/{ini_y} — {MES_ABR[int(fim_m)]}/{fim_y}"


def build_html(c, p, sintese, hoje):
    tpl = TEMPLATE_PATH.read_text(encoding="utf-8")

    sit = c["sit"]
    r_pago, r_av, r_v = sit["receita"]["pago"]["total"], sit["receita"]["a_vencer"]["total"], sit["receita"]["vencido"]["total"]
    d_pago, d_av, d_v = sit["despesa"]["pago"]["total"], sit["despesa"]["a_vencer"]["total"], sit["despesa"]["vencido"]["total"]
    r_tot, d_tot = (r_pago + r_av + r_v) or 1, (d_pago + d_av + d_v) or 1

    aging_d = c["aging"]["despesa"]

    replacements = {
        "@@PERIODO_TEXTO@@": fmt_periodo(c["fluxo_mensal"]),
        "@@GERADO_EM@@": hoje.strftime("%d/%m/%Y"),
        "@@MESES_TOTAL@@": str(c["meses_total"]),
        "@@MESES_POSITIVOS@@": str(c["meses_positivos"]),
        "@@KPI_SALDO_CLASS@@": "pos" if c["saldo_13m"] >= 0 else "neg",
        "@@KPI_SALDO_13M@@": brl(c["saldo_13m"]),
        "@@KPI_ABERTO_CLASS@@": "pos" if (c["receber_aberto"] - c["pagar_aberto"]) >= 0 else "neg",
        "@@KPI_SALDO_ABERTO@@": brl(c["receber_aberto"] - c["pagar_aberto"]),
        "@@KPI_RECEBER_ABERTO@@": brl(c["receber_aberto"] / 1_000_000, 2) + "M",
        "@@KPI_PAGAR_ABERTO@@": brl(c["pagar_aberto"] / 1_000_000, 2) + "M",
        "@@KPI_DESPESA_VENCIDA@@": brl(c["despesa_vencido_total"]),
        "@@PCT_VENCIDO_ANTIGO@@": f'{c["pct_vencido_antigo_despesa"]:.0f}',
        "@@KPI_ESTOQUE_CUSTO@@": brl(c["estoque_resumo"]["valor_custo_total"]),
        "@@KPI_ESTOQUE_VENDA@@": brl(c["estoque_resumo"]["valor_venda_total"] / 1_000_000, 2) + "M",
        "@@TITULO_FLUXO@@": p["fluxo"][0],
        "@@PROSE_FLUXO@@": p["fluxo"][1],
        "@@TITULO_ABERTO@@": p["aberto"][0],
        "@@PROSE_ABERTO@@": p["aberto"][1],
        "@@RECEITA_DUPLICATAS_TOTAL@@": brl(r_tot),
        "@@DESPESA_DUPLICATAS_TOTAL@@": brl(d_tot),
        "@@PCT_RECEITA_PAGO@@": f"{r_pago/r_tot*100:.1f}",
        "@@PCT_RECEITA_AVENCER@@": f"{r_av/r_tot*100:.1f}",
        "@@PCT_RECEITA_VENCIDO@@": f"{r_v/r_tot*100:.1f}",
        "@@PCT_DESPESA_PAGO@@": f"{d_pago/d_tot*100:.1f}",
        "@@PCT_DESPESA_AVENCER@@": f"{d_av/d_tot*100:.1f}",
        "@@PCT_DESPESA_VENCIDO@@": f"{d_v/d_tot*100:.1f}",
        "@@AGING_30@@": brl(aging_d["1_ate_30d"]["total"]),
        "@@AGING_30_QTD@@": str(aging_d["1_ate_30d"]["qtd"]),
        "@@AGING_90@@": brl(aging_d["2_31_90d"]["total"]),
        "@@AGING_90_QTD@@": str(aging_d["2_31_90d"]["qtd"]),
        "@@AGING_365@@": brl(aging_d["3_91_365d"]["total"]),
        "@@AGING_365_QTD@@": str(aging_d["3_91_365d"]["qtd"]),
        "@@AGING_MAIS@@": brl(aging_d["4_mais_365d"]["total"]),
        "@@AGING_MAIS_QTD@@": str(aging_d["4_mais_365d"]["qtd"]),
        "@@TITULO_EMPRESA@@": p["empresa"][0],
        "@@PROSE_EMPRESA@@": p["empresa"][1],
        "@@TITULO_CATEGORIAS@@": p["categorias"][0],
        "@@PROSE_CATEGORIAS@@": p["categorias"][1],
        "@@TITULO_PREVISAO@@": p["previsao"][0],
        "@@PROSE_PREVISAO@@": p["previsao"][1],
        "@@TITULO_ESTOQUE@@": p["estoque"][0],
        "@@PROSE_ESTOQUE@@": p["estoque"][1],
        "@@TITULO_COMPRAS@@": p["compras"][0],
        "@@PROSE_COMPRAS@@": p["compras"][1],
        "@@SINTESE_ITENS@@": sintese,
        "@@TOTAL_TRANSACOES@@": f'{c["total_transacoes"]:,}'.replace(",", "."),
        "@@TOTAL_NEGOCIACOES@@": f'{c["total_negociacoes"]:,}'.replace(",", "."),
    }

    for k, v in replacements.items():
        tpl = tpl.replace(k, v)

    data_json = {
        "fluxo_mensal": c["fluxo_mensal"],
        "mes_parcial": c["mes_parcial"],
        "por_empresa": c["por_empresa"],
        "top_receita": c["top_receita"],
        "top_despesa": c["top_despesa"],
        "previsao_60_dias": c["previsao_60_dias"],
        "estoque_marcas": c["estoque_marcas"],
        "pedidos_compra_fornecedores": c["pc_fornecedores"],
    }
    tpl = tpl.replace("__DATA_JSON__", json.dumps(data_json, ensure_ascii=False))
    return tpl


def export_pdf(html_path: Path, pdf_path: Path, chrome_path: str, profile_dir: Path):
    profile_dir.mkdir(parents=True, exist_ok=True)
    pdf_path = pdf_path.resolve()
    profile_dir = profile_dir.resolve()
    cmd = [
        chrome_path,
        "--headless", "--disable-gpu", "--no-sandbox",
        # /dev/shm costuma ser minusculo em runners de CI (GitHub Actions,
        # Docker) - sem essa flag o Chrome trava/crasha silenciosamente
        # renderizando paginas com canvas, em vez de dar erro claro.
        "--disable-dev-shm-usage",
        "--disable-background-networking",
        "--disable-sync",
        "--disable-default-apps",
        "--disable-extensions",
        "--disable-breakpad",
        "--disable-client-side-phishing-detection",
        "--disable-component-update",
        "--disable-hang-monitor",
        "--disable-ipc-flooding-protection",
        "--disable-popup-blocking",
        "--disable-prompt-on-repost",
        "--disable-renderer-backgrounding",
        "--metrics-recording-only",
        "--no-first-run",
        "--enable-automation",
        "--password-store=basic",
        "--use-mock-keychain",
        # --headless (mesmo o "antigo") em versoes recentes de Chrome ficou
        # preso indefinidamente tentando falar com GCM/DBus/NetworkManager
        # que nao existem no container de CI (achado em CI, 2026-08-18,
        # apos --disable-dev-shm-usage sozinho nao ter resolvido). Essas
        # duas flags forcam o Chrome a parar de esperar a pagina "ficar
        # quieta" e renderizar/imprimir logo, em vez de ficar pendurado.
        "--run-all-compositor-stages-before-draw",
        "--virtual-time-budget=15000",
        "--no-pdf-header-footer",
        f"--user-data-dir={profile_dir}",
        f"--print-to-pdf={pdf_path}",
        html_path.resolve().as_uri(),
    ]
    try:
        subprocess.run(cmd, check=True, capture_output=True, timeout=90)
    except subprocess.CalledProcessError as exc:
        print(exc.stdout.decode("utf-8", "replace"))
        print(exc.stderr.decode("utf-8", "replace"))
        raise
    except subprocess.TimeoutExpired as exc:
        if exc.stdout:
            print(exc.stdout.decode("utf-8", "replace"))
        if exc.stderr:
            print(exc.stderr.decode("utf-8", "replace"))
        raise


def build_email_body(c, hoje):
    """Resumo estatico (sem canvas/JS - nao roda em cliente de e-mail).
    O relatorio interativo completo vai em anexo (HTML + PDF)."""
    saldo_aberto = c["receber_aberto"] - c["pagar_aberto"]
    linhas_kpi = [
        ("Saldo realizado (13 meses)", brl(c["saldo_13m"]), c["saldo_13m"] >= 0),
        ("Saldo em aberto (a receber − a pagar)", brl(saldo_aberto), saldo_aberto >= 0),
        ("Despesas vencidas", brl(c["despesa_vencido_total"]), False),
        ("Estoque valorizado (custo)", brl(c["estoque_resumo"]["valor_custo_total"]), None),
    ]
    linhas_html = ""
    for label, valor, positivo in linhas_kpi:
        cor = "#1F7A63" if positivo is True else ("#A63A2C" if positivo is False else "#1B2130")
        linhas_html += (
            f'<tr><td style="padding:10px 0;color:#5B6472;font-size:13px;">{label}</td>'
            f'<td style="padding:10px 0;text-align:right;font-family:monospace;font-weight:600;'
            f'font-size:15px;color:{cor};">{valor}</td></tr>'
        )

    return f"""
    <div style="font-family:-apple-system,'Segoe UI',Roboto,Arial,sans-serif;max-width:520px;margin:0 auto;color:#1B2130;">
      <p style="font-size:11px;text-transform:uppercase;letter-spacing:.08em;color:#7A4F12;font-weight:600;margin:0 0 6px;">
        Relatório interno · Grupo Lucenera
      </p>
      <h1 style="font-size:24px;margin:0 0 4px;">Panorama Financeiro</h1>
      <p style="font-size:13px;color:#5B6472;margin:0 0 20px;">
        Semana de {hoje.strftime('%d/%m/%Y')} · ISLIGHT · FOCO Iluminação · Manoella
      </p>
      <table style="width:100%;border-collapse:collapse;border-top:1px solid #DDE2E8;">
        {linhas_html}
      </table>
      <p style="font-size:13px;color:#5B6472;margin:20px 0 0;">
        Relatório completo com gráficos em anexo — <strong>HTML</strong> (interativo, abra no navegador)
        e <strong>PDF</strong> (pronto pra imprimir/encaminhar).
      </p>
      <p style="font-size:11px;color:#8993A1;margin:24px 0 0;">
        Gerado automaticamente toda sexta-feira. Texto por modelo fixo a partir dos dados —
        conferir com o financeiro antes de decisões críticas.
      </p>
    </div>
    """


def enviar_email(to_email: str, subject: str, body_html: str, attachments: list, resend_api_key: str, from_email: str):
    payload = {
        "from": from_email,
        "to": [to_email],
        "subject": subject,
        "html": body_html,
        "attachments": [
            {"filename": path.name, "content": base64.b64encode(path.read_bytes()).decode("ascii")}
            for path in attachments
        ],
    }
    req = urllib.request.Request(
        "https://api.resend.com/emails",
        data=json.dumps(payload).encode("utf-8"),
        headers={"Content-Type": "application/json", "Authorization": f"Bearer {resend_api_key}"},
        method="POST",
    )
    with urllib.request.urlopen(req, timeout=30) as resp:
        result = json.loads(resp.read().decode("utf-8"))
        print(f"E-mail enviado: {result}")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out-html", required=True)
    ap.add_argument("--pdf")
    ap.add_argument("--chrome", default=None, help="Caminho do executavel Chrome/Chromium (obrigatorio se --pdf for usado)")
    ap.add_argument("--email-to", default=None, help="Envia o relatorio (HTML+PDF anexados) para este endereco. Exige RESEND_API_KEY no ambiente e --pdf.")
    ap.add_argument("--email-from", default="suporte@lucenera.com", help="Remetente (dominio ja verificado no Resend)")
    args = ap.parse_args()

    hoje = datetime.date.today()
    print(f"Gerando Panorama Financeiro para {hoje.isoformat()}...")

    data = run_queries()
    c = compute(data, hoje)
    p = gerar_prosa(c, hoje)
    sintese = gerar_sintese(c)
    html = build_html(c, p, sintese, hoje)

    out_html = Path(args.out_html)
    out_html.parent.mkdir(parents=True, exist_ok=True)
    out_html.write_text(html, encoding="utf-8")
    print(f"HTML gerado: {out_html} ({len(html)} bytes)")

    pdf_path = None
    if args.pdf:
        if not args.chrome:
            raise SystemExit("--pdf exige --chrome <caminho do executavel>")
        pdf_path = Path(args.pdf)
        pdf_path.parent.mkdir(parents=True, exist_ok=True)
        profile_dir = out_html.parent / ".chrome-profile"
        export_pdf(out_html, pdf_path, args.chrome, profile_dir)
        print(f"PDF gerado: {pdf_path}")

    if args.email_to:
        import os

        resend_key = os.environ.get("RESEND_API_KEY")
        if not resend_key:
            raise SystemExit("--email-to exige RESEND_API_KEY no ambiente")
        if not pdf_path:
            raise SystemExit("--email-to exige --pdf (o e-mail vai com HTML e PDF anexados)")

        body = build_email_body(c, hoje)
        subject = f"Panorama Financeiro Lucenera — {hoje.strftime('%d/%m/%Y')}"
        enviar_email(args.email_to, subject, body, [out_html, pdf_path], resend_key, args.email_from)


if __name__ == "__main__":
    main()
