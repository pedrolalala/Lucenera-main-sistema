# Relacionamentos principais do DB Lucenera

Status: atualizado com base no schema real extraído do Supabase em 2026-07-06.

Fonte principal: `supabase/db/current/01_schema_full.sql`.

Este documento não substitui o dump completo do banco. Ele serve como mapa lógico para orientar manutenção, IA assistida e evolução dos sistemas sem depender das migrations antigas espalhadas pelos projetos.

## Leitura rápida

O banco atual tem quatro eixos principais:

```text
Cadastros
  empresas, contatos, usuários, funcionários, fornecedores, produtos

Operação comercial / projetos
  orçamentos, projetos, itens, parcelas, sinal, histórico

Financeiro / administração bancária
  boletos, notas fiscais, transações, remessas, retornos

Operação física
  estoque, compras, separação, entregas
```

O ponto central do ecossistema é o projeto. A maior parte dos sistemas chega ao projeto por um orçamento, por um cliente/contato ou por uma movimentação operacional.

## Relação base: empresa, usuários e permissões

### Estrutura real — empresas do grupo Lucenera

```text
usuarios.empresa_id             -> empresas.id
projetos.empresa_id             -> empresas.id
orcamentos.empresa_id           -> empresas.id
boletos.empresa_id              -> empresas.id
contas_bancarias.empresa_id     -> empresas.id
transacoes.empresa_id           -> empresas.id
remessas.empresa_id             -> empresas.id
retornos_processados.empresa_id -> empresas.id
funcionarios.empresa_id         -> empresas.id
```

Aqui `empresas.id` representa as empresas do grupo econômico/operacional da Lucenera. É o `codempresa` usado para separar operação, faturamento, contas, remessas, transações e vínculos internos do grupo.

```text
usuarios.id        -> auth.users.id
usuarios_ubiqua.id -> auth.users.id

user_system_access.user_id -> usuarios.id
projetos.responsavel_id    -> usuarios.id
projetos.created_by        -> usuarios.id
separacoes.responsavel_id  -> usuarios.id
entregas.entregador_id     -> usuarios.id
transacoes.created_by      -> usuarios.id
```

```text
user_system_access.system_id -> systems.id
```

### Como interpretar

- `auth.users` é a identidade de login.
- `usuarios` é o cadastro operacional do usuário dentro do ecossistema Lucenera.
- `systems` e `user_system_access` formam a base do Hub/TI para definir quais sistemas cada usuário pode acessar.
- As permissões por sistema devem evoluir pela UI, sem hardcode em cada aplicação.

Ação a ser realizada: quando um sistema precisar controlar acesso, consultar `usuarios`, `systems` e `user_system_access`, evitando criar uma tabela local isolada para permissões.

## Cadastros: contatos, clientes, arquitetos e fornecedores

### Estrutura real

```text
contatos.created_by         -> auth.users.id
contatos.vendedor_id        -> auth.users.id
contatos.vendedor_padrao_id -> auth.users.id
contatos.canonical_id       -> contatos.id
contatos.empresa_id         -> contatos.id

contato_tipos.contato_id             -> contatos.id
contato_origens.contato_id           -> contatos.id
contatos_revisao.id_a                -> contatos.id
contatos_revisao.id_b                -> contatos.id
projetos.cliente_id                  -> contatos.id
projetos.client_id                   -> contatos.id
projetos.arquiteto_id                -> contatos.id
projetos.responsavel_obra_id         -> contatos.id
orcamentos.cliente_id                -> contatos.id
orcamentos.arquiteto_id              -> contatos.id
produtos.fornecedor_principal_id     -> contatos.id
negociacoes.contato_id               -> contatos.id
separacoes.cliente_id                -> contatos.id
```

SPEC-077 (2026-08-11) — divisão de lucro entre múltiplos arquitetos por percentual, uma tabela de junção por domínio (substitui `arquiteto_id` singular como fonte de verdade; a coluna singular continua sincronizada só por compatibilidade):

```text
projeto_arquitetos.projeto_id     -> projetos.id
projeto_arquitetos.arquiteto_id   -> contatos.id
orcamento_arquitetos.orcamento_id -> orcamentos.id
orcamento_arquitetos.arquiteto_id -> contatos.id
```

