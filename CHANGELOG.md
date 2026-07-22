# Changelog

Registro cronologico das mudancas no repositorio central `Lucenera - ADAPTA PASS`.

## 2026-07-22 (4)

### Corrigido — achado adicional: reserva de estoque por item nunca acontecia na aprovação

- Ao confirmar visualmente se os itens do ORC-0010 apareciam na Necessidade de Compra "Por Item de Orçamento", descoberto que `aprovar_orcamento_financeiro` nunca criava `estoque_saldos_projeto_item` (SPEC-010) nem reservava `estoque_itens.quantidade_reservada` — só criava `projeto_itens`/`projeto_parcelas`/`boletos`. Sem o saldo por item, nenhuma peça consegue aparecer numa tela de déficit de estoque, mesmo com L Fixo vinculado corretamente.
- Existia uma segunda função no banco (`aprovar_orcamento_financeiro_base_spec001`) que já fazia essa reserva corretamente, mas não era a chamada pelo sistema e usava nomenclatura de status desatualizada.
- Corrigido via `supabase/db/migrations/20260722_059_unificar_reserva_estoque_aprovacao/` — incorpora a lógica de reserva na função oficial, preservando o contrato de status da SPEC-016 e o vínculo de L Fixo da SPEC-040. Testado com orçamento sintético (déficit forçado): reserva criada corretamente, item apareceu na view real.
- Backfill retroativo aplicado ao ORC-0010 (autorizado pelo usuário): confirmado visualmente na tela publicada — `ORC-0010 / L03 / PLAFON DE EMB ECO / Pendente 1`.

## 2026-07-22 (3)

### Corrigido — backfill pontual de ORC-0010

- Após o hotfix de `aprovar_orcamento_financeiro`, auditados todos os 12 orçamentos com status `Orçamento Aprovado` para ver quais tinham `projeto_itens`/`projeto_parcelas`/`boletos` faltando. Achado: 4 já estavam corretos, 1 (ORC-0010) tinha dados válidos mas nunca foi processado (0 itens/parcelas/boletos), 1 (ORC-0013) tem 2 itens avulsos textualmente idênticos — impossível vincular ao L Fixo correto sem adivinhar, deixado como está por desenho (decisão P-05 da SPEC-040); 6 (ORC-0004, LEG-1092/1100/1108/1115/1169) ficam pendentes por motivos próprios (dado incompleto no orçamento ou parcela órfã pré-existente da importação legada).
- Corrigido apenas o ORC-0010: status voltado temporariamente para `Aprovação Financeira` (sem alterar itens, não reinicia o ciclo), `aprovar_orcamento_financeiro` chamada de verdade, gerou os 3 `projeto_itens` (vinculados a L01/L02/L03 corretamente), 1 parcela e 1 boleto, status retornado a `Orçamento Aprovado`.
- Os outros 6 orçamentos com pendência continuam documentados em `supabase/db/domains/orcamentos.md`, cada um com o motivo específico — não corrigidos nesta rodada, por decisão explícita do usuário.

## 2026-07-22 (2)

### Corrigido — achado crítico: aprovação de orçamento quebrada em produção há ~2 semanas

- Durante investigação de por que itens de orçamentos já aprovados não apareciam vinculados ao L Fixo na Necessidade de Compra (SPEC-040), descoberto que `aprovar_orcamento_financeiro` — a RPC oficial de aprovação financeira, domínio Orçamentos/Financeiro (SPEC-016) — estava falhando em **toda chamada real** desde algum momento após 06/07/2026 (nenhum `projeto_itens` no banco tem data de criação posterior a essa data).
- Causa: `projeto_itens.subtotal` virou coluna `GENERATED ALWAYS` em 26/06/2026, e a correção necessária (remover o `INSERT` explícito nessa coluna) foi aplicada só numa função legada (`aprovar_orcamento_financeiro_base_spec001`), não na função oficial. Um hotfix não documentado (nenhuma migration deste repositório o captura) reintroduziu o `INSERT` explícito na função oficial depois de 06/07, quebrando a aprovação.
- Corrigido via `supabase/db/migrations/20260722_058_hotfix_aprovar_orcamento_subtotal_gerado/`, testado com um orçamento sintético real (2 itens do mesmo produto em L Fixos diferentes, L01/L35) — aprovação funcionou, `projeto_itens` corretamente vinculados por item, parcela e boleto gerados. Dados de teste removidos.
- Detalhes completos em `supabase/db/domains/orcamentos.md`.

### Pendente

- Decisão de produto separada: aplicar ou não a migration `20260706_020` (checagem de permissão, validação de frete, reserva automática de estoque na aprovação) — nunca foi aplicada de fato, fora do escopo deste hotfix.
- Reextrair `supabase/db/current/` para o domínio de Orçamentos também (mesma pendência crônica já registrada para Compras).

## 2026-07-22 (1)

### Corrigido

- Layout da tela Necessidade de Compra (`compras-lucenera-3o23t98ee`) — correção pós-publicação da SPEC-040 feita pelo usuário: shell da aplicação (`App.tsx`) passa a `h-screen flex flex-col overflow-hidden`, com `<main>` distribuindo altura via `flex-1 min-h-0`; `AppNav.tsx` ganhou `shrink-0` para não ser comprimido pelo flex do shell; `NecessidadeCompra.tsx` trocou o cálculo fixo de altura (`h-[calc(100vh-4rem)]`) por `flex-1 min-h-0`, seguindo o padrão flex do shell em vez de um valor calculado manualmente. Publicado em produção — Skip v0.0.47.

## 2026-07-21 (3)

### Adicionado

- Criada e implementada `SPEC-040_Necessidade_Compra_Granularidade_L_Fixo.md` no sistema `compras-lucenera-3o23t98ee`: nova aba "Por Item de Orçamento" na tela Necessidade de Compra, permitindo comprar uma peça específica de uma posição específica ("L Fixo") de um orçamento específico, sem misturar com outras posições do mesmo produto — coexistindo com a aba "Por Produto" (agregada, SPEC-039), que permanece 100% inalterada.
- Isso reverteu, só para esta aba nova, a decisão de "necessidade de compra agregada por produto" (reunião 08/06/2026) — decisão explícita do usuário nesta sessão, confirmada depois de eu alertar sobre o conflito com a decisão documentada.
- Backend: `projeto_itens.orcamento_item_id`/`l_fixo` (FK real para `orcamento_itens`, gravada automaticamente na aprovação financeira do orçamento); backfill best-effort para itens já existentes (9 de 11 preenchidos; casos ambíguos — mesmo produto em 2+ posições do mesmo orçamento — ficam sem vínculo, sem adivinhação); view nova `vw_necessidade_compra_item_orcamento`; vínculo de origem (`pedido_compra_item_origem`) passa a ser obrigatório (não mais melhor-esforço) nas compras feitas por este fluxo novo.

