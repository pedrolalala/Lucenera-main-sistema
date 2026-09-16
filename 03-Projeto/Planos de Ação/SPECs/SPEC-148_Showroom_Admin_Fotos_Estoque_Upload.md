---
titulo: "SPEC-148 — Showroom /admin: fotos do estoque (fluxo inverso do PPT) + peça composta (1 foto, N produtos)"
status: implementado + migration aplicada + publicado no Skip (aguardando teste ao vivo end-to-end)
data_ultima_modificacao: 2026-09-15
sistemas_envolvidos:
  - Showroom (showroom-qtq8er2dk)
  - Supabase (banco central) — 2 tabelas novas, 5 RPCs novas + 2 RPCs estendidas, redesenho de `vw_showroom_publico`, policies de Storage
dependencias:
  - SPEC-125 (site + tela /admin de curadoria original, login usuário/senha em showroom_config, `vw_showroom_publico`)
  - SPEC-127 (showroom_import_pecas, showroom_buscar_produto)
  - SPEC-128 (showroom_login / showroom_cred_ok, credencial compartilhada)
  - SPEC-137 (achado: backfill de foto não duplica arquivo, só reaproveita URL — mesma cautela de não mexer em `import/`)
---

# SPEC-148 — Showroom /admin: fotos do estoque + peça composta

> Origem: pedido de Pedro (áudio). Hoje a tela `/admin` (SPEC-125/127/128) parte de peças
> extraídas do PowerPoint (`showroom_import_pecas`) com foto e o usuário vincula cada uma a UM
> `produtos`. Esta SPEC cobre duas capacidades relacionadas: **(A)** o fluxo inverso — partir
> dos produtos que já estão no estoque do showroom (`produtos.estoque_showroom > 0`) e permitir
> subir/trocar a foto (`produtos.imagem_showroom_url`) direto, via upload de arquivo; **(B)**
> "peça composta" — uma mesma foto pode representar um CONJUNTO de vários `produtos` de estoque
> distintos (ex.: base + haste + cúpula), onde 1 produto (o principal) guarda a foto e determina
> o nome exibido, e o valor exibido ao cliente é a soma do valor de venda de todos os produtos
> do conjunto. (B) foi incorporado depois de (A) já estar desenhado — pedido de acompanhamento
> do Pedro na mesma conversa.

## Checklist de Ação

**Fluxo A — fotos do estoque**

- [x] Migration `supabase/db/migrations/20260915_148_showroom_fotos_estoque/001_fotos_estoque.sql`
      (rascunho, **NÃO aplicado no Supabase real**): tabela `showroom_upload_grants`, função
      `showroom_upload_permitido`, 3 policies em `storage.objects` (insert/update/delete,
      escopo `showroom-lucenera/produtos/*`), RPCs `showroom_liberar_upload_produto`,
      `showroom_confirmar_foto_produto`. `showroom_listar_produtos_estoque` foi movida para o
      arquivo `002` (ver nota abaixo — desvio do rascunho original, documentado em Realizado).
- [x] Frontend: `Admin.tsx` vira duas abas ("Vincular do PPT" / "Fotos do estoque", shadcn/ui
      `Tabs`). Mesma sessão de login (credencial já em `sessionStorage`), sem segundo login.
- [x] Novo componente de listagem/busca de produtos com `estoque_showroom > 0` (nome/SKU/código),
      foto atual (ou placeholder) + botão "Adicionar/Trocar foto" com `<input type="file">`
      (`FotosEstoqueTab.tsx`).
- [x] Novo service `src/services/curadoriaEstoque.ts` com `listarProdutosEstoque`,
      `liberarUpload`, `confirmarFoto`, `trocarFotoProduto` (fluxo completo) e as chamadas de
      Storage (`upload`, `remove` condicional).

**Fluxo B — peça composta (novo nesta revisão)**

- [x] Migration (mesmo grupo `20260915_148_...`, arquivo `002_peca_composta.sql`, **NÃO aplicado
      no Supabase real**): tabela `showroom_grupo_itens`, índice único
      `showroom_grupo_itens_membro_unico`, RPCs `showroom_definir_composicao` e
      `showroom_obter_composicao`, `drop`+recriação de `showroom_listar_produtos_estoque`
      (nova) e `showroom_buscar_produto` (2 colunas novas cada: `eh_principal_de_grupo`,
      `membro_de_codigo_produto`), redesenho de `vw_showroom_publico` (2 ramos: peça avulsa e
      conjunto — ver §4.3).
- [x] Frontend: componente compartilhado `src/components/showroom-admin/ComposicaoConjuntoModal.tsx`
      (busca/lista membros, quantidade por membro com stepper, salvar/remover), acionado tanto
      pela aba "Vincular do PPT" (linha "Vinculadas", botão "Gerenciar composição") quanto pela
      aba nova "Fotos do estoque" (qualquer linha).
- [x] Estendido `src/services/curadoria.ts` (compartilhado pelas 2 abas) com `obterComposicao`,
      `definirComposicao`, e os 2 campos novos no tipo `ProdutoBusca`.
- [x] `PecaCard.tsx`/`PecaDetalhe.tsx`/`useVitrine.ts`/`services/showroom.ts` do site público:
      **nenhuma mudança de código feita**, como esperado — `vw_showroom_publico` continua
      devolvendo o mesmo contrato de 9 colunas. Validação visual ao vivo fica pendente da
      aplicação da migration (ver Passos manuais do usuário).

**Comum**

- [x] Criado `04-Sistemas/showroom-qtq8er2dk/supabase/AI_DB_CONTEXT.md` (não existia — gap desde
      a SPEC-125) documentando `produtos.imagem_showroom_url`, `showroom_config`,
      `showroom_import_pecas`, `showroom_upload_grants`, `showroom_grupo_itens` e todas as RPCs
      `showroom_*`.
- [x] Atualizado `supabase/db/domains/cadastros.md` com as tabelas/RPCs novas.
- [x] Atualizado `CHANGELOG.md`.

### Passos manuais do usuário

- [x] Aprovar a abordagem de controle de acesso ao Storage (§8) — **decisão tomada**: Opção B
      (liberação temporária via RPC), confirmada por Pedro em 2026-09-15.
- [x] Confirmar as 3 regras da peça composta (§4.5, Pendências P-6/P-7/P-8) — **todas confirmadas
      por Pedro em 2026-09-15, na opção recomendada**: (1) um produto só pode ser membro de 1
      conjunto por vez; (2) membro inativo dentro de um conjunto ativo zera a disponibilidade do
      conjunto inteiro (conjunto some da vitrine); (3) campo "quantidade" por membro já fica
      disponível na UI desde o dia 1.