### Empresa do contato não é a mesma coisa que `empresas`

No cadastro, a palavra “empresa” aparece com dois significados diferentes:

1. `empresas`
   - representa empresas do grupo econômico Lucenera;
   - é usada por orçamento, financeiro, remessa, transação, usuário e operação interna;
   - normalmente responde “por qual empresa da Lucenera esta operação está acontecendo?”.

2. `contatos.empresa_id -> contatos.id`
   - representa a empresa/PJ vinculada a uma pessoa ou contato;
   - a empresa do cliente, fornecedor, arquiteto ou responsável também é um registro em `contatos`;
   - permite que uma pessoa física esteja ligada a uma pessoa jurídica para nota fiscal, cobrança, relacionamento comercial ou histórico;
   - permite que um cliente tenha mais de uma empresa/PJ relacionada.

Exemplo: um arquiteto é um `contato`. Se ele atua por uma empresa/PJ, essa empresa também é um `contato`, e o vínculo pode ser feito por `contatos.empresa_id`.

Também existe a tabela `informacoes_cliente_ubiqua`, usada pelo fluxo de orçamentos/catálogo Ubiqua:

```text
orcamentos.informacoes_cliente_id      -> informacoes_cliente_ubiqua.id
orcamentos_revenda_ubiqua.cliente_id   -> informacoes_cliente_ubiqua.id
```

### Como interpretar

- `contatos` é a base cadastral mais ampla para clientes, arquitetos, fornecedores, empresas/PJ de clientes e outros contatos.
- `informacoes_cliente_ubiqua` é uma base mais simples/legada usada em orçamento Ubiqua/revenda.
- O Cadastro deve ficar responsável por dados cadastrais. Dados operacionais de estoque/compras não devem ser empurrados para Cadastro.
- `contatos.empresa_id` apontar para `contatos.id` é uma modelagem intencional para vincular pessoa/contato à sua empresa/PJ. Não deve ser “corrigido” para `empresas.id` sem uma decisão explícita de redesenho cadastral.

Ação a ser realizada: em novas integrações, preferir `contatos` como cadastro principal. Quando o fluxo vier de Ubiqua/revenda, mapear ou conciliar `informacoes_cliente_ubiqua` com `contatos` antes de criar novas dependências fortes.

## Projetos como núcleo operacional

### Estrutura real

```text
projetos.cliente_id          -> contatos.id
projetos.client_id           -> contatos.id
projetos.arquiteto_id        -> contatos.id
projetos.responsavel_obra_id -> contatos.id
projetos.responsavel_id      -> usuarios.id
projetos.created_by          -> usuarios.id
projetos.empresa_id          -> empresas.id
projetos.responsavel_funcionario_id -> funcionarios.id
```

`projetos.responsavel_funcionario_id` (SPEC-077, 2026-08-11) é o Responsável real do projeto, escolhido por dropdown vinculado a `funcionarios`. `projetos.responsavel_id` (-> `usuarios.id`) é uma FK morta/legada, praticamente sempre `NULL` na prática — não confundir os dois. O texto livre `responsavel_nome` continua existindo e sendo gravado junto (não substituído) porque alimenta o trigger `fn_sync_equipe_por_responsavel` (equipe/comissão).

`projetos.valor_total` é um total denormalizado mantido por `public.sync_projeto_valor_total()` a partir da soma de `projeto_itens.subtotal`. Ele existe para compatibilidade com a automação atual de itens do projeto; no fluxo financeiro novo, boletos e notas continuam rastreados por `orcamento_id`.

```text
orcamentos.projeto_id           -> projetos.id
projeto_itens.projeto_id        -> projetos.id
projeto_parcelas.projeto_id     -> projetos.id
projeto_sinal.projeto_id        -> projetos.id
projeto_produtos.projeto_id     -> projetos.id
transacoes.projeto_id           -> projetos.id
vendas.projeto_id               -> projetos.id
vendas_marca.projeto_id         -> projetos.id
separacoes.projeto_id           -> projetos.id
entregas.projeto_id             -> projetos.id
solicitacoes_compra.projeto_id  -> projetos.id
negociacoes.projeto_id          -> projetos.id
```

### Como interpretar

