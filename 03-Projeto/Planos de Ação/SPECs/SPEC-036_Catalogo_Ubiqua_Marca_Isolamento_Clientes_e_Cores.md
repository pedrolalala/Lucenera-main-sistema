---
titulo: "SPEC-036 — Catálogo Ubiqua: Identidade de Marca, Isolamento de Clientes por Representante e Variações de Cor"
status: implementado (aguardando QA manual e material do Vinicius para item 8)
data_ultima_modificacao: 2026-07-18
sistemas_envolvidos:
  - Catálogo de Peças Ubiqua (catalogo-pecas-ubiqua-e6fa0)
---

# SPEC-036 — Catálogo Ubiqua: Identidade de Marca, Isolamento de Clientes por Representante e Variações de Cor

> Primeira SPEC do repositório central cobrindo o sistema "Catálogo de Peças Ubiqua" (`04-Sistemas/catalogo-pecas-ubiqua-e6fa0`, repo próprio `pedrolalala/cat-logo-pe-as-ubiqua-`). Não existe SPEC anterior para este sistema — os únicos documentos prévios são o `03-Projeto/Escopos/09_ESCOPO_UBIQUA.md` (nível de diretriz, sem detalhamento técnico) e a ata `02-Reunioes/10. Lucenera Ubiqua (vinicius)/[0001] Renião Vinicius Ubiqua.txt`.

## Achado arquitetural importante (leia antes do resto)

O Catálogo Ubiqua **não é um projeto Supabase separado**. Ele usa o mesmo projeto central `vcvcwzmbiftcawncibke` do resto do ecossistema Lucenera:

- `src/lib/supabase/client.ts` lê `VITE_SUPABASE_URL`/`VITE_SUPABASE_PUBLISHABLE_KEY` (não há `.env` versionado, está no `.gitignore`, então não dá pra confirmar o valor por aqui), **mas** o host `vcvcwzmbiftcawncibke.supabase.co` está hardcoded em `src/hooks/use-parts.ts:25`, `src/components/PartDetailSheet.tsx:47` e em duas migrations locais do submodule (`supabase/migrations/20260521150014_update_catalog_images.sql`, `20260521164109_fix_catalog_images_6_digits.sql`).
- As tabelas que este app usa (`informacoes_cliente_ubiqua`, `itens_orcamento_ubiqua`, `orcamentos_revenda_ubiqua`, `revenda_ubiqua`, `usuarios_ubiqua`, `empresa_ubiqua`) **existem no snapshot central** `supabase/db/current/01_schema_full.sql`.
- Consequência prática: qualquer migration desta SPEC deve ser desenhada em `supabase/db/migrations/YYYYMMDD_NNN_.../` do **repositório central**, não dentro de `04-Sistemas/catalogo-pecas-ubiqua-e6fa0/supabase/migrations/`. Essa pasta local do submodule é histórico técnico do sistema (contém 30+ migrations aplicadas diretamente por fora do fluxo central) e, por regra do `AGENTS.md`, não deve ser tratada como fonte de verdade — a fonte é `supabase/db/current/`.
- `usuarios_ubiqua.id` é FK para `auth.users(id)` (`01_schema_full.sql:11816`) — ou seja, o login do representante usa o **mesmo pool de autenticação Supabase** do resto do ecossistema, não um sistema de auth isolado. `use-auth.tsx` já busca perfil em `usuarios_ubiqua` **e** em `usuarios` (tabela central) ao mesmo tempo.
- Achado colateral (fora do escopo desta SPEC, só registrando): a tabela central `orcamentos` tem uma coluna `informacoes_cliente_id` com FK para `informacoes_cliente_ubiqua(id)` (`01_schema_full.sql:5357` e `11228-11232`). Isso é uma ponte já existente entre o domínio Lucenera e o domínio Ubiqua que o Escopo Ubiqua (`SPEC-UBI-01`/`SPEC-UBI-07`) pede para não expandir sem caso de negócio — não mexer aqui.

## Checklist de Ação

