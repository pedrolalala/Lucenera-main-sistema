"""Gera o PDF 'Connect x Sistema - pecas' (so leitura) a partir da planilha de comparacao mais recente + consultas ao banco.
Antes rode: python scripts/comparar_connect_vs_sistema_pecas.py
Uso: python scripts/gerar_pdf_comparacao_pecas.py
"""
from __future__ import annotations

import glob
import html
import subprocess
import sys
import warnings
from datetime import datetime
from pathlib import Path

import pandas as pd
import psycopg2

warnings.filterwarnings("ignore")
if sys.stdout.encoding and sys.stdout.encoding.lower() != "utf-8":
    sys.stdout.reconfigure(encoding="utf-8")
ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "scripts"))
from _supabase_client import SUPABASE_DB_URL, para_pooler  # noqa: E402

OUT = ROOT / "scripts" / "logs" / "comparacao_pecas"
x = pd.read_excel(sorted(glob.glob(str(OUT / "comparacao_*.xlsx")))[-1], sheet_name=None)
c = psycopg2.connect(para_pooler(SUPABASE_DB_URL))
c.set_session(readonly=True)

P = x["Produtos divergentes"]
T = P[P.dif_total.abs() > 0.001].copy()

G = {
    "A": ("A", "Entrada de NF caiu na reserva do sistema, mas na Connect somou no estoque geral", "#0b6e4f"),
    "B": ("B", "Entrada ou ajuste feito só na Connect", "#b45309"),
    "C": ("C", "Separação/entrega feita nos dois sistemas ao mesmo tempo", "#1d4ed8"),
    "D": ("D", "Sem movimento no sistema desde 05/11 — mudou só na Connect", "#6b7280"),
}
nota = {
    9657: ("A", "O sistema recebeu 24 un. de NF e mandou direto para a reserva; a diferença é exatamente 24."),
    10458: ("A", "O sistema recebeu 14 un. para reserva; a diferença é exatamente 14."),
    10992: ("A", "O sistema recebeu 4 un. para reserva; a diferença é exatamente 4."),
    10169: ("A", "5 un. recebidas para reserva explicam parte dos 20; o restante precisa de conferência."),
    11384: ("A", "8 un. recebidas para reserva explicam parte dos 12."),
    12748: ("A", "5 un. recebidas para reserva explicam quase tudo dos 6."),
    13587: ("A", "129 un. recebidas para reserva e 86 canceladas em 11/11; o saldo líquido (43) explica parte dos 60."),
    12395: ("B", "A Connect tem 35 un. a mais no geral e a Entrega Futura de 18 un. virou Reserva (487+18=505). Parece NF lançada só na Connect."),
    12135: ("C", "No sistema, 30 un. foram alocadas à Entrega Futura e houve ajuste de 10/11. O sistema só baixa o geral ao finalizar a entrega; a Connect já baixou 32."),
    8952: ("C", "Aprovações, separações e entregas nos dois sistemas na semana; diferença de 1 un."),
    11150: ("C", "Separações em andamento no sistema; diferença de 2 un."),
    11636: ("C", "Entrega e transferências de 4 un. no sistema em 09/11; a Connect já havia baixado."),
    13270: ("C", "1 un. alocada à reserva e separada no sistema em 10/11."),
    9923: ("C", "Peça ajustada à mão em 09/11 (reunião 44): geral 81. Diferença de 1 un. depois do ajuste."),
    10106: ("C", "Peça ajustada à mão em 09/11 (geral 178). Hoje o sistema tem 174 e a Connect 182; precisa de conferência."),
    7365: ("D", "Nenhum movimento no sistema desde 05/11; a Connect baixou 2 un. (entrega ou ajuste)."),
    12761: ("D", "Nenhum movimento no sistema; a Connect tem 1 un. a mais."),
    13217: ("D", "Nenhum movimento relevante no sistema; diferença de 1 un."),
}


def f(v):
    v = float(v)
    s = f"{v:,.0f}" if abs(v - round(v)) < 0.05 else f"{v:,.1f}"
    return s.replace(",", "X").replace(".", ",").replace("X", ".")


def sg(v):
    return ("+" if v > 0 else "") + f(v)


