---
titulo: "SPEC-153 — Sistema de Vendas + Nota Fiscal pós-aprovação (sistema novo, incl. nota parcial multi-pagador)"
status: implementado, aplicado no banco real e publicado (Skip 59346 v0.0.11) — incluindo o espelho estilo DANFE
data_ultima_modificacao: 2026-09-17
sistemas_envolvidos:
  - Vendas (sistema novo — repositório/submodule `04-Sistemas/vendas-lucenera` já existem; código da tela "Vendas" implementado)
  - Financeiro / Administração Bancária (retorno-bancario-bradesco-5392a) — perde a tela de Notas Fiscais, mantém Contas a Pagar/Receber, Duplicatas, Boletos, Remessa, Retorno
  - Orçamentos (gestao-financeira-clone-544cb) — remoção de ações diretas de NF/boleto no modal pós-aprovação
  - Hub / Sistema de TI (central-lucenera-dashboard-1c9ba) — registro do sistema novo em `public.systems`
dependencias:
  - SPEC-136 (numero_venda — aplicada em produção, esta SPEC só consome)
  - SPEC-152 (plano_parcelas/permuta/carteira — aplicada e publicada, esta SPEC não altera nada lá)
  - SPEC-069 (RBAC matriz de papéis — Administração Bancária ainda não migrou para `hub_pode_executar`; o sistema Vendas nasce sem RBAC granular real enquanto isso não acontecer)
  - SPEC-154 (Integração Focus NFe — define a Edge Function real que o botão "Emitir Nota Fiscal" desta SPEC chama; sem ela, o botão só pode existir como interface, sem emissão de verdade)
---

# SPEC-153 — Sistema de Vendas + Nota Fiscal pós-aprovação (sistema novo, incl. nota parcial multi-pagador)

> Origem: segunda metade da reunião "24. Lucenera (Vinicius) - 16.09.2026_novo sistema de vendas" (`02-Reunioes/.../Reunião 01`, a partir de [29:56]). Reescreve a versão anterior desta SPEC depois de duas decisões do usuário: (1) Vendas é um **sistema novo separado**, não uma aba de Administração Bancária; (2) o provedor de nota fiscal escolhido é **Focus NFe** (detalhamento técnico na SPEC-154).

## Checklist de Ação

### Sistema novo "Vendas" — banco e contrato de dados (o que o implementador constrói depois que a infra existir)

