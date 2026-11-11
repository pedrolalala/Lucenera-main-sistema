# Backup diário (SPEC-198): copia o banco oficial de São Paulo para o projeto antigo de Ohio, que fica como
# reserva SOMENTE LEITURA. Roda no GitHub Actions (backup-sp-para-ohio.yml) ou à mão.
#
# Passos: 1) dump de SP (estrutura public/memoria + dados + auth + migrations) e arquivo .dump para guardar;
# 2) destranca Ohio; numa transação só: apaga public/memoria, recarrega tudo, recria policies de storage e o
# trigger de auth; 3) copia arquivos novos do Storage; 4) confere linhas tabela a tabela; 5) tranca Ohio de novo
# (sempre, mesmo se algo falhar). Se a carga falhar, a transação desfaz e Ohio fica como estava.
#
# Variáveis: SP_DB_URL, OHIO_DB_URL (pooler, modo sessão), SP_URL, OHIO_URL, SP_SERVICE_ROLE_KEY,
# OHIO_SERVICE_ROLE_KEY (as duas últimas só para copiar arquivos do Storage).
import os
import re
import subprocess
import sys
import urllib.parse
import urllib.request

import psycopg2

SP_DB, OH_DB = os.environ["SP_DB_URL"], os.environ["OHIO_DB_URL"]
OUT = os.environ.get("BACKUP_DIR", "backup_out")
os.makedirs(OUT, exist_ok=True)
ENV = dict(os.environ, PGCLIENTENCODING="UTF8", PGCONNECT_TIMEOUT="30")
RW = "-c default_transaction_read_only=off"  # sessão que grava mesmo com Ohio trancado


def p(nome):
    return os.path.join(OUT, nome)


def run(cmd, env=ENV):
    r = subprocess.run(cmd, capture_output=True, text=True, encoding="utf-8", env=env)
    if r.returncode != 0:
        print((r.stderr or "")[-3000:])
        raise RuntimeError(f"falhou: {cmd[0]} (rc {r.returncode})")


def trancar(on):
    c = psycopg2.connect(OH_DB, connect_timeout=30, options=RW)
    c.autocommit = True
    k = c.cursor()
    # o pooler ignora opções de conexão: liberar a gravação dentro da própria sessão
    k.execute("SET SESSION CHARACTERISTICS AS TRANSACTION READ WRITE")
    k.execute(f"ALTER DATABASE postgres SET default_transaction_read_only = {'on' if on else 'off'}")
    # derruba conexões abertas dos serviços para reabrirem já com a regra nova
    k.execute("""select count(pg_terminate_backend(pid)) from pg_stat_activity
                 where datname = 'postgres'
                   and pid <> pg_backend_pid()
                   and usename in ('authenticator', 'supabase_auth_admin', 'supabase_storage_admin', 'postgres')""")
    # a própria conexão também volta para o pool com a regra antiga: encerrar
    try:
        k.execute("select pg_terminate_backend(pg_backend_pid())")
    except Exception:
        pass
    c.close()
    print("Ohio", "trancado (somente leitura)." if on else "destrancado para a cópia.")