O projeto conecta CRM, orçamento, financeiro, estoque/compras e logística.

Mesmo assim, para o novo fluxo orçamento aprovado → financeiro, a decisão operacional é usar `orcamento_id` como vínculo principal. O `projeto_id` pode ser derivado do orçamento quando necessário.

Ação a ser realizada: em telas financeiras, buscar orçamento, projeto e cliente a partir do `orcamento_id`, evitando exigir que o usuário escolha projeto/cliente de novo manualmente.

## Orçamentos e itens aprovados

### Estrutura real — orçamento operacional

```text
orcamentos.empresa_id              -> empresas.id
orcamentos.cliente_id              -> contatos.id
orcamentos.arquiteto_id            -> contatos.id
orcamentos.vendedor_id             -> funcionarios.id
orcamentos.informacoes_cliente_id  -> informacoes_cliente_ubiqua.id
orcamentos.projeto_id              -> projetos.id
orcamentos.enviado_cliente_por     -> auth.users.id

orcamento_itens.orcamento_id       -> orcamentos.id
projeto_itens.orcamento_id         -> orcamentos.id
projeto_parcelas.orcamento_id      -> orcamentos.id
boletos.orcamento_id               -> orcamentos.id
notas_fiscais.orcamento_id         -> orcamentos.id
historico_status_orcamentos.orcamento_id -> orcamentos.id
```

```text
orcamento_itens.orcamento_id -> orcamentos.id
orcamento_itens.produto_id   -> produtos.id
orcamento_itens.item_pai_id  -> orcamento_itens.id
```

### Estrutura real — orçamento Ubiqua/revenda

```text
orcamentos_revenda_ubiqua.cliente_id -> informacoes_cliente_ubiqua.id

itens_orcamento_ubiqua.orcamento_id  -> orcamentos_revenda_ubiqua.id
historico_status_orcamento.orcamento_id -> orcamentos_revenda_ubiqua.id
```

```text
itens_orcamento_ubiqua.orcamento_id -> orcamentos_revenda_ubiqua.id
itens_orcamento_ubiqua.produto_id   -> revenda_ubiqua.id
```

### Regra de produto

Somente orçamento aprovado vira item aprovado de projeto.

```text
orcamentos Orçamento Aprovado
  -> orcamento_itens
  -> projeto_itens
  -> projeto_parcelas
  -> boletos / notas_fiscais
```

### Aprovação do cliente — estado real de 06/07/2026

`orcamentos` já possui as colunas:

```text
enviado_cliente_em
enviado_cliente_por -> auth.users.id
aprovado_cliente_em
recusado_cliente_em
motivo_recusa_cliente
token_aprovacao_cliente
requer_revisao_financeira
data_base_vencimento
```

Também existem RPCs de aprovação do cliente (`enviar_orcamento_para_cliente`, `cliente_aprovar_orcamento`, `cliente_recusar_orcamento`, `adm_aprovar_pelo_cliente`) e funções/triggers alternativas (`aprovar_orcamento_cliente*`, `handle_orcamento_workflow`, `normalize_orcamento_status`).

A SPEC-016 decidiu e implementou que o fluxo oficial é `enviado_cliente -> Aprovação Financeira -> Orçamento Aprovado`. `aprovado_cliente`, `aprovado` e `aprovado_financeiro` são legados/compatibilidade, e efeitos financeiros devem ser disparados só pela aprovação financeira por `orcamento_id`.

### Saldos de estoque por item de projeto — aplicado, com hardening pendente

Em 07/07/2026, o banco real já possui `estoque_saldos_projeto_item`, `estoque_movimentos_projeto_item` e as views da SPEC-010. A reserva agregada em `estoque_itens.quantidade_reservada` deve reconciliar com os saldos abertos (`q_reserva + q_entrega_futura + q_ag_separar + q_separado`); a migration corretiva `20260707_023_spec010_hardening` foi escrita para alinhar essa compatibilidade e fechar a exposição das views.

Ação a ser realizada: aplicar o hardening `20260707_023`, reextrair `db/current/` e definir a policy de RLS antes de tratar transferência entre itens de projeto, entrega futura detalhada, devolução automatizada ou badges ricos de reserva no CRM. A chave operacional deve ser `projeto_item_id`; produto, projeto, orçamento e cliente são derivados por relacionamento.