- [x] Rodar a migration no Supabase real — **aplicada em 2026-09-15/16** (dry-run com `rollback`
      antes do `commit` real, depois aplicação de `001_fotos_estoque.sql` e `002_peca_composta.sql`
      via Supabase Management API — `psql` direto instável de novo, mesmo contorno já usado na
      SPEC-144). Verificado no banco real: `showroom_upload_grants`, `showroom_grupo_itens` e as 7
      funções `showroom_*` existem; `vw_showroom_publico` mantém exatamente as 9 colunas do
      contrato desde a SPEC-125.
- [ ] Testar ao vivo: (a) subir foto em 1 produto sem foto e trocar foto em 1 produto que já
      tinha, conferindo que o arquivo antigo em `produtos/` some do bucket e que arquivos em
      `import/` não são tocados; (b) montar 1 conjunto de teste com 2–3 produtos e conferir na
      vitrine pública que aparece 1 card só, com nome do principal e valor somado; (c) zerar
      estoque de 1 membro do conjunto de teste e confirmar que o card some da vitrine.
- [ ] Confirmar se vale a pena, nesta SPEC ou numa futura, regenerar `supabase/db/current/`
      (achado: está desatualizado desde a SPEC-125).

### Publicado no Skip

- [x] Escrito na working tree do projeto Skip "Showroom Lucenera" (`projectId 54698`) em
      2026-09-16, sem drift em relação à base local (`Admin.tsx`/`curadoria.ts` conferidos
      idênticos antes da escrita). `skip_project_apply_changes` (modo `production`) com QA
      pipeline 100% `ok` (setup/staticAnalysis/build/integrations/test), versão `0.0.14`
      (`2450c3b`). `skip_project_publish` publicado em produção:
      https://tela-showroom-522b1.goskip.app/admin.
- [x] **Ajuste pós-teste ao vivo (2026-09-16)**: Pedro pediu pra trocar o campo `sku` (text)
      pelo `codigo_legado` (int) — é o identificador que o time reconhece na tela. Migration
      `003_codigo_legado_no_lugar_do_sku.sql` (recria `showroom_listar_produtos_estoque`,
      `showroom_buscar_produto`, `showroom_obter_composicao` trocando a coluna retornada/campo
      pesquisado) aplicada no Supabase real (dry-run + commit real, mesmo fluxo). Frontend
      (`ProdutoEstoque`, `MembroComposicao`, `FotosEstoqueTab`, `ComposicaoConjuntoModal`,
      `PPTTab`) atualizado e republicado no Skip: versão `0.0.15` (`5c23871`).

## Objetivo

Dar ao time duas formas novas de alimentar a vitrine pública do showroom sem depender do
PowerPoint importado: **(A)** subir/trocar a foto de um produto já em estoque diretamente, por
upload de arquivo; **(B)** representar, com uma única foto, um conjunto de vários produtos de
estoque fisicamente vendidos juntos (ex.: luminária = base + haste + cúpula), com nome do produto
principal e valor somado de todo o conjunto.

## Decisões aprovadas

- **Upload de arquivo, não campo de URL** — decidido com o usuário via pergunta direta.
- **Controle de acesso ao Storage: Opção B (liberação temporária via RPC)** — decidido com o
  usuário via pergunta direta em 2026-09-15 (ver §8). Nenhum upload acontece sem antes passar
  pela credencial do `/admin`.
- **Reaproveita o bucket `showroom-lucenera`**, em pasta nova `produtos/` (a pasta `import/`
  existente é do fluxo PPT e não deve ser tocada por este fluxo — ver §9).
- **Nova aba dentro da mesma tela `/admin`**, reaproveitando a sessão/credencial já existente
  (`showroom_config` / `showroom_login`) — sem segundo login.
- **Escopo de listagem (fluxo A)**: produtos com `estoque_showroom > 0`, com ou sem foto já
  cadastrada, com busca por nome/SKU/código do produto.
- **Peça composta (fluxo B)**: 1 produto principal guarda a foto e o nome exibido; N produtos
  membros contribuem valor e limitam a disponibilidade do conjunto. Identidade da "peça exibida"
  na vitrine continua sendo `codigo_produto` do principal (mesma rota `/peca/:codigo`, mesma
  mensagem de WhatsApp).
- **Gestão de composição é uma funcionalidade transversal às duas abas** de `/admin` (PPT e
  estoque) — mesmo componente/modal, acionado a partir de qualquer produto principal já
  vinculado, em qualquer uma das duas telas.

## Definição da SPEC

### 1. Estado atual confirmado no código/banco

- `04-Sistemas/showroom-qtq8er2dk/src/pages/Admin.tsx` — hoje é view única: login (usuário +
  senha) → lista "A vincular" / "Vinculadas" de `showroom_import_pecas`.
- `src/services/curadoria.ts` — `login()`, `listarImportPecas()`, `buscarProduto()`,
  `vincular()`, `desvincular()`. Credencial (`{user, senha}`) fica em `sessionStorage`
  (`showroom_admin_cred`), nunca no bundle; enviada em toda RPC.
- `src/lib/supabase/client.ts` — cliente **sempre anônimo** (chave `VITE_SUPABASE_PUBLISHABLE_KEY`,
  sem `persistSession`). O sistema **nunca** usa Supabase Auth — não existe sessão
  `authenticated`, só `anon`. Isso vale hoje e depois desta SPEC (as duas capacidades A e B).
- `vw_showroom_publico` (migration `20260831_126`) hoje é **1 linha por `produtos.codigo_produto`**,
  filtra `ativo AND imagem_showroom_url IS NOT NULL AND estoque_showroom > 0`, expõe
  `codigo_produto, nome, marca, categoria, estoque_showroom, valor_venda, descricao_tecnica,
  imagem_showroom_url, atualizado_em`. `PecaDetalhe.tsx`/`PecaCard.tsx`/`useVitrine.ts` (site
  público) consomem só essa view — **é o contrato que precisa continuar valendo** depois do
  redesenho da §4.3 (1 linha por "peça exibida", mesmas colunas, mesmo significado).
- Banco (aplicado, confirmado nas migrations 126/127/128/137, mesmo não estando no snapshot —
  ver achado §11): `produtos.imagem_showroom_url text`, `produtos.estoque_showroom int`,
  `produtos.codigo_produto int` (único via `produtos_codigo_produto_key`), `showroom_config`
  (credencial hash, RLS sem policy), `showroom_import_pecas` (peças do PPT, RLS select livre),
  `showroom_cred_ok(p_user,p_senha)` (helper interno), `showroom_login/vincular_peca/
  desvincular_peca(p_user,p_senha,...)`, `showroom_buscar_produto(p_termo)` (SECURITY DEFINER,
  **sem** credencial — já expõe só whitelist não sensível: código, nome, marca,
  estoque_showroom, valor_venda).
