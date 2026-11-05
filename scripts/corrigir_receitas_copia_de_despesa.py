"""SPEC-246 — Cancela as 'receitas' que são CÓPIA de uma despesa (contagem em dobro).

Achado de 05/11: 1.545 parcelas gravadas como receita (carga de 29/06 e 08/05) são idênticas
(cod_itens_duplicata + valor + vencimento) a uma despesa ativa do sistema e NÃO existem na planilha
ContaReceber_2026-11-05. Somam R$ 4.356.808,50 pagos e inflam a receita.

Regra: nada é apagado. A parcela é marcada status_pago=2 (cancelada) e o estado anterior fica em
backup.<tabela com data/hora>. Padrão = ENSAIO (ROLLBACK). Use --aplicar para gravar.
"""
import argparse, sys, datetime
import pandas as pd, psycopg2
sys.path.insert(0, r"C:\script python\ADAPTA-PASS-Lucenera-main\scripts")
from _supabase_client import para_pooler, SUPABASE_DB_URL

BASE = r"C:\script python\ADAPTA-PASS-Lucenera-main\01-Documento\01 - Planilhas" + "\\"
ap = argparse.ArgumentParser(); ap.add_argument("--aplicar", action="store_true"); ap.add_argument("--planilha", default="ContaReceber_2026-11-05.xlsx")
a = ap.parse_args()

rec = pd.read_excel(BASE + a.planilha)
c = psycopg2.connect(para_pooler(SUPABASE_DB_URL)); c.autocommit = False; cur = c.cursor()
cur.execute("set statement_timeout=0")

# chaves de conteúdo da planilha: uma receita que BATE com a planilha (cod+venc+valor) nunca é tocada
rec["_v"] = pd.to_datetime(rec.dt_vencimento, dayfirst=True, errors="coerce").dt.date
rec["_p"] = pd.to_numeric(rec.vl_parcela, errors="coerce").round(2)
rec["_c"] = pd.to_numeric(rec.cod_itens_duplicata, errors="coerce")
chaves_planilha = set(zip(rec._c.dropna().astype(int), rec._v[rec._c.notna()], rec._p[rec._c.notna()]))

SEL = """
select t.id, t.cod_itens_duplicata, t.dt_vencimento, round(t.vl_parcela,2) from transacoes t
where t.tipo::text='receita' and t.status_pago<>2
  and exists (select 1 from transacoes d where d.tipo::text='despesa' and d.status_pago<>2
              and d.cod_itens_duplicata=t.cod_itens_duplicata and d.vl_parcela=t.vl_parcela and d.dt_vencimento=t.dt_vencimento)
"""
cur.execute(SEL); cand = cur.fetchall()
ids = [r[0] for r in cand if (r[1], r[2], float(r[3])) not in chaves_planilha]
print(f"candidatas (igual a uma despesa ativa): {len(cand)} | protegidas por bater com a planilha: {len(cand)-len(ids)}")
print(f"receitas-cópia de despesa a cancelar: {len(ids)}")

def inv():
    cur.execute("""select tipo::text, count(*) filter (where status_pago<>2), coalesce(sum(vl_parcela) filter (where status_pago<>2),0),
                          coalesce(sum(vl_pago) filter (where status_pago<>2),0) from transacoes group by 1 order by 1""")
    return {r[0]: r[1:] for r in cur.fetchall()}
antes = inv()
cur.execute("select count(*), coalesce(sum(vl_parcela),0), coalesce(sum(vl_pago),0) from transacoes where id = any(%s::uuid[])", (ids,))
n, vp, vg = cur.fetchone(); print(f"  parcelas {n} | vl_parcela R$ {vp} | pago R$ {vg}")

tag = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
bk = f"backup._bkp_transacoes_receita_copia_despesa_{tag}"
cur.execute(f"create table {bk} as select * from transacoes where id = any(%s::uuid[])", (ids,))
cur.execute("update transacoes set status_pago=2 where id = any(%s::uuid[])", (ids,))
print("  cancelamento:", cur.rowcount)
depois = inv()
for t in ("receita", "despesa"):
    print(f"  {t}: antes {antes[t]} -> depois {depois[t]}")
assert antes["despesa"] == depois["despesa"], "despesa não pode mudar"
# a receita ativa agora deve ser só o que a planilha trouxe + histórico legítimo
cur.execute("select count(*) from (select cod_itens_duplicata from transacoes where tipo::text='receita' and status_pago<>2 group by 1 having count(*)>1) x")
print("  cods duplicados restantes na receita ativa:", cur.fetchone()[0])
if a.aplicar:
    c.commit(); print(f"APLICADO. Backup: {bk}")
else:
    c.rollback(); print("ENSAIO: nada gravado (ROLLBACK).")