Para o fluxo novo, `projeto_itens.orcamento_id`, `projeto_parcelas.orcamento_id`, `boletos.orcamento_id` e `notas_fiscais.orcamento_id` permitem rastrear a origem financeira e operacional do orçamento aprovado.

O histórico também é separado por família:

- `historico_status_orcamentos` (plural) pertence ao fluxo Lucenera novo e referencia `public.orcamentos(id)`;
- `historico_status_orcamento` (singular) pertence ao fluxo Ubiqua/revenda e referencia `public.orcamentos_revenda_ubiqua(id)`.

As parcelas do fluxo novo e legado também foram separadas por unicidade parcial:

- `projeto_parcelas_orcamento_numero_uniq`: `(orcamento_id, numero_parcela) WHERE orcamento_id IS NOT NULL`;
- `projeto_parcelas_projeto_numero_legado_uniq`: `(projeto_id, numero_parcela) WHERE orcamento_id IS NULL`.

### Atenção

Há duas famílias de orçamento no DB atual:

- `orcamentos` / `orcamento_itens`;
- `orcamentos_revenda_ubiqua` / `itens_orcamento_ubiqua`.

As relações financeiras novas apontam para `orcamentos`. Já `orcamentos_revenda_ubiqua` mantém histórico próprio e itens próprios.

Ação a ser realizada: antes de unificar relatórios ou automações entre os dois fluxos, decidir se `orcamentos_revenda_ubiqua` continuará separado, se será migrado para `orcamentos`, ou se será criada uma camada de conciliação/view.

## Financeiro e Administração Bancária

### Estrutura real

```text
projeto_parcelas.projeto_id   -> projetos.id
projeto_parcelas.orcamento_id -> orcamentos.id
projeto_parcelas.transacao_id -> transacoes.id

boletos.parcela_id            -> projeto_parcelas.id
transacoes.parcela_id         -> projeto_parcelas.id
```

```text
boletos.empresa_id    -> empresas.id
boletos.orcamento_id  -> orcamentos.id
boletos.parcela_id    -> projeto_parcelas.id
```

```text
notas_fiscais.boleto_id    -> boletos.id
notas_fiscais.orcamento_id -> orcamentos.id
```

```text
transacoes.conta_id       -> contas_bancarias.id
transacoes.categoria_id   -> categorias_financeiras.id
transacoes.empresa_id     -> empresas.id
transacoes.projeto_id     -> projetos.id
transacoes.parcela_id     -> projeto_parcelas.id
transacoes.created_by     -> usuarios.id
transacoes.funcionario_id -> funcionarios.id
transacoes.negociacao_id  -> negociacoes.id
```

```text
remessas.empresa_id    -> empresas.id
remessas.fornecedor_id -> fornecedores.id

retornos_processados.empresa_id -> empresas.id
```

### Regra de produto

O financeiro deve navegar pelo `orcamento_id` sempre que a origem for um orçamento aprovado.

```text
boletos.orcamento_id
  -> orcamentos.id
  -> orcamentos.projeto_id
  -> projetos.cliente_id
  -> contatos.id
```

Isso permite que a Administração Bancária mostre:

- orçamento;
- projeto;
- cliente;
- parcelas;
- boleto;
- nota fiscal.

Sem exigir que tudo seja preenchido manualmente de novo.

### Atenção

`boletos` tem `orcamento_id` e `parcela_id`. A coluna `boletos.projeto_id` foi removida, porque no fluxo novo de orçamento aprovado o boleto deve estar vinculado ao orçamento, não diretamente ao projeto.

O projeto já é obtido por `orcamentos.projeto_id`. Portanto, repetir esse vínculo dentro do boleto criava redundância e risco de divergência.

Ação a ser realizada: nas telas novas, tratar `orcamento_id` como origem da operação e derivar projeto/cliente por join com `orcamentos`, `projetos` e `contatos`.

## Produtos, estoque e compras

### Estrutura real