- Bucket `showroom-lucenera`: público, 5 MB, `jpeg/jpg/png/webp`. Policy de leitura pública
  (`anon`+`authenticated`). **Escrita hoje só via `service_role`** (scripts de import) — não
  existe policy de INSERT/UPDATE/DELETE para `anon`/`authenticated` neste bucket.
- Precedente no ecossistema: `catalogo-pecas-ubiqua-e6fa0` já faz upload direto do client, mas as
  policies daquele bucket são `TO authenticated` (Supabase Auth de verdade) — **não reaproveitável
  aqui** porque o showroom nunca tem sessão `authenticated`.

### 2. Panorama das duas capacidades

| | Fluxo A — fotos do estoque | Fluxo B — peça composta |
|---|---|---|
| Problema | Peça já está em estoque mas não tem foto do PPT | 1 foto física representa N produtos de estoque |
| Onde mexe | Storage (upload) + `produtos.imagem_showroom_url` | Nova tabela de junção + `vw_showroom_publico` |
| Aba de `/admin` | Nova ("Fotos do estoque") | Ação disponível nas duas abas (modal de composição) |
| Depende de | — | Pode ser combinado com A (subir foto de um produto que também é principal de um conjunto) |

As duas capacidades são independentes tecnicamente (dá pra implementar A sem B), mas B foi
desenhado já considerando que o produto principal de um conjunto pode ter sua foto vinda tanto do
PPT quanto do upload novo — por isso a composição vive num nível acima da foto, referenciando só
`codigo_produto`.

### 3. Nova aba "Fotos do estoque" (Fluxo A)

- Lista produtos com `estoque_showroom > 0` (com ou sem foto), busca por nome/SKU/código.
- Cada linha/card: foto atual (thumb, mesmo componente `Thumb` já existente, com placeholder se
  `imagem_showroom_url` for nulo) + nome + código + SKU + estoque + botão "Adicionar foto" /
  "Trocar foto" + botão "Gerenciar composição" (ver §4.4) + badges quando aplicável:
  "Conjunto (N produtos)" se `eh_principal_de_grupo`, ou "Já está no conjunto de #<código>"
  (desabilitando upload/composição própria) se `membro_de_codigo_produto` vier preenchido.
- Reaproveita a mesma sessão (`cred` já lido do `sessionStorage` no componente `Admin.tsx` pai) —
  se a aba for aberta sem login, mostra o mesmo `LoginForm` já existente.

### 4. Peça composta: 1 foto, N produtos (Fluxo B)

#### 4.1 Modelo de dados: `showroom_grupo_itens`

```sql
create table if not exists public.showroom_grupo_itens (
  codigo_produto_principal int not null references public.produtos(codigo_produto),
  codigo_produto_membro    int not null references public.produtos(codigo_produto),
  quantidade               int not null default 1 check (quantidade > 0),
  criado_em                timestamptz not null default now(),
  criado_por               text,
  primary key (codigo_produto_principal, codigo_produto_membro),
  check (codigo_produto_membro <> codigo_produto_principal)
);
comment on table public.showroom_grupo_itens is
  'SPEC-148: peca composta do showroom -- N produtos de estoque vinculados a 1 foto/produto '
  'principal. Nome exibido = produtos.nome do principal. Valor exibido = valor_venda do '
  'principal + soma(valor_venda * quantidade) dos membros. Estoque exibido = minimo de '
  '"conjuntos completos" possiveis entre principal e membros.';

-- Um produto so pode ser membro de, no maximo, 1 conjunto por vez (ver §4.5 -- recomendacao,
-- nao travada sozinho: confirmar com Pedro).
create unique index if not exists showroom_grupo_itens_membro_unico
  on public.showroom_grupo_itens (codigo_produto_membro);

alter table public.showroom_grupo_itens enable row level security;
-- Sem policy de select/insert/update/delete p/ anon/authenticated -- so e lida/escrita via RPC
-- SECURITY DEFINER (showroom_definir_composicao/showroom_obter_composicao) e pela view publica
-- (que roda como owner/postgres, bypassa RLS -- mesmo padrao ja usado em vw_showroom_publico
-- desde a migration 126).
```

O **principal não tem uma linha própria** nesta tabela (não é "membro de si mesmo") — sua
identidade já é `produtos.codigo_produto` + `produtos.imagem_showroom_url`. A tabela só guarda os
produtos adicionais que compõem o conjunto.

#### 4.2 RPCs de composição