### Corrigido — achado crítico #2: migration de outro domínio nunca aplicada + hotfix não documentado

- Ao preparar a migration que recria `aprovar_orcamento_financeiro` (função central de Orçamentos/Financeiro, SPEC-016 — precisava ganhar 2 colunas novas para viabilizar a SPEC-040), confirmei via consulta direta ao Supabase real que a função ao vivo diverge significativamente tanto da migration `20260706_020` quanto de `supabase/db/current/03_functions.sql`: falta checagem de permissão (admin/gerente), falta validação de frete obrigatório, falta reserva automática de estoque na aprovação — ou seja, essa migration nunca foi de fato aplicada neste banco (mesmo padrão do achado crítico da SPEC-038 com `pedidos_compra`, agora num domínio diferente). Em contrapartida, a função ao vivo tem lógica (cálculo de subtotal, fallback de descrição) que não existe em nenhuma migration do repositório — um hotfix aplicado direto em produção, nunca capturado em arquivo.
- A migration da SPEC-040 foi reescrita para copiar o corpo real da função (confirmado byte a byte via `pg_get_functiondef`), preservando exatamente o comportamento ao vivo — sem adicionar nem remover a checagem de permissão, validação de frete ou reserva de estoque, que ficam como decisão de produto em aberto, separada, do domínio de Orçamentos/Financeiro.
- Todas as 4 migrations da SPEC-040 aplicadas e testadas via chamadas reais (RPC + REST): backfill confirmado, view nova validada, vínculo de origem obrigatório testado com sucesso.
- Frontend sincronizado com o Skip (projeto 40326), QA completo e publicado em produção — versão `0.0.46`.

### Pendente

- Decidir separadamente (fora do escopo de Compras) se a migration `20260706_020` (checagem de permissão, validação de frete, reserva automática de estoque na aprovação de orçamento) deve ser aplicada intencionalmente, ou se foi abandonada por algum motivo que precisa ser investigado primeiro.
- Reextrair `supabase/db/current/` — pendência crônica, agora reforçada por dois achados críticos do mesmo tipo em dois domínios diferentes.
- Testar o golden path pela UI (validação desta sessão foi via API/RPC direta).

## 2026-07-21 (2)

### Adicionado

- Criada e implementada `SPEC-039_Necessidade_Compra_Grid_Fullscreen_Fix_Busca.md` (fluxo planner → implementador → revisor → orquestrador) no sistema `compras-lucenera-3o23t98ee`: layout full-screen da tela Necessidade de Compra (container e grid ocupam 100% da viewport, todas as colunas sempre visíveis com scroll horizontal em vez de esconder colunas em telas menores); colunas novas Fornecedor, Empresa que comprou, Status do pedido e Data prevista de entrega; correção de um bug real de busca; recálculo de "Pendente" descontando pedidos de compra já em aberto.
- Causa raiz do bug de busca confirmada via chamada HTTP direta ao PostgREST: `produtos.codigo_produto` é `integer`, e o filtro antigo usava `ilike` sobre essa coluna (`operator does not exist: integer ~~* unknown`, erro `42883`) — isso derrubava a query inteira, ou seja, **toda busca não vazia falhava**, não só a busca por código. Corrigido tratando termos só-numéricos como busca exata por código (`.eq`) e o restante como busca por nome (`.ilike`), sem cast em runtime.
- 4 migrations aplicadas e testadas no Supabase real (`20260722_056_spec039_necessidade_compra_grid`): `pedidos_compra.empresa_id` (preenchida automaticamente pela RPC a partir da empresa do usuário autenticado, sem input manual no frontend); views `vw_necessidade_compra_pedidos_abertos`/`vw_necessidade_compra_pedido_detalhe` (resumo agregado por produto + detalhe pedido a pedido no painel expansível, resolvendo o conflito de granularidade produto-vs-pedido); `vw_necessidade_compra` recriada com as colunas `pendente`/`qtd_pedidos_abertos`/`proxima_data_prevista_entrega`, e o filtro de visibilidade da lista mudou de "só estoque físico" para "descontando também pedidos de compra já em aberto" (decisão do usuário: produto sai da lista quando o déficit já está 100% coberto por pedido em andamento).
- Teste end-to-end encontrou e corrigiu um resíduo de dados de teste da sessão da SPEC-038 (um pedido de teste `PC-2026-0001` que não foi limpo corretamente por um bug de ordem no script de cleanup daquela sessão) — removido da base real, sem relação com o código desta SPEC.
- Frontend sincronizado com o Skip (projeto 40326), QA completo e publicado em produção — versão `0.0.45`.

### Pendente

- Reextrair `supabase/db/current/` — pendência crônica reafirmada mais uma vez.
- Testar o golden path pela UI (a validação desta sessão foi via chamadas diretas à API/RPC, não clicando na tela).

## 2026-07-21 (1)

### Adicionado

- Criada e implementada `SPEC-038_Impostos_Numeracao_Vinculo_Parcelas_Desconto_Compras.md` (fluxo planner → implementador → revisor → orquestrador) no sistema `compras-lucenera-3o23t98ee` (Necessidade de Compra / Cotações): custo separado em líquido+ICMS+IPI+ST (editável, pré-preenchido do cadastro do produto); numeração automática de pedido (`PC-<ano>-NNNN`); vínculo informativo (opcional, nunca bloqueante) entre item de pedido e item de projeto de origem; parcelas reais do pedido de compra ao fornecedor, geradas automaticamente e com valor/vencimento editáveis manualmente por parcela (decisão explícita do usuário); campo "% desconto" em Cotações isolado do desconto que já afeta o preço de venda ao cliente.
- Revisão (`revisor`) encontrou 2 avisos técnicos antes do commit — ambos corrigidos: `criar_pedido_compra_de_necessidade` teria virado uma sobrecarga órfã no Postgres (assinatura mudou de 8 para 12 parâmetros, `CREATE OR REPLACE` não substitui function com número de parâmetros diferente — corrigido com `DROP FUNCTION` explícito da assinatura antiga); tabela nova `pedido_compra_item_origem` tinha policy de INSERT aberta em vez de escrita só via RPC (padrão do resto do domínio) — corrigido com nova RPC `vincular_origem_pedido_compra_item`.

