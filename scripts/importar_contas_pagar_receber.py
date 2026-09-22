"""
Sincroniza transacoes (contas a pagar/receber) a partir das planilhas
ContaPagar_*.xlsx e ContaReceber_*.xlsx (export do sistema legado "Connect").

Modelo relacional (grounded em supabase/db/current/01_schema_full.sql):
  negociacoes  (1) -- (N) transacoes
  chave natural negociacoes:  UNIQUE (empresa_id, cod_duplicata, tipo)
  chave natural transacoes:   UNIQUE (negociacao_id, cod_itens_duplicata)

A planilha NAO diferencia ISLIGHT/FOCO/MANOELLA (cod_empresa/nm_empresa são
constantes em todas as linhas = "LUCE NERA"). "LUCE NERA" NAO é uma 4ª
empresa — é como o sistema legado Connect identifica a MANOELLA (mapeamento
permanente, confirmado pelo usuário em 2026-08-17: "luce nera = Manoella",
porque é assim que está cadastrado no banco de dados do Connect). Não é uma
decisão de negócio nem uma migração pontual — é fixo, sempre vai ser assim
enquanto a planilha vier do Connect. Duplicatas cujo (cod_duplicata, tipo)
já existe em negociacoes (criadas por uma empresa real) são só sincronizadas
normalmente. Duplicatas GENUINAMENTE NOVAS (nunca importadas) são criadas
sob a empresa MANOELLA (EMPRESA_LUCE_NERA_ID abaixo) — nunca sob
ISLIGHT/FOCO, que exigiriam um dado que não existe nesta planilha.

Havia um registro "LUCE NERA" separado em `empresas` (grupo/holding, ver
decisão de 2026-07-15) usado como placeholder até 2026-08-17; ele foi
removido/consolidado em algum momento sem passar pelo CHANGELOG e o import
quebrou com foreign key error (`negociacoes_empresa_id_fkey`) até essa
correção. NÃO recriar essa empresa "LUCE NERA" separada — o destino correto
é sempre MANOELLA.

Combinações (cod_duplicata, tipo) AMBÍGUAS (já existem em mais de uma
negociação — outra empresa, ou duas negociações na mesma empresa) são
roteadas para UMA preferida (MANOELLA, senão a mais antiga por created_at —
ver `neg_ambigua_map`). A(s) negociação(ões) perdedora(s) da ambiguidade têm
suas transações ABERTAS canceladas (`status_pago=2`) — ver
`neg_ambigua_perdedora_ids`/`perdedoras_a_cancelar`. Decisão do usuário
(08/09/2026), sem exceção: **a planilha é a fonte de verdade** — se ela só
reconhece 1 negociação por duplicata, o banco não pode ter 2 "abertas" ao
mesmo tempo, mesmo que uma view (`v_financeiro_realizado`) já filtre isso
via `rn=1`. Outros consumidores de `transacoes` sem passar pela view (ex.:
`ContasEmAberto.tsx` em `retorno-bancario-bradesco-5392a`, SPEC-117) leem a
tabela crua e mostrariam o valor duplicado sem essa limpeza.

Resolução de negociacoes novas:
  plano_contas_id  ← plano_de_contas.codigo_connect = cod_apropriacao
  funcionario_id   ← funcionarios.nm_connect        = nm_funcionario (upper/trim)
  contato_id       ← contatos.codigo_legado         = cod_pessoa

Uso:
  python scripts/importar_contas_pagar_receber.py --dry-run
  python scripts/importar_contas_pagar_receber.py
"""

import argparse
import sys
from pathlib import Path

import pandas as pd

if sys.stdout.encoding and sys.stdout.encoding.lower() != "utf-8":
    sys.stdout.reconfigure(encoding="utf-8")

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "scripts"))

from _supabase_client import get_client, SUPABASE_URL  # noqa: E402

CP_PADRAO = ROOT / "01-Documento" / "01 - Planilhas" / "ContaPagar_2026-09-21.xlsx"
CR_PADRAO = ROOT / "01-Documento" / "01 - Planilhas" / "ContaReceber_2026-09-21.xlsx"