```sql
create or replace function public.showroom_definir_composicao(
  p_user text, p_senha text, p_codigo_produto_principal int, p_membros jsonb
) returns jsonb
language plpgsql security definer set search_path = public
as $$
declare
  v_membro record;
  v_count  int;
begin
  if not public.showroom_cred_ok(p_user, p_senha) then
    raise exception 'usuario ou senha invalidos' using errcode = '28000';
  end if;

  if not exists (select 1 from public.produtos where codigo_produto = p_codigo_produto_principal and ativo) then
    raise exception 'produto principal % nao encontrado/ativo', p_codigo_produto_principal using errcode = 'P0002';
  end if;

  -- principal nao pode, ele mesmo, ja ser membro de outro conjunto
  if exists (select 1 from public.showroom_grupo_itens g where g.codigo_produto_membro = p_codigo_produto_principal) then
    raise exception 'produto % ja e membro de outro conjunto, nao pode virar principal', p_codigo_produto_principal using errcode = '22000';
  end if;

  -- valida o payload inteiro ANTES de tocar em qualquer dado (evita rollback no meio)
  for v_membro in
    select (elem->>'codigo_produto')::int as codigo_produto,
           coalesce((elem->>'quantidade')::int, 1) as quantidade
    from jsonb_array_elements(coalesce(p_membros, '[]'::jsonb)) elem
  loop
    if v_membro.codigo_produto is null or v_membro.codigo_produto = p_codigo_produto_principal then
      raise exception 'membro invalido (codigo % invalido ou igual ao principal)', v_membro.codigo_produto using errcode = '22000';
    end if;
    if v_membro.quantidade < 1 then
      raise exception 'quantidade invalida para produto %', v_membro.codigo_produto using errcode = '22000';
    end if;
    if not exists (select 1 from public.produtos where codigo_produto = v_membro.codigo_produto and ativo) then
      raise exception 'produto membro % nao encontrado/ativo', v_membro.codigo_produto using errcode = 'P0002';
    end if;
    if exists (select 1 from public.showroom_grupo_itens g where g.codigo_produto_principal = v_membro.codigo_produto) then
      raise exception 'produto % ja e principal de outro conjunto', v_membro.codigo_produto using errcode = '22000';
    end if;
    if exists (
      select 1 from public.showroom_grupo_itens g
      where g.codigo_produto_membro = v_membro.codigo_produto
        and g.codigo_produto_principal <> p_codigo_produto_principal
    ) then
      raise exception 'produto % ja pertence a outro conjunto', v_membro.codigo_produto using errcode = '22000';
    end if;
  end loop;

  delete from public.showroom_grupo_itens where codigo_produto_principal = p_codigo_produto_principal;

  insert into public.showroom_grupo_itens (codigo_produto_principal, codigo_produto_membro, quantidade, criado_por)
  select p_codigo_produto_principal, (elem->>'codigo_produto')::int, coalesce((elem->>'quantidade')::int, 1), p_user
  from jsonb_array_elements(coalesce(p_membros, '[]'::jsonb)) elem;

  get diagnostics v_count = row_count;
  return jsonb_build_object('ok', true, 'codigo_produto_principal', p_codigo_produto_principal, 'membros', v_count);
end;
$$;

create or replace function public.showroom_obter_composicao(p_codigo_produto_principal int)
returns table (codigo_produto int, nome text, sku text, estoque_showroom int, valor_venda numeric, quantidade int)
language sql stable security definer set search_path = public
as $$
  select p.codigo_produto, p.nome, p.sku, coalesce(p.estoque_showroom,0), coalesce(p.valor_venda,0), g.quantidade
  from public.showroom_grupo_itens g
  join public.produtos p on p.codigo_produto = g.codigo_produto_membro
  where g.codigo_produto_principal = p_codigo_produto_principal
  order by p.nome;
$$;

grant execute on function public.showroom_definir_composicao(text,text,int,jsonb) to anon, authenticated;
grant execute on function public.showroom_obter_composicao(int) to anon, authenticated;
```

`showroom_definir_composicao` é **substituição total e idempotente** da lista de membros de um
principal — mandar `[]` limpa o conjunto (produto volta a ser peça avulsa). Não existe RPC
separada de "remover 1 membro"; a UI sempre manda a lista completa de novo (igual ao padrão
"replace" já usado noutros pontos do ecossistema, ex. `replace_orcamento_itens`).

#### 4.3 Redesenho de `vw_showroom_publico`

```sql
drop view if exists public.vw_showroom_publico;

create view public.vw_showroom_publico as
with avulsas as (
  select
    p.codigo_produto, p.nome, m.nome as marca,
    coalesce(cp.nome, nullif(p.categoria, '')) as categoria,
    p.estoque_showroom::int as estoque_showroom,
    coalesce(p.valor_venda, 0)::numeric as valor_venda,
    nullif(p.descricao_tecnica, '') as descricao_tecnica,
    p.imagem_showroom_url, p.updated_at as atualizado_em
  from public.produtos p
  left join public.marcas m on m.id = p.marca_id
  left join public.categorias_produto cp on cp.id = p.categoria_id
  where p.ativo
    and p.imagem_showroom_url is not null and p.imagem_showroom_url <> ''
    and coalesce(p.estoque_showroom, 0) > 0
    -- exclui quem e membro de algum conjunto (nao aparece avulso, ja esta "dentro" do principal)
    and not exists (select 1 from public.showroom_grupo_itens g where g.codigo_produto_membro = p.codigo_produto)
    -- exclui quem E principal de algum conjunto (esse vai pelo ramo "conjuntos" abaixo, com valor/estoque agregados)
    and not exists (select 1 from public.showroom_grupo_itens g where g.codigo_produto_principal = p.codigo_produto)
),
conjuntos_agregado as (
  select
    g.codigo_produto_principal,
    sum(coalesce(pm.valor_venda,0) * g.quantidade) as valor_membros,
    -- "quantos conjuntos completos dá pra montar" olhando só os membros; membro inativo conta
    -- como estoque 0 (ver §4.5 -- recomendacao a confirmar)
    min(floor((case when pm.ativo then coalesce(pm.estoque_showroom,0) else 0 end)::numeric / g.quantidade))::int as min_conjuntos_membros
  from public.showroom_grupo_itens g
  join public.produtos pm on pm.codigo_produto = g.codigo_produto_membro
  group by g.codigo_produto_principal
),
conjuntos as (
  select
    pr.codigo_produto, pr.nome, mpr.nome as marca,
    coalesce(cppr.nome, nullif(pr.categoria, '')) as categoria,
    least(coalesce(pr.estoque_showroom,0), coalesce(ca.min_conjuntos_membros, 0))::int as estoque_showroom,
    (coalesce(pr.valor_venda,0) + coalesce(ca.valor_membros,0))::numeric as valor_venda,
    nullif(pr.descricao_tecnica, '') as descricao_tecnica,
    pr.imagem_showroom_url, pr.updated_at as atualizado_em
  from conjuntos_agregado ca
  join public.produtos pr on pr.codigo_produto = ca.codigo_produto_principal
  left join public.marcas mpr on mpr.id = pr.marca_id
  left join public.categorias_produto cppr on cppr.id = pr.categoria_id
  where pr.ativo and pr.imagem_showroom_url is not null and pr.imagem_showroom_url <> ''
)
select * from avulsas
union all
select * from conjuntos where estoque_showroom > 0;

comment on view public.vw_showroom_publico is
  'SPEC-125 + SPEC-148: superficie somente-leitura e anonima do showroom. 1 linha por "peca '
  'exibida" -- avulsa (1 produto) ou conjunto (1 principal + N membros, valor somado, estoque '
  '= minimo de conjuntos completos). Mesmo contrato de colunas desde a SPEC-125.';

grant select on public.vw_showroom_publico to anon;
revoke insert, update, delete, truncate, references, trigger on public.vw_showroom_publico from anon, authenticated;
```

**Contrato preservado**: mesmas 9 colunas, `codigo_produto` continua sendo o identificador da
peça exibida (do principal, quando for conjunto) — `PecaDetalhe.tsx`/`PecaCard.tsx`/
`useVitrine.ts` não precisam mudar.

**Casos que já se resolvem sozinhos pela fórmula** (não são decisão de negócio, são consequência
direta do cálculo — cito aqui só pra deixar claro que pensei neles, não precisam de confirmação):

- Principal desativado (`ativo = false`) → some da vitrine (mesmo filtro de sempre).
- Principal com `estoque_showroom = 0` → `LEAST(0, ...)` zera o conjunto → some da vitrine.