- [x] Migration nova (`supabase/db/migrations/20260917_153_notas_fiscais_parcial_multipagador/`) — arquivo `.sql` redigido, revisado e **aplicado no Supabase real em 2026-09-17** (dry-run combinado + aplicação real das 3 migrations em sequência, verificado por SELECT: `notas_fiscais.cliente_id`/`nome_destinatario`, tabela `notas_fiscais_itens`, RLS).
- [x] RPC `public.registrar_nota_fiscal_parcial(...)` — redigida no mesmo arquivo de migration, transacional (trava `orcamento_itens` envolvidos, valida cobertura, insere `notas_fiscais`+`notas_fiscais_itens`). **Aplicada e confirmada** (`pg_proc` tem 1 linha).
- [x] Sistema novo lista `orcamentos WHERE status = 'Orçamento Aprovado' AND natureza_operacao = 'venda'` — implementado em `04-Sistemas/vendas-lucenera/src/pages/Vendas.tsx` (join `contatos`/`projetos`/`orcamento_itens`/`notas_fiscais`+`notas_fiscais_itens`), colunas `numero_venda`, `numero`, cliente, projeto, valor, status de nota (`Sem itens`/`Nota pendente`/`Nota parcial`/`Nota completa`, derivado — sem flag redundante).
- [x] Tela "Emitir Nota Fiscal" (modal em `Vendas.tsx`) — calcula disponível por item (`quantidade - SUM(quantidade_faturada)` já registrado), permite quantidade parcial por item, pagador em 3 modos (cliente da venda / outro contato cadastrado com busca em `contatos` / nome livre), chama `registrar_nota_fiscal_parcial` com a assinatura exata da migration. Não chama nenhuma API fiscal externa (SPEC-154 é escopo separado).
- [x] **(2026-09-17, pedido do usuário)** O botão "Emitir Nota Fiscal" abre primeiro um **espelho/pré-visualização da nota cheia** (mesmo processo manual descrito na reunião — "tirar um espelho da nota fiscal cheia" e marcar o que já saiu): lista as notas já emitidas para a venda e todos os itens do orçamento, esmaecendo/riscando os que já estão 100% cobertos. Só depois de revisar isso o botão "Continuar para emissão" abre o formulário de preenchimento (que já existia). Bloqueia continuar se não sobrar nenhum item disponível.
- [x] **(2026-09-17, pedido do usuário — segunda iteração)** O espelho (passo 1) agora tem a **estrutura visual completa de um DANFE real** (`src/components/vendas/DanfePreview.tsx`): cabeçalho DANFE com indicador "0-Entrada/1-Saída" (sempre Saída) e N°/Série; código de barras Code128 renderizado de verdade (`src/components/vendas/CodigoBarras.tsx`, biblioteca nova `jsbarcode` — primeiro uso no ecossistema) a partir de uma chave de acesso placeholder de 44 dígitos no formato real (`src/lib/danfe.ts`, `montarChaveAcessoPlaceholder`); Emitente com dados reais de `empresas` (via `orcamentos.empresa_id`); Destinatário/Remetente com dados reais de `contatos` (cliente da venda, com nota de que o pagador final é escolhido no passo 2); Cálculo do Imposto (Valor Total dos Produtos, Frete, Desconto Global, Valor Total da Nota disponível); tabela de Dados do Produto/Serviço com Código/Descrição/NCM/CST/CFOP/Unidade/Quantidade/Valor Unitário/Valor Total (NCM/CST de `produtos`, CFOP pela mesma heurística provisória de `FiscalSummaryDialog.tsx`); Dados Adicionais citando que é um espelho interno sem valor fiscal. Selo vermelho "ESPELHO — SEM VALOR FISCAL — DOCUMENTO NÃO TRANSMITIDO À SEFAZ" no topo. Itens já 100% faturados continuam esmaecidos/riscados (comportamento preexistente preservado). Nenhuma chamada a API fiscal externa.
- [x] "Ver Boletos" — botão de navegação (`redirectWithCode` pro sistema `financeiro`, rota `/boletos?orcamento_id=...`), sem gerar boleto novo.
- [x] `FinanceResultModal.tsx` (Orçamentos) — botões "Abrir Nota Fiscal"/"Abrir Boletos" substituídos por um único "Ver na tela de Vendas" (`redirectWithCode`, `VENDAS_URL = https://pagina-de-vendas-9549c.goskip.app`, sistema `vendas`).
- [x] `AI_DB_CONTEXT.md` de Administração Bancária atualizado (nota fiscal fora do escopo, tabela/colunas novas documentadas) + `AI_DB_CONTEXT.md`/`DB_CHANGE_REQUEST_TEMPLATE.md` novos criados em `04-Sistemas/vendas-lucenera/supabase/`.

### Administração Bancária (`retorno-bancario-bradesco-5392a`) — ajustes pontuais, com citação da reunião

- [x] **Removida a rota/tela `NotasFiscais.tsx` (`/notas-fiscais`)** do roteamento (`App.tsx`) — arquivo `NotasFiscais.tsx` continua no disco sem uso (não removido fisicamente, decisão de limpeza do implementador).
- [x] **Confirmado**: Contas a Pagar/Contas a Receber, Duplicatas, Boletos/Remessa/Retorno não foram tocados.
- [x] Menu/nav de `Layout.tsx` ajustado, item "Notas Fiscais" removido.
- [x] `AI_DB_CONTEXT.md` atualizado (ver acima).