### Corrigido — achado crítico: "Registrar Compra" estava quebrado em produção desde 10/07

- Antes de aplicar as migrations da SPEC-038, uma checagem direta no Supabase real (não em `supabase/db/current/`, que documentava errado) revelou que a tabela `pedidos_compra` — usada pelas RPCs `criar_pedido_compra_de_necessidade`/`criar_pedido_compra_lote` desde a SPEC-021 (10/07) — **nunca existiu de verdade**. A migration que deveria criá-la (`20260710_031_spec020_operacionalizacao_compras/004_pedidos_compra.sql`) nunca tinha sido aplicada, só as vizinhas do mesmo lote. Como PL/pgSQL não valida tabelas referenciadas na criação da function, só na execução, as RPCs existiam e pareciam normais, mas todo INSERT real falhava. A funcionalidade de "Registrar Compra" (individual e em lote) esteve quebrada em produção por ~11 dias sem detecção — inclusive a SPEC-035 (análise de lacunas, 18/07) repetiu o engano de assumir "backend pronto" sem checar o banco real.
- Aplicada a migration retroativa `004_pedidos_compra.sql` (cria a tabela + FK que faltava em `pedido_compra_itens.pedido_id`), e corrigidas 2 colunas legadas com `NOT NULL` indevido em `solicitacoes_compra` (`projeto_id`, `quantidade_pedida`) que também bloqueavam as RPCs. As 2 RPCs de registrar pedido de compra foram testadas de ponta a ponta via chamada HTTP real (não simulação) e funcionaram — provavelmente a primeira vez desde que foram criadas.
- As 5 migrations da SPEC-038 aplicadas e testadas em seguida (numeração automática, geração/edição de parcelas, vínculo de origem, desconto de compra, view estendida) — tudo confirmado funcionando via teste real, dados de teste removidos depois.
- A correção retroativa (aplicação de `004_pedidos_compra.sql` + FK `pedido_compra_itens.pedido_id` + as 2 colunas `NOT NULL` removidas) foi capturada em arquivo de migration próprio, `20260721_055_fix_pedidos_compra_base`, para reprodutibilidade em outros ambientes (as 3 correções já haviam sido aplicadas diretamente no banco antes de existir o arquivo).

### Publicado

- Frontend de `compras-lucenera-3o23t98ee` sincronizado com o Skip (projeto 40326), QA completo (setup/análise estática/build/integrações/testes) e publicado em produção — versão `0.0.44`, `https://pagina-em-branco-cdd79.goskip.app`.
- Commit no submodule `compras-lucenera-3o23t98ee` (`977e36e`) com os 11 arquivos de frontend da SPEC-038 (9 modificados + 2 novos: `PedidosCompra.tsx`, `PedidoParcelasPanel.tsx`).

### Pendente

- Testar o golden path pela UI (não só via RPC direta) dos 5 itens da SPEC-038 — backend e frontend já publicados, falta o usuário clicar no fluxo completo.
- Reextrair `supabase/db/current/` — pendência crônica (SPEC-030/033/034/038), agora ainda mais urgente: a documentação estava desatualizada a ponto de esconder que uma tabela inteira não existia.

## 2026-07-20 (2)

### Corrigido (5)

- **E-mail de notificação confirmado funcionando** (SPEC-037): usuário confirmou que o e-mail do teste caiu na pasta de spam de `vinicius@lucenera.com.br`/`pedro@lucenera.com.br` — ou seja, o envio via Gmail SMTP está funcionando; falta só os destinatários marcarem "Não é spam" para melhorar a reputação do remetente.
- Bug achado pelo usuário: botão "Baixar PDF" (na tela de orçamento salvo) sempre falhava com "Erro ao gerar o documento" — `savedQuote` nunca incluía a lista de itens (`QuoteData.items` ficava `undefined`), e `generateQuoteHTML` precisa desse array. Corrigido anexando o `items` do carrinho (capturado antes do `clearCart()`) ao `savedQuote`. Mesma causa também afetava "Enviar por E-mail".

### Adicionado (2)

- Cadastro de cliente (`CustomersPage.tsx`) passou a aceitar **CPF ou CNPJ**, não só CNPJ — pedido do usuário, revisando a decisão da SPEC-036 ("sempre CNPJ, nunca CPF"). Novo helper `formatCPFOuCNPJ`/`isValidCPFOuCNPJ` em `src/lib/utils.ts` detecta automaticamente qual dos dois pelo número de dígitos digitados. `AI_DB_CONTEXT.md` atualizado.

## 2026-07-20 (1)

### Adicionado

- Criada `SPEC-037_Ubiqua_Backorder_Sem_Estoque_e_Necessidade_Importacao.md`: toda a marca Ubiqua é importada pela empresa do usuário, então "sem estoque" e "aguardando importação" são o mesmo conceito. Implementado: texto "Não tem aquela peça em estoque" trocado por "Sem estoque" em `PartCard.tsx`/`QuantityModal.tsx`/`NewQuote.tsx`; botão "Adicionar ao Orçamento" deixou de ser bloqueado por falta de estoque (`PartCard.tsx`, combobox de busca e controles de quantidade em `NewQuote.tsx`, guard silencioso removido de `use-cart.tsx`); `QuantityModal.tsx` ganhou aviso de backorder com card visual (logo `og-image.png`) e checkbox de ciência do prazo de até 3 meses, com teto técnico de quantidade de 999 quando sem estoque.
- Migration `supabase/db/migrations/20260719_053_ubiqua_necessidade_importacao/` (rascunhada, **não aplicada** no Supabase real): coluna `itens_orcamento_ubiqua.sem_estoque_no_pedido` (snapshot no momento do pedido) + view `vw_necessidade_importacao_ubiqua` (demanda agregada por produto, decisão tomada após comparar 3 alternativas de modelagem — ver SPEC-037). `NewQuote.tsx` já grava a coluna e preenche `orcamentos_revenda_ubiqua.prazo_entrega` com aviso de importação quando o orçamento tem item de backorder.
- `AI_DB_CONTEXT.md` do sistema Ubiqua atualizado com a nova coluna, view e a seção "Necessidade de importação".

### Corrigido

- Bug crítico bloqueando testes: `CustomersPage.tsx` usava `formatCNPJ`/`isValidCNPJ` sem importar de `@/lib/utils` (diferente de `ProfilePage.tsx`/`Onboarding.tsx`, que importam certo) — o campo de CNPJ do cadastro de cliente não aceitava digitação (o `onChange` lançava `ReferenceError` antes de atualizar o estado).
- Sincronização com Skip: corrigido bug de imagem sumindo na página de detalhe do produto — a causa real não era o `onLoad`/cache de imagem (hipótese original), e sim o plugin legado `@tailwindcss/aspect-ratio` em `tailwind.config.ts` desabilitando a utility nativa `aspect-square` do Tailwind v3, colapsando o container da imagem para ~2px de altura. Removido o plugin (não usado por nenhum componente).

