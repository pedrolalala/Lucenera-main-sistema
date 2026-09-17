---
titulo: "SPEC-153 — Sistema de Vendas + Nota Fiscal pós-aprovação (incl. nota parcial multi-pagador)"
status: não iniciado
data_ultima_modificacao: 2026-09-17
sistemas_envolvidos:
  - Financeiro / Administração Bancária (retorno-bancario-bradesco-5392a) — sistema principal da nova tela "Vendas"
  - Orçamentos (gestao-financeira-clone-544cb) — remoção de ações diretas de NF/boleto no modal pós-aprovação
dependencias:
  - SPEC-136 (número da venda — já aplicada; esta SPEC só pede verificação ao vivo, não reimplementação)
  - SPEC-069 (RBAC matriz de papéis — Administração Bancária ainda não migrou para `hub_pode_executar`, conforme `hub_ti.md`)
---

# SPEC-153 — Sistema de Vendas + Nota Fiscal pós-aprovação (incl. nota parcial multi-pagador)

> Origem: segunda metade (grosso) da reunião "24. Lucenera (Vinicius) - 16.09.2026_novo sistema de vendas" (`02-Reunioes/.../Reunião 01`).

## Checklist de Ação

- [ ] Criar nova tela/rota **"Vendas"** dentro do sistema `retorno-bancario-bradesco-5392a` (Financeiro/Administração Bancária), seguindo o mesmo padrão visual já usado nas telas existentes desse sistema (`Layout.tsx`, `Boletos.tsx`, `NotasFiscais.tsx` — tabela com filtros no topo, cards de resumo, modais de ação), por ser o layout que o usuário chamou explicitamente de "robusto" e pediu para copiar.
- [ ] Tela "Vendas" lista todo `orcamentos` com `status = 'Orçamento Aprovado'` e `natureza_operacao = 'venda'` (join `orcamentos → contatos/projetos`), com colunas: número da venda (`numero_venda`), número do orçamento, cliente, valor, status de nota fiscal ("Nota emitida" com número, ou botão "Emitir Nota Fiscal" quando não há nota vinculada).
- [ ] `FinanceResultModal.tsx` (Orçamentos): remover os botões diretos "Abrir Nota Fiscal" e "Abrir Boletos" que hoje levam para `/notas-fiscais` e `/boletos` de Administração Bancária logo após a aprovação financeira — substituir por um único botão "Ver na tela de Vendas", apontando para a nova rota `/vendas` (ou `/vendas/:orcamento_id`), consistente com a regra explícita do usuário: emitir nota/boleto passa a ser ação exclusiva da tela de Vendas, não da aprovação do orçamento.
- [ ] Mover/adaptar o fluxo de registro de Nota Fiscal hoje em `NotasFiscais.tsx` para dentro do contexto da tela "Vendas" (reaproveitando a lógica existente de upload + vínculo a boleto — **não há integração automática com nenhuma API fiscal no código atual**, ver "Achado crítico" abaixo).
- [ ] Regra: o sistema deve **permitir** (não bloquear) emitir boleto sem nota fiscal ainda vinculada — hoje já é tecnicamente possível (nenhum código força NF antes de boleto), então esse ponto é confirmação/documentação, não mudança de comportamento.
- [ ] Depois de registrar/emitir uma nota fiscal na tela de Vendas, oferecer a ação em sequência "Deseja gerar os boletos desta venda agora?" (fluxo de UI, não é uma automação de banco).
- [ ] Modelagem da **nota fiscal parcial com pagador diferente do titular da venda**:
  - `notas_fiscais.cliente_id uuid REFERENCES contatos(id)` nullable — quando preenchido, é o pagador real daquela nota parcial (pode ser diferente de `orcamentos.cliente_id`); quando nulo, assume o cliente do orçamento.
  - `notas_fiscais.nome_destinatario text` nullable — para o caso do pagador real (ex. cônjuge) não ter cadastro em `contatos`, permitindo texto livre sem forçar cadastro.
  - Nova tabela de junção `notas_fiscais_itens` (`nota_fiscal_id uuid REFERENCES notas_fiscais(id)`, `orcamento_item_id uuid REFERENCES orcamento_itens(id)`, `quantidade_faturada numeric`, `valor_faturado numeric`) — permite saber, por venda, quais itens já foram cobertos por alguma nota parcial e quais ainda faltam, sem duplicar item em duas notas nem perder item sem nota. Constraint de aplicação: `SUM(quantidade_faturada)` por `orcamento_item_id` não pode ultrapassar a quantidade do item original.
  - Tela de emissão de nota: ao criar uma nota parcial, mostrar os itens do orçamento ainda não totalmente cobertos (`orcamento_itens` menos o que já está em `notas_fiscais_itens`), permitindo selecionar quais entram nesta nota, com soma batendo com o valor efetivamente recebido até o momento (referência: valor das parcelas já pagas via `projeto_parcelas.status = 'paga'`).