### Sistema novo "Vendas" — infraestrutura

- [x] Repositório GitHub (`pedrolalala/Vendas-Lucenera`) e submodule `04-Sistemas/vendas-lucenera` já existiam (sessão anterior). SSO implementado nesta sessão: `src/lib/cross-system-auth.ts` (`sistema_origem: 'vendas'`), `src/hooks/use-auth.tsx` (`consumeCodeFromUrl('vendas')`, `hub_pode_executar(..., 'vendas', ...)`), `src/components/SystemSwitcher.tsx`/`src/hooks/useSistemasPermitidos.ts` copiados sem alteração de lógica, `Layout.tsx` com `<SystemSwitcher currentSlug="vendas" />` e `pr-16 sm:pr-20` no `<main>`. Placeholders do template (`Clientes.tsx`, `Relatorios.tsx`, `Configuracoes.tsx`, `Dashboard.tsx`, `Index.tsx`) removidos; `App.tsx` só tem `/login` e `/vendas`.
- [x] **(2026-09-17) Publicado no Skip** — `pagina-de-vendas-9549c.goskip.app`, projectId 59346, v0.0.8 (`22c6c77`), QA 100% verde. O projeto sincroniza automaticamente do GitHub (achado: commits no repo `Vendas-Lucenera` disparam auto-build/publish via um merge commit assinado pelo próprio usuário — diferente do fluxo manual `skip_file_write`/`apply_changes`/`publish` usado nos outros sistemas).
- [x] **(2026-09-17) Registro em `public.systems` (`slug='vendas'`) aplicado** — confirmado por SELECT: `Vendas | https://pagina-de-vendas-9549c.goskip.app | visivel=true`.
- [x] **(2026-09-17) RBAC inicial aplicado** — `papel_permissoes` tem linha (`acao=NULL`) pra `admin` e `admin_geral` no sistema `vendas`, confirmado por SELECT.

### Passos manuais do usuário

- [x] ~~Criar o repositório GitHub do sistema Vendas~~ — já existe (`pedrolalala/Vendas-Lucenera`).
- [ ] **Confirmar que o projeto Skip do sistema Vendas está de fato publicado** em `https://pagina-de-vendas-9549c.goskip.app` com o código implementado nesta sessão (`skip_file_write`/`apply_changes`/`publish` — ver lição `feedback_skip_deploy_separate_tree`), e que `VITE_SUPABASE_URL`/`VITE_SUPABASE_PUBLISHABLE_KEY` estão configuradas lá (o `.env` local usado para build/lint já tem os valores reais).
- [x] ~~Registrar o submodule~~ — já registrado.
- [x] ~~Preencher `VENDAS_URL` real em `FinanceResultModal.tsx`~~ — feito nesta sessão.
- [x] ~~Aplicar as 3 migrations desta SPEC~~ — feito 2026-09-17, verificado.
- [ ] **Confirmar com o usuário**: quando remover fisicamente `NotasFiscais.tsx` de Admin Bancária (hoje só foi tirado do roteamento, arquivo continua no disco), checar ao vivo que não há nota fiscal real cadastrada que dependa daquela tela (contagem de 23/06/2026 apontava 0).
- [ ] Definir RBAC final (Carol completo em Vendas; Lana só Remessa/Retorno em Admin Bancária) via Hub — depende de migrar Administração Bancária (e o novo sistema Vendas) para `hub_pode_executar` (SPEC-069), que ainda não aconteceu em nenhum dos dois.
- [ ] **Testar o golden path ao vivo** (ver "Realizado" abaixo) depois das migrations aplicadas e do Skip publicado.
- [ ] **(2026-09-17, novo)** Testar visualmente o espelho em formato DANFE: abrir "Emitir Nota Fiscal" de uma venda real, conferir se o código de barras renderiza e é escaneável, se os dados de emitente (empresa)/destinatário (cliente) vêm corretos do banco, e se NCM/CST/CFOP aparecem para os itens que têm produto cadastrado com esses campos preenchidos (itens sem NCM/CST cadastrado vão mostrar "-").

