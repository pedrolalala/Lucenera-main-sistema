---
titulo: "SPEC-125 — Site do Showroom Lucenera (vitrine de pronta entrega)"
status: pendente
data_ultima_modificacao: 2026-08-31
sistemas_envolvidos:
  - Sistema novo "Showroom Lucenera" (a criar — nome/repositório é passo manual do usuário)
  - Supabase (banco central) — nova coluna em `produtos`, nova view pública, bucket de Storage público
  - Hub / Sistema de TI — registro opcional em `public.systems` (inventário, `visivel_no_hub = false`)
  - Scripts (raiz `scripts/`) — job único de importação das fotos do PowerPoint
dependencias:
  - SPEC-069 / SPEC-087 (RLS de `produtos` — `authenticated` + `hub_pode_executar`; esta SPEC NÃO abre `produtos` para `anon`)
  - SPEC-072 (precedente de "sistema novo": repo + projeto Skip + submodule + env vars + registro em `systems`)
  - SPEC-081 (PostgREST corta em 1000 linhas — paginação da vitrine precisa de range/keyset)
  - SPEC-100/116 (`buscar_produtos_fuzzy` — usada no match nome↔produto do import)
  - SPEC-028 (`estoque_showroom` / views de estoque — origem do "pronta entrega no showroom")
  - Catálogo Ubiqua (`catalogo-pecas-ubiqua-e6fa0`) — referência de grid/card + view `anon` + Storage público
---

# SPEC-125 — Site do Showroom Lucenera (vitrine de pronta entrega)

> Origem: pedido direto do usuário nesta conversa ("transforme a necessidade em uma
> especificação clara para um site de showroom da Lucenera, considerando apenas a parte
> visível do site"). Refinado por quatro perguntas de esclarecimento (ver Decisões
> aprovadas). Escopo é somente a superfície visível ao cliente — nenhum fluxo de revendedor,
> login, orçamento, carrinho ou bastidor.

## Checklist de Ação

### Banco — migration `20260831_126_spec125_showroom_publico` **APLICADA no Supabase real (2026-08-31)**

- [x] `produtos.imagem_showroom_url text` (nullable) + índice parcial `produtos_showroom_vitrine_idx`
- [x] `public.vw_showroom_publico` (whitelist da §3, **sem `security_invoker`**) — verificado `GET /rest/v1/vw_showroom_publico` responde `200` para `anon`
- [x] `GRANT SELECT ... TO anon` + `REVOKE` dos privilégios de escrita que o default do Supabase concede automaticamente — anon/authenticated ficam **só com SELECT**
- [x] Bucket `showroom-lucenera` (público, 5 MB, jpeg/png/webp) + policy `showroom_lucenera_public_read` (SELECT p/ anon+authenticated)
- [x] `produtos` RLS (SPEC-069/087) **intacta** — `GET /rest/v1/produtos` com `anon` continua `200 []`
- [ ] Atualizar `supabase/db/domains/*` (produtos/estoque) com a coluna e a view novas
- [ ] (Opcional) linha em `public.systems` com `visivel_no_hub = false` só para inventário

### Sistema novo — Showroom Lucenera (`04-Sistemas/showroom-qtq8er2dk`) — IMPLEMENTADO, não publicado