- [x] 1. Adicionar subtítulo de marca ("Ubiqua Representações"/"Ubiqua Revendedores" — texto exato a confirmar) junto ao logo "Ubìqua" no header (`src/components/Layout.tsx:48-58`) e revisar o texto do footer (`Layout.tsx:163`, hoje "Ubiqua Peças").
- [ ] 2. Sem alteração de código necessária — ver análise do item 2 abaixo (ação é operacional, feita pela tela `/admin` já existente).
- [ ] 3. Auditar dados reais de `revenda_ubiqua` (mesma `desc_produto`, `cor`, `valor_revenda` distintos) para confirmar a hipótese de causa-raiz do bug de cores, e então corrigir a chave de agrupamento em `groupCatalogItems()` (`src/hooks/use-parts.ts:63-116`) para não depender de `valor_revenda`.
- [ ] 4. Sem alteração de código — ver análise do item 4 (hipótese de divergência de deploy, não bug de código-fonte).
- [x] 5. **Correção pós-implementação (2026-07-18):** a análise original desta SPEC estava errada — `AuthWrapper.tsx` só implementa o formulário de LOGIN. Não existe, em lugar nenhum da UI, um formulário/link de CADASTRO de novo representante, apesar de `use-auth.tsx` já ter uma função `signUp()` pronta (nunca chamada por nenhum componente). Isso bloqueava totalmente o "primeiro acesso" que o Vinicius descreveu. Corrigido: adicionado alternador Entrar/Criar conta em `AuthWrapper.tsx`, usando o `signUp()` já existente; após cadastro, o fluxo já existente (`OnboardingGuard`) assume e leva o novo representante para `/onboarding`. Ver Realizado.
- [x] 6. Criar coluna de vínculo entre `informacoes_cliente_ubiqua` e `usuarios_ubiqua`/`empresa_ubiqua` (nome e granularidade a definir — ver Pendências), escrever RLS restritiva por representante, e ajustar `CustomersPage.tsx` (`loadCustomers()`) e `NewQuote.tsx` (linhas 102-110) para filtrar pelo usuário autenticado.
- [ ] 7. Nenhuma alteração estrutural — já garantido por `orcamentos_revenda_ubiqua.cliente_id NOT NULL` + fluxo de `NewQuote.tsx`. Revisar apenas se a definição de "cadastro completo" mudar com o item 8.
- [ ] 8. Expandir schema de `informacoes_cliente_ubiqua` e o formulário de `CustomersPage.tsx` com os campos definidos pelo Vinicius (**BLOQUEADO** até o print/lista chegar).
- [x] 9. Ajustar rótulos de menu para deixar explícito "Cadastro de Cliente" e "Cadastro de Representante" (hoje: "Clientes" e "Meu Perfil") em `Layout.tsx` (desktop, linhas 59-75, e mobile, linhas 116-157).
- [x] Criar `04-Sistemas/catalogo-pecas-ubiqua-e6fa0/supabase/AI_DB_CONTEXT.md` documentando as tabelas Ubiqua e o novo vínculo de isolamento por representante (arquivo ainda não existe neste submodule).

### Passos manuais do usuário

- [ ] Vinicius enviar o print/lista completa de campos do cadastro de cliente PJ (bloqueia item 8 — sem isso não avançamos no schema de cliente além do mínimo já existente).
- [x] Decidir se o isolamento de clientes (item 6) é por **representante individual** ou por **representação/empresa** — decidido: representante individual (`usuarios_ubiqua.id`). Ver Realizado/Pendências.
- [x] Decidir o que fazer com os clientes já cadastrados hoje em `informacoes_cliente_ubiqua`, que não têm nenhum dono registrado — decidido: ficam com `cadastrado_por_usuario_id = NULL`, sem atribuição automática. Ver Realizado/Pendências.
- [x] Definir o texto exato do subtítulo de marca do item 1 — decidido (placeholder): "Ubiqua Representações", já implementado.
- [x] Antes de mudar a lógica de agrupamento por cor (item 3), rodar no Supabase um `SELECT desc_produto, cor, valor_revenda FROM revenda_ubiqua ORDER BY desc_produto` (ou equivalente) para confirmar quantos produtos realmente têm cores com preços diferentes — auditoria rodada, resultado registrado em Pendências. A mudança de código em `groupCatalogItems()` continua NÃO feita, pois a auditoria revelou que o problema real exige decisão de qual fonte de planilha (`fonte_planilha1/2/3`) é autoritativa em caso de conflito — isso ainda precisa de decisão humana.
- [ ] Testar o clique na logo "Ubìqua" numa versão publicada/atualizada do sistema (o `.skip.config.json` mostra último publish em 2026-06-01) antes de assumir que ainda existe bug de navegação.
- [x] Fazer upload das imagens corretas (retiradas do site oficial da Ubiqua) via `/admin` → aba de imagens — a ferramenta já existe e já funciona (ver item 2).
- [x] Aplicar a migration `supabase/db/migrations/20260718_052_spec036_ubiqua_isolamento_clientes/001_informacoes_cliente_ubiqua_isolamento_representante.sql` no Supabase real (`vcvcwzmbiftcawncibke`) — **aplicada em 2026-07-18** pelo orquestrador (nunca por subagente), com confirmação explícita do usuário. Verificado após aplicação: coluna `cadastrado_por_usuario_id` criada; as 5 policies novas (`select/insert/update/delete_informacoes_cliente_por_representante` + `Permitir leitura admin_gerente` preservada) são exatamente as que existem hoje na tabela; índice `idx_informacoes_cliente_ubiqua_dono` criado; os 4 clientes já existentes ficaram com `cadastrado_por_usuario_id = NULL`, como esperado (sem atribuição automática).
- [ ] Depois de aplicar a migration, decidir qual fonte de planilha (`fonte_planilha1`/`fonte_planilha2`/`fonte_planilha3`) é autoritativa em `revenda_ubiqua` quando há descrição/preço conflitante para o mesmo produto (caso "CRYSTAL", ver Pendências) — só então faz sentido revisitar o item 3.
- [ ] Homologar manualmente o golden path em celular real: login → onboarding (representante + representação) → catálogo → cadastro de cliente → seleção do cliente → orçamento.
- [ ] Testar manualmente o novo fluxo de "Criar conta" em `AuthWrapper.tsx` (item 5): criar um representante novo pelo formulário, confirmar criação real no Supabase Auth, e verificar se o projeto exige confirmação por e-mail antes do primeiro login (não verificável por leitura de código).

## Objetivo