## Objetivo

Criar um sistema novo e independente, "Vendas", que se torna o único lugar onde nota fiscal e boleto são orquestrados a partir de um orçamento aprovado — removendo essa ação da aprovação do orçamento em si e da tela de Notas Fiscais de Administração Bancária — reaproveitando o layout mais maduro do ecossistema como referência visual (tabela com filtros, cards de resumo, modais de ação, já usado em `retorno-bancario-bradesco-5392a`), suportando a exceção real e recorrente de nota fiscal parcial emitida para um pagador diferente do titular da venda, e preparando o terreno de dados para a emissão real via Focus NFe (SPEC-154).

## Decisões aprovadas

- **Vendas é um sistema novo e separado**, não uma aba dentro de Administração Bancária nem dentro da Separação Parcial — decisão explícita do usuário ([29:42]-[35:21]): *"Além disso, vai ter que ter um novo sistema de venda"*; *"Eu acho que não tem nada a ver com isso daí por enquanto"* (referindo-se a colocar como aba de Admin Bancária).
- Notas Fiscais sai de Administração Bancária; Contas a Pagar/Receber, Duplicatas, Boletos, Remessa e Retorno ficam (ver citações no Checklist).
- Carol opera o sistema Vendas por completo (nota fiscal, boleto, contas a receber, duplicatas); Lana só acessa Remessa e Retorno bancário em Administração Bancária, acesso ao banco é exclusivo dela (citação direta, [35:31]-[35:55]).
- Depois que o orçamento vira venda (Orçamento Aprovado), qualquer correção de item/parcela volta a ser feita dentro do Orçamento — a tela de Vendas não edita item/parcela, só orquestra nota fiscal e boleto (regra já vigente hoje para o pós-aprovação, `AI_DB_CONTEXT.md` de Orçamentos).
- Boleto sem nota fiscal é permitido como exceção, não é o caminho padrão nem deve ser bloqueado (o próprio usuário admite fazer isso ocasionalmente, [33:22]).
- Nota fiscal parcial pode ser emitida em nome de pessoa diferente do titular da venda, sem alterar o titular da venda em si — caso de uso real e recorrente (relato detalhado do usuário, [39:11]-[42:54]).
- Emissão de nota fiscal deixa de ser uma ação disponível na tela de aprovação do orçamento — citação direta: *"aprovou o orçamento, ali na aprovação do orçamento não me dá opção de emitir nota fiscal e nem opção de emitir boleto"*.

## Definição da SPEC

### Nova tela "Vendas" (sistema novo)

- Fonte de dados: `orcamentos WHERE status = 'Orçamento Aprovado' AND natureza_operacao = 'venda'` (devolução não gera venda nova, SPEC-071/136), join `contatos` (cliente), `projetos`, `notas_fiscais`/`notas_fiscais_itens` (status de cobertura fiscal).
- Colunas: `numero_venda`, `numero` (orçamento de origem), cliente, valor, status de nota fiscal (derivado de `notas_fiscais_itens` vs. `orcamento_itens` — sem flag redundante, ver próxima seção).
- Ações por linha: "Emitir Nota Fiscal" (abre o fluxo de nota parcial, chama a Edge Function real da SPEC-154) e "Ver Boletos" (navegação — boletos já existem desde a aprovação).

### Nota fiscal parcial multi-pagador

Fluxo operacional replicado do processo manual descrito na reunião ("espelho da nota cheia, riscando manualmente o que já saiu", [42:41]-[43:36]):