```text
produtos.marca_id                 -> marcas.id
produtos.categoria_id             -> categorias_produto.id
produtos.fornecedor_principal_id  -> contatos.id

estoque_itens.produto_id          -> produtos.id
projeto_itens.produto_id          -> produtos.id
orcamento_itens.produto_id        -> produtos.id
separacao_itens.produto_id        -> produtos.id
solicitacoes_compra.produto_id    -> produtos.id
```

```text
estoque_itens.produto_id     -> produtos.id
estoque_itens.atualizado_por -> usuarios.id
```

```text
solicitacoes_compra.projeto_id -> projetos.id
solicitacoes_compra.produto_id -> produtos.id
```

### Regra de produto

- Vendas representam itens aprovados.
- O restante das movimentações relacionadas a cliente deve ser tratado como movimentação operacional de estoque.
- Cadastro mantém dados cadastrais.
- Estoque/Compras mantém dados cadastrais necessários para operação e os dados operacionais.

Ação a ser realizada: evoluir Estoque/Compras como sistema próprio, usando `produtos`, `estoque_itens`, `solicitacoes_compra`, `projeto_itens` e `separacao_itens` como base inicial.

## Logística: separação e entrega

### Estrutura real

```text
separacoes.projeto_id     -> projetos.id
separacoes.cliente_id     -> contatos.id
separacoes.responsavel_id -> usuarios.id

separacao_itens.separacao_id -> separacoes.id
entregas.separacao_id        -> separacoes.id
```

```text
separacao_itens.separacao_id -> separacoes.id
separacao_itens.produto_id   -> produtos.id
```

```text
entregas.separacao_id  -> separacoes.id
entregas.projeto_id    -> projetos.id
entregas.entregador_id -> usuarios.id
```

### Como interpretar

Separação é a etapa operacional que organiza o material para entrega. Entrega é o registro logístico posterior ou paralelo à separação.

O sistema antigo de logística está fora do Supabase como fonte de verdade de funções. Ele deve ser analisado como referência funcional para replicar o comportamento necessário no novo sistema de logística.

Ação a ser realizada: ao recriar/evoluir logística, usar `separacoes`, `separacao_itens`, `entregas` e arquivos de separação como base, mas revisar status legados antes de hardcodar fluxo.

## RH

### Estrutura real

```text
funcionarios.usuario_id      -> usuarios.id
funcionarios.departamento_id -> departamentos.id
funcionarios.empresa_id      -> empresas.id

ferias.funcionario_id              -> funcionarios.id
controle_falta.funcionario_id      -> funcionarios.id
folha_pagamento.funcionario_id     -> funcionarios.id
periodos_aquisitivos.funcionario_id -> funcionarios.id
transacoes.funcionario_id          -> funcionarios.id
orcamentos.vendedor_id             -> funcionarios.id
negociacoes.funcionario_id         -> funcionarios.id
```

```text
ferias.funcionario_id          -> funcionarios.id
ferias.aprovado_por            -> usuarios.id
ferias.periodo_aquisitivo_id   -> periodos_aquisitivos.id
```

### Como interpretar

RH possui relações reais com usuários, funcionários, férias, faltas e folha. Porém, as functions locais do RH não são fonte de verdade do ecossistema central.

Ação a ser realizada: usar o DB central como referência de dados e tratar códigos locais de RH como implementação de sistema, não como regra global do banco.

## CRM configurável

### Situação atual

Hoje `projetos.status` usa o enum `projeto_status`.

```text
projetos.status
  -> public.projeto_status
```

Também há views de apoio:

```text
vw_projetos_pipeline
vw_projetos_por_status
vw_projetos_status_enum
vw_dashboard_crm_fechamento
```

### Regra de produto

As etapas do CRM, sub-status, checklists, bloqueios, paralelismo, sequência, SLA e responsáveis devem ser configuráveis pela UI.

O relacionamento futuro esperado é:

```text
projetos
  -> timeline do projeto
  -> etapa configurada
  -> sub-status configurado
  -> checklist configurado
  -> tarefas / SLA / responsáveis
```

Ação a ser realizada: não criar novas regras hardcoded de etapa no código. Quando evoluir o CRM, criar tabelas de configuração para etapas, sub-status, checklists, dependências, bloqueios, SLA e responsáveis.

## Compras: nota de entrada, parcelas e pagamento antecipado (SPEC-215, migration 229)