# "LUCE NERA" = MANOELLA. NAO é uma decisão, é um fato permanente: é assim
# que a empresa está identificada no banco de dados do Connect (sistema
# legado que gera esta planilha). Confirmado pelo usuário em 2026-08-17.
# Se esse id mudar de novo (empresa recriada/renomeada), atualizar aqui —
# mas o mapeamento LUCE NERA->MANOELLA em si NUNCA muda.
EMPRESA_LUCE_NERA_ID = "9c877812-20e9-452c-bc65-5a542f67ff94"  # MANOELLA

BATCH_SIZE = 200
PAGE_SIZE = 1000

COLUNAS_TRANSACAO = [
    "dt_emissao",
    "dt_vencimento",
    "dt_pagamento",
    "vl_parcela",
    "vl_desconto",
    "vl_juros",
    "vl_pago",
    "vl_frete",
    "vl_ipi",
    "pago",
    "num_parc",
    "total_parc",
    "acordo",
    "tipo_pagamento",
    "cod_itens_duplicata",
    "cod_duplicata",
    "desc_apropriacao",
    "cod_apropriacao",
    "cod_venda",
    "cod_pessoa",
    "nm_funcionario",
    "dev_troca",
]


def carregar_planilha(path: Path, tipo: str) -> pd.DataFrame:
    df = pd.read_excel(path, sheet_name="Financeiro")
    df.columns = [c.strip() for c in df.columns]
    df = df[COLUNAS_TRANSACAO].copy()
    df["tipo"] = tipo

    for col in ["dt_emissao", "dt_vencimento", "dt_pagamento"]:
        df[col] = pd.to_datetime(df[col], dayfirst=True, errors="coerce")

    for col in ["vl_parcela", "vl_desconto", "vl_juros", "vl_pago", "vl_frete", "vl_ipi"]:
        df[col] = pd.to_numeric(df[col], errors="coerce").fillna(0.0)

    df["status_pago"] = pd.to_numeric(df["pago"], errors="coerce").fillna(0).astype(int)
    df["cod_itens_duplicata"] = pd.to_numeric(df["cod_itens_duplicata"], errors="coerce").astype("Int64")
    df["cod_duplicata"] = pd.to_numeric(df["cod_duplicata"], errors="coerce").astype("Int64")
    df["cod_apropriacao"] = pd.to_numeric(df["cod_apropriacao"], errors="coerce").astype("Int64")
    df["cod_pessoa"] = pd.to_numeric(df["cod_pessoa"], errors="coerce").astype("Int64")
    df["num_parc"] = pd.to_numeric(df["num_parc"], errors="coerce").fillna(1).astype(int)
    df["total_parc"] = pd.to_numeric(df["total_parc"], errors="coerce").fillna(1).astype(int)
    df["acordo"] = pd.to_numeric(df["acordo"], errors="coerce").fillna(0).astype(int)
    df["cod_venda"] = pd.to_numeric(df["cod_venda"], errors="coerce").astype("Int64")
    df["dev_troca"] = df["dev_troca"].fillna(0).astype(int).astype(bool)
    df["nm_funcionario"] = df["nm_funcionario"].astype(str).str.strip().str.upper()
    df.loc[df["nm_funcionario"].isin(["NAN", "NONE", ""]), "nm_funcionario"] = None
    df = df.dropna(subset=["cod_itens_duplicata", "cod_duplicata"])

    df["data_transacao"] = df["dt_pagamento"].fillna(df["dt_vencimento"]).fillna(df["dt_emissao"])
    df["descricao"] = df["desc_apropriacao"].fillna("SEM DESCRICAO").str.strip()
    df["valor"] = df["vl_parcela"]

    return df


def buscar_paginado(client, table: str, columns: str) -> pd.DataFrame:
    rows = []
    offset = 0
    while True:
        resp = client.table(table).select(columns).range(offset, offset + PAGE_SIZE - 1).execute()
        data = resp.data or []
        rows.extend(data)
        if len(data) < PAGE_SIZE:
            break
        offset += PAGE_SIZE
    return pd.DataFrame(rows)