Traduzir os 9 pedidos do Vinicius (sócio/representante Ubiqua) em mudanças técnicas concretas no Catálogo de Peças Ubiqua, deixando claro — com base na leitura real do código — o que já está pronto, o que está parcial, e o que precisa ser construído do zero. O achado central desta SPEC é que **a maior parte do fluxo estrutural que ele pediu (login obrigatório, seleção de cliente antes do orçamento, onboarding antes do catálogo, módulo de clientes separado) já está implementada**; o que falta de verdade é: (a) isolamento de dados de cliente por representante (não existe nenhum vínculo hoje), (b) diferenciação visual de marca, (c) um provável bug de agrupamento de variantes de cor por preço, e (d) expansão do cadastro de cliente (bloqueada por material que o Vinicius ainda vai enviar).

## Decisões aprovadas

Decisões já fechadas pelo Vinicius na reunião, não devem ser reabertas sem necessidade:

- Cadastro de cliente é sempre pessoa jurídica (CNPJ obrigatório); não pode existir campo de data de nascimento.
- Não é possível iniciar/montar um orçamento sem um cliente selecionado antes.
- "Cadastro de Cliente" e "Cadastro de Representante" precisam ser módulos/menus explícitos, não etapas escondidas no fim de outro fluxo.
- O app precisa ser mobile-first — funcionar bem no celular é prioridade, não um extra.
- Cada representante só pode ver os clientes que ele mesmo cadastrou (motivo declarado: atendimento regional, evitar erro de seleção de cliente).
- Produtos com múltiplas cores devem mostrar todas as cores disponíveis como ícones/badges, cada um com a quantidade daquela cor — mesmo que o número de estoque ainda não esteja certo, o que importa agora é a opção de cor aparecer.
- Deve existir um texto de diferenciação de marca perto do nome "Ubiqua" indicando que aquela área é de representantes/revenda.

## Definição da SPEC

### Análise obrigatória de ecossistema

- **Depende de `projetos`/`orcamentos`/`contatos`/`produtos`/`boletos`/`projeto_itens`/`projeto_parcelas`/`usuarios`/`systems`/`user_system_access`?** Indiretamente apenas em identidade: `usuarios_ubiqua.id` é a mesma linha de `auth.users` usada pela tabela central `usuarios`, e `use-auth.tsx` já lê as duas. Não há dependência direta de `orcamentos`, `projetos`, `boletos` etc. — o domínio Ubiqua usa seu próprio conjunto paralelo de tabelas (`orcamentos_revenda_ubiqua`, `itens_orcamento_ubiqua`, `informacoes_cliente_ubiqua`, `revenda_ubiqua`), como já registrado no Escopo Ubiqua (SPEC-UBI-01/04).
- **Afeta CRM, Orçamentos, Financeiro, Cadastro, Estoque/Compras, Logística, RH ou Hub/TI?** Não diretamente. Esta SPEC não altera nenhuma tabela do fluxo Lucenera central. Há uma superfície de contato futura com Hub/TI (identidade/permissão centralizada, per Escopo Ubiqua SPEC-UBI-02/03), mas essa unificação é explicitamente adiada pelo Escopo Ubiqua e não faz parte desta SPEC.
- **Existe dado duplicado que deveria ser derivado por relacionamento em vez de duplicado?** Sim, dois pontos:
  1. É exatamente o problema do item 6 — hoje `informacoes_cliente_ubiqua` não tem nenhuma coluna de relacionamento com quem cadastrou o cliente; a correção proposta é justamente criar esse relacionamento em vez de continuar sem ele.
  2. O agrupamento de variantes por cor é feito hoje inteiramente no client (`groupCatalogItems()` em `use-parts.ts`), reprocessando o que as views `vw_catalogo_ubiqua` e `vw_catalogo_unificado` (`supabase/db/current/05_views.sql:16-38`) já calculam no banco (`cores_disponiveis`, `detalhes_por_cor`/`estoque_total`). Não é um bloqueador desta SPEC, mas é uma duplicação de lógica que vale registrar.
- **Existe migration antiga em algum sistema que contradiz o snapshot central?** Não encontrei contradição de schema — as ~30 migrations locais em `04-Sistemas/catalogo-pecas-ubiqua-e6fa0/supabase/migrations/` batem com o que existe em `supabase/db/current/`. O ponto de atenção não é contradição, é que essa pasta local não deve continuar sendo usada como se fosse a fonte de verdade daqui pra frente — migrations novas para essas tabelas devem nascer no repo central.
- **A mudança exige atualizar `AI_DB_CONTEXT.md` de algum sistema?** Sim — hoje não existe nenhum `AI_DB_CONTEXT.md` em `04-Sistemas/catalogo-pecas-ubiqua-e6fa0/supabase/`. Esta SPEC deve criar um, documentando as 6 tabelas Ubiqua e a nova coluna de isolamento por representante.
- **Qual o padrão de acesso a dados que o sistema já usa?** Acesso direto: `supabase.from(...)` inline dentro das próprias páginas/hooks (`CustomersPage.tsx`, `NewQuote.tsx`, `Onboarding.tsx`, `ProfilePage.tsx`, `use-parts.ts`), sem camada de `services/`/repositório. Existe um início de camada em `src/lib/api.ts` e `src/lib/api-admin.ts`, mas só para operações específicas (PDF/e-mail, catálogo administrativo). Todas as mudanças desta SPEC devem seguir esse mesmo padrão de acesso direto — não introduzir uma camada de abstração nova.