rows = {k: [] for k in G}
for _, r in T.sort_values("dif_total", key=abs, ascending=False).iterrows():
    g, tx = nota.get(int(r.cod), ("D", "Sem explicação identificada."))
    cls = "neg" if r.dif_total < 0 else "pos"
    rows[g].append(
        f"<tr><td class=n>{int(r.cod)}</td><td>{html.escape(str(r.nome))[:58]}</td><td class=r>{f(r.pl_total)}</td>"
        f"<td class=r>{f(r.sy_total)}</td><td class='r d {cls}'>{sg(r.dif_total)}</td><td class=t>{html.escape(tx)}</td></tr>"
    )
grp_html = ""
for k, (lt, tit, cor) in G.items():
    if rows[k]:
        grp_html += (
            f"<h3><span class=tag style='background:{cor}'>{lt}</span>{tit} <small>({len(rows[k])} peças)</small></h3>"
            "<table><thead><tr><th>Cód.</th><th>Peça</th><th>Connect</th><th>Sistema</th><th>Dif.</th>"
            f"<th>O que provavelmente aconteceu</th></tr></thead><tbody>{''.join(rows[k])}</tbody></table>"
        )


def top(tab, n=8):
    t = x[tab].copy()
    t["tot"] = t.sistema_connect + t.sistema_vendas_novas
    t["d"] = t.tot - t.planilha
    t = t[t.d.abs() > 0.001]
    t["a"] = t.d.abs()
    t = t.sort_values("a", ascending=False).head(n)
    return "".join(
        f"<tr><td class=n>{int(r.produto)}</td><td class=r>{f(r.planilha)}</td><td class=r>{f(r.sistema_connect)}</td>"
        f"<td class=r>{f(r.sistema_vendas_novas)}</td><td class='r d {'neg' if r.d < 0 else 'pos'}'>{sg(r.d)}</td></tr>"
        for _, r in t.iterrows()
    )


CSS = """
@page{size:A4;margin:0} *{box-sizing:border-box} body{font:10.5pt/1.45 'Segoe UI',Arial,sans-serif;color:#1f2937;margin:0}
.cover{height:297mm;background:linear-gradient(160deg,#111827 0%,#1e3a5f 100%);color:#fff;padding:30mm 22mm;page-break-after:always;position:relative}
.cover h1{font-size:34pt;line-height:1.1;margin:60mm 0 8mm;font-weight:700} .cover p{font-size:13pt;color:#cbd5e1;max-width:140mm}
.cover .m{position:absolute;bottom:22mm;left:22mm;color:#94a3b8;font-size:10pt} .bar{width:28mm;height:3mm;background:#f59e0b;margin-bottom:8mm}
.pg{padding:16mm 16mm 14mm;page-break-after:always;min-height:297mm} .pg:last-child{page-break-after:auto}
h2{font-size:17pt;margin:0 0 4mm;color:#111827;border-bottom:2px solid #f59e0b;padding-bottom:2mm} h3{font-size:11.5pt;margin:7mm 0 2mm}
h3 small{color:#6b7280;font-weight:400} .tag{display:inline-block;color:#fff;border-radius:3px;width:6mm;height:6mm;line-height:6mm;text-align:center;margin-right:2mm;font-size:9.5pt}
.k{display:flex;gap:4mm;margin:4mm 0} .k div{flex:1;background:#f3f4f6;border-radius:6px;padding:3.5mm 4mm} .k b{display:block;font-size:19pt;color:#1e3a5f} .k span{font-size:8.5pt;color:#4b5563}
table{width:100%;border-collapse:collapse;font-size:8.5pt;margin-bottom:3mm} th{background:#1e3a5f;color:#fff;text-align:left;padding:1.8mm 2mm;font-weight:600}
td{padding:1.6mm 2mm;border-bottom:1px solid #e5e7eb;vertical-align:top} tr{page-break-inside:avoid} .r{text-align:right;white-space:nowrap} .n{color:#6b7280;white-space:nowrap} .t{color:#374151}
.d{font-weight:700} .neg{color:#b91c1c} .pos{color:#047857} .box{background:#fffbeb;border-left:4px solid #f59e0b;padding:3mm 4mm;margin:4mm 0;border-radius:0 4px 4px 0}
.q li{margin-bottom:2.5mm} .foot{font-size:8pt;color:#9ca3af;margin-top:6mm} .two{display:flex;gap:6mm} .two>div{flex:1}
"""