### Corrigido (2)

- Bug crítico bloqueando qualquer salvamento de orçamento novo, achado no primeiro teste real do usuário: `itens_orcamento_ubiqua.valor_total` é coluna `GENERATED ALWAYS` (calculada como `quantidade * valor_unitario - desconto_item`) no schema real, mas `NewQuote.tsx` tentava inserir um valor nela explicitamente — Postgres rejeitava com `cannot insert a non-DEFAULT value into column "valor_total"`. Bug pré-existente, não introduzido pela SPEC-037. Corrigido removendo o campo do insert.
- Migration `20260719_053_ubiqua_necessidade_importacao` **aplicada no Supabase real** (coluna `sem_estoque_no_pedido` e view `vw_necessidade_importacao_ubiqua`, verificadas via `information_schema`), com confirmação explícita do usuário, pelo orquestrador.
- Teste ponta a ponta em produção após os dois fixes: orçamento **ORC-2026-000012** salvo com sucesso, usando cliente real já cadastrado. Esse salvamento também dispara `process-budget-pdf` — pendente o usuário confirmar se o e-mail chegou em `vinicius@lucenera.com.br`/`pedro@lucenera.com.br`.

### Corrigido (3)

- **Causa raiz de "e-mail não chega" identificada**: usuário confirmou que nenhum e-mail chegou no teste do ORC-2026-000012. Verificado via `supabase secrets list --project-ref vcvcwzmbiftcawncibke`: a secret `RESEND_API_KEY` **não existe** no projeto Supabase real — nem para `process-budget-pdf`, `welcome-email` ou `enviar-confirmacao-email`. Não é bug de código, é configuração ausente; usuário precisa cadastrar a chave da própria conta Resend (o assistente não manuseia essa credencial).
- Corrigido bug adjacente: `process-budget-pdf` escondia falha de envio (`console.error`/`console.warn` sem `throw`, sempre retornava `success:true`). Agora propaga erro real. Deployado no Supabase real (`supabase functions deploy`, confirmado pelo usuário) — corrigido nas duas cópias (submodule e repo central).
- **Achado**: `supabase functions deploy` rodado da raiz do repo central publicou a partir de `supabase/functions/` do repo central — resolve a dúvida em aberto da SPEC-037 sobre qual cópia (submodule vs. central) é a fonte real de deploy das Edge Functions.

### Corrigido (4)

- Trocado o provedor de e-mail de `process-budget-pdf` de Resend para Gmail SMTP: usuário não tem acesso ao DNS de `lucenera.com.br`, então não dá pra verificar domínio customizado no Resend (obrigatório para entregar fora da própria conta). Agora usa `nodemailer` autenticado via senha de app do Google, remetente `erp.lucenera@gmail.com`. Secrets: `GMAIL_USER` (configurado) e `GMAIL_APP_PASSWORD` (pendente do usuário).
- **Incidente de segurança**: durante a sessão, o usuário colou em texto puro uma API key do Resend e a senha da conta Gmail `erp.lucenera@gmail.com`. O assistente recusou usar as duas (regra fixa: nunca inserir senha/API key/token em nenhum sistema, mesmo com autorização explícita do usuário) e orientou a revogar/trocar ambas.

### Pendente

- Usuário gerar senha de app do Google (myaccount.google.com/apppasswords) e configurar `GMAIL_APP_PASSWORD` nas secrets do Supabase (`supabase secrets set GMAIL_APP_PASSWORD=... --project-ref vcvcwzmbiftcawncibke`) — depois disso, o disparo de e-mail em todo pedido deve funcionar sem nenhum código novo.
- Confirmar que o usuário revogou a API key do Resend exposta e trocou a senha da conta Gmail.
- Reextrair `supabase/db/current/` para refletir a migration `20260719_053` já aplicada.
- Decidir endereços do fluxo `approvePurchase` (admin) — manter `vinicius@ubiqua.com`/`josi@ubiqua.com` ou trocar para os novos `@lucenera.com.br`.
- Teto de negócio real de quantidade em pedido sob encomenda — decisão do usuário com o gerente, teto técnico provisório de 999 em uso.
- Commit e push do submodule + ponteiro no repo central.

## 2026-07-18 (6)

### Adicionado

- Registrado o sistema "Catálogo de Peças Ubiqua" (`04-Sistemas/catalogo-pecas-ubiqua-e6fa0`, `pedrolalala/cat-logo-pe-as-ubiqua-`) como submodule central. Achado arquitetural: usa o mesmo projeto Supabase central (`vcvcwzmbiftcawncibke`), não um projeto separado.
- Criada e implementada `SPEC-036_Catalogo_Ubiqua_Marca_Isolamento_Clientes_e_Cores.md` (planner → implementador → revisor), a partir da análise da reunião com o Vinicius (representante/sócio Ubiqua). Entregue: subtítulo de marca "Ubiqua Representações" no header/footer; menus renomeados para deixar explícito "Cadastro de Cliente"/"Cadastro de Representante"; isolamento de clientes por representante individual — nova coluna `informacoes_cliente_ubiqua.cadastrado_por_usuario_id` + RLS restrita ao dono ou a `nivel_acesso IN ('admin','interno')`, substituindo policies antigas totalmente abertas (`USING (true)` para anon/authenticated); `AI_DB_CONTEXT.md` novo documentando o domínio Ubiqua.
- **Efeito colateral corrigido de brinde**: não existia nenhuma policy de DELETE em `informacoes_cliente_ubiqua` — exclusão de cliente nunca funcionava. Corrigido pela mesma migration.
- Migration `supabase/db/migrations/20260718_052_spec036_ubiqua_isolamento_clientes/` aplicada no Supabase real e verificada (coluna, 5 policies, índice, os 4 clientes pré-existentes ficaram com `cadastrado_por_usuario_id = NULL`, sem atribuição automática).

### Corrigido

- Achado crítico separado durante o teste do fluxo: o app Ubiqua não tinha **nenhuma forma de um representante novo criar conta** — `AuthWrapper.tsx` só implementava login; a função `signUp()` já existia no hook `use-auth.tsx` mas nunca era chamada por nenhum componente. Corrigido: alternador Entrar/Criar Conta no mesmo formulário, com validação de confirmação de senha. Ajuste adicional: `signUp()` passou a retornar `hasSession`, para mostrar a mensagem certa ao usuário conforme o projeto Supabase exigir ou não confirmação de e-mail.