- [x] Submodule `04-Sistemas/showroom-qtq8er2dk` (repo `github.com/pedrolalala/showroom-qtq8er2dk`) registrado em `.gitmodules`
- [x] `@supabase/supabase-js` adicionado ao `package.json`; `src/lib/supabase/client.ts` (sem persistência de sessão)
- [x] `src/App.tsx` — rotas públicas, sem `AuthProvider`/`ProtectedRoute`/`SystemSwitcher`
- [x] `src/pages/Vitrine.tsx` — grid, busca (nome/marca/categoria), filtros Marca/Categoria, ordenação, scroll infinito (IntersectionObserver), estados loading/vazio/erro, contador
- [x] `src/pages/PecaDetalhe.tsx` — `/peca/:codigo`; foto grande, campos da §3, CTA WhatsApp+tel com código/nome
- [x] `src/pages/Showroom.tsx` — página estática de contato; `src/pages/NotFound.tsx` pt-BR
- [x] `src/components/showroom/PecaCard.tsx`, `src/hooks/useVitrine.ts`, `src/services/showroom.ts`, `src/lib/format.ts`, `src/lib/contato.ts`
- [x] Tokens de marca Lucenera em `src/main.css` (laranja `#f39c12`, navy `#1a202e`, Inter); `index.html` pt-BR + título/OG
- [x] `pnpm install` + `tsc --noEmit` + `oxlint` + `oxfmt` + `vite build` limpos; `vite preview` serve HTTP 200
- [x] **Commitado e pushado** no GitHub (`showroom-qtq8er2dk` @ `c92b219`); ponteiro do submodule + `CHANGELOG` commitados no central (`4787f66`, **não pushado**)
- [ ] Teste ao vivo em aba anônima: agora a view existe, mas ainda **0 produtos com `imagem_showroom_url`** → vitrine mostra estado vazio até rodar `aplicar`
- [ ] Criar projeto Skip + `skip_env_set` das env vars + QA pipeline + publish com autorização

### Importação das fotos — `scripts/importar_fotos_showroom.py` (extrair / match / aplicar)

- [x] Script criado com 3 subcomandos; lê `.odp` **e** `.pptx` (stdlib `zipfile`+`xml`)
- [x] `extrair` rodado no arquivo real (268 MB): **189 slides, 167 com foto**, 22 divisórias de seção. Nome limpo (sem o "N " de quantidade) + `nome_bruto` + `quantidade_ppt` (inteiro do início do nome; não pega mais ano de design)
- [x] `match` reescrito: top-3 candidatos por sobreposição de token + bônus forte no 1º token (modelo). **162/167 peças com ≥1 candidato**; CSV com `cand1..3_cod/nome/sh/score`, `fuzzy_rpc_*` e a coluna de revisão **`codigo_confirmado`** (o revisor cola o `codigo_produto`)
- [x] `--semear-estoque` implementada: no `aplicar`, onde `estoque_showroom = 0`, usa `ppt_qtd` como valor inicial. `aplicar --dry-run --semear-estoque` validado
- [ ] **Revisão humana do CSV** (`codigo_confirmado`) — só 4 linhas vieram pré-preenchidas (score alto); o resto o time confere
- [ ] `aplicar --semear-estoque` (após CSV revisado): sobe fotos p/ `showroom-lucenera/showroom/<codigo>.<ext>` + `UPDATE produtos SET imagem_showroom_url` (+ `estoque_showroom` onde 0)

### Passos manuais do usuário

- [x] Repositório do sistema criado (`showroom-qtq8er2dk`) e arquivo da lista fornecido (`.odp`)
- [x] Migration `20260831_126` aplicada no Supabase real (com autorização explícita)
- [ ] Criar o projeto Skip para `showroom-qtq8er2dk` e rodar `skip_env_set` (`VITE_SUPABASE_URL`, `VITE_SUPABASE_PUBLISHABLE_KEY`) → QA → publish
- [ ] Revisar o CSV de match (`codigo_confirmado`) e rodar `aplicar --semear-estoque`
- [ ] Preencher `src/lib/contato.ts` com WhatsApp/telefone/endereço/horário reais (P-2)
- [ ] `git push` do repo central (commit `4787f66` está local)
- [ ] Confirmar decisões em aberto: domínio (P-3), indexação/SEO (P-4)

## Objetivo

Site público **somente de visualização** que lista as peças em pronta entrega no showroom —
foto, nome, quantidade disponível e preço — para o cliente ver o que pode levar na hora. Sem
qualquer ação transacional: o contato é offline (WhatsApp / telefone / visita ao showroom).
Fora de escopo: login, revendedor, carrinho, checkout, pagamento, reserva online, orçamento,
cadastro de produto e qualquer fluxo de bastidor.

## Decisões aprovadas

Respostas do usuário às perguntas de esclarecimento nesta conversa:

- **Plataforma:** sistema novo dedicado — novo repositório + novo projeto Skip, público e sem
  login, usando o Supabase central. Segue o precedente da SPEC-072.