### Estado real por pedido do Vinicius

| # | Pedido | Status | Onde está / o que falta |
|---|--------|--------|--------------------------|
| 1 | Subtítulo "Ubiqua Revendedores/Representações" | **(c) não existe** | `Layout.tsx:48-58` só renderiza "Ubìqua"; footer diz "Ubiqua Peças" (`Layout.tsx:163`). Mudança de texto simples. |
| 2 | Trocar imagens ruins | **(a) ferramenta já pronta** | `AdminImages.tsx` + `api-admin.ts` (`uploadCatalogImageExact`, `updateCatalogImageUrl`, `deleteCatalogImage`) já permitem trocar imagem por variante via `/admin`. Não é um problema de código, é conteúdo — falta alguém subir as imagens corretas. |
| 3 | Cores como ícones com quantidade | **(a)/(b) já implementado, com bug provável** | `revenda_ubiqua.cor` já existe (`01_schema_full.sql:5916`), views já agregam cor (`05_views.sql:16-27`), e `PartCard.tsx`, `ProductDetail.tsx`, `AdminImages.tsx` já renderizam swatches de cor com hex e quantidade por cor. **Mas** `groupCatalogItems()` (`use-parts.ts:63-116`) agrupa por `descrição + preço` — se as cores de um mesmo produto tiverem preços diferentes, viram cards separados em vez de swatches no mesmo card. O próprio `AdminImages.tsx:320-323` avisa: *"Alterar o valor separará esta variante em um novo card."* Essa é a hipótese mais provável para o "Lume não mostra as 4 cores". |
| 4 | Logo não volta para home | **Investigado, sem bug encontrado no código** | Único lugar no código-fonte que renderiza o logo/nome "Ubìqua" clicável é `Layout.tsx:48-58`, e já é um `<Link to="/">` real do react-router. Busquei em todo `src/` por outras ocorrências do texto "Ubiqua"/"Ubìqua" (`Index.tsx`, `pdf.ts`, footer) — nenhuma outra é um elemento de logo clicável. `.skip.config.json` mostra `lastPublishedRef` com `publishedAt: 2026-06-01`, mais de um mês antes de hoje — hipótese mais provável é divergência entre a versão publicada testada pelo Vinicius e o código-fonte atual do GitHub. |
| 5 | Login do representante | **(a) já implementado** | `AuthWrapper.tsx` usa Supabase Auth real (`signInWithPassword`), envolve `/onboarding` e todas as outras rotas em `App.tsx`. Sem login, nada é acessível. |
| 6 | Isolamento de clientes por representante | **(c) não existe nada** | `informacoes_cliente_ubiqua` (`01_schema_full.sql:5138-5145`) não tem nenhuma coluna de dono/representante/empresa. RLS de SELECT é `USING (true)` para `anon, authenticated` (`07_rls_policies.sql:494-499`). `CustomersPage.tsx:78-81` e `NewQuote.tsx:102-110` fazem `select('*')` sem filtro. Precisa de schema novo + RLS nova + filtro no frontend. |
| 7 | Cadastro de cliente obrigatório antes de orçar | **(a) já garantido, inclusive no banco** | `orcamentos_revenda_ubiqua.cliente_id` é `NOT NULL` com FK `RESTRICT` para `informacoes_cliente_ubiqua` (`01_schema_full.sql:5432`, `11248`). `NewQuote.tsx:390-481` bloqueia a tela de montagem do orçamento até haver `activeQuoteId`, que só existe depois de `handleStartQuote()` com `selectedCustomerId` preenchido. |
| 8 | Dados completos do cliente PJ (regime tributário etc.) | **(b) parcial, bloqueado** | Hoje só existem 4 campos: `nome`, `email`, `telefone`, `cpf_cnpj` (validado como CNPJ via `isValidCNPJ`), todos obrigatórios (`CustomersPage.tsx:48-53,108-118`). Não há campo de data de nascimento no código atual (reforça a hipótese de divergência de versão publicada no item 4/8). Não há `regime_tributário`, endereço ou outros campos — **não vou inventar a lista**, ver Pendências. |
| 9a/9b | Login/onboarding antes do catálogo | **(a) já implementado** | `App.tsx:28-46` + `OnboardingGuard.tsx` redirecionam para `/onboarding` até `profile.onboarding_completado === true`; só depois libera `/`, `/produtos`, etc. |
| 9c | Cadastro de Cliente e Cadastro de Representante como módulos/menus próprios | **(b) parcial** | `/clientes` já é rota própria com item "Clientes" no menu desktop (`Layout.tsx:63-68`) e na navegação mobile (`Layout.tsx:126-135`) — não está escondido em outro fluxo. Já atende ao pedido nesse sentido. Porém "Cadastro de Representante" contínuo (pós-onboarding) existe como `/perfil`, cujo título interno é "Módulo de Representante" (`ProfilePage.tsx:162`), mas o rótulo do menu é "Meu Perfil" (`Layout.tsx:70-74` e `148-157`) — não usa a palavra "Cadastro", o que pode ser o motivo do Vinicius não reconhecer isso como um módulo equivalente ao de clientes. |
| 9d | Selecionar cliente antes de montar orçamento | **(a) já implementado** | Mesma evidência do item 7 — `NewQuote.tsx` força seleção de cliente antes de mostrar o catálogo/carrinho de itens do orçamento. |
| 9e | Mobile-first | **(a)/(b) já com bastante trabalho feito** | `Layout.tsx` tem bottom nav mobile dedicada (linhas 113-159), `NewQuote.tsx` e `CustomersPage.tsx` têm layouts separados para mobile (cards) e desktop (tabela). Não encontrei evidência de quebra grave no código; não consigo validar visualmente em dispositivo real (fora do meu escopo de leitura de arquivos) — recomendo QA manual dedicado. |