### Investigado, não corrigido (decisão consciente)

- Hipótese original da SPEC de que o agrupamento de variantes de cor (`groupCatalogItems()` em `use-parts.ts`) tinha um bug de chave de agrupamento não se confirmou por auditoria direta dos dados reais: só 1 produto ("CRYSTAL") tem cores com preços diferentes, e mesmo esse caso vem de descrições/preços conflitantes entre 3 planilhas de origem diferentes (`fonte_planilha1/2/3`) — não é um bug de código, é dado duplicado/conflitante entre fontes. `use-parts.ts` não foi alterado; fica pendente decisão de qual planilha é autoritativa.
- Cadastro de cliente PJ completo (campos além de nome/email/telefone/CNPJ) segue bloqueado até o Vinicius enviar a lista/print combinada na reunião.

### Pendente

- Vinicius enviar campos completos do cadastro de cliente PJ.
- Decidir fonte de planilha autoritativa em `revenda_ubiqua` antes de revisitar o agrupamento por cor.
- Homologação manual do golden path completo (criar conta → onboarding → catálogo → cadastro de cliente → orçamento) em dispositivo real — não testável por leitura de código.
- Commit e push do submodule + ponteiro no repo central.

## 2026-07-18 (5)

### Adicionado

- Criada e implementada `SPEC-034_Sugestao_Automatica_Fornecedor_por_Marca.md` (fluxo planner → implementador → revisor). Análise real no Supabase mostrou que 63 das 109 marcas sem fornecedor tinham candidato de nome quase idêntico via `word_similarity()`. Entregue: correção da RPC `buscar_fornecedores_fuzzy` (usava `similarity()`, que não achava termo curto em nome de fornecedor longo — pendência aberta desde a SPEC-030), nova RPC `sugerir_fornecedores_marcas()`, e tela "Marcas" ganhou badge de sugestão + confirmação individual ou em lote (sempre com revisão explícita, nunca aplicação automática). Migrations aplicadas no Supabase real, revisado sem achado crítico, commitado (`51123f8`) e publicado em produção via Skip (`0.0.43`).
- **61 das 63 marcas de alta confiança foram vinculadas ao fornecedor** nesta sessão, a pedido do usuário. 2 casos foram sinalizados como possível falso positivo (encontrados só ao revisar a lista completa, fora da amostra que embasou a SPEC) e excluídos após confirmação do usuário: "LIGHT LIGHT"→"OMEGA LIGHT" (match por palavra genérica "LIGHT") e "OUTROS"→"OUTROS" (parecem registros placeholder dos dois lados). Total de marcas com fornecedor vinculado: 62 de 109.

## 2026-07-18 (4)

### Corrigido

- SPEC-033 (`compras-lucenera-3o23t98ee`): Pedro reportou que, mesmo após usar a tela nova "Marcas" para vincular fornecedor, os checkboxes de "Necessidade de Compra" continuavam desabilitados. Diagnóstico confirmado por teste direto no Supabase real: `UPDATE marcas SET fornecedor_id = ...` via SQL puro funciona e a view reflete corretamente — o bug estava só no frontend. Causa raiz: `atualizarFornecedorMarca()` chamava `.update().eq('id', ...)` **sem `.select()`**; quando a policy RLS bloqueia a escrita (0 linhas afetadas), o Postgrest não gera erro nenhum (`Prefer: return=minimal`), então a função assumia sucesso e mostrava toast de confirmação mesmo sem nada persistir. Corrigido encadeando `.select('id').single()` e tratando ausência de dado retornado como falha explícita. Revisado sem achado crítico, commitado (`255d30b`), pushado e republicado em produção via Skip (`0.0.42`).
- Registrada suspeita não confirmada para acompanhamento caso o erro persista após a correção: sessão JWT expirada/anônima no frontend, ou mismatch entre `auth.uid()` e `usuarios.id` para o usuário real logado — ambas as causas ficariam agora visíveis via toast de erro explícito, em vez de falso sucesso.

## 2026-07-18 (3)

### Adicionado

- Criada e implementada `SPEC-033_Fornecedor_por_Marca_e_Melhorias_Necessidade_Compra.md` (fluxo completo planner → implementador → revisor). Diagnóstico: o Pedido em Lote (SPEC-030 Parte 2) estava 100% travado — 0 de 233 produtos com necessidade de compra tinham `fornecedor_id` resolvido, porque `marcas.fornecedor_id` nunca foi preenchido para nenhuma das 110 marcas (não existia tela para isso). Entregue nesta sessão: tela nova "Marcas" (`/marcas`) em `compras-lucenera-3o23t98ee` para mapear marca → fornecedor pela UI (sem SQL manual); coluna "Disponível" em "Necessidade de Compra" (saldo real, pode ser negativo — campo já existia na view, só não era exibido); contexto de estoque (física/comprometida/disponível) dentro do modal "Pedido em Lote". Nenhuma migration nova. Revisado sem achado crítico, commitado (`1ebbace`), pushado e publicado em produção via Skip MCP (`pagina-em-branco-cdd79.goskip.app`, versão `0.0.41`).
- **Pendente**: o backfill em si (mapear cada uma das ~110 marcas ao fornecedor correspondente) continua sendo trabalho manual de Pedro/Filippo pela nova tela — sem isso, o Pedido em Lote continua sem itens selecionáveis.

## 2026-07-18 (2)

### Adicionado

- Criada e implementada `SPEC-032_Header_Unico_Itens_Orcamento.md`: na tela de edição de orçamento, o cabeçalho de colunas dos itens (`Luminária, Código Produto, Código de Referência, Produto, Qtd, Preço Unit., Desc %, Subtotal`) deixa de se repetir a cada item — passa a aparecer uma única vez, no topo da lista, em telas largas (mobile inalterado, a pedido do usuário). Componente novo `BudgetItemsHeader.tsx`; `BudgetItemCard.tsx` esconde os rótulos por campo via `lg:hidden`. Commitado/pushado (`2e139e8`) e publicado em produção via Skip MCP (versão `0.0.295`).
- Achado durante a publicação: `BudgetFormPage.tsx` no Skip tem um campo (`prazo_entrega_dias`, schema + UI completos) que não existe em nenhum commit do GitHub — usado `skip_file_patch` (busca/substituição cirúrgica) em vez de sobrescrever o arquivo inteiro, para não perder essa funcionalidade só-Skip. Registrado como pendência de investigação na SPEC-032.

