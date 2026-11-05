"""SPEC-246 — Batimento do financeiro DENTRO do Supabase (somente leitura).
Cruza: planilhas (e espelho) x transacoes x negociacoes x contatos x boletos x views do dashboard.
Uso: python bater_supabase_financeiro.py [--data 2026-11-05]
Nada é gravado."""
import argparse, sys
import pandas as pd, psycopg2
sys.path.insert(0, r"C:\script python\ADAPTA-PASS-Lucenera-main\scripts")
from _supabase_client import para_pooler, SUPABASE_DB_URL

ap = argparse.ArgumentParser(); ap.add_argument("--data", default="2026-11-05"); a = ap.parse_args()
BASE = r"C:\script python\ADAPTA-PASS-Lucenera-main\01-Documento\01 - Planilhas" + "\\"
c = psycopg2.connect(para_pooler(SUPABASE_DB_URL)); c.set_session(readonly=True); cur = c.cursor(); cur.execute("set statement_timeout=0")
def q(s, p=None):
    cur.execute(s, p); return cur.fetchall()
def brl(x): return f"R$ {float(x or 0):,.2f}".replace(",", "X").replace(".", ",").replace("X", ".")
ok = lambda b: "OK " if b else "ERRO"
achados = []
def achado(nome, qtd, valor=0, detalhe=""):
    achados.append((nome, qtd, valor)); print(f"  [{ok(qtd == 0)}] {nome}: {qtd}" + (f" · {brl(valor)}" if valor else "") + (f"  ({detalhe})" if detalhe else ""))

print("=" * 100); print("BATIMENTO DO SUPABASE — CONTAS A RECEBER E CONTAS A PAGAR —", a.data); print("=" * 100)

# ---- 1. planilha x espelho x sistema, por tipo e situação ----
print("\n1) PLANILHA x ESPELHO x SISTEMA (parcelas, todas as situações)")
for arq, tipo, nome in ((f"ContaReceber_{a.data}.xlsx", "receita", "Receber"), (f"ContaPagar_{a.data}.xlsx", "despesa", "Pagar")):
    d_all = pd.read_excel(BASE + arq)
    canc = d_all[pd.to_numeric(d_all.pago, errors="coerce") == 2]  # cancelada na própria Connect (pago = 2)
    d = d_all[pd.to_numeric(d_all.pago, errors="coerce") != 2].copy()
    d["cod"] = pd.to_numeric(d.cod_itens_duplicata, errors="coerce"); d["vp"] = pd.to_numeric(d.vl_parcela, errors="coerce"); d["vg"] = pd.to_numeric(d.vl_pago, errors="coerce").fillna(0)
    esp = q("select count(*), coalesce(sum(vl_parcela),0), coalesce(sum(vl_pago),0) from connect_contas_espelho where tipo=%s and coalesce(pago,0)<>2", (tipo,))[0]
    sis = q("select count(*), coalesce(sum(vl_parcela),0), coalesce(sum(vl_pago),0) from transacoes where tipo::text=%s and status_pago<>2", (tipo,))[0]
    cods = [int(x) for x in d.cod.dropna()]
    nos = q("select count(*), coalesce(sum(vl_parcela),0), coalesce(sum(vl_pago),0) from transacoes where tipo::text=%s and status_pago<>2 and cod_itens_duplicata=any(%s)", (tipo, cods))[0]
    fora = q("select count(*), coalesce(sum(vl_parcela),0), coalesce(sum(vl_pago),0) from transacoes where tipo::text=%s and status_pago<>2 and not (cod_itens_duplicata=any(%s))", (tipo, cods))[0]
    print(f"  {nome}: planilha {len(d_all)} linhas = {len(d)} ativas + {len(canc)} canceladas na Connect ({brl(pd.to_numeric(canc.vl_parcela, errors='coerce').sum())})")
    print(f"  {nome}: planilha ATIVA {len(d)} · parcela {brl(d.vp.sum())} · pago {brl(d.vg.sum())}")
    print(f"        espelho  {esp[0]} · {brl(esp[1])} · pago {brl(esp[2])}  -> {ok(esp[0]==len(d) and abs(float(esp[1])-d.vp.sum())<0.01)}")
    print(f"        sistema (ativas) {sis[0]} · {brl(sis[1])} · pago {brl(sis[2])}")
    print(f"          das quais NA planilha {nos[0]} · {brl(nos[1])} · pago {brl(nos[2])}  | FORA da planilha (histórico de cargas antigas) {fora[0]} · {brl(fora[1])} · pago {brl(fora[2])}")
    achado(f"{nome}: dif. de parcela planilha x sistema (só as da planilha)", int(abs(float(nos[1]) - d.vp.sum()) > 0.01) + int(nos[0] != len(d)), abs(float(nos[1]) - d.vp.sum()))