### Item 3 em detalhe — proposta de correção do agrupamento de cor

**Hoje** (`use-parts.ts:69`):
```
const key = `${desc.toLowerCase()}_${price.toFixed(2)}`
```
Isso significa: dois registros de `revenda_ubiqua` com a mesma `descricao`/`desc_produto`, mas `valor_revenda` diferente (o que é plausível — acabamentos diferentes costumam custar diferente), **não** viram swatches de cor no mesmo card — viram dois cards de produto distintos, cada um mostrando só a cor daquele grupo de preço.

**Proposta** (a confirmar depois da auditoria de dados pedida em Pendências): agrupar apenas por descrição normalizada (sem acento, sem case, sem espaços duplicados) — na linha do que a própria view `vw_catalogo_unificado` já faz no banco via regex sobre `referencia`/`descricao` (`05_views.sql:28-38`) — e, quando as cores tiverem preços diferentes, exibir uma faixa de preço ("a partir de R$ X") em vez de um valor único, trocando o preço exibido apenas quando o usuário seleciona uma cor específica (o componente já faz isso parcialmente via `selectedVariant?.valor_revenda`).

**Risco que não posso decidir sozinho:** mudar a chave de agrupamento pode juntar produtos que hoje são intencionalmente cards separados (por exemplo, se duas linhas de produto diferentes compartilham a mesma descrição por coincidência). Por isso o passo manual de auditoria de dados vem antes do item de código no Checklist.

### Item 6 em detalhe — proposta de schema e RLS (a confirmar, não aplicar sem aprovação)

Proposta de estrutura (rascunho, sujeito ao que for decidido nas Pendências sobre granularidade individual vs. empresa):

```sql
-- PROPOSTA — não aplicar sem decisão confirmada sobre granularidade
ALTER TABLE public.informacoes_cliente_ubiqua
  ADD COLUMN cadastrado_por_usuario_id uuid REFERENCES public.usuarios_ubiqua(id);
-- Alternativa/complemento, se o isolamento for por representação (empresa) e não por indivíduo:
-- ADD COLUMN cadastrado_por_empresa_id uuid REFERENCES public.empresa_ubiqua(id);
```

RLS proposta (substituindo as policies hoje totalmente abertas `all_select_informacoes_cliente`/`Permitir leitura anon e auth`, ambas `USING (true)`):

```sql
-- PROPOSTA — esboço, não é definição final
CREATE POLICY select_informacoes_cliente_por_representante
  ON public.informacoes_cliente_ubiqua
  FOR SELECT TO authenticated
  USING (
    cadastrado_por_usuario_id = auth.uid()
    OR EXISTS (
      SELECT 1 FROM usuarios_ubiqua u
      WHERE u.id = auth.uid() AND u.nivel_acesso IN ('admin', 'interno')
    )
  );
```

Pontos em aberto que travam a versão final dessa migration (ver Pendências): granularidade do vínculo, estratégia de backfill dos registros sem dono, e o que fazer com as policies de `anon` hoje existentes (`anon_insert_informacoes_cliente`, `anon_update_informacoes_cliente`) — não encontrei nenhuma rota pública/anônima no `App.tsx` atual que ainda use isso (todas as rotas estão atrás de `AuthWrapper`), o que sugere que sejam resquícios de um fluxo antigo de "guest checkout" (há migrations históricas `20260521183359_guest_checkout_setup.sql`, `20260521185310_guest_checkout_rls.sql`, `20260528172051_fix_quote_submission_rls.sql` no submodule) que pode já estar morto no frontend atual — vale confirmar antes de decidir se essas policies de `anon` são removidas junto.

### Fluxo mobile-first (estado atual confirmado no código, não é proposta)

```mermaid
flowchart TD
    A[Abre o app] --> B{Logado?}
    B -- não --> C[AuthWrapper: login e-mail/senha]
    C --> B
    B -- sim --> D{onboarding_completado?}
    D -- não --> E["/onboarding: dados do representante + dados da representação"]
    E --> D
    D -- sim --> F[Catálogo "/"]
    F --> G["/clientes: Módulo de Clientes"]
    F --> H["/novo-orcamento"]
    H --> I{Cliente selecionado?}
    I -- não --> J[Tela de seleção obrigatória de cliente]
    J --> I
    I -- sim --> K[Monta orçamento, adiciona itens, salva]
```

### Critérios de aceite