- **Estoque exibido:** `produtos.estoque_showroom` ao vivo (peças fisicamente no showroom =
  "pronta entrega"). O número do PowerPoint serve só para a carga inicial.
- **Vínculo foto↔produto:** nova coluna `produtos.imagem_showroom_url text` (1 foto por
  produto; `produtos` continua como fonte única — sem tabela nova, sem tabela genérica de
  imagens).
- **Quantidade para o cliente:** número exato (ex.: "3 disponíveis").
- **Modelo confirmado (2ª rodada, 2026-08-31):** apesar de `estoque_showroom` estar hoje
  incompleto (só 266 produtos > 0, e ~91/167 peças do ODP sem match óbvio no catálogo), o
  usuário optou por **manter o modelo da SPEC** — a vitrine é `produtos` com
  `estoque_showroom > 0` + `imagem_showroom_url`. Corrigir `estoque_showroom` e casar as peças
  é trabalho de curadoria da equipe (via o CSV de revisão + Cadastro), não muda o modelo.
- **Preço (2026-08-31):** exibir **sempre** `valor_venda` do produto; se for `0`/não
  cadastrado, mostrar "R$ 0,00" mesmo — é o sinal de que alguém precisa cadastrar o preço em
  Peças/Produtos. Sem "Sob consulta", sem esconder card por falta de preço.

## Definição da SPEC

### 1. Estrutura de páginas / seções

| Rota | Página | Conteúdo |
|---|---|---|
| `/` | **Vitrine** | Grid responsivo de cards (foto, nome, qtd, preço). Busca por texto + filtros de Marca e Categoria + ordenação (nome A–Z, menor/maior preço). Contador de resultados. Estados de loading (skeleton), vazio e erro. Paginação por scroll infinito. |
| `/peca/:codigo` | **Detalhe da peça** | Foto grande, nome, marca, categoria, quantidade disponível, preço, `descricao_tecnica` (se houver), código da peça. CTA "Falar com o showroom" (link `wa.me` / `tel:` / `mailto:` com código + nome já na mensagem). Sem formulário. |
| `/showroom` | **Visite o showroom** (estática, opcional) | Endereço, horário de funcionamento, telefone/WhatsApp, mapa/foto. |
| `*` | **404** | Mensagem + link para a vitrine. |

**Layout:** header com logo Lucenera + campo de busca; footer com contato e endereço. Sem
menu de navegação entre sistemas, sem `SystemSwitcher`, sem tela de login, sem
`ProtectedRoute`. Mobile-first (o cliente costuma estar no próprio showroom com o celular).

### 2. Campos mínimos de cada peça

| Campo exibido | Origem no Supabase | Onde aparece | Obrigatório p/ listar |
|---|---|---|---|
| Foto | `produtos.imagem_showroom_url` | card + detalhe | **Sim** |
| Nome | `produtos.nome` | card + detalhe | Sim |
| Quantidade disponível | `produtos.estoque_showroom` | card + detalhe | Sim (> 0) |
| Preço | `produtos.valor_venda` (fallback `preco_venda`) | card + detalhe | Não (ver §4) |
| Marca | `marcas.nome` via `produtos.marca_id` | card + detalhe | Não |
| Categoria | `categorias_produto.nome` via `produtos.categoria_id` | detalhe (e filtro) | Não |
| Código da peça | `produtos.codigo_produto` | detalhe (e CTA) | Não |
| Descrição técnica | `produtos.descricao_tecnica` | detalhe | Não |

**Nunca expor** ao público: `preco_custo`, `custo_total`, `margem_lucro`, `percentual_lucro`,
campos fiscais (`ncm`, `cst`, `icms_*`, `porc_*` etc.), `fornecedor_principal_id`, reservas
por cliente/projeto. A superfície pública seleciona só a whitelist acima (ver §5).

### 3. Vínculo entre produtos do Supabase e as fotos do PowerPoint

O PowerPoint tem, por slide: **foto(s) + nome da peça + quantidade**. O vínculo é feito por um
processo **único e reexecutável** (quando o PPT for atualizado), fora do site:

1. **Extração** — script Python lê o `.pptx` (reaproveitar o `.venv` com `python-pptx` já
   existente em `04-Sistemas/lucenera-power-point/`; ver `ppt.py`). Por slide: extrai a(s)
   imagem(ns), o texto do nome e o texto da quantidade.
2. **Match sugerido** — para cada nome do PPT, buscar o produto correspondente em `produtos`
   (RPC `buscar_produtos_fuzzy` ou match local por `nome`/`referencia`/`sku`). Gera um CSV de
   revisão: `slide, ppt_nome, ppt_qtd, produto_id_sugerido, produto_nome, score,
   produto_id_confirmado`.
3. **Revisão humana** — alguém preenche/corrige `produto_id_confirmado` no CSV. Necessário
   porque os nomes do PPT não batem exatamente com `produtos.nome` e há ~40 produtos sem SKU.
4. **Aplicação** — por linha confirmada: sobe a imagem para o bucket público
   (`showroom-lucenera`, caminho `showroom/<codigo_produto>.<ext>`) e roda
   `UPDATE produtos SET imagem_showroom_url = '<url pública>' WHERE id = :produto_id_confirmado`.
5. **Estoque inicial (opcional)** — se `estoque_showroom` estiver zerado para um item, semear
   com a quantidade do PPT. A partir daí a fonte é sempre `estoque_showroom` ao vivo (o PPT
   não volta a ser lido salvo nova rodada de import).

O site **não lê o PowerPoint** — só `imagem_showroom_url` + `estoque_showroom` do banco.

### 4. Regras de exibição de estoque e preço

**Estoque**

- Um item só aparece se: `ativo = true` **E** `imagem_showroom_url IS NOT NULL` **E**
  `estoque_showroom > 0`.
- Quantidade exibida = `estoque_showroom`, número exato ("1 disponível" / "3 disponíveis").
- Item que zera some da vitrine automaticamente (o filtro da view cuida disso) — sem estado
  "esgotado" persistente, sem lista de espera.
- Sem badge de "reservado" nem qualquer conceito interno de estoque — o showroom só mostra o
  que está pronto para levar.
- Atualização: assinatura realtime no `produtos` (canal Supabase) **ou** refetch periódico
  (2–5 min) + refetch ao focar a aba. Latência de alguns minutos é aceitável.

**Preço**

- Fonte: `valor_venda`; se `0`/nulo, `preco_venda`; se ambos `0`/nulos → exibir
  **"Sob consulta"** (o card continua aparecendo).
- Formato: `Intl.NumberFormat('pt-BR', { style: 'currency', currency: 'BRL' })`.
- Sem preço "de/por", sem desconto, sem parcelamento, sem simulação.
- O preço é público — confirmação de negócio pendente (P-1).

### 5. Arquitetura da parte do site

**Sistema novo** (mesmo scaffold Skip dos demais):

- Repositório + projeto Skip novos + submodule em `04-Sistemas/<nome>` (nome final = passo
  manual; sugestão `showroom-lucenera`).
- `src/App.tsx`: `BrowserRouter` + rotas **públicas** (sem `AuthProvider`, sem
  `ProtectedRoute`).
- `src/pages/`: `Vitrine.tsx`, `PecaDetalhe.tsx`, `NotFound.tsx` (+ `Showroom.tsx` opcional).
- `src/components/showroom/PecaCard.tsx` — inspirado em
  `catalogo-pecas-ubiqua-e6fa0/src/components/PartCard.tsx`.
- `src/services/showroom.ts` — consultas à view pública, paginação keyset, filtros.
- `src/lib/supabase/client.ts` — gerado; `VITE_SUPABASE_URL` + `VITE_SUPABASE_PUBLISHABLE_KEY`
  (chave anônima) do projeto Skip novo. Sessão não é necessária.

**Superfície de dados pública (backstage mínimo necessário):**