## 2026-07-18

### Adicionado

- Criada e implementada `SPEC-031_Etapa_Aprovacao_Equipe_Orcamentos.md`: novo status `Aprovação da Equipe` no fluxo de orçamentos (`enviado_cliente -> Aprovação da Equipe -> Aprovação Financeira -> Orçamento Aprovado`), permitindo que a equipe confirme ou devolva ao cliente (com motivo obrigatório, trocando peça/cor) depois da visita à obra. Migration aplicada no Supabase real (`supabase/db/migrations/20260718_050_spec031_aprovacao_equipe_orcamentos/`): altera as 5 funções de aprovação do cliente para parar em `Aprovação da Equipe`, cria as RPCs `equipe_aprovar_orcamento`/`equipe_devolver_orcamento_cliente`, e cadastra o módulo `aprovacao_equipe` no Hub (SPEC-006, reaproveitando a ação `editar` já existente). Frontend implementado em `gestao-financeira-clone-544cb (1)` (`TeamApprovalTab.tsx` novo, `budget-status.ts`, `Budgets.tsx`, `BudgetFormPage.tsx`, `useBudgetStore.ts`), commitado/pushado (`066f2f3`, após reconciliar com 2 commits que já estavam em `origin/main`) e **publicado em produção via Skip MCP** (`https://gestao-financeira-clone-544cb.goskip.app`, versão `0.0.294`). Lint/build limpos, QA do Skip limpo. **Pendente**: conceder a permissão do módulo a algum papel no Hub (só admin/gerente conseguem agir por enquanto), homologar no app publicado.
- Achado durante a publicação: o projeto Skip tinha uma versão (`5492ca4`) sem correspondência em nenhum commit do GitHub, e o arquivo `useBudgetStore.ts` no Skip tinha um campo (`prazo_entrega_dias`) ausente do GitHub — preservado ao escrever a atualização (não sobrescrito às cegas). Risco de divergência Skip x GitHub documentado como pendência aberta na SPEC-031.
- Durante a implementação, confirmado por query direta no Supabase real que os objetos da SPEC-019 (`aprovado_cliente_origem`, `financeiro_editar_orcamento`, `buscar_orcamento_para_aprovacao`, `recusar_orcamento_cliente_publico`, trigger de reset) existem em produção — o snapshot local (`supabase/db/current/`) é que está desatualizado desde 2026-07-07, não a SPEC-019.

## 2026-07-17

### Corrigido

- Aplicadas no Supabase real as 5 migrations de `supabase/db/migrations/20260716_049_spec030_pedido_lote_marca_fornecedor/` (SPEC-030 Parte 2), que estavam apenas em rascunho desde 2026-07-16: coluna `marcas.fornecedor_id`, `vw_necessidade_compra` estendida com `marca_id`/`marca_nome`/`fornecedor_id`/`fornecedor_nome`, RPC `criar_pedido_compra_lote`, índice fuzzy `idx_contatos_nome_unaccent_trgm` e RPC `buscar_fornecedores_fuzzy`. Motivo: Pedro reportou que a marca não aparecia vinculada em Necessidade de Compra (sistema `compras-lucenera-3o23t98ee`), apesar de já aparecer em Estoque de Produtos — o frontend já estava pronto (commit `eb5cc7e`), só faltava a migration no banco.
- Corrigidos 2 bugs no rascunho da migration, encontrados só ao aplicar contra o Postgres real: (1) `004_idx_contatos_nome_unaccent_trgm.sql` usava `unaccent()` direto em expressão de índice, que exige função `IMMUTABLE` (`unaccent()` é `STABLE`) — corrigido com wrapper `public.immutable_unaccent()`; (2) `005_rpc_buscar_fornecedores_fuzzy.sql` tinha `SELECT DISTINCT ... ORDER BY` por expressão fora da lista de SELECT, rejeitado pelo Postgres — corrigido com subquery.
- Confirmado por query direta: `vw_necessidade_compra` agora retorna `marca_nome` preenchido em 230 de 233 linhas (as 3 restantes são produtos sem `marca_id` cadastrado, não um bug).

### Pendente

- Backfill de `marcas.fornecedor_id` (mapeamento marca → fornecedor, decisão de dado de Pedro/Filippo) — sem ele, `fornecedor_id`/`fornecedor_nome` continuam nulos e o Pedido em Lote não tem itens selecionáveis, embora a marca já apareça.
- Busca fuzzy de fornecedor (`buscar_fornecedores_fuzzy`) roda sem erro mas retorna 0 resultados em buscas curtas contra nomes de fornecedor longos (ex.: "Stella" vs. "STELLA IMPORTACAO E EXPORTACAO DE LUMINARIAS LTDA" tem `similarity() = 0.119`, abaixo do threshold `0.3`) — precisa de ajuste de algoritmo (`word_similarity()` em vez de `similarity()`), não só de threshold. Ver Pendências da SPEC-030 Parte 2.
- Teste manual no navegador e publicação via Skip continuam pendentes do usuário.
- Reextração do snapshot `supabase/db/current/` (desatualizado desde 2026-07-07) continua pendente.

## 2026-07-16

### Corrigido

- `compras-lucenera-3o23t98ee`: commit `55fd80e` (pushado) corrige `getFornecedores()` em `src/services/pedido-compra.ts` para filtrar por `contato_tipos.tipo = 'fornecedor'` (antes retornava contatos de qualquer tipo — arquiteto, cliente — na busca de "Marca/Fornecedor" do Registrar Pedido de Compra). Removida duplicata morta `getFornecedores()`/`FornecedorOption` em `services/compras.ts` e o mock associado. Ponteiro do submodule atualizado no repo central (`6ca80f2`). SPEC-030, Parte 1. Revisado pelo agente `revisor` sem achado crítico/aviso, lint/build limpos. **Publicação via Skip ainda pendente**: o servidor MCP `skip` está registrado mas com status "Needs authentication" — falta concluir OAuth para liberar as ferramentas `mcp__skip__*` de publish.

### Atualizado

- `03-Projeto/Planos de Ação/SPECs/SPEC-030_Fix_Filtro_Tipo_Fornecedor_Compras.md` expandida com uma Parte 2 (planejamento, não implementado): consolidar a Necessidade de Compra por fornecedor, fluxo de "Pedido em Lote" (1 pedido = 1 fornecedor, gerado a partir de `produtos.fornecedor_principal_id`) e busca de fornecedor tolerante a erro de digitação/variação de nome via `pg_trgm` + `unaccent` (extensões já habilitadas no banco). Decisões de escopo confirmadas por Pedro; implementação ainda não iniciada.