- Header e footer exibem o texto de diferenciação de marca definido com o Vinicius (item 1).
- Um produto com cores de preços diferentes (ex.: Lume, após a correção do item 3) aparece como **um único card** com um swatch por cor e a quantidade correta por cor — verificação manual no catálogo, sem depender de suíte de testes automatizada.
- Um representante autenticado só vê, em `/clientes` e no seletor de cliente de `/novo-orcamento`, os clientes que ele mesmo cadastrou; um segundo representante de teste, logado com outra conta, não vê os clientes do primeiro — verificado manualmente com dois logins reais.
- Tentar criar/montar um orçamento sem cliente selecionado continua bloqueado (já é hoje — não regressão).
- `SELECT` direto no Supabase confirma que a nova coluna de vínculo em `informacoes_cliente_ubiqua` está preenchida em todo registro criado após a migration, e que a policy de SELECT restringe corretamente por `auth.uid()`.
- `04-Sistemas/catalogo-pecas-ubiqua-e6fa0/supabase/AI_DB_CONTEXT.md` existe e reflete o schema atualizado.
- Build e lint do sistema (`pnpm build`, `pnpm lint`) passam sem erro após as mudanças de frontend.

## Realizado

**2026-07-18 — implementação dos itens 1, 6 e 9 + AI_DB_CONTEXT.md (agente implementador).**

Decisões de negócio que estavam pendentes nesta SPEC foram tomadas pelo orquestrador antes desta implementação (não foram decididas pelo agente implementador) e estão registradas abaixo:

- **Item 6 — granularidade do isolamento:** por representante individual (`usuarios_ubiqua.id`), não por empresa/representação, com base na fala do Vinicius na reunião.
- **Item 6 — backfill:** clientes já existentes sem dono ficam com a nova coluna `NULL` (sem atribuição automática), visíveis apenas para admin/interno/staff central, até decisão futura de backfill manual.
- **Item 1 — texto do subtítulo:** "Ubiqua Representações", tratado como placeholder fácil de trocar depois (não é o texto final definitivo do Vinicius).

Migration criada (rascunhada, **não aplicada** no Supabase real):

- `supabase/db/migrations/20260718_052_spec036_ubiqua_isolamento_clientes/001_informacoes_cliente_ubiqua_isolamento_representante.sql` — adiciona `informacoes_cliente_ubiqua.cadastrado_por_usuario_id` (FK para `usuarios_ubiqua.id`) + índice; remove as policies antigas abertas (`"Permitir leitura anon e auth"`, `all_select_informacoes_cliente`, `anon_insert_informacoes_cliente`, `anon_update_informacoes_cliente`, `auth_insert_informacoes_cliente`, `auth_update_informacoes_cliente`); cria policies novas de SELECT/INSERT/UPDATE/DELETE restritas ao dono (`cadastrado_por_usuario_id = auth.uid()`) ou a `usuarios_ubiqua.nivel_acesso IN ('admin','interno')`; mantém intacta a policy pré-existente `"Permitir leitura admin_gerente"` (staff Lucenera central). Efeito colateral: corrige de brinde a ausência total de policy de DELETE nessa tabela (bug pré-existente).
- `supabase/db/migrations/20260718_052_spec036_ubiqua_isolamento_clientes/README.md` — documenta contexto, decisões e status "não aplicada".

Frontend alterado em `04-Sistemas/catalogo-pecas-ubiqua-e6fa0`:

- `src/pages/CustomersPage.tsx` — importa `useAuth` (`@/hooks/use-auth`), pega `user` e, no `handleSave`, ao criar cliente novo (branch `else`), inclui `cadastrado_por_usuario_id: user?.id` no payload do `insert`. Não altera o `update` (edição não muda o dono). `loadCustomers()` não foi alterado — o `select('*')` já existente passa a ser filtrado automaticamente pela RLS nova assim que a migration for aplicada; `NewQuote.tsx` também não precisou de alteração pelo mesmo motivo.
- `src/components/Layout.tsx` — subtítulo "Ubiqua Representações" (desktop) / "Representações" (mobile) abaixo do nome "Ubìqua" no header (Link para `/`); footer trocado de "Ubiqua Peças" para "Ubiqua Representações"; menu desktop: "Clientes" → "Cadastro de Cliente", "Meu Perfil" → "Cadastro de Representante"; bottom nav mobile: rótulo do ícone `Users` trocado de "Clientes" para "Cadastro" (rótulo do ícone `User`/"Perfil" mantido por restrição de espaço mobile, conforme a própria SPEC permite).

Documentação criada:

- `04-Sistemas/catalogo-pecas-ubiqua-e6fa0/supabase/AI_DB_CONTEXT.md` (novo arquivo) — documenta que o Ubiqua usa o Supabase central `vcvcwzmbiftcawncibke`, as 6 tabelas do domínio (`empresa_ubiqua`, `usuarios_ubiqua`, `revenda_ubiqua`, `informacoes_cliente_ubiqua`, `orcamentos_revenda_ubiqua`, `itens_orcamento_ubiqua`), a nova coluna de isolamento, e a característica conhecida de `desc_produto`/múltiplas fontes de planilha em `revenda_ubiqua`.

Verificação feita:

- `npx oxlint src` no submodule: sem erros novos introduzidos pelas mudanças desta SPEC (todos os warnings existentes são pré-existentes, em arquivos não tocados ou em código não relacionado às linhas alteradas).
- `npx vite build`: build passa sem erro (`✓ built in ~3s`).

