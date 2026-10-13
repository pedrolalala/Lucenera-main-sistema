---
titulo: "SPEC-197 — \"Vínculo Connect\" como Tipo de Operação no Novo Orçamento"
status: publicada 13/10 (falta teste na tela com XML real)
data_ultima_modificacao: 2026-10-13
origem:
  - "pedido do usuário 13/10: \"uma opção igual das opções que tem quando clica em novo orçamento (venda, devolução, outros e SAC) — venda vinculada da Connect\""
sistemas_envolvidos:
  - Orçamentos (gestao-financeira-clone-544cb, Skip 32554)
  - Supabase (vincular_orcamento_connect)
relacionadas: [SPEC-050, SPEC-071, SPEC-074, SPEC-195]
---

# SPEC-197 — "Vínculo Connect" como Tipo de Operação no Novo Orçamento

## Por quê
O vínculo da SPEC-195 (venda já aprovada na Connect: liga peças e valor ao projeto, sem reserva de estoque, sem
parcela/boleto e sem nota) só existia como um ícone de corrente na linha da lista, visível só para quem aprova.
O usuário não achou o botão. Pedido: escolher "Vínculo Connect" já no Tipo de Operação, como Venda/Devolução/Outros/SAC.

## Decisões do usuário (13/10)
- **Número da Connect só pelo XML** ("Importar XML (Connect)"). Não há campo para digitar o número.
- **Todos que fazem orçamento podem usar** (não só quem aprova).

## O que muda
- [x] **1. Botão "Vínculo Connect"** no Tipo de Operação (5ª opção). Por dentro continua `natureza_operacao = 'venda'`
  (subgrupo VENDAS) — o vínculo é marcado por `vinculo_connect`, como na SPEC-195; nenhuma outra tela muda.
- [x] **2. Aviso** ao escolher: não reserva estoque, não gera parcela/boleto, não vai para nota; mostra se o XML já foi
  importado (nº da Connect) ou pede para importar.
- [x] **3. "Salvar e vincular"**: salva o orçamento e chama `vincular_orcamento_connect`. Sem XML importado, não salva
  (mensagem pedindo o XML). Se o vínculo recusar (falta projeto/cliente, peça sem cadastro, nº repetido), o orçamento
  fica salvo como rascunho e a mensagem do banco aparece.
- [x] **4. Ao editar** um orçamento de venda importado do XML e ainda não vinculado (ex.: ORC-0038), o botão
  "Vínculo Connect" também pode ser escolhido.
- [x] **5. Permissão** (migration 206): `vincular_orcamento_connect` aceita quem pode **criar** orçamento no Hub
  (antes: só **aprovar**). O ícone de corrente da lista também passa a aparecer para quem cria orçamento.
  **Desfazer vínculo continua só para quem aprova** (sem mudança).

## Fora do escopo
- Digitar o número da Connect à mão (decisão: só XML).
- Mudar o que o vínculo grava (SPEC-195 A1–A5 continua igual).

## Realizado
### 13/10
- Migration `20261013_206_spec197_vincular_connect_quem_cria` **aplicada** (gerada da definição real; rollback.sql =
  definição anterior). Ensaio: Adriana (vendedora) antes "Permissão negada", depois vincula; desfazer continua negado
  para ela; login viewer continua negado; 1 só versão da função. ORC-0038 não foi alterado.
- Orçamentos 32554 **v0.0.389** (`ca34147`) publicado: `BudgetFormPage.tsx` (5ª opção, aviso, "Salvar e vincular",
  `vincularDepoisDeSalvar`) e `BudgetTableRow.tsx` (ícone da lista para quem não é viewer). QA Skip ok; Edge
  Functions sem mudança. tsc: mesmos 40 erros antigos no arquivo, nenhum novo.