1. Usuário abre "Emitir Nota Fiscal" a partir de uma venda.
2. Tela mostra todos os `orcamento_itens` da venda, marcando quais já têm cobertura total em `notas_fiscais_itens` de notas anteriores (somem da seleção) e quais estão parcial/não cobertos.
3. Usuário seleciona os itens/quantidades que compõem esta nota, define o pagador (cadastrado ou nome livre), e confirma.
4. Nota fica registrada com seus itens vinculados (via RPC transacional, para não permitir corrida entre duas notas parciais simultâneas cobrindo o mesmo item além do disponível).
5. Quando a soma de todas as notas parciais cobrir 100% dos itens da venda, isso é derivável de `notas_fiscais_itens` vs. `orcamento_itens` — sem necessidade de flag adicional (mantém decisão da v1: não decidir UX de "badge de completo" sozinho, ver Pendências).

### Remoção de emissão direta na aprovação do orçamento

- `FinanceResultModal.tsx`: troca dos botões "Abrir Nota Fiscal"/"Abrir Boletos" por um único "Ver na tela de Vendas", mesmo padrão SSO (`redirectWithCode`) já usado para o link atual de Financeiro.

### Número da venda — já resolvido, sem trabalho novo aqui

`orcamentos.numero_venda` já existe, gerado por `aprovar_orcamento_financeiro` (SPEC-136, aplicada em produção). Esta SPEC só consome essa coluna como identificador principal da tela de Vendas.

## Análise de ecossistema (obrigatória)

- **Depende de `orcamentos`, `boletos`, `contatos`, `produtos`, `orcamento_itens`, `usuarios`, `systems`, `user_system_access`?** Sim — `orcamentos` (fonte da lista de vendas, `numero_venda`, `natureza_operacao`), `orcamento_itens` (granularidade da nota parcial), `contatos` (cliente/pagador), `notas_fiscais`/`notas_fiscais_itens` (novo), `systems`/`user_system_access` (sistema novo precisa se registrar). `produtos` só indiretamente, via `orcamento_itens.produto_id` (a granularidade fiscal do produto — NCM/CFOP — é escopo da SPEC-154).
- **Afeta CRM, Orçamentos, Financeiro, Cadastro, Estoque/Compras, Logística, RH, Hub/TI?** Financeiro/Administração Bancária (perde tela de NF), Orçamentos (remove 2 botões), Hub/TI (sistema novo a registrar + RBAC pendente nos dois lados).
- **Dado duplicado que deveria ser derivado por relacionamento?** `notas_fiscais.nome_destinatario` continua sendo a única exceção proposital (pagador sem cadastro em `contatos`) — legítimo, não é duplicação indevida. Confirmação nova desta reescrita: os boletos da venda **não são recriados** em Vendas — são os mesmos já criados por `aprovar_orcamento_financeiro`, só visualizados/navegados a partir do sistema novo.
- **Migration antiga que contradiz o snapshot central?** `supabase/db/current/01_schema_full.sql` (2026-07-07) não reflete `numero_venda`, `natureza_operacao`, `tipo_operacao`/`perfil` de `notas_fiscais` (já usados em `NotasFiscais.tsx` hoje, achado novo desta reescrita) nem `plano_parcelas`/enum atualizado de `pagamento_forma` (SPEC-152). Recomendo reextrair `supabase/db/current/` antes de aplicar esta SPEC.
- **Exige atualizar `AI_DB_CONTEXT.md`?** Sim — Administração Bancária (remoção da tela de NF, nova tabela compartilhada) e Orçamentos (remoção dos botões). O sistema Vendas precisa de um `AI_DB_CONTEXT.md` próprio assim que existir (fora do alcance desta SPEC, é passo do implementador na criação do sistema).
- **Padrão de acesso a dados já usado**: Administração Bancária usa chamadas diretas `supabase.from(...)`/`supabase.storage` dentro de cada página, sem camada de `services/`/hooks compartilhados (`NotasFiscais.tsx`, `Boletos.tsx`) — o sistema Vendas, sendo novo, deve seguir esse mesmo padrão simples por consistência com o restante do ecossistema-satélite (nenhum dos 10 sistemas tem uma camada de services robusta), a menos que o usuário peça explicitamente algo diferente para o sistema novo.

