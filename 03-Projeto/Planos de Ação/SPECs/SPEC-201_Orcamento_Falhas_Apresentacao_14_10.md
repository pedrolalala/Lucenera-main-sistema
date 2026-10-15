---
titulo: "SPEC-201 — Orçamento: falhas vistas na apresentação de 14/10 (equipe sem admin)"
status: pendente
data_ultima_modificacao: 2026-10-15
sistemas_envolvidos:
  - Orçamentos (gestao-financeira-clone-544cb)
  - CRM (lucenera-crm-3bd29) — só pela regra de cadastro de cliente no banco
---

# SPEC-201 — Orçamento: falhas vistas na apresentação de 14/10 (equipe sem admin)

> Origem: `02-Reunioes/31. Lucenera (reunião apresentação) - 15/10/2026/Reunião.01` (gravação da apresentação de
> 14/10 às equipes; o ORC-0001 feito ao vivo foi apagado em 15/10). Continuação da SPEC-200, que já resolveu
> "equipe aprovar o cliente" e "cada equipe vê só a sua". Esta SPEC cobre só **Orçamento**; CRM, Consulta de Produtos,
> Separação e Showroom ficam para outras SPECs da mesma reunião.

## Checklist de Ação

- [x] A1 — Banco: as 3 funções de aprovação do cliente voltam a levar o orçamento para **Aprovação da Equipe** (migration 213, que também devolve o status ao CHECK)
- [x] A2 — Teste no banco (transação desfeita): Marina e admin → Aprovação da Equipe → Financeira; Thais barrada
- [ ] A3 — Teste pela tela com a conta da equipe, depois de publicado
- [x] B1 — Banco: a regra pelo Hub já existia (`spec069_contatos_*`, permissão do CRM). Faltava eletricista no CHECK de `contato_tipos` (migration 214)
- [x] B2 — Tela: `ClientCreateModal` usa `hub_pode_executar('crm', criar)`; fornecedor só para admin/gerente/operador
- [ ] B3 — Teste: importar XML de cliente que não existe, logado como Marina, até salvar o orçamento
- [x] C1 — Importar XML de novo **atualiza** o orçamento do mesmo nº da Connect até a Aprovação da Equipe
- [ ] C2 — Teste com XML revisado real
- [x] D1 — Lista: legenda "O que significa cada status?" (recolhida) abaixo das abas
- [x] D2 — Lista: aba "Aprovação do cliente" passa a se chamar "Enviado ao Cliente"
- [ ] E1 — Identificar o que veio faltando no XML importado ao vivo ("ele veio sem o… isso aqui eu preciso corrigir", 45 min)

### Passos manuais do usuário

- [x] Confirmar as decisões B e C (15/10).
- [ ] Mandar 1 XML real da Connect de cliente **não cadastrado** e 1 de orçamento **revisado** (mesmo nº, itens mudados) para os testes B3 e C1.
- [ ] Dizer o que faltou no XML importado na apresentação (item E1) — a gravação corta a frase.

## Objetivo

Na apresentação, a importação do XML e a aprovação só andaram depois de trocar para o login de um admin. A partir de
agora as equipes vão usar o sistema de verdade: o orçamento importado da Connect tem que passar por Rascunho → Enviado
ao Cliente → Aprovação da Equipe → Revisão Financeira → Aprovado **com a conta da própria equipe**, sem pular etapa.

## O que falhou na reunião (com a causa encontrada)

| # | Momento | O que aconteceu | Causa |
|---|---|---|---|
| 1 | 47:12 | Importar XML com a conta da Marina: "está pedindo um acesso para cadastrar o cliente" | `ClientCreateModal.tsx:157` só libera `admin/gerente/operador`; a equipe é `funcionario`. No banco, a política `contatos_insert`/`contatos_update` também só aceita esses 3 roles |
| 2 | 54:48 | "Nessa conta não vai dar… entra na minha" — trocou para conta admin para aprovar | Resolvido pela SPEC-200 (módulo Hub `aprovacao_cliente`, migration 211) |
| 3 | 56:15 / 1:12:39 | "Nem tá caindo aqui, ele já pulou" — aprovou o cliente e o orçamento foi direto para Revisão Financeira | **Não é só admin.** `aprovar_orcamento_cliente`, `_manual` e `_publico` gravam `status = 'Aprovação Financeira'`. A SPEC-031 (migration 050) mandava para `Aprovação da Equipe`; uma regravação posterior voltou ao texto antigo e a 211 manteve. Histórico do ORC-0001: `enviado_cliente → Aprovação Financeira → Orçamento Aprovado` |
| 4 | 1:30:18 / 1:32:16 | Orçamento muda depois de importado (cores, peças na aprovação da equipe) — como atualizar? | Hoje o modal recusa: "Este orçamento Connect já foi importado" |
| 5 | 1:03:19 | Filippo: o status é o mais importante; precisa explicar bem cada um | Não existe legenda; a aba "Aprovação do Cliente" foi entendida como "a equipe tem que aprovar", não como "enviado e aguardando o cliente" |
| 6 | 45:xx | "No caso ele veio sem o… isso aqui eu preciso corrigir" | Frase cortada na gravação — ver E1 |