#### 4.4 UI: componente compartilhado de composição

`src/components/showroom-admin/ComposicaoConjuntoModal.tsx` — recebe `codigoProdutoPrincipal` +
`nomePrincipal`, usado tanto pela aba "Vincular do PPT" (botão na lista "Vinculadas", ao lado de
"Desfazer") quanto pela aba nova "Fotos do estoque" (botão em cada linha).

- Carrega composição atual via `obterComposicao(codigoProdutoPrincipal)`.
- Lista membros atuais: nome, código, estoque, valor, campo de quantidade (stepper, mínimo 1,
  default 1), botão remover (X).
- Campo de busca (mesmo padrão do `BuscaProduto` já existente) pra adicionar novo membro —
  resultado mostra badge/desabilita quando `eh_principal_de_grupo` ("já é peça própria") ou
  `membro_de_codigo_produto` aponta pra outro principal ("já está em outro conjunto #N").
- Rodapé com prévia client-side (não autoritativa, só feedback): "Valor exibido: R$ X (N
  produtos)" e "Estoque de conjuntos completos: Y" — espelha a mesma fórmula da view, calculada
  em cima dos dados já carregados na tela.
- Botão "Salvar composição" → `definirComposicao(cred, codigoProdutoPrincipal, membros[])` —
  manda a lista inteira (substituição total, ver §4.2). Botão "Limpar conjunto" (mesma RPC com
  `[]`) volta o produto a ser peça avulsa.

#### 4.5 Pontos que ficaram como recomendação, não como decisão travada

Peço confirmação explícita de Pedro antes de implementar (controle de acesso e regra de
estoque/orfandade são categorias que não decido sozinho):

1. **Um produto pode ser membro de mais de 1 conjunto ao mesmo tempo?** Recomendo **não**
   (índice único em `codigo_produto_membro`, §4.1). Trade-off: se a mesma peça física (ex. uma
   cúpula-modelo) for usada em 2 conjuntos visuais diferentes, o modelo atual não permite —
   teria que virar 2 produtos de estoque diferentes (ou revisitar esta regra depois, trocando a
   lógica de disponibilidade por algo mais complexo, tipo "estoque compartilhado ponderado").
2. **Membro inativo (`ativo = false`) dentro de um conjunto ainda ativo** — recomendo tratar como
   estoque 0 pra esse membro (zera a disponibilidade do conjunto inteiro até alguém corrigir a
   composição), em vez de ignorar o membro inativo no cálculo. Rationale: nunca "vender" um
   conjunto que depende de uma peça que a própria equipe marcou como inativa.
3. **Quantidade por membro > 1** — o pedido original do usuário só menciona 1 unidade de cada
   parte, mas a coluna `quantidade` já existe e a UI (§4.4) já expõe o campo, então a
   funcionalidade fica completa desde o dia 1 em vez de "coluna que ninguém usa". Baixo risco,
   decisão de escopo de UI, não de regra de negócio — segui em frente, mas fica registrado.

### 5. Tabela `showroom_upload_grants` (Fluxo A)

Controla, por produto, uma "liberação temporária" de upload — é o mecanismo central da §8.

```sql
create table if not exists public.showroom_upload_grants (
  codigo_produto  int primary key references public.produtos(codigo_produto),
  path            text not null,       -- caminho novo liberado p/ INSERT/UPDATE (produtos/...)
  old_path        text,                -- caminho antigo liberado p/ DELETE (só se também for produtos/...)
  criado_por      text not null,       -- admin_user que gerou a liberação
  criado_em       timestamptz not null default now(),
  expira_em       timestamptz not null default now() + interval '15 minutes'
);
alter table public.showroom_upload_grants enable row level security;
-- RLS on, SEM policy de select/insert/update/delete p/ anon/authenticated:
-- só é lida pela função SECURITY DEFINER usada nas policies de storage.objects.
```

### 6. RPCs de upload (Fluxo A)

**Leitura (sem credencial — mesmo padrão de `showroom_buscar_produto`, expõe só whitelist não
sensível; agora com as 2 colunas de composição):**

```sql
drop function if exists public.showroom_listar_produtos_estoque(text);
create or replace function public.showroom_listar_produtos_estoque(p_termo text default null)
returns table (
  codigo_produto int, nome text, sku text, referencia text,
  estoque_showroom int, imagem_showroom_url text, marca text,
  eh_principal_de_grupo boolean, membro_de_codigo_produto int
)
language sql stable security definer set search_path = public
as $$
  select p.codigo_produto, p.nome, p.sku, p.referencia,
         coalesce(p.estoque_showroom,0), p.imagem_showroom_url, m.nome,
         exists(select 1 from public.showroom_grupo_itens g1 where g1.codigo_produto_principal = p.codigo_produto),
         (select g2.codigo_produto_principal from public.showroom_grupo_itens g2 where g2.codigo_produto_membro = p.codigo_produto)
  from public.produtos p
  left join public.marcas m on m.id = p.marca_id
  where p.ativo
    and coalesce(p.estoque_showroom,0) > 0
    and (
      p_termo is null or p_termo = ''
      or p.nome ilike '%'||p_termo||'%'
      or p.sku ilike '%'||p_termo||'%'
      or p.referencia ilike '%'||p_termo||'%'
      or p.codigo_produto::text = p_termo
    )
  order by (p.imagem_showroom_url is null) desc, p.nome
  limit 1000;
$$;
grant execute on function public.showroom_listar_produtos_estoque(text) to anon, authenticated;

drop function if exists public.showroom_buscar_produto(text);
create or replace function public.showroom_buscar_produto(p_termo text)
returns table (
  codigo_produto int, nome text, marca text, estoque_showroom int, valor_venda numeric,
  eh_principal_de_grupo boolean, membro_de_codigo_produto int
)
language sql stable security definer set search_path = public
as $$
  select p.codigo_produto, p.nome, m.nome, coalesce(p.estoque_showroom,0), coalesce(p.valor_venda,0),
         exists(select 1 from public.showroom_grupo_itens g1 where g1.codigo_produto_principal = p.codigo_produto),
         (select g2.codigo_produto_principal from public.showroom_grupo_itens g2 where g2.codigo_produto_membro = p.codigo_produto)
  from public.produtos p
  left join public.marcas m on m.id = p.marca_id
  where p.ativo
    and (
      p.codigo_produto::text = p_termo
      or p.nome ilike '%' || p_termo || '%'
      or p.sku ilike '%' || p_termo || '%'
      or p.referencia ilike '%' || p_termo || '%'
    )
  order by (p.codigo_produto::text = p_termo) desc, p.nome
  limit 20;
$$;
grant execute on function public.showroom_buscar_produto(text) to anon, authenticated;
```