## Realizado

**2026-09-17 (implementador, sessão 3 — espelho vira DANFE visual):**

- Pedido do usuário: o espelho (passo 1 do modal "Emitir Nota Fiscal") deveria parecer de verdade a estrutura de uma nota fiscal real (DANFE), com código de barras e campos fiscais reais, não uma tabela simples — mantendo o selo de que é só um espelho interno, sem valor fiscal (SPEC-154 ainda não implementada).
- `04-Sistemas/vendas-lucenera/src/lib/danfe.ts` (novo): `montarChaveAcessoPlaceholder` (chave de 44 dígitos no formato real cUF+AAMM+CNPJ+mod+série+nNF+tpEmis+cNF+cDV, com dígito verificador mod-11 calculado de verdade sobre dados placeholder — nunca validada pela SEFAZ), `formatarChaveAcesso` (agrupamento em blocos de 4), `cfopHeuristico` (mesma heurística provisória `porc_st > 0 ? '5405' : '5102'` já usada em `gestao-financeira-clone-544cb (1)/src/components/budgets/FiscalSummaryDialog.tsx`, comentário citando a origem e a limitação de não tratar operação interestadual).
- `04-Sistemas/vendas-lucenera/src/components/vendas/CodigoBarras.tsx` (novo): wrapper de `jsbarcode@^3.12.3` (dependência nova no `package.json` deste sistema; primeiro uso de biblioteca de código de barras no ecossistema) renderizando um SVG Code128 de verdade a partir da chave placeholder.
- `04-Sistemas/vendas-lucenera/src/components/vendas/DanfePreview.tsx` (novo): estrutura completa de DANFE — selo "ESPELHO — SEM VALOR FISCAL" no topo, banda Emitente/DANFE/código de barras+chave, Natureza da Operação + "Protocolo de Autorização" (sempre "Não autorizado — sem valor fiscal"), Destinatário/Remetente (cliente da venda, com nota de que o pagador final é escolhido no passo 2), Cálculo do Imposto, tabela Dados do Produto/Serviço (Código/Descrição/NCM/CST/CFOP/Unidade/Quantidade/Valor Unitário/Valor Total, itens 100% faturados esmaecidos/riscados), Dados Adicionais.
- `04-Sistemas/vendas-lucenera/src/pages/Vendas.tsx`: query de `fetchVendas` expandida — `empresa:empresas(...)` (novo, via `orcamentos.empresa_id`), `cliente:contatos!orcamentos_cliente_id_fkey(...)` expandido com campos fiscais (`razao_social`, `cpf_cnpj`, `cnpj`, `cpf`, `inscricao_estadual`, `endereco`, `numero`, `bairro`, `cidade`, `estado`, `cep`, `telefone`), `orcamento_itens` com `produto:produtos(id, nome, sku, codigo_produto, referencia, ncm, cst, unidade, porc_st)` (novo join, não existia), `frete_valor`/`desconto_global` de `orcamentos`. Interfaces `ProdutoFiscal`/`EmpresaEmitente`/`ClienteFiscal`/`OrcamentoItem`/`Venda` e helpers `formatCurrency`/`valorUnitario`/`jaFaturado` exportados para reuso em `DanfePreview.tsx`. Passo 1 do modal ("Espelho da Nota Fiscal") agora renderiza `<DanfePreview />` no lugar da tabela simples anterior (mantendo a lista de "Notas já emitidas" acima); dialog fica mais largo (`max-w-4xl`) só no passo 1. Formulário do passo 2 não foi alterado.
- **Achado e corrigido (bug pré-existente, não introduzido nesta sessão)**: `@supabase/supabase-js` era importado em `src/lib/supabase/client.ts` mas nunca esteve declarado em `package.json` (confirmado em todo o histórico de commits do submodule) — o build só "funcionava" porque o pacote ficava como dependência órfã (extraneous) em `node_modules` de sessões anteriores. Ao rodar `npm install jsbarcode`, o npm podou 8 pacotes órfãos (o próprio `@supabase/supabase-js` e suas dependências), quebrando o `vite build`. Corrigido adicionando `@supabase/supabase-js@^2.116.0` explicitamente ao `package.json` (mesma faixa major/minor usada em `retorno-bancario-bradesco-5392a`, sistema de referência desta SPEC).
- Verificação: `npm run lint` (só o warning pré-existente de `exhaustive-deps`, mesmo de antes), `npm run format` (oxfmt, sem diffs de conteúdo além de formatação), `npm run build` (sucesso).
- **Não testado ao vivo nesta sessão** (fora do alcance do implementador): abrir o modal no navegador e conferir visualmente o DANFE renderizado, o código de barras escaneável, e os dados reais de emitente/destinatário/produto vindo do banco.

