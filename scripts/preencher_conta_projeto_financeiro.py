"""SPEC-246 — Preenche, SEM dado novo, duas ligações que a planilha já traz:
  * transacoes.conta_id   <- cod_conta da planilha (Caixa/Bradesco...) -> contas_bancarias.codigo_connect (só onde está vazio)
  * negociacoes.projeto_id <- código do projeto no início do nome da pessoa ("24.416 FLAVIA E AGENOR...") -> projetos.codigo / codigo_legado
                              (só onde está vazio e o código acha UM projeto)
Nada é sobrescrito: só preenche vazio. Estado anterior em backup.<tabela timestamp>. Padrão = ENSAIO (ROLLBACK); --aplicar grava.
Invariante: contagens e somas de transacoes/negociacoes iguais antes e depois.
"""
import argparse, datetime, re, sys
import pandas as pd, psycopg2
sys.path.insert(0, r"C:\script python\ADAPTA-PASS-Lucenera-main\scripts")
from _supabase_client import para_pooler, SUPABASE_DB_URL

BASE = r"C:\script python\ADAPTA-PASS-Lucenera-main\01-Documento\01 - Planilhas" + "\\"
ap = argparse.ArgumentParser(); ap.add_argument("--aplicar", action="store_true"); ap.add_argument("--data", default="2026-11-05")
a = ap.parse_args()

c = psycopg2.connect(para_pooler(SUPABASE_DB_URL)); c.autocommit = False; cur = c.cursor(); cur.execute("set statement_timeout=0")
def q(s, p=None):
    cur.execute(s, p); return cur.fetchall()
dig = lambda x: re.sub(r"\D", "", str(x or ""))

def invariantes():
    t = q("select count(*), coalesce(sum(vl_parcela),0), coalesce(sum(vl_pago),0), coalesce(sum(status_pago),0) from transacoes")[0]
    n = q("select count(*), count(distinct cod_duplicata) from negociacoes")[0]
    return t, n
antes = invariantes()
tag = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")

# ---------- conta bancária ----------
contas = {int(k): v for k, v in q("select codigo_connect, id from contas_bancarias where codigo_connect is not null")}
pares = []  # (tipo, cod_itens, conta_id)
for arq, tipo in ((f"ContaReceber_{a.data}.xlsx", "receita"), (f"ContaPagar_{a.data}.xlsx", "despesa")):
    d = pd.read_excel(BASE + arq)
    d["cod"] = pd.to_numeric(d.cod_itens_duplicata, errors="coerce"); d["cc"] = pd.to_numeric(d.cod_conta, errors="coerce")
    for cod, cc in zip(d.cod, d.cc):
        if pd.notna(cod) and pd.notna(cc) and int(cc) in contas:
            pares.append((tipo, int(cod), contas[int(cc)]))
print(f"planilhas com conta bancária conhecida: {len(pares)} linhas")
cur.execute("create temp table _conta (tipo text, cod int, conta_id uuid) on commit drop")
cur.executemany("insert into _conta values (%s,%s,%s)", pares)
cur.execute("""create temp table _alvo_conta as select t.id, c.conta_id from transacoes t join _conta c on c.tipo=t.tipo::text and c.cod=t.cod_itens_duplicata
               where t.conta_id is null and t.status_pago<>2""")
cur.execute("select count(*) from _alvo_conta"); n_conta = cur.fetchone()[0]
print(f"transacoes.conta_id a preencher: {n_conta}")
cur.execute(f"create table backup._bkp_transacoes_conta_id_{tag} as select t.id, t.conta_id from transacoes t join _alvo_conta a on a.id=t.id")
cur.execute("update transacoes t set conta_id=a.conta_id from _alvo_conta a where a.id=t.id and t.conta_id is null")
print("  atualizadas:", cur.rowcount)

# ---------- projeto ----------
proj = {}
for pid, cod, leg in q("select id, codigo, codigo_legado from projetos"):
    for v in (cod, leg):
        k = dig(v)
        if len(k) >= 5: proj.setdefault(k, set()).add(pid)
rows = q("select id, coalesce(nullif(btrim(nome_pessoa),''), nullif(btrim(razao_pessoa),'')) from negociacoes where projeto_id is null and tipo::text='receita'")
rx = re.compile(r"^\s*(\d{2}\.?\d{3})\b")
alvo, ambig, semproj = [], 0, 0
for nid, nome in rows:
    m = rx.match(nome or "")
    if not m: continue
    ach = proj.get(dig(m.group(1)), set())
    if len(ach) == 1: alvo.append((nid, next(iter(ach))))
    elif len(ach) > 1: ambig += 1
    else: semproj += 1
print(f"negociacoes de receber sem projeto com código no nome: ligáveis {len(alvo)} | ambíguas {ambig} | código sem projeto no sistema {semproj}")
cur.execute("create temp table _proj (nid uuid, pid uuid) on commit drop")
cur.executemany("insert into _proj values (%s,%s)", alvo)
cur.execute(f"create table backup._bkp_negociacoes_projeto_id_{tag} as select n.id, n.projeto_id from negociacoes n join _proj p on p.nid=n.id")
cur.execute("update negociacoes n set projeto_id=p.pid from _proj p where p.nid=n.id and n.projeto_id is null")
print("  atualizadas:", cur.rowcount)

depois = invariantes()
print("invariantes antes:", antes, "\ninvariantes depois:", depois)
assert antes == depois, "contagens/somas mudaram"
print("cobertura após:", q("select count(*) filter (where conta_id is not null), count(*) from transacoes where status_pago<>2")[0],
      q("select count(*) filter (where projeto_id is not null), count(*) from negociacoes where tipo::text='receita'")[0])
if a.aplicar:
    c.commit(); print(f"APLICADO. Backups: backup._bkp_transacoes_conta_id_{tag}, backup._bkp_negociacoes_projeto_id_{tag}")
else:
    c.rollback(); print("ENSAIO: nada gravado (ROLLBACK).")