## Decisões aprovadas (na reunião)

- Ficam **duas aprovações** da equipe: Cliente (o cliente aprovou → "Aprovar") e Equipe (depois de validar com obra/arquiteto). Depois disso é só Administração (Filippo e Vinícius, 1:31).
- Os status servem de **filtro de acompanhamento**: "Enviado ao Cliente" lista tudo o que está esperando retorno (Filippo, 1:07–1:10).
- Cada equipe vê só a própria equipe; administração vê tudo (já feito na SPEC-200).
- Por enquanto as equipes fazem o orçamento na Connect e **importam o XML quando o cliente aprova** (Filippo/Vinícius, 1:31). Observações técnicas e administrativas continuam **por e-mail** neste primeiro momento (Vinícius, 59:59; Marina: "pra começar é melhor").
- "Quem digitou" não precisa de campo: vem do login (Thairine, 38:07) — já gravado pela SPEC-200.

## Decisões do usuário (15/10)

- **B:** a equipe cria e edita cliente, arquiteto, engenheiro e eletricista; **fornecedor não** (Mariane, 15:54); excluir continua só admin/gerente.
- **C:** reimportar XML só enquanto o orçamento está em Rascunho, Enviado ao Cliente (ou recusado) ou Aprovação da Equipe. Na Revisão Financeira ou depois de aprovado, recusa (aí já tem parcela/boleto — Vinícius, 54:16).

## Definição

### A — Aprovação do cliente vai para a Aprovação da Equipe

- Migration nova regrava as 3 funções **a partir de `pg_get_functiondef` do banco SP** (nunca de migration antiga — foi assim que a regressão aconteceu). Única troca: `status = 'Aprovação da Equipe'`, `requer_revisao_financeira = false`, texto do histórico "…aguardando aprovação da equipe". Permissões e validações (frete, forma de pagamento, valor, item especial sem preço, prazo) ficam iguais.
- `equipe_aprovar_orcamento` já leva de Equipe → Financeira; não muda.
- Rollback = as 3 definições atuais salvas em `rollback.sql`.

### B — Equipe cadastra cliente

- Banco: `contatos_insert` e `contatos_update` aceitam também quem tem permissão no Hub (função `hub_pode_executar` com `(SELECT auth.uid())`, ver regra de desempenho de RLS) para o tipo permitido. Política nova com subselect, não por linha.
- Tela: `ClientCreateModal` troca `AUTHORIZED_ROLES` pela mesma checagem (hook de permissão do Hub, como o `canApproveClient` da SPEC-200). Vale também para o "+" de cliente/projeto dentro do orçamento.
- O CRM usa a mesma tabela: com a política nova a equipe também cadastra por lá (era o que foi mostrado na reunião).

### C — Reimportar XML atualiza o orçamento

- Mesmo `origem_connect_cod_orcamento` + status permitido → o modal mostra "Este orçamento já existe (ORC-xxxx). Atualizar com este XML?" e, confirmando, abre o orçamento existente com itens/valores do XML para revisar e salvar.
- Salvar troca os itens (como uma edição normal), mantém número, equipe, quem digitou e status, e grava no histórico "Atualizado pelo XML da Connect".
- Em Aprovação da Equipe, a troca de itens **não** pode devolver o orçamento sozinho para outro status — usar o mesmo cuidado do `trg_orcamento_item_change_reset`.

### D — Status legíveis

| Status (banco) | Nome na tela | Quem age |
|---|---|---|
| `rascunho` | Rascunho | equipe montando, cliente ainda não recebeu |
| `enviado_cliente` | Enviado ao Cliente | aguardando retorno do cliente |
| `Aprovação da Equipe` | Aprovação da Equipe | cliente aprovou; equipe valida cores, articulação, obra |
| `Aprovação Financeira` | Revisão Financeira | Administração |
| `Orçamento Aprovado` | Aprovado | vira venda, gera necessidade de compra |