def to_date_str(x):
    if pd.isna(x):
        return None
    return x.strftime("%Y-%m-%d")


def processar(dry_run: bool) -> None:
    print(f"Supabase: {SUPABASE_URL}")
    print(f"Modo:     {'DRY-RUN (sem gravação)' if dry_run else 'GRAVAÇÃO REAL'}\n")

    cp = carregar_planilha(CP_PADRAO, "despesa")
    cr = carregar_planilha(CR_PADRAO, "receita")
    planilha = pd.concat([cp, cr], ignore_index=True)
    print(f"Linhas na planilha (CP+CR), após limpeza: {len(planilha)}")

    client = get_client()

    chaves_vigentes = sorted({(int(cd), t) for cd, t in zip(planilha["cod_duplicata"], planilha["tipo"])})
    if dry_run:
        print(f"(dry-run) stg_duplicatas_vigentes seria atualizada com {len(chaves_vigentes)} chaves")
    else:
        print(f"Atualizando stg_duplicatas_vigentes ({len(chaves_vigentes)} chaves)…")
        client.table("stg_duplicatas_vigentes").delete().neq("cod_duplicata", -1).execute()
        registros_stg = [{"cod_duplicata": cd, "tipo": t} for cd, t in chaves_vigentes]
        for i in range(0, len(registros_stg), BATCH_SIZE):
            client.table("stg_duplicatas_vigentes").insert(registros_stg[i : i + BATCH_SIZE]).execute()

    print("Buscando negociacoes existentes…")
    neg = buscar_paginado(client, "negociacoes", "id,empresa_id,cod_duplicata,tipo,created_at")
    neg["cod_duplicata"] = pd.to_numeric(neg["cod_duplicata"], errors="coerce").astype("Int64")
    print(f"  {len(neg)} negociacoes no banco")

    # Verifica se (cod_duplicata, tipo) é uma chave suficiente (sem ambiguidade de empresa)
    dup_key_counts = neg.groupby(["cod_duplicata", "tipo"]).size()
    ambiguous_keys = dup_key_counts[dup_key_counts > 1]
    neg_unicas = neg[~neg.set_index(["cod_duplicata", "tipo"]).index.isin(ambiguous_keys.index)]
    neg_map = neg_unicas.set_index(["cod_duplicata", "tipo"])["id"].to_dict()
    ambiguous_set = set(ambiguous_keys.index)

    # Chaves ambíguas: a mesma (cod_duplicata, tipo) existe em >1 empresa.
    # Antes eram PULADAS — errado: são recebimentos REAIS (uma parcela vence no
    # início do mês e outra no fim, o cliente pagou as duas; ou a empresa foi
    # trocada para um acordo de RT com arquiteto). Não pode sair da soma.
    # Confirmado (02/09/2026): as 402 chaves ambíguas são TODAS receita e em
    # todas a negociação mais antiga é MANOELLA (lote LUCE NERA). Rotear a
    # linha para essa negociação MANOELLA — que também é a `negociacao_preferida`
    # (rn=1 por created_at) que a view v_financeiro_realizado usa, então o valor
    # passa a aparecer no Dashboard sem duplicar.
    neg_ambigua_map = {}
    if len(ambiguous_keys):
        neg_amb = neg[neg.set_index(["cod_duplicata", "tipo"]).index.isin(ambiguous_keys.index)]
        for (cd, tp), g in neg_amb.groupby(["cod_duplicata", "tipo"]):
            man = g[g["empresa_id"] == EMPRESA_LUCE_NERA_ID]
            neg_ambigua_map[(cd, tp)] = (
                man.iloc[0]["id"] if len(man) else g.sort_values("created_at").iloc[0]["id"]
            )
        print(
            f"  {len(ambiguous_keys)} combinações (cod_duplicata,tipo) em >1 empresa — roteadas "
            f"para a negociação MANOELLA/preferida (antes eram puladas)."
        )

    # Negociacoes "perdedoras" da ambiguidade: quando (cod_duplicata, tipo)
    # existe em mais de uma negociacao — mesma empresa ou nao —, so uma e a
    # "preferida" (MANOELLA, ou a mais antiga por created_at) e so ela recebe
    # as linhas da planilha (neg_ambigua_map acima); e a mesma que
    # v_financeiro_realizado usa via rn=1, entao o Dashboard NAO mostra a
    # duplicidade. Mas a(s) negociacao(oes) perdedora(s) continuam com
    # transacoes ABERTAS na tabela crua — o item-level orphan check abaixo
    # nao pega isso, porque o cod_itens_duplicata delas aparece sim na
    # planilha (so que sob a negociacao preferida, nao sob elas). Achado
    # real 08/09/2026: 136 cod_duplicata duplicados (ex.: ISLIGHT/FOCO
    # ILUMINACAO + MANOELLA, ou 2 negociacoes na mesma empresa), R$ 1,68 mi
    # em "Em Aberto" que nao existe na planilha. Decisao do usuario
    # (08/09/2026): a planilha e a fonte de verdade, sem excecao — cancelar
    # (status_pago=2) tudo que estiver aberto nas negociacoes perdedoras,
    # nao so confiar que toda tela vai usar v_financeiro_realizado (a tela
    # "Contas em Aberto" do sistema retorno-bancario-bradesco-5392a le
    # `transacoes` direto, sem a view, e mostraria o valor errado).
    neg_ambigua_perdedora_ids = set()
    if len(ambiguous_keys):
        for (cd, tp), g in neg_amb.groupby(["cod_duplicata", "tipo"]):
            preferida_id = neg_ambigua_map[(cd, tp)]
            neg_ambigua_perdedora_ids.update(nid for nid in g["id"] if nid != preferida_id)

    print("Buscando plano_de_contas (codigo_connect -> id)...")
    pc = buscar_paginado(client, "plano_de_contas", "id,codigo_connect")
    pc_map = pc.set_index("codigo_connect")["id"].to_dict()

    # Achado 2026-09-21: a Connect reemitiu "DESP. OPERAC. FILIPPO" com um
    # cod_apropriacao NOVO (10000007, dentro de um cod_sub_grupo=9999006
    # "OPERAC. FILIPPO" que não existe no nosso plano_de_contas), mas a
    # categoria já existe de verdade sob o código antigo (90000014, dentro
    # de Despesas > Operacional/9999005) -- mesmo nome, sem histórico na
    # negociação nenhuma ainda usando o código novo. Redireciona pra não
    # criar uma categoria duplicada com o mesmo nome (decisão do usuário,
    # 2026-09-22: mapear pra categoria já existente).
    PC_ALIAS_CODIGO_CONNECT = {10000007: 90000014}
    for codigo_novo, codigo_existente in PC_ALIAS_CODIGO_CONNECT.items():
        if codigo_existente in pc_map:
            pc_map[codigo_novo] = pc_map[codigo_existente]

    print("Buscando funcionarios (nm_connect -> id)...")
    func = buscar_paginado(client, "funcionarios", "id,nm_connect")
    func["nm_connect"] = func["nm_connect"].astype(str).str.strip().str.upper()
    func_map = func.dropna(subset=["nm_connect"]).set_index("nm_connect")["id"].to_dict()

    print("Buscando contatos (codigo_legado -> id)...")
    contatos_df = buscar_paginado(client, "contatos", "id,codigo_legado")
    contatos_df["codigo_legado"] = pd.to_numeric(contatos_df["codigo_legado"], errors="coerce").astype("Int64")
    contato_map = contatos_df.dropna(subset=["codigo_legado"]).set_index("codigo_legado")["id"].to_dict()

    # Duplicatas genuinamente novas: (cod_duplicata, tipo) não existe em nenhuma
    # empresa e não é ambíguo — vão para a empresa "LUCE NERA" (grupo).
    novas_chaves = sorted(
        {
            (row["cod_duplicata"], row["tipo"])
            for row in planilha.to_dict("records")
            if (row["cod_duplicata"], row["tipo"]) not in neg_map
            and (row["cod_duplicata"], row["tipo"]) not in ambiguous_set
        }
    )
    print(f"\nDuplicatas novas (sem negociacao em nenhuma empresa): {len(novas_chaves)}")

    primeira_linha_por_chave = {}
    for row in planilha.to_dict("records"):
        chave = (row["cod_duplicata"], row["tipo"])
        if chave in novas_chaves and chave not in primeira_linha_por_chave:
            primeira_linha_por_chave[chave] = row

    novas_negociacoes = []
    sem_plano_contas = 0
    for chave in novas_chaves:
        row = primeira_linha_por_chave[chave]
        plano_contas_id = pc_map.get(int(row["cod_apropriacao"])) if pd.notna(row["cod_apropriacao"]) else None
        if plano_contas_id is None:
            sem_plano_contas += 1
        funcionario_id = func_map.get(row["nm_funcionario"]) if row["nm_funcionario"] else None
        contato_id = contato_map.get(int(row["cod_pessoa"])) if pd.notna(row["cod_pessoa"]) else None
        novas_negociacoes.append(
            {
                "empresa_id": EMPRESA_LUCE_NERA_ID,
                "contato_id": contato_id,
                "funcionario_id": funcionario_id,
                "plano_contas_id": plano_contas_id,
                "tipo": row["tipo"],
                "cod_duplicata": int(row["cod_duplicata"]),
                "cod_venda": int(row["cod_venda"]) if pd.notna(row["cod_venda"]) else None,
                "total_parc": int(row["total_parc"]),
                "dev_troca": bool(row["dev_troca"]),
                "cod_pessoa": int(row["cod_pessoa"]) if pd.notna(row["cod_pessoa"]) else None,
            }
        )
    if novas_chaves:
        print(f"  Sem plano_contas_id resolvido (cod_apropriacao não encontrado): {sem_plano_contas}")

    if dry_run:
        for chave, rec in zip(novas_chaves, novas_negociacoes):
            neg_map[chave] = f"DRY-RUN-{rec['cod_duplicata']}-{rec['tipo']}"
    elif novas_negociacoes:
        print(f"Criando {len(novas_negociacoes)} negociacoes novas sob empresa LUCE NERA…")
        for i in range(0, len(novas_negociacoes), BATCH_SIZE):
            lote_chaves = novas_chaves[i : i + BATCH_SIZE]
            lote = novas_negociacoes[i : i + BATCH_SIZE]
            resp = client.table("negociacoes").insert(lote).execute()
            for chave, criado in zip(lote_chaves, resp.data):
                neg_map[chave] = criado["id"]
            print(f"  Negociacoes criadas: {min(i+BATCH_SIZE, len(novas_negociacoes))}/{len(novas_negociacoes)}", end="\r")
        print()

    print("Buscando transacoes existentes…")
    trans = buscar_paginado(
        client,
        "transacoes",
        "id,negociacao_id,cod_itens_duplicata,status_pago,vl_pago,dt_pagamento,vl_desconto,vl_juros,"
        "vl_parcela,dt_vencimento,dt_emissao,vl_frete,vl_ipi",
    )
    print(f"  {len(trans)} transacoes no banco\n")
    trans_map = {
        (r["negociacao_id"], r["cod_itens_duplicata"]): r
        for r in trans.to_dict("records")
        if r["negociacao_id"] is not None and r["cod_itens_duplicata"] is not None
    }

    novas_transacoes = []
    atualizacoes = []
    sem_negociacao = []
    inalteradas = 0

    for row in planilha.to_dict("records"):
        chave_neg = (row["cod_duplicata"], row["tipo"])
        negociacao_id = neg_map.get(chave_neg) or neg_ambigua_map.get(chave_neg)

        if negociacao_id is None:
            sem_negociacao.append(row)
            continue

        chave_trans = (negociacao_id, row["cod_itens_duplicata"])
        existente = trans_map.get(chave_trans)

        if existente is None:
            novas_transacoes.append(
                {
                    "negociacao_id": negociacao_id,
                    "tipo": row["tipo"],
                    "descricao": row["descricao"],
                    "valor": float(row["valor"]),
                    "data_transacao": to_date_str(row["data_transacao"]),
                    "cod_itens_duplicata": int(row["cod_itens_duplicata"]),
                    "num_parc": int(row["num_parc"]),
                    "dt_emissao": to_date_str(row["dt_emissao"]),
                    "dt_vencimento": to_date_str(row["dt_vencimento"]),
                    "dt_pagamento": to_date_str(row["dt_pagamento"]),
                    "vl_parcela": float(row["vl_parcela"]),
                    "vl_desconto": float(row["vl_desconto"]),
                    "vl_juros": float(row["vl_juros"]),
                    "vl_pago": float(row["vl_pago"]),
                    "vl_frete": float(row["vl_frete"]),
                    "vl_ipi": float(row["vl_ipi"]),
                    "status_pago": int(row["status_pago"]),
                    "tipo_pagamento": row["tipo_pagamento"] if pd.notna(row["tipo_pagamento"]) else None,
                    "acordo": int(row["acordo"]),
                    "cod_venda": int(row["cod_venda"]) if pd.notna(row["cod_venda"]) else None,
                }
            )
            continue

        novo_dt_pagamento = to_date_str(row["dt_pagamento"])
        novo_dt_vencimento = to_date_str(row["dt_vencimento"])
        novo_dt_emissao = to_date_str(row["dt_emissao"])
        # Achado em 02/09/2026: o update só sincronizava status/pagamento e
        # deixava `vl_parcela`/`dt_vencimento`/`dt_emissao` travados no valor do
        # 1º insert. Quando uma duplicata era renegociada/corrigida no Connect
        # (ex.: dup 6836, R$ 550.000 -> R$ 55.000 — um zero a mais), o
        # `transacoes.vl_parcela` ficava errado e o "fluxo futuro" (Em Aberto
        # por vencimento) do Dashboard inflava — ~R$ 2 mi só nessa duplicata.
        # Agora esses campos também entram na comparação e no update.
        mudou = (
            existente["status_pago"] != row["status_pago"]
            or round(float(existente["vl_pago"] or 0), 2) != round(float(row["vl_pago"]), 2)
            or (existente["dt_pagamento"] or None) != (novo_dt_pagamento or None)
            or round(float(existente["vl_desconto"] or 0), 2) != round(float(row["vl_desconto"]), 2)
            or round(float(existente["vl_juros"] or 0), 2) != round(float(row["vl_juros"]), 2)
            or round(float(existente["vl_parcela"] or 0), 2) != round(float(row["vl_parcela"]), 2)
            or (existente.get("dt_vencimento") or None) != (novo_dt_vencimento or None)
            or (existente.get("dt_emissao") or None) != (novo_dt_emissao or None)
            or round(float(existente["vl_frete"] or 0), 2) != round(float(row["vl_frete"]), 2)
            or round(float(existente["vl_ipi"] or 0), 2) != round(float(row["vl_ipi"]), 2)
        )
        if mudou:
            atualizacoes.append(
                {
                    "id": existente["id"],
                    "status_pago": int(row["status_pago"]),
                    "vl_pago": float(row["vl_pago"]),
                    "dt_pagamento": novo_dt_pagamento,
                    "vl_desconto": float(row["vl_desconto"]),
                    "vl_juros": float(row["vl_juros"]),
                    "vl_parcela": float(row["vl_parcela"]),
                    "dt_vencimento": novo_dt_vencimento,
                    "dt_emissao": novo_dt_emissao,
                    "vl_frete": float(row["vl_frete"]),
                    "vl_ipi": float(row["vl_ipi"]),
                }
            )
        else:
            inalteradas += 1

    # Parcelas órfãs: a duplicata ESTÁ no export atual, mas o cod_itens_duplicata
    # não — ou seja, aquela parcela foi substituída/removida no Connect. Achado
    # em 02/09/2026: ~1.200 dessas, quase todas DESPESA (COMPRAS-REVENDA, RT,
    # RETIRADA DE LUCRO, ICMS, tarifa bancária) coladas em negociações
    # `tipo='receita'` de imports antigos, inflando a Receita Realizada em ~R$ 4 mi.
    # A planilha é a fonte de verdade -> cancelar (status_pago = 2).
    neg_cd_map = {
        n["id"]: (n["cod_duplicata"], n["tipo"])
        for n in neg.to_dict("records")
        if n["cod_duplicata"] is not None
    }
    planilha_item_keys = {
        (int(r["cod_duplicata"]), r["tipo"], int(r["cod_itens_duplicata"]))
        for r in planilha.to_dict("records")
    }
    planilha_dup_keys = {(int(r["cod_duplicata"]), r["tipo"]) for r in planilha.to_dict("records")}

    # Duplicata INTEIRA ausente do export atual (não só um item) — a
    # planilha simplesmente não reconhece mais essa cod_duplicata+tipo.
    # Achado real 08/09/2026: 136 cod_duplicata de RECEITA (quase todas
    # ISLIGHT/FOCO ILUMINACAO — empresas legadas, nunca recebem duplicata
    # nova desde que a resolução de ambíguas passou a rotear tudo para
    # MANOELLA) somando R$ 1,68 mi em "Em Aberto" que não existe em nenhuma
    # forma na planilha (nem aberta, nem paga — 109 das 136 já venceram há
    # muito tempo). A view `v_financeiro_realizado` já EXCLUI esses casos
    # (join com `stg_duplicatas_vigentes`), então o Dashboard principal não
    # mostra o erro — mas quem lê `transacoes` direto sem passar pela view
    # (ex.: `ContasEmAberto.tsx` em `retorno-bancario-bradesco-5392a`,
    # SPEC-117) mostraria o valor errado. Decisão do usuário (08/09/2026),
    # sem exceção: a planilha é a fonte de verdade — cancelar também esses
    # (só os ABERTOS; não mexe em histórico já pago, que é uma pergunta
    # diferente sobre receita realizada, não decidida aqui).
    orfas_a_cancelar = []
    perdedoras_a_cancelar = []
    duplicata_ausente_a_cancelar = []
    for r in trans.to_dict("records"):
        if r["status_pago"] == 2:
            continue
        if r["negociacao_id"] in neg_ambigua_perdedora_ids:
            # so cancela quem esta ABERTO (0). Ja pago (1) e' historico real
            # de pagamento -- nao vira cancelado so porque a negociacao
            # perdeu a ambiguidade (diferente do orfao de item abaixo, que
            # tambem cobre pago=1 porque ali o item nem deveria existir).
            if r["status_pago"] == 0:
                perdedoras_a_cancelar.append(r["id"])
            continue
        cdt = neg_cd_map.get(r["negociacao_id"])
        if not cdt or cdt[0] is None:
            continue
        dup_key = (int(cdt[0]), cdt[1])
        if dup_key not in planilha_dup_keys:
            if r["status_pago"] == 0:
                duplicata_ausente_a_cancelar.append(r["id"])
            continue
        if r["cod_itens_duplicata"] is None:
            continue
        item_key = (int(cdt[0]), cdt[1], int(r["cod_itens_duplicata"]))
        if item_key not in planilha_item_keys:
            orfas_a_cancelar.append(r["id"])

    print("\n=== RESUMO ===")
    print(f"Negociacoes novas (empresa LUCE NERA): {len(novas_negociacoes)}")
    print(f"Transações novas a inserir:        {len(novas_transacoes)}")
    print(f"Transações a atualizar (status):   {len(atualizacoes)}")
    print(f"Parcelas órfãs a CANCELAR (item fora do export): {len(orfas_a_cancelar)}")
    print(f"Transações em negociação DUPLICADA a CANCELAR (perdedora da ambiguidade): {len(perdedoras_a_cancelar)}")
    print(f"Transações ABERTAS a CANCELAR (duplicata inteira ausente do export): {len(duplicata_ausente_a_cancelar)}")
    print(f"Transações já sincronizadas (nada a fazer): {inalteradas}")
    print(f"Linhas sem negociação (não roteadas): {len(sem_negociacao)}")

    if sem_negociacao:
        codes = sorted({(r["cod_duplicata"], r["tipo"]) for r in sem_negociacao})
        print(f"  Exemplos de (cod_duplicata, tipo): {codes[:15]}")

    if dry_run:
        print("\n=== DRY-RUN: nada foi gravado ===")
        if novas_transacoes:
            print("\nAmostra de transação nova:")
            print(novas_transacoes[0])
        if atualizacoes:
            print("\nAmostra de atualização:")
            print(atualizacoes[0])
        return

    total_ok, total_erro = 0, 0
    for i in range(0, len(novas_transacoes), BATCH_SIZE):
        lote = novas_transacoes[i : i + BATCH_SIZE]
        try:
            client.table("transacoes").insert(lote).execute()
            total_ok += len(lote)
        except Exception as exc:
            print(f"  ERRO ao inserir lote {i}-{i+len(lote)}: {exc}")
            total_erro += len(lote)
        print(f"  Inserindo: {min(i+BATCH_SIZE, len(novas_transacoes))}/{len(novas_transacoes)}", end="\r")
    print(f"\nInsert concluído: {total_ok} ok, {total_erro} erros.")

    total_ok2, total_erro2 = 0, 0
    for rec in atualizacoes:
        try:
            client.table("transacoes").update(
                {
                    "status_pago": rec["status_pago"],
                    "vl_pago": rec["vl_pago"],
                    "dt_pagamento": rec["dt_pagamento"],
                    "vl_desconto": rec["vl_desconto"],
                    "vl_juros": rec["vl_juros"],
                    "vl_parcela": rec["vl_parcela"],
                    "dt_vencimento": rec["dt_vencimento"],
                    "dt_emissao": rec["dt_emissao"],
                    "vl_frete": rec["vl_frete"],
                    "vl_ipi": rec["vl_ipi"],
                }
            ).eq("id", rec["id"]).execute()
            total_ok2 += 1
        except Exception as exc:
            print(f"  ERRO ao atualizar id={rec['id']}: {exc}")
            total_erro2 += 1
    print(f"Update concluído: {total_ok2} ok, {total_erro2} erros.")

    total_ok3, total_erro3 = 0, 0
    for i in range(0, len(orfas_a_cancelar), BATCH_SIZE):
        lote = orfas_a_cancelar[i : i + BATCH_SIZE]
        try:
            client.table("transacoes").update({"status_pago": 2}).in_("id", lote).execute()
            total_ok3 += len(lote)
        except Exception as exc:
            print(f"  ERRO ao cancelar orfas lote {i}: {exc}")
            total_erro3 += len(lote)
    print(f"Cancelamento de orfas concluido: {total_ok3} ok, {total_erro3} erros.")

    total_ok4, total_erro4 = 0, 0
    for i in range(0, len(perdedoras_a_cancelar), BATCH_SIZE):
        lote = perdedoras_a_cancelar[i : i + BATCH_SIZE]
        try:
            client.table("transacoes").update({"status_pago": 2}).in_("id", lote).execute()
            total_ok4 += len(lote)
        except Exception as exc:
            print(f"  ERRO ao cancelar negociação duplicada lote {i}: {exc}")
            total_erro4 += len(lote)
    print(f"Cancelamento de negociação duplicada (perdedora) concluido: {total_ok4} ok, {total_erro4} erros.")

    total_ok5, total_erro5 = 0, 0
    for i in range(0, len(duplicata_ausente_a_cancelar), BATCH_SIZE):
        lote = duplicata_ausente_a_cancelar[i : i + BATCH_SIZE]
        try:
            client.table("transacoes").update({"status_pago": 2}).in_("id", lote).execute()
            total_ok5 += len(lote)
        except Exception as exc:
            print(f"  ERRO ao cancelar duplicata ausente lote {i}: {exc}")
            total_erro5 += len(lote)
    print(f"Cancelamento de duplicata ausente do export concluido: {total_ok5} ok, {total_erro5} erros.")


def main():
    parser = argparse.ArgumentParser(description="Sincroniza ContaPagar/ContaReceber com transacoes")
    parser.add_argument("--dry-run", action="store_true", help="Apenas mostra o que seria feito")
    args = parser.parse_args()
    processar(args.dry_run)


if __name__ == "__main__":
    main()