# ---- 2. duplicidade ----
print("\n2) DUPLICIDADE")
achado("parcelas ativas com o mesmo (tipo, cod_itens_duplicata)", q("select count(*) from (select 1 from transacoes where cod_itens_duplicata is not null and status_pago<>2 group by tipo,cod_itens_duplicata having count(*)>1) x")[0][0])
achado("receita ativa igual a uma despesa ativa (cópia)", q("select count(*) from transacoes t where t.tipo::text='receita' and t.status_pago<>2 and exists (select 1 from transacoes d where d.tipo::text='despesa' and d.status_pago<>2 and d.cod_itens_duplicata=t.cod_itens_duplicata and d.vl_parcela=t.vl_parcela and d.dt_vencimento=t.dt_vencimento)")[0][0])
r = q("select count(*), coalesce(sum(x.vl_parcela),0) from (select vl_parcela from transacoes where status_pago<>2 and negociacao_id is not null group by negociacao_id, num_parc, vl_parcela, dt_vencimento, tipo having count(*)>1) x")[0]
achado("mesma duplicata + nº de parcela + valor + vencimento repetidos (códigos diferentes)", r[0], r[1])
achado("negociações iguais (empresa, tipo, cod_duplicata) — deveria ser 0 pelo índice", q("select count(*) from (select 1 from negociacoes group by empresa_id,cod_duplicata,tipo having count(*)>1) x")[0][0])

# ---- 3. coerência parcela x duplicata ----
print("\n3) COERÊNCIA PARCELA x DUPLICATA")
achado("tipo da parcela diferente do tipo da duplicata", q("select count(*) from transacoes t join negociacoes n on n.id=t.negociacao_id where t.tipo<>n.tipo")[0][0])
achado("parcela ativa sem duplicata", q("select count(*) from transacoes where negociacao_id is null and status_pago<>2")[0][0])
achado("duplicata sem nenhuma parcela", q("select count(*) from negociacoes n where not exists (select 1 from transacoes t where t.negociacao_id=n.id)")[0][0])
achado("duplicata ativa cujo nº de parcelas ativas difere do total_parc", q("select count(*) from (select n.id from negociacoes n join transacoes t on t.negociacao_id=n.id and t.status_pago<>2 group by n.id,n.total_parc having count(*)<>n.total_parc) x")[0][0],
       detalhe="total_parc é do dia da criação; diferença pode ser parcela cancelada/acordo")
achado("duplicata ativa só com parcelas canceladas", q("select count(*) from negociacoes n where exists (select 1 from transacoes t where t.negociacao_id=n.id) and not exists (select 1 from transacoes t where t.negociacao_id=n.id and t.status_pago<>2)")[0][0])

# ---- 4. situação x valores x datas ----
print("\n4) SITUAÇÃO x VALORES x DATAS (parcelas ativas)")
r = q("select count(*), coalesce(sum(vl_parcela),0) from transacoes where status_pago=1 and coalesce(vl_pago,0)=0 and coalesce(vl_parcela,0)>0")[0]; achado("paga com valor pago zero", r[0], r[1])
r = q("select count(*), coalesce(sum(vl_pago),0) from transacoes where status_pago=0 and coalesce(vl_pago,0)>0")[0]; achado("em aberto com valor pago", r[0], r[1])
achado("paga sem data de pagamento", q("select count(*) from transacoes where status_pago=1 and dt_pagamento is null")[0][0])
achado("em aberto com data de pagamento", q("select count(*) from transacoes where status_pago=0 and dt_pagamento is not null")[0][0])
achado("vencimento anterior à emissão", q("select count(*) from transacoes where status_pago<>2 and dt_vencimento<dt_emissao")[0][0], detalhe="dado da Connect")
achado("pago maior que o valor da parcela em mais de R$ 1 (juros/multa explicam parte)", q("select count(*) from transacoes where status_pago=1 and vl_pago>vl_parcela+1+coalesce(vl_juros,0)")[0][0])
achado("parcela com valor zero ou nulo (ativa)", q("select count(*) from transacoes where status_pago<>2 and coalesce(vl_parcela,0)<=0")[0][0])

# ---- 5. ligações ----
print("\n5) LIGAÇÕES (todas as parcelas ativas)")
tot = q("select count(*) from transacoes where status_pago<>2")[0][0]
for nome, cond in (("sem conta bancária", "t.conta_id is null"), ):
    r = q(f"select tipo::text,count(*) from transacoes t where status_pago<>2 and {cond} group by 1 order by 1"); print(f"  {nome}: {r} de {tot}")