- Legenda (ícone "?" ao lado das abas ou linha de texto) com essa tabela. Só texto e nome de aba: **sem** mudar colunas, abas ou dropdown além disso (ver rollback de 14/10).

## Critérios de aceite

1. Logado como Marina (equipe, sem admin): importar XML de cliente novo → cadastrar cliente → salvar → enviar ao cliente → aprovar cliente → aparece em **Aprovação da Equipe** → aprovar equipe → aparece em Revisão Financeira para a Administração.
2. Logado como admin, a aprovação do cliente também cai em Aprovação da Equipe (nada pula).
3. Thais não vê nem aprova orçamento da equipe da Marina (regressão da SPEC-200).
4. Reimportar o XML revisado do mesmo nº atualiza o ORC existente; reimportar com orçamento em Revisão Financeira é recusado com mensagem clara.
5. Equipe não consegue cadastrar fornecedor nem excluir contato.

## Fora de escopo (próximas SPECs da mesma reunião)

- Observações **técnicas** (para Compras/Debora) e **administrativas** (Lana/Carol) separadas, bem visíveis na Revisão Financeira e consultáveis depois (Vinícius, 58:12).
- Articulação/fixação por peça dentro do orçamento, opcional na criação e cobrada na aprovação da equipe (Debora e Giovana, 1:12–1:15).
- Canal de conversa por cliente no lugar do e-mail (Thairine/Marina, 1:01).
- E-mail automático ao enviar para o cliente, com PDF anexo (Filippo, 1:08) — exige e-mail do cliente no cadastro.
- CRM: "+" para cadastrar cliente/arquiteto/engenheiro/eletricista dentro da edição de projeto, campo eletricista no projeto, valores do dashboard aparecendo para a equipe, Financeiro/Configurações visíveis para a equipe, sincronização SharePoint → sistema.

## Realizado

### 2026-10-15

- **Migration 213** `20261015_213_spec201_aprovacao_cliente_vai_para_equipe` APLICADA em SP. Achado extra: o CHECK
  `orcamentos_status_check` não tinha mais `'Aprovação da Equipe'` (a 098 tinha incluído; foi perdido depois), então a
  etapa da equipe estava morta por dois motivos. A migration devolve o valor ao CHECK e regrava `aprovar_orcamento_cliente`,
  `_manual` e `_publico` a partir de `pg_get_functiondef` (só status, `requer_revisao_financeira = false` e texto do
  histórico). Teste em transação desfeita: Marina e Vinícius caem em Aprovação da Equipe e de lá na Financeira; Thais
  recebe "Orçamento não encontrado".
- **Migration 214** `20261015_214_spec201_contato_eletricista` APLICADA: `contato_tipos_tipo_check` aceita
  `eletricista` (antes ninguém conseguia cadastrar eletricista). Teste como Marina: cria/edita cliente, arquiteto,
  engenheiro, eletricista; fornecedor e excluir barrados.
- **Orçamentos** (`gestao-financeira-clone-544cb`), commit `9d65e5d`, PUBLICADO na Cloudflare (`financeiro-lucenera.pages.dev`, conferido no bundle):
  - `ClientCreateModal.tsx`: libera quem tem `crm/criar` no Hub; esconde Fornecedor para quem não é admin/gerente/operador.
  - `ImportConnectXmlModal.tsx` + `xml-budget-import.ts` (`STATUS_PERMITE_REIMPORTAR_XML`): XML de orçamento já
    importado mostra "Atualizar ORC-xxxx"; se for outro orçamento, abre ele (`/budgets/:id`) e troca os itens;
    depois da Aprovação da Equipe, recusa com o status atual.
  - `BudgetFormPage.tsx`: modo "substituir itens" no import (mantém cliente/empresa do orçamento se o XML não casar);
    ao salvar grava no histórico "Itens atualizados pelo XML da Connect (nº X)".
  - `ClientApproval.tsx` (link do cliente): `Aprovação da Equipe` conta como já aprovado.
  - `Budgets.tsx`: aba "Enviado ao Cliente" e legenda dos status.
  - `vite build` ok; `tsc` com os mesmos 187 erros antigos antes e depois (nenhum novo); lint sem aviso novo.

## Pendências

- [ ] Testar pela tela com a conta de uma pessoa da equipe (A3, B3, C2) — publicado em 15/10, falta o teste.
- [ ] Descobrir o que veio faltando no XML importado ao vivo na apresentação de 14/10 (frase cortada aos 45 min da gravação).