> Nota: hoje `produtos` com `estoque_showroom > 0` são ~266 (achado da SPEC-125). `limit 1000`
> cobre isso com folga; se crescer muito, paginar (mesma lição da SPEC-081).

**Escrita — credencial obrigatória (reaproveita `showroom_cred_ok`, migration 128):**

```sql
create or replace function public.showroom_liberar_upload_produto(
  p_user text, p_senha text, p_codigo_produto int, p_extensao text
) returns jsonb
language plpgsql security definer set search_path = public
as $$
declare
  v_ext text := lower(p_extensao);
  v_old_url text;
  v_path text;
  v_old_path text;
begin
  if not public.showroom_cred_ok(p_user, p_senha) then
    raise exception 'usuario ou senha invalidos' using errcode = '28000';
  end if;
  if v_ext not in ('jpg','jpeg','png','webp') then
    raise exception 'extensao nao suportada: %', p_extensao using errcode = '22000';
  end if;

  select imagem_showroom_url into v_old_url
  from public.produtos where codigo_produto = p_codigo_produto and ativo;
  if not found then
    raise exception 'produto codigo % nao encontrado/ativo', p_codigo_produto using errcode = 'P0002';
  end if;

  v_path := 'produtos/' || p_codigo_produto || '_' || extract(epoch from now())::bigint || '.' || v_ext;

  -- Só libera DELETE do arquivo antigo se ele for desta MESMA pasta (produtos/).
  -- Nunca libera delete de algo em import/ — ver §9.
  if v_old_url like '%/storage/v1/object/public/showroom-lucenera/produtos/%' then
    v_old_path := split_part(v_old_url, '/storage/v1/object/public/showroom-lucenera/', 2);
  end if;

  insert into public.showroom_upload_grants (codigo_produto, path, old_path, criado_por)
  values (p_codigo_produto, v_path, v_old_path, p_user)
  on conflict (codigo_produto) do update
    set path = excluded.path, old_path = excluded.old_path,
        criado_por = excluded.criado_por, criado_em = now(),
        expira_em = now() + interval '15 minutes';

  return jsonb_build_object('path', v_path, 'old_path', v_old_path);
end;
$$;

create or replace function public.showroom_confirmar_foto_produto(
  p_user text, p_senha text, p_codigo_produto int, p_url_publica text
) returns jsonb
language plpgsql security definer set search_path = public
as $$
declare
  v_grant public.showroom_upload_grants%rowtype;
begin
  if not public.showroom_cred_ok(p_user, p_senha) then
    raise exception 'usuario ou senha invalidos' using errcode = '28000';
  end if;

  select * into v_grant from public.showroom_upload_grants
  where codigo_produto = p_codigo_produto and expira_em > now();
  if not found then
    raise exception 'nenhuma liberacao de upload valida para o produto %', p_codigo_produto using errcode = 'P0002';
  end if;

  if position(('/showroom-lucenera/' || v_grant.path) in p_url_publica) = 0 then
    raise exception 'url nao corresponde ao path liberado' using errcode = '22000';
  end if;

  if not exists (select 1 from storage.objects where bucket_id = 'showroom-lucenera' and name = v_grant.path) then
    raise exception 'arquivo nao encontrado no storage: %', v_grant.path using errcode = 'P0002';
  end if;

  update public.produtos
     set imagem_showroom_url = p_url_publica, updated_at = now()
   where codigo_produto = p_codigo_produto;

  delete from public.showroom_upload_grants where codigo_produto = p_codigo_produto;

  return jsonb_build_object('ok', true, 'url', p_url_publica, 'old_path', v_grant.old_path);
end;
$$;

grant execute on function public.showroom_liberar_upload_produto(text,text,int,text) to anon, authenticated;
grant execute on function public.showroom_confirmar_foto_produto(text,text,int,text) to anon, authenticated;
```

### 7. Storage: policies de `storage.objects` (Fluxo A)

```sql
create or replace function public.showroom_upload_permitido(p_bucket text, p_name text)
returns boolean
language sql stable security definer set search_path = public
as $$
  select exists (
    select 1 from public.showroom_upload_grants g
    where p_bucket = 'showroom-lucenera'
      and g.expira_em > now()
      and (g.path = p_name or g.old_path = p_name)
  );
$$;
grant execute on function public.showroom_upload_permitido(text,text) to anon, authenticated;

create policy showroom_produtos_upload
on storage.objects for insert to anon, authenticated
with check (
  bucket_id = 'showroom-lucenera'
  and (storage.foldername(name))[1] = 'produtos'
  and public.showroom_upload_permitido(bucket_id, name)
);

create policy showroom_produtos_update
on storage.objects for update to anon, authenticated
using (
  bucket_id = 'showroom-lucenera'
  and (storage.foldername(name))[1] = 'produtos'
  and public.showroom_upload_permitido(bucket_id, name)
);

create policy showroom_produtos_delete
on storage.objects for delete to anon, authenticated
using (
  bucket_id = 'showroom-lucenera'
  and (storage.foldername(name))[1] = 'produtos'
  and public.showroom_upload_permitido(bucket_id, name)
);
-- Nada muda na policy de leitura publica existente (showroom_lucenera_public_read)
-- nem nas policies do bucket 'revenda-ubiqua-images'/'orcamentos' (outros sistemas).
```

### 8. Ponto mais delicado: como restringir quem sobe arquivo, sem Supabase Auth real

O problema: `storage.objects` RLS roda com o **role** da requisição (aqui, sempre `anon` — a
chave anônima fica no bundle público, e o "login" deste sistema é só uma RPC que confere hash
numa tabela, não cria sessão Supabase). Uma policy de Storage **não enxerga** a credencial
(`user`/`senha`) que o usuário digitou — ela só vê `bucket_id`, `name` (path) e o role da
requisição.

- **Opção A — simples (mesmo padrão já usado no bucket `orcamentos`):** policy de
  INSERT/UPDATE/DELETE liberando `anon` só pelo prefixo `produtos/`. **Risco:** qualquer pessoa
  que descubra o endpoint pode subir/sobrescrever/apagar arquivos sem passar pelo login.
- **Opção B — ESCOLHIDA (2026-09-15):** a policy de Storage só libera INSERT/UPDATE/DELETE para
  um `path` específico com uma linha não expirada em `showroom_upload_grants` — criada só por
  RPC que exige credencial válida (§6). Fecha o buraco da Opção A.

### 9. Achado importante: não apagar arquivos de `import/`