- [ ] Atualizar `AI_DB_CONTEXT.md` de Administração Bancária/Financeiro com a nova tela, tabelas e a distinção nota-cheia vs. nota-parcial.

### Passos manuais do usuário

- [ ] **Confirmar o que realmente foi mostrado ao vivo na reunião como "Nota Fiscal Eletrônica" com retorno de API/JSON** — ver "Achado crítico" abaixo; não encontrei nenhuma integração fiscal automática em nenhum dos 10 sistemas deste repositório. Pode ser (a) uma ferramenta externa não mapeada neste ecossistema, (b) uma tela que existe só em produção/Skip e nunca foi commitada localmente (padrão já visto antes, ver memória "SPEC-120 rollout pendente"), ou (c) uma confusão de nomenclatura na reunião. **Isto precisa ser esclarecido antes de escrever qualquer migration de integração fiscal.**
- [ ] Decidir o provedor/API de emissão de nota fiscal, se a decisão (c) acima for "ainda não existe, precisa ser criado" — pendência já registrada há meses em `supabase/docs/ai_context_global.md` e nunca fechada.
- [ ] Decidir a nomenclatura final do módulo: manter "Administração Bancária" com uma aba nova "Vendas", ou renomear o sistema para "Contas a Pagar / Contas a Receber" e a estrutura de Vendas ficar como um módulo à parte — o usuário levantou isso na reunião mas não fechou, e o próprio `06_ESCOPO_FINANCEIRO.md` (SPEC-FIN-01) já propõe renomear para "Financeiro" há tempos, sem decisão final até hoje.
- [ ] Definir/ajustar a matriz de permissões (Carol acesso completo a Vendas: emitir nota, gerar boleto, consultar; Lana restrita a Remessa/Retorno bancário) — via Hub/RBAC (SPEC-069/SPEC-006). Achado: Administração Bancária **ainda não foi migrada** para `hub_pode_executar` (confirmado em `supabase/db/domains/hub_ti.md` — está na lista dos sistemas pendentes), então a nova permissão de "Vendas" nasceria sem o controle granular que os outros sistemas já têm, a não ser que essa migração seja feita junto.
- [ ] Verificar ao vivo, no Skip publicado, se `orcamentos.numero_venda` (SPEC-136) está realmente visível no fluxo real de aprovação — a investigação de código mostra que sim (`BudgetTableRow.tsx`), mas o usuário relatou insegurança sobre isso na reunião e nenhum teste ao vivo fechou essa dúvida.
- [ ] Aplicar as migrations novas (`notas_fiscais.cliente_id`, `notas_fiscais.nome_destinatario`, tabela `notas_fiscais_itens`).

## Objetivo

Criar uma área "Vendas" dentro do sistema Financeiro/Administração Bancária, que vira o único lugar onde nota fiscal e boleto são emitidos a partir de um orçamento aprovado (removendo essa ação da aprovação do orçamento em si), reaproveitando o layout mais maduro do ecossistema (`retorno-bancario-bradesco-5392a`), com a logo da Lucenera no documento de nota, e suportando a exceção real e recorrente de nota fiscal parcial emitida para um pagador diferente do titular da venda, cobrindo apenas os itens ainda não faturados até fechar o total da venda.

## Decisões aprovadas

- A nova tela "Vendas" fica dentro do sistema de Administração Bancária/Financeiro — **não** dentro da Separação Parcial (público de acesso diferente, decisão explícita do usuário na reunião).
- A tela de Vendas não reaproveita a tela atual de "Contas a Receber" como está (falta visibilidade de produtos/itens da venda).
- Depois que o orçamento vira venda (Orçamento Aprovado), qualquer correção de item/parcela volta a ser feita dentro do Orçamento — a tela de Vendas não edita item/parcela, só orquestra nota fiscal e boleto (mesma regra já vigente hoje para o pós-aprovação, conforme `AI_DB_CONTEXT.md` de Orçamentos).
- Boleto sem nota fiscal é permitido como exceção, não é o caminho padrão nem deve ser bloqueado.
- Nota fiscal parcial pode ser emitida em nome de pessoa diferente do titular da venda, sem alterar o titular da venda em si.