hoje = datetime.now().strftime("%d/%m/%Y")
H = f"""<!doctype html><html lang=pt-BR><meta charset=utf-8><title>Connect x Sistema — Peças</title><style>{CSS}</style>
<div class=cover><div class=bar></div><p style='letter-spacing:2px;font-size:10pt'>LUCENERA · ADAPTA PASS</p>
<h1>Connect × Sistema<br>Conferência de peças</h1><p>Estoque, Reserva e Entrega Futura — planilhas da Connect de 12/11/2026 contra o Supabase (São Paulo).</p>
<div class=m>Relatório de conferência · {hoje} · Para Filippo e Vinicius · Somente leitura: nada foi alterado no banco</div></div>

<div class=pg><h2>1. Resumo</h2>
<div class=k><div><b>4.571</b><span>peças em comum entre Connect e sistema</span></div><div><b>18</b><span>peças com estoque total diferente</span></div><div><b>0</b><span>peças com Showroom diferente</span></div><div><b>−2</b><span>diferença líquida em Reserva (Connect + vendas novas)</span></div></div>
<p>Comparamos as três planilhas exportadas da Connect hoje (<b>Produtos</b>, <b>ReservaxAmbiente</b> e <b>EntregaFuturaxAmbiente</b>) com o que está no sistema. O resultado é bom: estoque e Showroom estão praticamente iguais, e Reserva e Entrega Futura fecham quase por inteiro quando somamos as vendas feitas no sistema novo.</p>
<table><thead><tr><th>Item</th><th class=r>Connect</th><th class=r>Sistema</th><th>Leitura</th></tr></thead><tbody>
<tr><td>Estoque total (peças em comum)</td><td class=r>32.667,7</td><td class=r>32.521,7</td><td>18 peças divergem</td></tr>
<tr><td>Showroom</td><td class=r>443</td><td class=r>443</td><td>Igual em todas</td></tr>
<tr><td>Reserva (qtd.)</td><td class=r>16.466,2</td><td class=r>16.406,2 + 58 de vendas novas</td><td>23 de 606 peças ainda divergem</td></tr>
<tr><td>Entrega Futura (qtd.)</td><td class=r>5.232,5</td><td class=r>5.064 + 187,5 de vendas novas</td><td>4 de 607 peças ainda divergem</td></tr>
<tr><td>Disponível</td><td class=r>—</td><td class=r>—</td><td>Diverge em 75 peças, em grande parte reflexo de Reserva e Entrega Futura</td></tr></tbody></table>
<div class=box><b>Ideia central.</b> Os dois sistemas rodam em paralelo e a importação de estoque da Connect está suspensa desde 22/10 (SPEC-222), para não apagar entradas de NF e reservas feitas no sistema novo. Por isso, parte das diferenças é só o movimento de uma semana que um lado já registrou e o outro ainda não. Um caso aponta para uma <b>diferença de regra</b>, descrita no grupo A da seção 2.</div>
<p><b>Fora da comparação:</b> a peça 0 (“Produto especial”), que a reunião de 04/11 mandou deixar de fora, e 375 peças que existem só no sistema (cadastradas aqui, sem equivalente na Connect).</p></div>

<div class=pg><h2>2. As 18 peças com estoque diferente</h2>
<p>Diferença = Sistema − Connect. Vermelho: o sistema tem <b>menos</b> que a Connect. Verde: o sistema tem <b>mais</b>. As explicações são <b>hipóteses</b> montadas a partir dos movimentos registrados no sistema desde 05/11; precisam de confirmação de quem opera.</p>
{grp_html}</div>

<div class=pg><h2>3. Reserva e Entrega Futura</h2>
<p>A planilha da Connect traz uma linha por venda, peça e ambiente. Comparamos por peça com o que o sistema tem (vendas que vieram da Connect + vendas feitas no sistema novo).</p>
<div class=two><div><h3>Reserva — maiores diferenças</h3><table><thead><tr><th>Peça</th><th class=r>Connect</th><th class=r>Sist. Connect</th><th class=r>Sist. novas</th><th class=r>Dif.</th></tr></thead><tbody>{top('Reserva por peca')}</tbody></table></div>
<div><h3>Entrega Futura — maiores diferenças</h3><table><thead><tr><th>Peça</th><th class=r>Connect</th><th class=r>Sist. Connect</th><th class=r>Sist. novas</th><th class=r>Dif.</th></tr></thead><tbody>{top('EF por peca')}</tbody></table></div></div>
<h3>O que mudou desde a importação de 05/11</h3>
<table><thead><tr><th></th><th class=r>Saíram da planilha</th><th class=r>Novas na planilha</th><th class=r>Quantidade mudou</th></tr></thead><tbody>
<tr><td>Reserva (linhas)</td><td class=r>266</td><td class=r>53</td><td class=r>14</td></tr><tr><td>Entrega Futura (linhas)</td><td class=r>20</td><td class=r>61</td><td class=r>4</td></tr></tbody></table>
<ul><li><b>Saíram da planilha:</b> provavelmente vendas entregues ou baixadas na Connect.</li><li><b>Novas:</b> vendas aprovadas na Connect depois de 05/11.</li><li><b>Peça 12395:</b> a Entrega Futura de 18 un. no sistema virou Reserva na Connect (487 + 18 = 505). Só a classificação mudou; a soma é igual.</li><li><b>Peça 0 (Produto especial):</b> 3 un. de EF na planilha, ignoradas por regra.</li></ul></div>

<div class=pg><h2>4. Pontos para decisão</h2><ol class=q>
<li><b>Recebimento “para reserva” e o estoque geral (grupo A).</b> Quando a NF chega e a peça já está comprometida, o sistema manda a quantidade direto para a Reserva e, pelo que os dados indicam, <b>não soma no geral</b>. A Connect soma no geral <i>e</i> mostra a mesma quantidade como reservada. Na regra de 28/10 (<i>disponível = geral + Showroom − reservado</i>) o disponível pode sair igual, mas o número de “Estoque Geral” fica diferente. <b>É isso que se espera?</b></li>
<li><b>Peça 12395 (fonte S Power 100W).</b> Divergência de estoque (−35), de Reserva (−18) e de Entrega Futura (+18). Conferir se houve NF de entrada lançada só na Connect.</li>
<li><b>Peças 9923 e 10106.</b> Foram ajustadas à mão em 09/11. A 10106 hoje tem 174 no sistema e 182 na Connect (era 178 após o ajuste). Conferir contagem física.</li>
<li><b>Rotina semanal.</b> Diferenças pequenas (1 a 2 un.) em peças sem movimento no sistema (7365, 12761, 13217) indicam que a Connect segue se movendo. Definir se o estoque geral será reconferido a cada semana com esta mesma comparação.</li></ol>
<h3>Como foi feito</h3><p>Leitura das três planilhas de 12/11/2026 e consulta somente leitura ao Supabase (produtos, estoque, saldos por item de venda, espelho da importação da Connect e movimentações). Chave de comparação: código da peça (Reserva e EF também por venda + peça + ambiente). O detalhe completo, com todas as peças divergentes, está no Excel da comparação e pode ser regerado a qualquer momento.</p>
<p class=foot>“Sist. Connect” = vendas que vieram da Connect para o sistema; “Sist. novas” = vendas feitas diretamente no sistema.</p></div></html>"""

hp = OUT / "relatorio_connect_vs_sistema_pecas.html"
hp.write_text(H, encoding="utf-8")
pdf = OUT / f"Relatorio_Connect_vs_Sistema_Pecas_{datetime.now():%Y%m%d}.pdf"
subprocess.run([r"C:\Program Files\Google\Chrome\Application\chrome.exe", "--headless=new", "--disable-gpu",
                "--no-pdf-header-footer", f"--print-to-pdf={pdf}", hp.as_uri()], check=True, timeout=120)
print(pdf, pdf.stat().st_size)