**2026-09-17 (implementador, sessão 2 — continuação após corte por limite de API):**

- Migrations (`supabase/db/migrations/20260917_153_notas_fiscais_parcial_multipagador/001`, `002`, `003`) redigidas e revisadas na sessão anterior — **nenhuma aplicada no Supabase real** nesta sessão (regra do implementador: nunca aplica migration).
- `04-Sistemas/vendas-lucenera`: scaffold completo do sistema (SSO, layout, login), seguindo o padrão de `retorno-bancario-bradesco-5392a` (referência pedida pelo usuário):
  - Copiados/adaptados: `src/lib/supabase/client.ts`+`types.ts`, `src/lib/cross-system-auth.ts` (slug `vendas`), `src/hooks/use-auth.tsx` (slug `vendas`), `src/hooks/useSistemasPermitidos.ts`, `src/components/SystemSwitcher.tsx`, `src/pages/Login.tsx`, `src/assets/logotipo-verticalv1preto-b4de9.png`.
  - `src/components/Layout.tsx` reescrito (header simples + `SystemSwitcher` + `pr-16 sm:pr-20` no `<main>`, mesmo fix já aplicado em Separação Parcial/CRM pra não sobrepor conteúdo).
  - `src/App.tsx` reescrito: só `/login` e `/vendas` (protegidas por `hub_pode_executar`), placeholders do template removidos (`Clientes.tsx`, `Relatorios.tsx`, `Configuracoes.tsx`, `Dashboard.tsx`, `Index.tsx`).
  - `src/pages/Vendas.tsx`: tela principal completa — lista de vendas com status de nota fiscal derivado, modal "Emitir Nota Fiscal" com seleção de item/quantidade parcial, 3 modos de pagador (venda/contato cadastrado com busca/nome livre), chamada a `registrar_nota_fiscal_parcial`, botão "Ver Boletos" (navegação `redirectWithCode` pro sistema `financeiro`, sem gerar boleto novo).
  - `supabase/AI_DB_CONTEXT.md` e `supabase/DB_CHANGE_REQUEST_TEMPLATE.md` novos, documentando o recorte de banco do sistema.
  - `npm install` + `npm run lint` (só 1 warning pré-existente de `exhaustive-deps`, mesmo padrão dos sistemas-irmãos) + `npm run build` (sucesso) + `npm run format` (oxfmt).