- Migration em `supabase/db/migrations/AAAAMMDD_NNN_spec125_showroom_publico/`:
  - `ALTER TABLE public.produtos ADD COLUMN imagem_showroom_url text;`
  - `CREATE VIEW public.vw_showroom_publico AS SELECT` só `codigo_produto`, `nome`,
    `estoque_showroom`, `valor_venda`, `preco_venda`, `marca`, `categoria`,
    `descricao_tecnica`, `imagem_showroom_url` `FROM produtos p LEFT JOIN marcas ... LEFT JOIN
    categorias_produto ... WHERE p.ativo AND p.imagem_showroom_url IS NOT NULL AND
    p.estoque_showroom > 0;`
  - `GRANT SELECT ON public.vw_showroom_publico TO anon;`
  - **Sem** `security_invoker` na view e **sem** abrir política `anon` em `produtos` (abrir
    `produtos` para `anon` vazaria custo/margem/fiscal). A view whitelisted é a única porta
    anônima. Alternativa a avaliar com quem cuida do banco: Edge Function pública.
  - Bucket de Storage público novo `showroom-lucenera` (leitura `anon`, ~5 MB,
    `image/jpeg|jpg|png|webp`) — replicar
    `catalogo-pecas-ubiqua-e6fa0/supabase/migrations/20260525140000_create_storage_and_policies.sql`.
- Registro no Hub: opcional, linha em `public.systems` com `visivel_no_hub = false` só para
  inventário. Não precisa de RBAC/`papel_permissoes` (site público).

### 6. Considerações de usabilidade para o cliente final

- **Zero fricção:** sem cadastro, sem login, sem carrinho. Abrir o site já mostra as peças.
- **Mobile-first:** 1 coluna no celular → 2/3/4 no desktop; alvos de toque grandes.
- **Foto:** proporção fixa, `object-contain`, `loading="lazy"`, placeholder no carregamento e
  fallback visível (ícone) quando a URL falhar; `alt` = nome da peça.
- **Informação-chave no card:** foto, nome, quantidade e preço visíveis sem abrir o detalhe.
- **Busca instantânea** + filtros simples (Marca, Categoria) + ordenação; contador de
  resultados e estado vazio amigável ("Nenhuma peça disponível no momento").
- **CTA de contato** no detalhe: botão WhatsApp com mensagem pré-preenchida (código + nome).
- **Performance:** paginação keyset/range (PostgREST corta em 1000 — SPEC-081); imagens
  redimensionadas no import para o grid abrir rápido.
- **Acessibilidade:** contraste, foco visível, textos alternativos, navegação por teclado.
- **Idioma:** pt-BR apenas.
- **Identidade visual:** laranja `#f39c12`, navy `#1a202e`, fonte Inter.

### 7. Fora de escopo (não implementar)

Login, autenticação, revendedor, carrinho, checkout, pagamento, reserva/hold online, geração
de orçamento, cadastro/edição de produto, gestão de estoque, painel administrativo, qualquer
fluxo interno não visível ao cliente.

### 8. Análise de ecossistema

- **Depende de:** `produtos` (nome, preço, estoque_showroom, descrição, código), `marcas`,
  `categorias_produto`, Storage, `buscar_produtos_fuzzy` (só no import). Nenhuma escrita em
  tabela transacional — o site é 100% leitura.
- **Afeta:** adiciona 1 coluna a `produtos` (`imagem_showroom_url`, nullable, sem default —
  não quebra nada existente) e 1 view nova. Cria 1 bucket de Storage. Não altera RLS de
  `produtos`, não altera RPC, não toca em estoque/reserva/orçamento.
- **Dado duplicado que deveria ser derivado:** nenhum — `imagem_showroom_url` é dado novo
  (não existe hoje em lugar nenhum do schema); quantidade e preço são lidos ao vivo, não
  copiados.
- **Risco de exposição:** `produtos` é hoje `RLS authenticated` + `hub_pode_executar`
  (SPEC-069/087). A view pública precisa ser desenhada com whitelist estrita para não vazar
  custo/margem/fiscal — este é o ponto de revisão mais importante da migration.
- **Exige atualizar `AI_DB_CONTEXT.md`:** o domínio de produtos/estoque em `supabase/db/domains/`
  quando a migration for aplicada. O sistema novo terá o seu próprio `supabase/AI_DB_CONTEXT.md`.