`showroom_import_pecas.imagem_url` (usada na aba "A vincular"/"Vinculadas" já existente) aponta
pro mesmo arquivo físico que pode estar, hoje, em `produtos.imagem_showroom_url` (copiado pela
RPC `showroom_vincular_peca`). Por isso `showroom_liberar_upload_produto` (§6) só libera DELETE
do arquivo antigo quando ele já estiver em `produtos/` (subido por este fluxo novo, não pelo
import do PPT). Trocar a foto de um produto vinculado ao PPT pela primeira vez, por esta aba nova,
**não apaga** o arquivo do PPT — só passa a apontar `produtos.imagem_showroom_url` pro novo
arquivo em `produtos/`.

### 10. Fluxo passo a passo — Fluxo A (upload de foto)

1. Usuário abre aba "Fotos do estoque" → `listarProdutosEstoque(termo?)`.
2. Escolhe um produto, seleciona arquivo (`<input type="file" accept="image/jpeg,image/png,image/webp">`).
   Frontend valida tamanho (≤ 5 MB) e tipo antes de chamar qualquer RPC.
3. `liberarUpload(cred, codigo_produto, extensao)` → retorna `{ path, old_path }`.
4. `supabase.storage.from('showroom-lucenera').upload(path, file, { upsert: true, contentType })`.
5. `getPublicUrl(path)` monta a URL pública.
6. `confirmarFoto(cred, codigo_produto, url)` → grava `produtos.imagem_showroom_url`, consome a
   liberação, retorna `old_path`.
7. Se `old_path` veio preenchido, `remove([old_path])` — só depois do passo 6 confirmar sucesso.
8. UI atualiza a foto exibida. **Efeito colateral esperado**: se o produto já tinha
   `estoque_showroom > 0`, aparece automaticamente na vitrine pública.

### 11. Fluxo passo a passo — Fluxo B (definir composição)

1. Em qualquer uma das 2 abas, usuário clica "Gerenciar composição" num produto/peça já vinculado
   a um `codigo_produto` (o principal).
2. Modal carrega `obterComposicao(codigo_produto_principal)` → lista atual de membros.
3. Usuário busca produtos candidatos (`buscarProduto`/`listarProdutosEstoque`, já com os 2 campos
   novos) — resultados já vinculados a outro grupo aparecem desabilitados com o motivo.
4. Usuário adiciona/remove membros na lista local, ajusta quantidade (default 1).
5. "Salvar composição" → `definirComposicao(cred, codigo_produto_principal, membros[])`
   (substituição total).
6. Modal fecha, lista/card do principal atualiza badge "Conjunto (N produtos)". Efeito colateral
   esperado: a vitrine pública passa a mostrar 1 card (o principal) com valor somado e estoque
   recalculado; os N-1 membros somem de qualquer listagem avulsa da vitrine (continuam
   aparecendo normalmente nas listagens internas de `/admin`, só marcados como "em conjunto").

### 12. Análise de ecossistema (obrigatória)

- **Depende de**: `produtos` (`codigo_produto`, `nome`, `sku`, `referencia`, `estoque_showroom`,
  `imagem_showroom_url`, `ativo`, `marca_id`, `valor_venda`, `updated_at`). Nenhuma dependência
  de `projetos`/`orcamentos`/`contatos`/`boletos`/`projeto_itens`/`projeto_parcelas`/`usuarios`/
  `systems`/`user_system_access`.
- **Afeta**: só o sistema Showroom. Não toca CRM, Orçamentos, Financeiro, Cadastro,
  Estoque/Compras, Logística, RH ou Hub/TI — `imagem_showroom_url` e `showroom_grupo_itens` são
  exclusivos do showroom (conferido: nenhuma menção em `cadastro-lucenera-b86fe`, o sistema que
  edita `produtos` de verdade). **Importante**: `showroom_grupo_itens` não altera
  `produtos.estoque_showroom` nem `produtos.valor_venda` — o agrupamento é só de exibição na
  view; o estoque real de cada peça física continua individual em `produtos`, igual sempre foi
  (nenhuma duplicação/gravação cruzada entre produtos do mesmo conjunto).
- **Dado duplicado que deveria ser derivado**: nenhum novo. `showroom_upload_grants` é transiente
  (TTL 15 min). `showroom_grupo_itens` é relação pura (FKs pra `produtos`), sem duplicar
  nome/valor/estoque — tudo isso é lido ao vivo de `produtos` na view (§4.3), nunca copiado.
- **Migration antiga que contradiz o snapshot central**: **sim, achado relevante**.
  `supabase/db/current/01_schema_full.sql` não tem `produtos.imagem_showroom_url` nem as tabelas
  `showroom_config`/`showroom_import_pecas` nem nenhuma função `showroom_*`, embora as migrations
  126/127/128/137 estejam aplicadas no Supabase real. Snapshot desatualizado desde 2026-08-31 —
  implementador precisa ler o banco real, não o snapshot, e regenerar depois.
- **Exige atualizar `AI_DB_CONTEXT.md`**: sim — o sistema `showroom-qtq8er2dk` não tem esse
  arquivo hoje.
- **Padrão de acesso a dados do sistema afetado**: `services/*.ts` com funções puras chamando
  `db.from()/db.rpc()`, sem hook de estado global nem store — só `useState`/`useCallback` no
  componente. Credencial explícita por chamada. Esta SPEC segue o mesmo padrão para os 2 fluxos.

## Realizado

**2026-09-15 — implementado (banco em rascunho, frontend completo).**