- `04-Sistemas/retorno-bancario-bradesco-5392a`: rota `/notas-fiscais` removida de `App.tsx`, item de menu removido de `Layout.tsx` (arquivo `NotasFiscais.tsx` permanece no disco, sem uso — ver Pendências antes de apagar fisicamente). `supabase/AI_DB_CONTEXT.md` atualizado (nota fiscal fora do escopo, tabela `notas_fiscais_itens` e colunas novas de `notas_fiscais` documentadas). `lint`/`build` OK (só warnings pré-existentes não relacionados).
- `04-Sistemas/gestao-financeira-clone-544cb (1)`: `FinanceResultModal.tsx` — botões "Abrir Nota Fiscal"/"Abrir Boletos" substituídos por "Ver na tela de Vendas" (`VENDAS_URL = https://pagina-de-vendas-9549c.goskip.app`, `redirectWithCode` sistema `vendas`). `prettier --write` aplicado no arquivo, `oxlint`/`build` OK.
- **Não implementado nesta sessão** (fora do que foi pedido/fora de alcance do implementador): aplicação real das 3 migrations, criação/confirmação do projeto Skip publicado, RBAC fino Carol/Lana (depende de SPEC-069), remoção física do arquivo `NotasFiscais.tsx`, qualquer teste ao vivo no navegador.

### O que falta o usuário testar (golden path, depois das migrations aplicadas + Skip publicado)

1. Aplicar as 3 migrations na ordem certa (001 → 002 → 003).
2. Confirmar/publicar o projeto Skip de `vendas-lucenera` com o código desta sessão.
3. Login em Vendas via SSO a partir da Central ou de Orçamentos (botão "Ver na tela de Vendas" no `FinanceResultModal`).
4. Ver a lista de vendas aparecer (orçamento aprovado, natureza venda) com status de nota correto.
5. Emitir uma nota parcial (item parcial + pagador nome livre) e conferir que a segunda nota só oferece o restante disponível.
6. "Ver Boletos" abrindo a tela de Boletos de Admin Bancária já filtrada pelo `orcamento_id`.

## Pendências

- [x] ~~Nome e repositório definitivo do sistema Vendas~~ — resolvido, `pedrolalala/Vendas-Lucenera` / `04-Sistemas/vendas-lucenera`.
- [x] **Ação "Ver boletos desta venda"** — implementado como navegação pura (`redirectWithCode` pro sistema `financeiro`, `/boletos?orcamento_id=...`), sem gerar nada novo. Se o usuário quiser um fluxo diferente (ex. ajustar valor/vencimento no momento da nota), é pendência nova, não coberta aqui.
- [x] **Indicador de "nota completa"** — implementado como badge derivado (`Sem itens`/`Nota pendente`/`Nota parcial`/`Nota completa`) comparando `notas_fiscais_itens` com `orcamento_itens`, sem flag gravada. Decisão de UX final (cores/rótulos) pode mudar depois de teste ao vivo.
- [ ] **Confirmar antes de remover fisicamente `NotasFiscais.tsx`** de Administração Bancária (hoje só saiu do roteamento) que não há nota fiscal real registrada que dependa daquela tela (contagem de 23/06/2026 apontava 0, mas precisa reconfirmação ao vivo).
- [ ] **RBAC real (Carol/Lana)** depende de migrar Administração Bancária **e** o sistema Vendas novo para `hub_pode_executar` (SPEC-069) — nenhum dos dois está migrado hoje. Nesta sessão só foi coberto o bootstrap mínimo (`admin`/`admin_geral` com acesso total, migration 003, não aplicada).
- [ ] **Confirmar que o Skip de Vendas está publicado** com o código desta sessão (só há evidência de que o repositório/submodule existem, não que o deploy Skip reflete `Vendas.tsx`/SSO implementados agora).
- [x] **(2026-09-17) Espelho DANFE publicado no Skip** — v0.0.11 (`154fa4b`), QA 100% verde. Achado do processo: o sync automático do Skip a partir do GitHub não pegou os arquivos novos a tempo (2 tentativas) — aplicado via `skip_file_write` direto, mesmo padrão manual usado nos outros sistemas. Corrigido também um bug real: `package.json` ficou com `@supabase/supabase-js` duplicado (2 versões) depois de um merge automático do Skip — removida a entrada antiga, mantida `^2.116.0`.
- [ ] Reextrair `supabase/db/current/` — segue desatualizado (SPEC não bloqueou nisso, mas o próximo trabalho de banco neste recorte deve reextrair antes).