- **Padrão de acesso a dados:** seguir um dos dois já existentes no ecossistema (hooks +
  cliente `supabase` direto, estilo Ubiqua/Logística) — não introduzir um terceiro.

## Realizado

### 2026-08-31

- **Sistema novo implementado** em `04-Sistemas/showroom-qtq8er2dk` (submodule do repo
  `github.com/pedrolalala/showroom-qtq8er2dk`, que já vinha com o scaffold Skip). Público,
  sem login. Páginas: Vitrine (`/`), PecaDetalhe (`/peca/:codigo`), Showroom (`/showroom`),
  NotFound. Hook `useVitrine` (busca com debounce, filtros Marca/Categoria, ordenação, scroll
  infinito via IntersectionObserver, refresh no `focus`/3 min quando na 1ª página). Service
  `showroom.ts` lê só `vw_showroom_publico`. Preço via `formatarPreco` (sempre `valor_venda`,
  "R$ 0,00" quando 0). Contato em `src/lib/contato.ts` com placeholders. Tokens de marca
  Lucenera aplicados. `pnpm install` + `tsc --noEmit` + `oxlint` + `vite build` + `vite
  preview` (HTTP 200) — todos limpos. Bundle único de ~622 KB (185 KB gzip) — code-split fica
  como melhoria futura.
- **Migration redigida** (não aplicada): `supabase/db/migrations/20260831_126_spec125_showroom_publico/001_showroom_publico.sql`
  — coluna `imagem_showroom_url`, view `vw_showroom_publico` (whitelist, sem
  `security_invoker`), `GRANT ... TO anon`, bucket `showroom-lucenera` + policy de leitura
  anon. README com pontos de revisão e rollback.
- **Script `scripts/importar_fotos_showroom.py`** (extrair/match/aplicar). `extrair` rodado no
  `.odp` real (268 MB): 189 slides, 167 com foto. `match` rodado: 4 726 produtos carregados,
  ~76/167 slides com candidato. CSV de revisão gerado (fora do repo, na área de trabalho).
- **Achado (2ª rodada de perguntas):** o `estoque_showroom` do banco cobre só 266 produtos
  (majoritariamente componentes), e boa parte das peças do ODP (designer/exposição: Parentesi,
  May Day, Toio, pendentes DIMLUX) tem match fraco/nulo no catálogo ou `estoque_showroom = 0`.
  O usuário decidiu **manter o modelo da SPEC** mesmo assim (ver Decisões aprovadas) — a
  vitrine só mostra produto com `estoque_showroom > 0` + foto; encher isso é curadoria da
  equipe.
### 2026-08-31 (continuação — publicação parcial + tela de curadoria)

- **Migration `20260831_126` APLICADA** no Supabase real (Management API, com autorização):
  coluna `imagem_showroom_url`, view `vw_showroom_publico`, `GRANT`/`REVOKE` (anon só SELECT),
  bucket `showroom-lucenera`. Verificado: `anon` lê a view, não lê `produtos`.
- **Matcher reescrito** (brand-aware + `difflib`): 167 peças, 152 com candidato. Auto-confirma
  só vencedor claro (score ≥ 0.85, folga ≥ 0.15, sem colisão de código) → 23; revisão manual
  tirou 4 duvidosos (GLÓRIA/PONTE/BIMBA — nº divergente).
- **19 peças publicadas na vitrine** via `aplicar --semear-estoque` (upload da foto +
  `imagem_showroom_url` + `estoque_showroom` = qtd da lista ou 1). Confirmado pela chave anônima:
  19 linhas em `vw_showroom_publico`, imagens públicas retornam 200.
- **15 peças não achadas no catálogo** de jeito nenhum (MAY DAY, VITTO, HERACLEUM/Moooi,
  ECLISSE/Artemide, PH5/Louis Poulsen, KAIRO, abajures Cris Bertolucci, FUNGUI/WENTZ, GALILEO,
  ACERVO FAS, XL4888) — podem estar com outro nome; quem conhece o catálogo resolve na `/admin`.