- **Banco (rascunho, NÃO aplicado no Supabase real)**:
  `supabase/db/migrations/20260915_148_showroom_fotos_estoque/001_fotos_estoque.sql` e
  `002_peca_composta.sql`, copiados fielmente do SQL da SPEC (§5–§7 e §4.1–§4.3), envolvidos em
  `begin;`/`commit;`, com cabeçalho `RASCUNHO — não aplicar sem aprovação.` no mesmo padrão das
  migrations 125/126/127/128.
  - **Desvio do enunciado desta tarefa** (documentado, não é regra de negócio): a definição da
    SPEC (Checklist "Fluxo A") lista `showroom_listar_produtos_estoque` como parte da migration
    `001`, mas o SQL definitivo da função (§6 da SPEC) já nasce com as 2 colunas de composição
    (`eh_principal_de_grupo`/`membro_de_codigo_produto`) que só existem depois de
    `showroom_grupo_itens` ser criada. Criar essa função em `001` sem essas colunas e
    dropar/recriar 3 linhas de SQL depois em `002` seria trabalho redundante sem propósito —
    optei por criar `showroom_listar_produtos_estoque` uma única vez, já completa, em `002`
    (que já teria que fazer `drop function if exists` dela de qualquer forma, conforme a
    própria SPEC pede explicitamente no Checklist do Fluxo B: "`drop`+recriação de
    `showroom_listar_produtos_estoque` (nova, ainda não existe)"). O resultado final aplicado
    no banco é idêntico ao que o rascunho da SPEC descreve; só a divisão entre os 2 arquivos
    mudou. `001` documenta essa decisão em comentário.
- **Frontend (`04-Sistemas/showroom-qtq8er2dk`)**:
  - `src/pages/Admin.tsx` reescrito: mantém `LoginForm`/`sessionStorage` (`showroom_admin_cred`)
    exatamente como antes, agora renderiza `<Tabs>` (shadcn/ui) com "Vincular do PPT" e "Fotos
    do estoque".
  - `src/components/showroom-admin/PPTTab.tsx` — conteúdo antigo de `Admin.tsx` (lista "A
    vincular"/"Vinculadas", `BuscaProduto`), sem mudança de lógica, + botão novo "Gerenciar
    composição" na lista "Vinculadas".
  - `src/components/showroom-admin/FotosEstoqueTab.tsx` — aba nova: lista
    `listarProdutosEstoque` (debounce de busca 300ms, mesmo padrão do resto do sistema), thumb +
    badges "Conjunto (N produtos)"/"Já está no conjunto de #X", botão "Adicionar/Trocar foto"
    (`<input type="file" accept="image/jpeg,image/png,image/webp">` oculto, disparado por
    clique) com validação client-side de tipo e tamanho (≤5MB) antes de chamar
    `trocarFotoProduto`, e botão "Gerenciar composição". Produto que já é membro de outro
    conjunto tem upload/composição desabilitados (só pode ser gerenciado pelo principal).
  - `src/components/showroom-admin/Thumb.tsx` — `Thumb` extraído de `Admin.tsx` (era local),
    compartilhado pelas 2 abas.
  - `src/components/showroom-admin/ComposicaoConjuntoModal.tsx` — modal compartilhado: carrega
    `obterComposicao` + dados do principal (via `buscarProduto` pelo próprio código, já que nem
    `ImportPeca` nem `ProdutoEstoque` trazem `valor_venda`); lista de membros com stepper de
    quantidade (mínimo 1) e botão remover; busca de novo produto (mesmo padrão visual do
    `BuscaProduto`) desabilitando quem já é principal de outro grupo ou membro de outro grupo,
    com o motivo em texto; prévia client-side de valor somado e estoque de conjuntos completos;
    botões "Salvar composição" (substituição total) e "Limpar conjunto" (`[]`).
  - `src/services/curadoriaEstoque.ts` (novo) — `listarProdutosEstoque`, `liberarUpload`,
    `confirmarFoto`, e `trocarFotoProduto` (orquestra os 3 passos + `supabase.storage.upload`/
    `getPublicUrl`/`remove` condicional do arquivo antigo, só depois de `confirmarFoto` ter
    sucesso — remoção do arquivo antigo é best-effort, uma falha nela não desfaz a troca de foto
    já confirmada no banco). Mesmo padrão de `curadoria.ts`: funções puras, `db.rpc()`,
    credencial explícita por chamada.
  - `src/services/curadoria.ts` estendido com `obterComposicao`, `definirComposicao`, tipos
    `MembroComposicao`/`MembroComposicaoInput`, e os 2 campos novos em `ProdutoBusca`.
  - `04-Sistemas/showroom-qtq8er2dk/supabase/AI_DB_CONTEXT.md` criado do zero (não existia).
  - `supabase/db/domains/cadastros.md` atualizado com as 2 tabelas/RPCs novas.
  - `CHANGELOG.md` atualizado.
- **Verificações rodadas** (sistema não tem suite de testes automatizada):
  - `npx oxlint src` — limpo (1 warning de variável não usada corrigido durante a implementação).
  - `npx tsc --noEmit -p tsconfig.app.json` — sem erros.
  - `npx vite build` — build ok (bundle único ~658KB, mesmo aviso de chunk grande que já existia
    antes desta SPEC, não é regressão).
  - `npx oxfmt --check` — aponta "issues" em ~65-67 arquivos, **incluindo arquivos que esta SPEC
    não tocou**; confirmado (via `git stash` + re-check) que esse drift de formatação já existia
    antes desta implementação (provável causa: normalização de fim de linha CRLF/LF do Git no
    Windows, ver os avisos "LF will be replaced by CRLF" do próprio `git`) — não é uma regressão
    introduzida aqui, não foi "corrigido" por não ser o escopo desta SPEC.
- **O que falta ser testado manualmente pelo usuário** (não posso confirmar sozinho, ver "Passos
  manuais do usuário"): aplicar a migration no Supabase real; login em `/admin`; upload/troca de
  foto em pelo menos 1 produto sem foto e 1 com foto (conferir que o arquivo antigo em
  `produtos/` some do bucket e que `import/` não é tocado); montar 1 conjunto de teste (2-3
  produtos) e conferir na vitrine pública 1 card só, nome do principal, valor somado; zerar
  estoque de 1 membro do conjunto de teste e confirmar que o card some da vitrine.

## Pendências

- [x] **P-1** — Controle de acesso ao upload no Storage. **Decidido: Opção B**, em 2026-09-15.
- [ ] **P-2** — `supabase/db/current/` desatualizado desde a SPEC-125. Regenerar o snapshot
      central em algum momento (não bloqueia esta SPEC).
- [ ] **P-3** — `04-Sistemas/showroom-qtq8er2dk/supabase/AI_DB_CONTEXT.md` não existe; criar.
- [ ] **P-4** — Confirmar se `limit 1000` em `showroom_listar_produtos_estoque` é suficiente
      (hoje ~266 produtos com `estoque_showroom > 0`) ou se vale paginar desde já.
- [ ] **P-5** — `showroom_upload_grants` acumula linhas expiradas (TTL 15 min, sem cron de
      limpeza). Não crítico, item de manutenção futura.
- [x] **P-6** — "Um produto é membro de no máximo 1 conjunto por vez". **Confirmado** por Pedro
      em 2026-09-15 (índice único em `codigo_produto_membro`, mantido como no rascunho §4.1).
- [x] **P-7** — Membro inativo dentro de um conjunto ativo: **confirmado** tratar como estoque 0
      pro conjunto inteiro (§4.3) — conjunto some da vitrine até a composição ser corrigida.
- [x] **P-8** — Campo "quantidade" por membro: **confirmado** disponível na UI desde o
      lançamento (§4.4, stepper por membro).