def dump_sp():
    # arquivos para guardar (pg_restore): -n e -t não se misturam no mesmo pg_dump
    run(["pg_dump", SP_DB, "-Fc", "--no-owner", "-n", "public", "-n", "memoria", "-f", p("lucenera_sp.dump")])
    run(["pg_dump", SP_DB, "-Fc", "--no-owner", "-t", "auth.users", "-t", "auth.identities",
         "-t", "supabase_migrations.schema_migrations", "-f", p("lucenera_sp_auth.dump")])
    run(["pg_dump", SP_DB, "--schema-only", "--quote-all-identifiers", "--no-owner", "-n", "public", "-n", "memoria",
         "-f", p("schema.sql")])
    run(["pg_dump", SP_DB, "--data-only", "--quote-all-identifiers", "--no-owner", "-n", "public", "-n", "memoria",
         "--disable-triggers", "-f", p("data_public.sql")])
    run(["pg_dump", SP_DB, "--data-only", "--quote-all-identifiers", "--no-owner", "-t", "auth.users",
         "-t", "auth.identities", "-t", "supabase_migrations.schema_migrations", "--disable-triggers",
         "-f", p("data_auth.sql")])

    schema = open(p("schema.sql"), encoding="utf-8").read().replace('CREATE SCHEMA "public";', "-- (public criado antes)")
    schema = re.sub(r'^ALTER DEFAULT PRIVILEGES FOR ROLE "supabase_admin".*$', "-- (supabase_admin)", schema, flags=re.M)
    # Views que leem o schema "backup" (que não é copiado) quebravam a carga em Ohio (11/11/2026:
    # vw_staging_resumo -> backup.staging_conta_pagar/receber). Ficam de fora da reserva, junto com os
    # GRANT/COMMENT delas; o resto da cópia segue igual.
    fora = []
    for m in list(re.finditer(r'^CREATE VIEW "public"\."([^"]+)" AS\n.*?;\n', schema, flags=re.M | re.S)):
        if '"backup".' in m.group(0):
            fora.append(m.group(1))
    for nome in fora:
        schema = re.sub(r'^CREATE VIEW "public"\."' + re.escape(nome) + r'" AS\n.*?;\n',
                        f"-- (view {nome} fora: lê o schema backup)\n", schema, flags=re.M | re.S)
        schema = re.sub(r'^(GRANT|REVOKE|COMMENT|ALTER)[^\n]*"public"\."' + re.escape(nome) + r'"[^\n]*;$',
                        "", schema, flags=re.M)
    if fora:
        print("views fora da reserva (leem o schema backup):", ", ".join(fora))
    open(p("schema_x.sql"), "w", encoding="utf-8").write(schema)
    for src, dst in (("data_auth.sql", "d1.sql"), ("data_public.sql", "d2.sql")):
        t = open(p(src), encoding="utf-8").read()
        t = re.sub(r"^ALTER TABLE .* (DISABLE|ENABLE) TRIGGER ALL;$", "", t, flags=re.M)
        open(p(dst), "w", encoding="utf-8").write(
            "SET session_replication_role = replica;\n" + t + "\nSET session_replication_role = origin;\n")
    # A regra de data de início do pagamento foi retirada do banco (data retroativa liberada). Sem ela o
    # re.search devolvia None e o backup parava desde 20/10/2026. Agora: se a regra existir, ela é tirada antes
    # dos dados e recriada depois; se não existir, segue sem ela.
    m = re.search(r'ALTER TABLE "public"\."orcamentos"\s+ADD CONSTRAINT "orcamentos_data_inicio_pagamento_check"'
                  r'[^;]*;', schema)
    chk = m.group(0) if m else "-- (sem orcamentos_data_inicio_pagamento_check)"
    drop_chk = ('ALTER TABLE "public"."orcamentos" DROP CONSTRAINT "orcamentos_data_inicio_pagamento_check";'
                if m else "-- (sem orcamentos_data_inicio_pagamento_check)")

    # políticas de storage (dependem de funções de public e somem no DROP CASCADE)
    c = psycopg2.connect(SP_DB, connect_timeout=30)
    k = c.cursor()
    k.execute("""select policyname, permissive, roles, cmd, qual, with_check from pg_policies
                 where schemaname = 'storage' and tablename = 'objects' order by policyname""")
    pols = []
    for n, perm, roles, cmd, qual, wc in k.fetchall():
        s = f'CREATE POLICY "{n}" ON "storage"."objects" AS {perm} FOR {cmd} TO {", ".join(roles)}'
        if qual:
            s += f" USING ({qual})"
        if wc:
            s += f" WITH CHECK ({wc})"
        pols.append(s + ";")
    c.close()
    open(p("storage_policies.sql"), "w", encoding="utf-8").write("\n".join(pols) + "\n")

    inc = lambda f: "\\i " + p(f).replace("\\", "/")
    open(p("restore.sql"), "w", encoding="utf-8").write("\n".join([
        "SET TRANSACTION READ WRITE;",
        "DO $$ declare r record; begin",
        "  for r in select policyname from pg_policies where schemaname='storage' and tablename='objects' loop",
        "    execute format('drop policy %I on storage.objects', r.policyname); end loop; end $$;",
        "DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;",
        "DROP SCHEMA IF EXISTS memoria CASCADE;",
        "DROP SCHEMA public CASCADE;",
        "CREATE SCHEMA public;",
        "ALTER SCHEMA public OWNER TO pg_database_owner;",
        "CREATE EXTENSION IF NOT EXISTS pg_net WITH SCHEMA public;",
        "CREATE EXTENSION IF NOT EXISTS unaccent WITH SCHEMA public;",
        inc("schema_x.sql"),
        drop_chk,
        "TRUNCATE auth.users CASCADE;",
        "TRUNCATE supabase_migrations.schema_migrations;",
        inc("d1.sql"),
        inc("d2.sql"),
        chk,
        "SET search_path = public, extensions;",
        inc("storage_policies.sql"),
        "CREATE TRIGGER on_auth_user_created AFTER INSERT ON auth.users FOR EACH ROW "
        "EXECUTE FUNCTION public.handle_new_user();",
        "",
    ]))