**2026-07-18 — revisão do agente revisor.** Sem achado crítico. Migration validada linha a linha contra o enum `nivel_acesso_tipo` real e contra as policies hoje existentes em `07_rls_policies.sql` (todas as 6 policies abertas cobertas pelos `DROP`, `"Permitir leitura admin_gerente"` preservada). Confirmado que `CustomersPage.tsx` só renderiza dentro de `AuthWrapper` (garante `user.id` não-nulo no insert) e que nenhum fluxo de usuário comum depende de ler cliente de outro representante. Build/lint sem regressão. Dois avisos não-bloqueantes, endereçados/registrados:
- Cabeçalho de contexto (citando a SPEC) adicionado à migration para bater com a convenção das migrations mais recentes do repo central.
- `src/lib/api.ts:33-76` (`saveClienteInfo()`) é uma segunda função de insert em `informacoes_cliente_ubiqua`, hoje morta (não é chamada em nenhum lugar do submodule), que **não** seta `cadastrado_por_usuario_id` — se um dia for reativada, vai falhar contra a `WITH CHECK` da migration nova. Registrado como pendência abaixo; não corrigido agora por estar fora do escopo desta SPEC (código já morto).

**Não realizado nesta rodada (fora de escopo por instrução explícita):** item 3 (agrupamento de cor em `use-parts.ts`/`groupCatalogItems()`) e item 8 (campos completos de cliente PJ) — ver Pendências.

**2026-07-18 — correção do item 5: ausência de UI de cadastro de representante (agente implementador).**

Achado do bug: a análise original desta SPEC classificava o item 5 (login do representante) como "(a) já implementado", mas isso considerava apenas o fluxo de LOGIN. Na prática, `AuthWrapper.tsx` (único ponto de entrada de autenticação do app) só renderizava um formulário de e-mail/senha chamando `signIn()`. Não existia em nenhum componente um formulário ou link de CADASTRO de conta nova, apesar de `src/hooks/use-auth.tsx` já expor uma função `signUp()` pronta e funcional (confirmado via grep no submodule inteiro: `signUp` só aparecia na definição do hook, nunca era invocada em nenhum componente). Isso bloqueava totalmente o "primeiro acesso do representante" descrito pelo Vinicius.

Arquivo alterado: `04-Sistemas/catalogo-pecas-ubiqua-e6fa0/src/components/AuthWrapper.tsx` (reescrito por completo, sem criar rota ou arquivo novo):

- Adicionado `useState<'login' | 'signup'>('login')` para alternar entre os dois modos dentro do mesmo formulário.
- Modo `signup` usa os mesmos campos de e-mail/senha, mais um campo de confirmação de senha; valida que as senhas batem (`toast.error('As senhas não coincidem.')`) antes de chamar `signUp(email, password)` (desestruturado de `useAuth()`, que já era exportado mas não usado).
- Textos condicionais por modo: título/subtítulo e texto do botão de submit ("Entrar" vs. "Criar Conta"), conforme especificado.
- Link de alternância entre modos abaixo do formulário ("Ainda não tem conta? Criar conta" / "Já tem conta? Entrar"), que também limpa os campos de senha ao trocar de modo.
- Em caso de sucesso no `signUp`, mostra `toast.success('Conta criada! Se pedir confirmação por e-mail, verifique sua caixa de entrada antes de entrar.')` (sem prometer login automático, já que não há acesso para confirmar se a confirmação de e-mail está habilitada no projeto Supabase real) e retorna automaticamente ao modo `login`, sem deixar o usuário preso na tela de cadastro.
- Nenhuma alteração em `use-auth.tsx`, `Onboarding.tsx`, `OnboardingGuard.tsx` ou `App.tsx` — o fluxo pós-cadastro (nova sessão sem `onboarding_completado` → redireciona para `/onboarding`) já funciona automaticamente assim que existir uma sessão ativa.

Verificação feita:

- `npx oxlint src` no submodule: nenhum warning novo nas linhas alteradas de `AuthWrapper.tsx`; todos os warnings existentes são pré-existentes em outros arquivos (`AdminCatalog.tsx`, `CustomersPage.tsx`, `AdminImages.tsx`, `ProfilePage.tsx`, `NewQuote.tsx`).
- `npx vite build`: build passa sem erro (`✓ built in ~2s`).
- **Teste manual pendente (não posso confirmar sozinho):** golden path completo no navegador/celular — clicar em "Criar conta", preencher e-mail/senha/confirmação, submeter, confirmar que a conta é criada no Supabase Auth real e que, ao logar em seguida, o fluxo cai em `/onboarding` como esperado. Também confirmar manualmente se o projeto Supabase real exige confirmação de e-mail antes do primeiro login (não é algo que dá para verificar por leitura de código).

**2026-07-18 — revisão do agente revisor (correção do item 5) + ajuste do orquestrador.** Sem achado crítico; caminho de UI de cadastro confirmado corretamente ligado a `signUp()`, `AuthWrapper` corretamente posicionado antes de `OnboardingGuard` em `App.tsx`. Um aviso real de UX: `use-auth.tsx` descartava o `data` do retorno de `supabase.auth.signUp()`, então `AuthWrapper` não sabia se uma sessão já tinha sido criada — se o projeto Supabase real tiver confirmação de e-mail desabilitada, o usuário já fica logado imediatamente, mas via o toast genérico "verifique seu e-mail" mesmo assim (confuso, embora não quebre nada). Corrigido pelo orquestrador: `signUp()` em `use-auth.tsx` agora retorna também `hasSession: boolean` (baseado em `data.session`); `AuthWrapper.tsx` usa isso para mostrar "Conta criada! Você já está conectado." quando há sessão imediata, ou a mensagem original de confirmação por e-mail quando não há. `npx oxlint`/`npx vite build` seguem sem erro. Segundo aviso do revisor (mensagem de erro genérica para senha curta) não foi corrigido — é consistente com o padrão já existente no restante do arquivo (login também usa mensagem genérica) e não é regressão; fica como possível melhoria futura, não registrado como pendência por ser nitpick de UX.