### Adicionado

- SPEC-030 Parte 2 implementada em código (commit `d1a2a7e`, pushado): filtro por **marca** (não fornecedor direto — marca/fornecedor tratados como equivalentes a pedido de Pedro) na Necessidade de Compra, fluxo de "Pedido em Lote" (`ModalPedidoLote.tsx` + RPC `criar_pedido_compra_lote`, generalização transacional de `criar_pedido_compra_de_necessidade`) e busca de fornecedor tolerante a erro de digitação via nova RPC `buscar_fornecedores_fuzzy` (`pg_trgm` + `unaccent`, threshold `similarity() > 0.3`). Migrations em rascunho (`supabase/db/migrations/20260716_049_spec030_pedido_lote_marca_fornecedor/`), **ainda não aplicadas no Supabase real** — inclui a coluna nova `marcas.fornecedor_id` (nullable, depende de backfill manual de Pedro/Filippo: mapear cada marca ao fornecedor correspondente). Revisado pelo agente `revisor` sem achado crítico/aviso; lint/build limpos. Publicação via Skip segue pendente (mesmo bloqueio de OAuth do MCP `skip` da Parte 1).
- Durante o push do commit `d1a2a7e`, reconciliados via merge vários commits automáticos do bot `Skip <skip@usecurling.com>` já presentes em `origin/main` (bumps de versão `v0.0.30`–`v0.0.32` e sincronizações de build) — evidência de que a plataforma Skip publica direto no GitHub por conta própria, independente da autenticação do MCP usada por agentes desta sessão.

## 2026-07-07

### Adicionado

- Criada `SPEC-019_Origem_Aprovacao_Cliente_e_Reset_Pos_Aprovacao.md`: coluna `orcamentos.aprovado_cliente_origem` (manual/token), reset automático da aprovação ao editar valor/frete/forma de pagamento/prazo/itens de um orçamento já em `Aprovação Financeira`/`Orçamento Aprovado`, RPC `financeiro_editar_orcamento` com opção explícita de não reiniciar (modal na tela de Aprovação Financeira), e criação de `buscar_orcamento_para_aprovacao`/`recusar_orcamento_cliente_publico` — RPCs que o frontend do sistema de Orçamentos (`ClientApproval.tsx`) já chamava mas nunca existiram no banco, causando "Link Inválido" em qualquer link público de aprovação.
- Corrigido no sistema de Orçamentos: modal de criar cliente/projeto direto do formulário de orçamento mostrava sucesso sem persistir nada — o evento de submit borbulhava por portal React até o form pai; adicionado `stopPropagation` em `ClientCreateModal.tsx`/`ProjectCreateModal.tsx`.
- Criado `03-Projeto/07_ANALISE_LACUNAS_IMPLEMENTACAO_2026_07_07.md`, comparando reuniões, mapeamentos, SPECs, snapshot Supabase e código dos sistemas para listar lacunas implementáveis, bloqueios, riscos de segurança, status de build/lint e ordem recomendada de execução.
- Implementadas localmente as migrations centrais `20260708_029_spec006_permissoes_granulares_hub` e `20260708_030_spec007_sso_cross_system`, com permissões granulares no Hub, SSO por `sso_code`, Edge Functions `generate-cross-system-code`/`exchange-cross-system-code` e checagem TDD em `scripts/verify-spec006-007.mjs`.
- Criada a evidência TDD `03-Projeto/Evidencias TDD/SPEC-006-007_TDD_2026_07_07.md` com RED/GREEN e comandos de build/lint executados.
- Adicionado `src/lib/cross-system-auth.ts` nos apps Hub, Orçamentos, Financeiro/Retorno e CRM para `redirectWithCode`/`consumeCodeFromUrl`.
- Aplicada/verificada a SPEC-006 no Supabase remoto e aplicada a SPEC-007 via `SUPABASE_DB_URL` do `.env`; Edge Functions `generate-cross-system-code` e `exchange-cross-system-code` publicadas como `ACTIVE`.

### Atualizado

- Atualizado `03-Projeto/00_INDICE.md` para incluir a análise de lacunas e corrigir status obsoletos das SPECs 008 a 018.
- Atualizadas `SPEC-006`, `SPEC-007`, `00_TASKS_GERAIS_ECOSSISTEMA.md`, `supabase/db/domains/hub_ti.md` e contextos locais dos sistemas afetados para refletir aplicação/publicação remota e pendência real de homologação/adopção.
- Reextraído `supabase/db/current/` após SPEC-006/007, atualizando schema, funções, triggers, views, policies, inventário e manifesto.
- Hub/Central: dashboard agora prefere `hub_sistemas_permitidos` para cards por permissão e abre sistemas com `redirectWithCode`; administração recebeu telas de papéis, exceções e auditoria de permissões.
- Orçamentos, Financeiro/Retorno e CRM: fluxos cross-system passaram a consumir/gerar `sso_code` para evitar login duplicado entre apps, mantendo fallback para link direto.
- Implementada a SPEC-014 no CRM: `getProjeto()` passa a carregar `projeto_itens(*)` e `ProjectDetail.tsx` ganhou o Card "Itens Aprovados do Projeto", somente leitura, com quantidade, preço, desconto, subtotal, origem por orçamento e situação `Cancelado`/`Ativo`. `getProjetos()` permaneceu sem `projeto_itens(*)` para não pesar a listagem. Badges ricos de estoque seguem pendentes da leitura da SPEC-010 com RLS/policy definida.
- Confirmada a SPEC-010 no Supabase real e escrita a migration corretiva `20260707_023_spec010_hardening`: recria views com `security_invoker`, revoga grants de `anon`/`authenticated`, reconcilia `estoque_itens.quantidade_reservada` para os quatro produtos divergentes encontrados e endurece `trigger_fechar_projeto` para não transformar `q_entrega_futura` diretamente em entregue.

## 2026-07-06

### Atualizado