def carregar_ohio():
    run(["psql", OH_DB, "-v", "ON_ERROR_STOP=1", "--single-transaction", "-q", "-f", p("restore.sql")],
        env=dict(ENV, PGOPTIONS=RW))
    print("carga em Ohio: ok")


def storage_req(base, key, method, path, data=None, ctype=None):
    h = {"Authorization": "Bearer " + key, "apikey": key, "User-Agent": "lucenera-backup"}
    if ctype:
        h["Content-Type"] = ctype
        h["x-upsert"] = "true"
    req = urllib.request.Request(base + "/storage/v1/" + path, data=data, method=method, headers=h)
    return urllib.request.urlopen(req, timeout=180)


def objetos(db):
    c = psycopg2.connect(db, connect_timeout=30, options=RW)
    k = c.cursor()
    k.execute("""select bucket_id, name, coalesce((metadata->>'size')::bigint, 0),
                        coalesce(metadata->>'mimetype', 'application/octet-stream')
                 from storage.objects where name not like '%.emptyFolderPlaceholder'""")
    r = k.fetchall()
    c.close()
    return r


def copiar_arquivos():
    if not (os.environ.get("SP_SERVICE_ROLE_KEY") and os.environ.get("OHIO_SERVICE_ROLE_KEY")):
        print("arquivos: pulado (sem as chaves service_role)")
        return
    ja = {(b, n): s for b, n, s, _ in objetos(OH_DB)}
    novos = erros = 0
    for b, n, s, mt in objetos(SP_DB):
        if ja.get((b, n)) == s:
            continue
        q = urllib.parse.quote(n)
        try:
            dados = storage_req(os.environ["SP_URL"], os.environ["SP_SERVICE_ROLE_KEY"], "GET", f"object/{b}/{q}").read()
            storage_req(os.environ["OHIO_URL"], os.environ["OHIO_SERVICE_ROLE_KEY"], "POST", f"object/{b}/{q}",
                        data=dados, ctype=mt).read()
            novos += 1
        except Exception as e:  # um arquivo com erro não derruba o backup do banco
            erros += 1
            print("  arquivo com erro:", b, n, str(e)[:100])
    print(f"arquivos: {novos} copiados, {erros} com erro")


def contar(db):
    c = psycopg2.connect(db, connect_timeout=30, options=RW)
    k = c.cursor()
    k.execute("select schemaname||'.'||tablename from pg_tables where schemaname in ('public','memoria') order by 1")
    tot = {}
    for (t,) in k.fetchall():
        s, n = t.split(".", 1)
        k.execute(f'select count(*) from "{s}"."{n}"')
        tot[t] = k.fetchone()[0]
    k.execute("select count(*) from auth.users")
    tot["auth.users"] = k.fetchone()[0]
    c.close()
    return tot


dump_sp()
trancar(False)
try:
    carregar_ohio()
    copiar_arquivos()
    a, b = contar(SP_DB), contar(OH_DB)
    dif = sorted(t for t in set(a) | set(b) if a.get(t) != b.get(t))
    print(f"conferência: SP {sum(a.values())} linhas, Ohio {sum(b.values())} linhas, {len(dif)} tabelas diferentes",
          dif[:10])
    # diferença pequena = gravação em SP durante a cópia; muitas = falha
    if len(dif) > 5:
        raise RuntimeError("conferência com muitas diferenças")
finally:
    trancar(True)