## Definição da SPEC

### Achado crítico — não existe integração fiscal automática no código

Busquei em todo `04-Sistemas/` por qualquer integração com provedor de emissão de NFe (Focus NFe, TecnoSpeed, PlugNotas, SEFAZ direto, etc.) e não encontrei nada. A tela real hoje (`NotasFiscais.tsx`) é 100% manual: formulário + upload de PDF + vínculo manual a um boleto existente. Isso contradiz a descrição da reunião de uma tela já em produção que faz "JSON" para um provedor e recebe confirmação de emissão de volta. `supabase/docs/ai_context_global.md` também lista "decidir ferramenta/API de emissão de nota fiscal" como pendência global nunca fechada.

**Isto muda o escopo real possível desta SPEC**: não é possível, hoje, propor código que "chama a API e recebe confirmação" — essa API não existe no ecossistema mapeado. O que É possível e concreto:
1. Mover o fluxo manual de registro de NF (upload + campos) para dentro da nova tela de Vendas, com o contexto de venda/itens visível (resolvendo a reclamação real do usuário: "cadê os produtos?").
2. Preparar o modelo de dados (`notas_fiscais_itens`, `cliente_id`, `nome_destinatario`) para quando uma API real existir, sem se comprometer com nenhum provedor específico agora.
3. Gerar um documento interno em PDF com a logo da Lucenera (reaproveitando o padrão de `pdf-logo.ts`/SPEC-084) como representação visual da nota — mas isso é um documento interno de controle, não uma NFe fiscalmente válida perante a SEFAZ, a menos que uma API real seja integrada depois.

### Nova tela "Vendas"

- Rota nova em `retorno-bancario-bradesco-5392a` (ex. `/vendas`), registrada em `App.tsx` e no menu de `Layout.tsx`, seguindo o mesmo padrão visual das telas existentes.
- Fonte de dados: `orcamentos` filtrado por `status = 'Orçamento Aprovado'` e `natureza_operacao = 'venda'` (devolução não gera venda, conforme SPEC-136), com `numero_venda`, join para `contatos` (cliente), `projetos`, e `notas_fiscais` (para status "emitida"/"pendente").
- Ações por linha: "Emitir Nota Fiscal" (abre o formulário — hoje manual, ver achado acima) e "Gerar Boletos" (reaproveita a lógica já existente de criação de `boletos`, hoje espalhada entre `aprovar_orcamento_financeiro` e `Boletos.tsx`).
- Depois de "emitir" uma nota, oferecer "Deseja gerar os boletos agora?" como próxima ação (fluxo de UI).

### Remoção de emissão direta na aprovação do orçamento

- `FinanceResultModal.tsx`: troca dos botões "Abrir Nota Fiscal"/"Abrir Boletos" por um único "Ver na tela de Vendas" (`redirectWithCode` para a nova rota `/vendas`, mesmo padrão SSO já usado — `cross-system-auth.ts`).

### Nota fiscal parcial multi-pagador

Ver Checklist para o desenho de schema (`notas_fiscais.cliente_id`, `notas_fiscais.nome_destinatario`, tabela `notas_fiscais_itens`). Fluxo operacional replicado do processo manual descrito na reunião ("espelho da nota cheia, riscando manualmente o que já saiu"):

1. Usuário abre "Emitir Nota Fiscal" a partir de uma venda.
2. Tela mostra todos os `orcamento_itens` da venda, marcando quais já têm cobertura total em `notas_fiscais_itens` de notas anteriores (não aparecem mais para seleção) e quais estão parcialmente ou não cobertos.
3. Usuário seleciona os itens (ou quantidade parcial de um item) que compõem esta nota específica, define o nome do pagador (cliente cadastrado ou nome livre), e salva.
4. Nota fica registrada com seus itens vinculados; a próxima nota parcial da mesma venda só pode escolher entre o que sobrou.
5. Quando a soma de todas as notas parciais cobrir 100% dos itens da venda, a venda pode ser considerada com nota completa — não há necessidade de um flag adicional, isso é derivável de `notas_fiscais_itens` vs. `orcamento_itens`.

### Número da venda — verificação, não reimplementação