- Escrita a migration central `20260706_022_saldos_estoque_projeto_item` implementando a SPEC-010 (saldos operacionais de estoque por item de projeto): cria `estoque_saldos_projeto_item`/`estoque_movimentos_projeto_item`, atualiza `aprovar_orcamento_financeiro_base_spec001` (alocação `q_reserva`/`q_entrega_futura` item por item, com lock por produto/local), `cancelar_orcamento` (reversão pelo saldo aberto real, não pela quantidade original) e `trigger_fechar_projeto` (move saldo para `q_entregue`), cria as views `vw_estoque_saldos_projeto_item`/`vw_estoque_por_produto_projeto`/`vw_estoque_resumo`, e um backfill conservador para itens aprovados antes da migration. RLS habilitada sem policy nas duas tabelas novas, por decisão de segurança pendente (ver README da migration e pendência crítica 7 do checklist geral). Aplicação no Supabase real confirmada em 07/07/2026; hardening complementar ficou em `20260707_023_spec010_hardening`.
- Aplicadas no Supabase real as migrations centrais `20260706_020_normalizacao_aprovacao_financeira_orcamento` e `20260706_021_criar_produto_orcamento`.
- Normalizada a aprovação financeira de orçamento no banco conforme SPEC-016: contrato oficial `enviado_cliente -> Aprovação Financeira -> Orçamento Aprovado`, RPC transacional por `orcamento_id`, wrappers legados protegidos e auditoria por orçamento.
- Criada a RPC `public.criar_produto_orcamento(p_payload jsonb)` para a SPEC-018, gravando diretamente em `public.produtos` com validações cadastrais canônicas, sem catálogo paralelo.
- Atualizadas `SPEC-016`, `SPEC-017` e `SPEC-018` com o estado aplicado no banco.
- Implementadas na UI de Orçamentos, via projeto Skip da org Lucenera, as SPECs `SPEC-017` e `SPEC-018`: aba financeira agora trabalha por orçamento em `Aprovação Financeira`, aprovação final usa `orcamento_id`, e o cadastro de produto pode ser feito direto no fluxo de orçamento.
- Aplicado `skip_project_apply_changes` no projeto Skip `32554` (`Orçamentos Aprovação`) em modo development, gerando a versão `0.0.273` / `dcd3442` com QA verde.
- Refatoradas as SPECs pendentes de Estoque para consolidar o contrato técnico por `projeto_item_id`: `SPEC-010` agora define `estoque_saldos_projeto_item` e `estoque_movimentos_projeto_item`; `SPEC-011` transfere entre itens de projeto; `SPEC-013` foi absorvida; `SPEC-015` passou a usar a regra de devolução dos vídeos Connect.
- Reextraído `supabase/db/current/` a partir do Supabase real, refletindo `razao_social` em contatos e o fluxo parcial de aprovação do cliente em orçamentos.
- Regenerado `supabase/db/current/09_schema_inventory.md`.
- Incorporada a reunião 08 em `02-Reunioes/`, com transcrição, ata, fluxos, decisões/pendências e insights.
- Consolidadas SPECs 010/011/012/013/014 para saldos por item de projeto, entrega futura, transferência de reservas e badges no CRM.
- Criada e depois consolidada `SPEC-015_Devolucao_Estoque_por_Item_de_Projeto.md` para a regra de devolução.
- Criadas `SPEC-016`, `SPEC-017` e `SPEC-018` para normalizar aprovação financeira de orçamentos, unificar o modal/fluxo de edição financeira e permitir criação de produto dentro do modal de orçamento.
- Atualizados `00_TASKS_GERAIS_ECOSSISTEMA.md`, escopos afetados e docs/domínios Supabase.

### Inconsistências registradas

- Aprovação do cliente possuía contratos concorrentes no banco real; a SPEC-016 decidiu e aplicou o contrato oficial `enviado_cliente -> Aprovação Financeira -> Orçamento Aprovado` na camada Supabase. A UI de Orçamentos foi atualizada pela SPEC-017 e segue para homologação visual.
- `estoque_saldos_projeto_item` e `estoque_movimentos_projeto_item` já existem no banco real, mas a revisão encontrou exposição das views para `anon`/`authenticated`, divergência de `quantidade_reservada` em quatro produtos e entrega direta de `q_entrega_futura`; aplicar `20260707_023_spec010_hardening` antes de destravar transferência, entrega futura detalhada, devolução automatizada e badges ricos no CRM.
- `supabase/db/current/` ainda precisa ser reextraído depois das migrations 020 e 021; esta etapa ficou pendente para não sobrescrever alterações locais já existentes no snapshot.

## 2026-06-26

### Atualizado

- Baixadas as Edge Functions remotas atuais do projeto Supabase `vcvcwzmbiftcawncibke`.
- Removida a cópia central de `sync-fechamentos-automatica`, ausente no remoto.
- Documentado `process-billing-automation` como legado ainda ativo no remoto e fora do fluxo novo.
- Espelhadas as migrations da SPEC-005 em `supabase/db/migrations/20260626_009_spec005_remocao_triggers_legados_aprovacao/`.
- Atualizados domínios, inventário de automações, mapa de relacionamentos, status/enums e contexto global do Supabase.
- Atualizadas SPECs 001-005 e `00_TASKS_GERAIS_ECOSSISTEMA.md` com o que foi confirmado nos repos e no remoto.
- Puxadas atualizações dos repositórios de sistemas; alterações locais existentes foram preservadas em stash antes do pull.

### Pendente

- Reextrair `supabase/db/current/` após a SPEC-005. A tentativa local falhou sem Docker/`pg_dump`.
- Confirmar remoção definitiva de `process-billing-automation` após checar scheduler/webhook externo.
- Homologar o fluxo de aprovação real com orçamento completo, frete, prazo, histórico, parcelas e boletos.

### Adicionado

- Criada governanca inicial do repositorio central.
- Criado `README.md` com fontes de verdade, estrutura alvo e regras de leitura.
- Criado `AGENTS.md` geral com fluxo obrigatorio para IA/desenvolvedor.
- Criada regra de `.gitignore` para evitar commit de `.env`, `node_modules`, `dist` e temporarios.
- Criados documentos operacionais em `00-Contexto/`.
- Criados `AGENTS.md` por area principal do repositorio central.
- Adicionada instrucao de submodules em `00-Contexto/SUBMODULES.md`.
- Adicionados scripts `scripts/submodules-clone-all.sh` e `scripts/submodules-register.sh`.
- Adicionado `.env.example` e instrucao para criar `.env` local geral para acesso ao Supabase.

### Decisao

- O repositorio central guarda memoria, contexto, banco consolidado, relatorios, specs e inventario.
- Cada sistema continua sendo atualizado tambem em seu repositorio proprio.
- Sistemas com repositorio proprio devem ser registrados como submodules dentro de `04-Sistemas/`.
- O `.env` geral deve existir apenas localmente e nao deve ser commitado.
- O banco consolidado em `supabase/` e a fonte de verdade tecnica; migrations antigas dentro de sistemas sao historico, nao definicao final.