- **Preço:** mudado para `valor_venda` quando > 0, senão **"Sob consulta"** (decisão do usuário
  nesta rodada). Quantidade 0 → "Disponível".
- **Tela `/admin` de curadoria** (rota não listada, protegida por PIN) — `src/pages/Admin.tsx`
  + `src/services/curadoria.ts`. Lista cada peça do PPT não vinculada com a foto + até 3
  candidatos (botão de 1 clique) + busca livre de produto; "Vincular" grava
  `imagem_showroom_url`/`estoque_showroom` via RPC; "Desfazer" por peça.
- **Migration `20260831_127` APLICADA** (com autorização): `showroom_import_pecas` (staging das
  167 peças, RLS SELECT anon), `showroom_config` (PIN, não legível por anon), RPCs
  `showroom_vincular_peca` / `showroom_desvincular_peca` / `showroom_buscar_produto`
  (SECURITY DEFINER, gated por PIN). **PIN ainda é o placeholder `TROCAR-ESTE-PIN`** — o
  usuário vai definir.
- `scripts/importar_fotos_showroom.py` ganhou `publicar-import` (sobe as 167 fotos p/
  `showroom-lucenera/import/` + popula `showroom_import_pecas`). Ignora svg/emf/wmf.

## Pendências

- [x] ~~P-1~~ resolvida (2026-08-31, 2ª versão): preço = `valor_venda` quando > 0, senão
  **"Sob consulta"**.
- [ ] **P-2** — Preencher `src/lib/contato.ts` com WhatsApp/telefone/e-mail/endereço/horário
  reais da Lucenera (hoje são placeholders `5516999999999` etc.).
- [ ] **P-3** — Domínio: `*.goskip.app` ou domínio próprio (ex.: `showroom.lucenera...`).
- [ ] **P-4** — SEO/indexação: definir se o site deve ser indexável (robots, meta por peça,
  OG image). Hoje `index.html` já tem `<title>`/`description`/`og:*` genéricos.
- [ ] **P-5** — Curadoria: **~148 peças** ainda a vincular na tela `/admin` (19 já feitas).
  As 15 "não achadas" precisam de quem conhece o catálogo. `--semear-estoque` já cuida do
  `estoque_showroom = 0` (usa qtd da lista, senão 1) tanto no script quanto na RPC.
- [x] ~~P-6~~ — migration aplicada com a view `SECURITY DEFINER` + `GRANT TO anon` (abordagem
  confirmada em uso). Edge Function pública fica como alternativa não necessária.
- [x] ~~P-8b~~ — `/admin` passou a usar **usuário + senha** (migration `20260831_128`):
  `showroom_config` guarda `admin_user` = `Lucenera` e `admin_pass_hash` = bcrypt de
  `Lucenera123`. RPC `showroom_login` valida na hora; `showroom_vincular_peca`/`_desvincular_`
  recriadas com `(p_user, p_senha, …)`. Login testado ao vivo. Trocar senha:
  `update showroom_config set valor = extensions.crypt('<nova>', extensions.gen_salt('bf'))
  where chave = 'admin_pass_hash';`. Ao terminar a curadoria: `revoke execute` das RPCs
  `showroom_*` de `anon` (ver README da migration 128).
- [ ] **P-7** — Criar o projeto Skip para `showroom-qtq8er2dk`, `skip_env_set` das env vars,
  rodar o QA pipeline e publicar. Depois: `git push` no repo do sistema + atualizar o
  ponteiro do submodule + `CHANGELOG.md`.
- [ ] **P-8** — Revisão humana do CSV `revisao_showroom.csv` (coluna `produto_id_confirmado`):
  casar as ~167 peças do ODP com produtos reais. Nomes do ODP são terços ("1 PACO - OLE") x
  nomes verbosos do catálogo ("PENDENTE PACO COM 6 FOCOS GU10 - PRETO FOSCO").
- [ ] **P-9** — Teste ao vivo em aba anônima (grid carrega, filtros, detalhe, CTA WhatsApp,
  imagem quebrada → fallback, lista vazia) — só possível depois de P-6 + ao menos 1 produto
  com `imagem_showroom_url`.