## Pendências

- [ ] **Bloqueante para o item 8.** Vinicius ainda não enviou o print/lista completa de campos do cadastro de cliente PJ. Só sabemos, por enquanto: é sempre CNPJ (nunca CPF/data de nascimento), e ele citou "regime tributário" como exemplo. Não inventar a lista final — o único ponto de referência real no schema central é `empresas.regime_tributario` (`01_schema_full.sql:4748`, campo `text` livre, sem enum), que pode servir de padrão de nome de coluna, mas não substitui a lista completa que ele vai mandar.
- [x] **DECIDIDO — granularidade do item 6.** Isolamento é por representante individual (`usuarios_ubiqua.id`), não por representação/empresa (`empresa_ubiqua.id`). Justificativa: fala direta do Vinicius na reunião ("representante A cadastra... representante B não consegue visualizar"). Migration já desenhada com essa granularidade (ver Realizado).
- [x] **DECIDIDO — backfill do item 6.** Clientes já existentes em `informacoes_cliente_ubiqua` sem dono ficam com `cadastrado_por_usuario_id = NULL` (não atribuir a ninguém automaticamente) — ficam visíveis apenas para admin/interno (`usuarios_ubiqua.nivel_acesso`) e para staff central (`usuarios.role IN ('admin','gerente')`, via policy pré-existente) até decisão futura de backfill manual.
- [ ] Confirmar se as policies de `anon` em `itens_orcamento_ubiqua`/`orcamentos_revenda_ubiqua` (relacionadas a um fluxo antigo de "guest checkout" que não encontrei mais referenciado no `App.tsx` atual) ainda são necessárias ou podem ser removidas. Em `informacoes_cliente_ubiqua` as policies de `anon` já foram removidas pela migration desta SPEC (ver Realizado).
- [x] **Auditoria de dados do item 3 realizada.** Rodado `SELECT desc_produto, cor, valor_revenda FROM revenda_ubiqua` no Supabase real: de 87 linhas em `revenda_ubiqua`, 16 produtos têm mais de uma cor cadastrada, mas só **1** desses (o produto "CRYSTAL") também tem preços diferentes por cor. Mesmo esse caso não é um bug simples de chave de agrupamento: são registros vindos de fontes de planilha diferentes (`fonte_planilha1/2/3`) com descrições e preços literalmente conflitantes para o que parece ser o mesmo produto físico (ex.: cor CORTEN aparece com preço R$734,27 numa fonte e R$624,91 em outra). **Conclusão:** corrigir isso exige uma decisão de limpeza/deduplicação de dados entre as 3 fontes de planilha (qual fonte é autoritativa quando há conflito), não uma mudança segura de código — permanece como pendência que precisa de decisão humana antes de qualquer fix em `groupCatalogItems()`. Quanto ao caso específico do "Lume" citado pelo Vinicius (2 variantes: CORTEN e PRETO, mesmo preço): já seria agrupado corretamente pelo código atual — a causa provável do Lume não mostrar "4 cores" é que só existem 2 variantes de cor cadastradas no banco para esse produto (dado incompleto, não bug de agrupamento).
- [ ] Confirmar em uma versão publicada/atualizada do sistema se o bug de navegação do logo (item 4) realmente persiste — o código-fonte atual não mostra nenhum problema.
- [x] **DECIDIDO/placeholder — texto do subtítulo de marca do item 1.** "Ubiqua Representações", já implementado no header e footer. É um placeholder fácil de trocar depois (uma das opções que o próprio Vinicius sugeriu na reunião), não é a decisão final e definitiva dele.
- [ ] Avaliar, numa SPEC futura e separada (fora deste escopo), se o login/identidade do representante deve migrar para o modelo central de permissões do Hub/TI, como sugerido pelo Escopo Ubiqua (`SPEC-UBI-02`/`SPEC-UBI-03`) — não é urgente e não foi pedido pelo Vinicius nesta reunião.
- [ ] **Achado do revisor (não-bloqueante):** `04-Sistemas/catalogo-pecas-ubiqua-e6fa0/src/lib/api.ts:33-76` tem uma função `saveClienteInfo()` que insere em `informacoes_cliente_ubiqua` sem setar `cadastrado_por_usuario_id`. Hoje é código morto (nenhum lugar do submodule a chama), então não há risco funcional atual. Mas se um dia for reativada (ex.: futuro fluxo de cadastro rápido de cliente dentro do orçamento), o insert falhará contra a `WITH CHECK` da migration desta SPEC. Recomendação: remover a função morta, ou corrigi-la preventivamente para setar `cadastrado_por_usuario_id`, na próxima vez que alguém mexer nesse arquivo.
