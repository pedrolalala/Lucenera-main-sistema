---
titulo: "SPEC-153 — Sistema de Vendas + Nota Fiscal pós-aprovação (sistema novo, incl. nota parcial multi-pagador)"
status: não iniciado
data_ultima_modificacao: 2026-09-17
sistemas_envolvidos:
  - Vendas (sistema novo — a criar; repositório/projeto Skip ainda não existem)
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

- [ ] Migration nova (`supabase/db/migrations/20260917_153_notas_fiscais_parcial_multipagador/`):
  - `notas_fiscais.cliente_id uuid REFERENCES contatos(id)` nullable — quando preenchido, é o pagador real daquela nota parcial (pode ser diferente de `orcamentos.cliente_id`); quando nulo, assume o cliente do orçamento.
  - `notas_fiscais.nome_destinatario text` nullable — para o pagador real (ex. cônjuge) sem cadastro em `contatos`, sem forçar cadastro.
  - Nova tabela `notas_fiscais_itens` (`id uuid PK`, `nota_fiscal_id uuid REFERENCES notas_fiscais(id)`, `orcamento_item_id uuid REFERENCES orcamento_itens(id)`, `quantidade_faturada numeric`, `valor_faturado numeric`, `created_at timestamptz DEFAULT now()`) — rastreia por venda quais itens já foram cobertos por nota parcial. Constraint de aplicação (RPC, não trigger cega): `SUM(quantidade_faturada)` por `orcamento_item_id` não pode ultrapassar `orcamento_itens.quantidade`.
- [ ] RPC `public.registrar_nota_fiscal_parcial(...)` (nome sugerido) que faz, transacionalmente: valida que os itens somados não ultrapassam o disponível, insere `notas_fiscais` + `notas_fiscais_itens`. Evita corrida entre duas notas parciais simultâneas da mesma venda (que um `INSERT` solto na tela não garante).
- [ ] Sistema novo lista `orcamentos WHERE status = 'Orçamento Aprovado' AND natureza_operacao = 'venda'` (join `contatos`/`projetos`/`notas_fiscais`), colunas: `numero_venda`, `numero` (orçamento), cliente, valor, status de nota ("Nota emitida" com número/status Focus NFe — ver SPEC-154 — ou botão "Emitir Nota Fiscal").
- [ ] Tela "Emitir Nota Fiscal": mostra os `orcamento_itens` da venda ainda não totalmente cobertos por `notas_fiscais_itens` de notas anteriores, permite selecionar item/quantidade parcial, define pagador (`cliente_id` cadastrado ou `nome_destinatario` livre), soma deve bater com o valor a cobrir nesta nota (referência sugerida: valor das parcelas já pagas, `projeto_parcelas.status = 'paga'` — decisão de UX de qual referência mostrar fica com o implementador/usuário, não travar o salvamento nisso).
- [ ] Depois de registrar/emitir uma nota, oferecer em sequência "Ver boletos desta venda" — **não cria boleto novo**: `aprovar_orcamento_financeiro` já cria os boletos da venda com `status = 'pendente_registro'` no momento da aprovação (confirmado em `20260911_136_orcamento_numero_venda/001_numero_venda.sql`). A ação em Vendas é de navegação/confirmação, não de geração. Ver Pendências sobre se o usuário quer algo além disso.
- [ ] `FinanceResultModal.tsx` (Orçamentos, `src/components/budgets/FinanceResultModal.tsx:80-89`): remover os botões "Abrir Nota Fiscal" (`/notas-fiscais`) e "Abrir Boletos" (`/boletos`), que hoje apontam para `FINANCEIRO_URL` (Admin Bancária) — substituir por um único botão "Ver na tela de Vendas", usando o mesmo padrão `redirectWithCode` (`@/lib/cross-system-auth`) com uma constante `VENDAS_URL` nova (valor real só existirá depois que o projeto Skip de Vendas for criado — ver Passos manuais).
- [ ] Atualizar `AI_DB_CONTEXT.md` de Administração Bancária: nota fiscal sai do escopo do sistema (rota `/notas-fiscais` removida — ver abaixo), documentar a nova tabela `notas_fiscais_itens` e as colunas novas em `notas_fiscais` mesmo que o CRUD delas não more mais neste sistema (o schema é compartilhado). Criar `AI_DB_CONTEXT.md` novo para o sistema Vendas assim que ele existir.

### Administração Bancária (`retorno-bancario-bradesco-5392a`) — ajustes pontuais, com citação da reunião

- [ ] **Remover a rota/tela `NotasFiscais.tsx` (`/notas-fiscais`)** deste sistema — citação direta ([36:14]-[37:20]): *"Eu acho que isso nem deveria existir, tá? Nota fiscal, administração bancária, aí no meio. Para mim nem existiria isso."* A funcionalidade (registro manual + upload + vínculo a boleto) migra para dentro do sistema Vendas, agora acoplada à emissão real via Focus NFe (SPEC-154).
- [ ] **Não remover** Contas a Pagar/Contas a Receber, Duplicatas (`ConsultarDuplicatas.tsx`) nem Boletos/Remessa/Retorno — citação direta do próprio usuário logo em seguida, respondendo à própria pergunta: *"Aqui vai estar o contas a pagar, o contas a receber ou não? É isso, receber e apagar. Acho que isso aqui nem deveria estar"* (a frase final se refere à Nota Fiscal, tema da fala inteira — Contas a Pagar/Receber ele confirma que ficam).
- [ ] Ajustar o menu/nav de `Layout.tsx` removendo o item "Notas Fiscais".
- [ ] Atualizar `AI_DB_CONTEXT.md` (ver acima).