- `notas_fiscais_compra.pedido_compra_id` -> `pedidos_compra.id`; `fornecedor_id` = fornecedor da nota (se a nota
  veio em outro nome, o pedido passa a ser desse fornecedor).
- `nota_fiscal_compra_parcelas.nota_id` -> `notas_fiscais_compra.id` (parcelas digitadas na entrada; ST na 1ª).
- `pagamentos_antecipados.fornecedor_id` -> `contatos.id`; `empresa_id` -> `empresas.id`; `pedido_compra_id`
  (opcional) -> `pedidos_compra.id`.
- `pagamento_antecipado_vinculos.pagamento_id` -> `pagamentos_antecipados.id`; `nota_id` -> `notas_fiscais_compra.id`.
  Saldo = `valor` − soma de `valor_aplicado`.
- `negociacoes.num_nota` (Connect) casa com `notas_fiscais_compra.numero_nf` por empresa + número + total (±R$ 1):
  quando a duplicata do Connect chega, a parcela da nota sai do A Pagar (`vw_contas_pagar_pedidos_compra`).
  O fornecedor não serve para casar (fornecedores dos pedidos não são os contatos das duplicatas do Connect).

## Caminhos recomendados para navegação nos sistemas

### Aprovação de orçamento para financeiro

```text
orcamentos.id
  -> orcamento_itens.orcamento_id
  -> projeto_itens.orcamento_id
  -> projeto_parcelas.orcamento_id
  -> boletos.orcamento_id
  -> notas_fiscais.orcamento_id
```

Uso esperado: aprovar orçamento, gerar itens aprovados do projeto e disponibilizar pendência na Administração Bancária para nota fiscal/boleto.

### Administração Bancária exibindo contexto completo

```text
boletos.orcamento_id
  -> orcamentos.id
  -> orcamentos.projeto_id
  -> projetos.id
  -> projetos.cliente_id
  -> contatos.id
```

Uso esperado: uma tela financeira consegue mostrar cliente/projeto/orçamento sem pedir preenchimento duplicado.

### Projeto para separação e entrega

```text
projetos.id
  -> projeto_itens.projeto_id
  -> separacoes.projeto_id
  -> separacao_itens.separacao_id
  -> entregas.separacao_id
```

Uso esperado: logística consegue enxergar o que precisa separar/entregar por projeto.

### Produto para estoque e operação

```text
produtos.id
  -> estoque_itens.produto_id
  -> projeto_itens.produto_id
  -> separacao_itens.produto_id
  -> solicitacoes_compra.produto_id
```

Uso esperado: Estoque/Compras consegue cruzar disponibilidade, reserva, compra e separação.

## Pendências de conciliação

1. `contatos` e `informacoes_cliente_ubiqua`
   - Existem duas bases de cliente.
   - Ação a ser realizada: definir regra de conciliação antes de unificar relatórios comerciais.

2. Significado duplo de empresa
   - `empresas` representa empresas do grupo Lucenera.
   - `contatos.empresa_id` representa a empresa/PJ de um contato e aponta para outro registro em `contatos`.
   - Ação a ser realizada: documentar isso nas telas e integrações para evitar que uma IA ou desenvolvedor troque esse relacionamento por engano.

3. `orcamentos` e `orcamentos_revenda_ubiqua`
   - Existem dois fluxos de orçamento com tabelas de itens diferentes.
   - Ação a ser realizada: definir se o orçamento Ubiqua/revenda será migrado, conciliado via view ou mantido separado.

4. Boletos por orçamento
   - `boletos.projeto_id` foi removido.
   - O boleto usa `orcamento_id`; o projeto é derivado por `orcamentos.projeto_id`.
   - Ação a ser realizada: manter consultas, filtros e telas financeiras baseados em `orcamento_id`.

5. `projeto_parcelas`
   - A coluna `venda_id` foi removida.
   - Ação a ser realizada: manter parcelas do fluxo aprovado vinculadas por `orcamento_id`; o projeto continua disponível por `projeto_id`.

6. Logística antiga vs novo sistema
   - Parte das regras úteis está no sistema backup, não como fonte central de functions.
   - Ação a ser realizada: replicar o que for necessário no novo sistema de logística, sem tratar o backup como fonte de verdade do DB.