`orcamentos.numero_venda` já existe, já é gerado por `aprovar_orcamento_financeiro` (SPEC-136, aplicada em produção 2026-09-14) e já aparece em `BudgetTableRow.tsx` (Orçamentos) e na Separação. Esta SPEC não recria nada — só usa `numero_venda` como coluna principal da nova tela de Vendas e pede, como passo manual, a confirmação ao vivo no Skip publicado (o usuário relatou insegurança sobre isso, mas o código já resolve).

## Análise de ecossistema (obrigatória)

- **Depende de `orcamentos`, `boletos`, `contatos`, `projeto_itens`, `projeto_parcelas`, `usuarios`, `systems`, `user_system_access`?** Sim — `orcamentos` (fonte da lista de vendas), `boletos`/`projeto_parcelas` (geração de cobrança), `contatos` (cliente/pagador da nota), `notas_fiscais` (existente, ganha colunas novas). Não depende de `produtos` diretamente (os itens já são snapshot em `orcamento_itens`).
- **Afeta CRM, Orçamentos, Financeiro, Cadastro, Estoque/Compras, Logística, RH, Hub/TI?** Financeiro/Administração Bancária (principal), Orçamentos (remoção de 2 botões), Hub/TI (a matriz de permissões de Vendas depende de RBAC granular que este sistema ainda não tem).
- **Dado duplicado que deveria ser derivado por relacionamento?** `notas_fiscais.nome_destinatario` é a única exceção proposital — precisa existir como texto livre porque o pagador de uma nota parcial pode não ter cadastro em `contatos` (ex. cônjuge sem cadastro próprio). Não é duplicação indevida, é um caso legítimo de dado que não tem de onde ser derivado.
- **Migration antiga que contradiz o snapshot central?** Mesma observação da SPEC-152: `supabase/db/current/` está desatualizado (2026-07-07); a definição de `notas_fiscais` nesse snapshot (`numero_nf`, `serie`, `fornecedor`, `arquiteto`, `boleto_id`, `orcamento_id`) bate com o código real atual, então serve como base confiável para as colunas novas propostas aqui — mas recomendo reextração antes de aplicar, por segurança.
- **Exige atualizar `AI_DB_CONTEXT.md`?** Sim, do sistema Financeiro/Administração Bancária (nova tela, novas tabelas/colunas) e do sistema de Orçamentos (remoção dos botões diretos de NF/boleto no modal pós-aprovação).
- **Padrão de acesso a dados já usado pelo sistema**: `retorno-bancario-bradesco-5392a` usa chamadas diretas `supabase.from(...)`/`supabase.storage` dentro de cada página (`NotasFiscais.tsx`, `Boletos.tsx`), sem camada de `services/`/hooks compartilhados — a nova tela "Vendas" deve seguir o mesmo padrão para não introduzir uma arquitetura nova isolada dentro de um sistema que já tem convenção própria.

## Realizado

_(nada implementado ainda — SPEC recém-criada)_

## Pendências

- [ ] **Esclarecer o que foi mostrado ao vivo na reunião como tela de emissão fiscal com retorno de API/JSON** — não encontrado em nenhum sistema deste repositório; pode ser ferramenta externa, tela nunca commitada localmente, ou confusão de nomenclatura. Bloqueia qualquer proposta de integração fiscal automática real.
- [ ] Decidir provedor/API de emissão de NFe, caso a resposta acima seja "ainda não existe, precisa ser construído do zero" (pendência global antiga, nunca fechada).
- [ ] Decidir nomenclatura final: "Administração Bancária" com aba "Vendas" vs. renomear para "Contas a Pagar/Receber" com Vendas como estrutura própria — proposta em aberto desde `06_ESCOPO_FINANCEIRO.md` (SPEC-FIN-01), nunca fechada pelo usuário.
- [ ] Definir a matriz de permissões de Vendas (Carol completo, Lana restrita a remessa/retorno) — depende de migrar Administração Bancária para `hub_pode_executar` (RBAC granular da SPEC-069), o que ainda não aconteceu.
- [ ] Confirmar ao vivo, no Skip publicado, que `orcamentos.numero_venda` aparece corretamente no fluxo real (investigação de código diz que sim, usuário não fechou esse teste na reunião).
- [ ] Regra de negócio: quando a soma das notas parciais cobrir 100% dos itens de uma venda, isso precisa de algum indicador visual na tela de Vendas ("Nota completa") ou basta ser derivável? Deixado em aberto para não decidir UX de negócio sozinho.