### Sistema novo "Vendas" — infraestrutura (fora do alcance do planner, ver Passos manuais)

- [ ] Repositório GitHub próprio, projeto Skip próprio, submodule em `04-Sistemas/`, SSO via `cross-system-auth.ts`/`SystemSwitcher.tsx` (mesmo padrão dos outros 10 sistemas — `consumeCodeFromUrl('vendas')` no `AuthProvider`, `SystemSwitcher` reaproveitado sem alteração porque já é 100% orientado a dados de `public.systems`).
- [ ] Registro em `public.systems` (`slug = 'vendas'`, `name`, `description`, `link` = URL real do Skip, `icon_name`, `display_order`, `visivel_no_hub = true`) — precedente: SPEC-072 (Separação Parcial) e SPEC-125 (Showroom), ambos confirmam que o Hub (`Dashboard.tsx`) é 100% orientado a dado, sem precisar de mudança de código lá.
- [ ] RBAC inicial (`papel_permissoes`) para o sistema `vendas` — mesmo problema estrutural do resto do ecossistema: sem RLS/RBAC granular aplicada ainda em produção para Administração Bancária, então a separação Carol (tudo)/Lana (nada em Vendas, só remessa/retorno em Admin Bancária) fica documentada como regra mas não tecnicamente imposta até a SPEC-069 avançar nesses dois sistemas.

### Passos manuais do usuário

- [ ] **Criar o repositório GitHub do sistema Vendas** (nome a definir — sugestão: `lucenera-vendas` ou equivalente, seguindo o padrão dos demais).
- [ ] **Criar o projeto Skip novo** para esse repositório, configurar `VITE_SUPABASE_URL`/`VITE_SUPABASE_PUBLISHABLE_KEY` via `skip_env_set` (mesmo Supabase compartilhado — não é um projeto novo de banco).
- [ ] **Registrar o submodule** em `04-Sistemas/<nome-do-repo>/` no repositório central.
- [ ] Depois que a URL do Skip existir, **preencher `VENDAS_URL` real** em `FinanceResultModal.tsx` (isso pode ser feito pelo implementador, mas depende do passo manual anterior estar concluído primeiro).
- [ ] Aplicar a migration desta SPEC (`notas_fiscais.cliente_id`, `notas_fiscais.nome_destinatario`, tabela `notas_fiscais_itens`, RPC de registro).
- [ ] **Confirmar com o usuário**: quando remover `NotasFiscais.tsx` de Admin Bancária, existem hoje 0 notas fiscais registradas na tabela real (conforme `06_ESCOPO_FINANCEIRO.md`, achado de 23/06/2026 — "0 notas fiscais registradas") — mas isso precisa ser reconfirmado ao vivo antes de remover a tela, para não perder acesso a dado real se algo tiver sido cadastrado depois dessa contagem.
- [ ] Definir RBAC final (Carol completo em Vendas; Lana só Remessa/Retorno em Admin Bancária) via Hub — depende de migrar Administração Bancária (e o novo sistema Vendas) para `hub_pode_executar` (SPEC-069), que ainda não aconteceu em nenhum dos dois.

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

_(nada implementado — SPEC recém-reescrita)_

## Pendências

- [ ] **Nome e repositório definitivo do sistema Vendas** — não decidido na reunião, só o conceito.
- [ ] **Ação "Ver boletos desta venda"**: confirmar com o usuário se ele só quer navegação/confirmação (os boletos já existem desde a aprovação, `status = 'pendente_registro'`) ou se espera alguma ação adicional (ex. ajustar valor/vencimento de boleto no momento da nota) — a reunião ([31:36]) sugere um fluxo de "deseja gerar boletos, sim/não" que hoje tecnicamente já não teria o que "gerar" de novo.
- [ ] **Indicador de "nota completa"**: quando `notas_fiscais_itens` cobrir 100% de `orcamento_itens` de uma venda, precisa de um indicador visual explícito na tela de Vendas ou basta ser derivável ao consultar? Deixado em aberto (decisão de UX/negócio, não do planner).
- [ ] **Confirmar antes de remover `NotasFiscais.tsx`** de Administração Bancária que não há nota fiscal real registrada que dependa daquela tela (contagem de 23/06/2026 apontava 0, mas precisa reconfirmação ao vivo).
- [ ] **RBAC real (Carol/Lana)** depende de migrar Administração Bancária **e** o sistema Vendas novo para `hub_pode_executar` (SPEC-069) — nenhum dos dois está migrado hoje.
- [ ] Reextrair `supabase/db/current/` antes de implementar (snapshot desatualizado, não reflete várias colunas já usadas em produção).