r = q("select n.tipo::text,count(*) filter (where n.contato_id is null),count(*) filter (where n.plano_contas_id is null),count(*) filter (where n.projeto_id is null),count(*) filter (where n.empresa_id is null),count(*) from negociacoes n group by 1 order by 1")
print("  duplicatas (tipo, sem contato, sem plano, sem projeto, sem empresa, total):", r)
r = q("select n.tipo::text,count(*) from negociacoes n join contatos k on k.id=n.contato_id where (n.tipo::text='receita' and k.tipo::text='fornecedor') or (n.tipo::text='despesa' and k.tipo::text='cliente') group by 1")
print("  tipo do contato possivelmente invertido (receber->fornecedor, pagar->cliente):", r, "(pagar->cliente pode ser legítimo: devolução/comissão)")
r = q("select n.id::text from negociacoes n join contatos k on k.id=n.contato_id where n.nome_pessoa is not null and upper(btrim(n.nome_pessoa)) <> upper(btrim(k.nome)) and (k.razao_social is null or upper(btrim(n.nome_pessoa)) <> upper(btrim(k.razao_social))) limit 0")
r = q("select count(*) from negociacoes n join contatos k on k.id=n.contato_id where n.nome_pessoa is not null and regexp_replace(upper(n.nome_pessoa),'[^A-Z0-9]','','g') <> regexp_replace(upper(coalesce(k.nome,'')),'[^A-Z0-9]','','g') and regexp_replace(upper(coalesce(n.razao_pessoa,n.nome_pessoa)),'[^A-Z0-9]','','g') <> regexp_replace(upper(coalesce(k.razao_social,k.nome,'')),'[^A-Z0-9]','','g')")
print("  duplicatas cujo contato ligado tem NOME DIFERENTE do nome da planilha:", r[0][0])

# ---- 6. boletos ----
print("\n6) BOLETOS")
print("  boletos:", q("select count(*), count(*) filter (where parcela_id is not null) from boletos")[0], "(total, ligados a parcela)")
achado("boleto ligado a parcela que não existe/está cancelada", q("select count(*) from boletos b left join transacoes t on t.id=b.parcela_id where b.parcela_id is not null and (t.id is null or t.status_pago=2)")[0][0])

# ---- 7. dashboard x tabela ----
print("\n7) DASHBOARD (v_financeiro_realizado, lógica sem filtro de permissão) x TRANSAÇÕES")
r = q("""with m as (select coalesce((select encerrado_em from connect_financeiro_encerrado limit 1),'infinity'::timestamptz) m),
 np as (select n.id, row_number() over (partition by case when v.cod_duplicata is not null and n.created_at<=(select m from m) then n.cod_duplicata::text else n.id::text end, n.tipo order by n.created_at) rn
   from negociacoes n left join stg_duplicatas_vigentes v on v.cod_duplicata=n.cod_duplicata and v.tipo=n.tipo
   where (v.cod_duplicata is not null and n.created_at<=(select m from m)) or n.created_at>(select m from m))
 select t.tipo::text, count(*) filter (where np.rn=1), coalesce(sum(t.vl_pago) filter (where np.rn=1),0), count(*) filter (where np.id is null or np.rn>1), coalesce(sum(t.vl_pago) filter (where np.id is null or np.rn>1),0)
 from transacoes t left join np on np.id=t.negociacao_id where t.status_pago<>2 group by 1 order by 1""")
for tp, n_in, v_in, n_out, v_out in r: print(f"  {tp}: no dashboard {n_in} · pago {brl(v_in)} | fora do dashboard {n_out} · pago {brl(v_out)}")

# ---- 8. por empresa e ano (visão para o Filippo) ----
print("\n8) POR EMPRESA (parcelas ativas): em aberto e pago")
for row in q("""select e.nome, t.tipo::text, count(*) filter (where t.status_pago=0), coalesce(sum(t.vl_parcela) filter (where t.status_pago=0),0), coalesce(sum(t.vl_pago) filter (where t.status_pago=1),0)
 from transacoes t join negociacoes n on n.id=t.negociacao_id join empresas e on e.id=n.empresa_id where t.status_pago<>2 group by 1,2 order by 2,1"""):
    print(f"  {row[1]:8s} {row[0]:18s} em aberto {row[2]:5d} · {brl(row[3]):>18s} | pago {brl(row[4]):>18s}")

print("\nRESUMO:", "TUDO CERTO" if all(x[1] == 0 for x in achados) else f"{sum(1 for x in achados if x[1] != 0)} verificações com achados (ver [ERRO] acima)")
