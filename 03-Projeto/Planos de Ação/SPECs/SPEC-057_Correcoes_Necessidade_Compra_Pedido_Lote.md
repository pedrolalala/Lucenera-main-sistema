---
titulo: "SPEC-057 — Correções na tela de Necessidade de Compra e Pedido em Lote (achados de teste ao vivo com Débora)"
status: implementado e publicado em produção (Skip) em 2026-08-04 — pendente homologação manual da Débora
data_ultima_modificacao: 2026-08-04
sistemas_envolvidos:
  - Compras (compras-lucenera-3o23t98ee)
  - Supabase (banco central)
dependencias:
  - SPEC-038 (pedido de compra: custo/impostos, numeração automática, parcelas)
  - SPEC-039 (Necessidade de Compra: colunas Pendente/Empresa que comprou/Status/Entrega)
  - SPEC-040 (abas Por Produto / Por Item de Orçamento)
---

# SPEC-057 — Correções na tela de Necessidade de Compra e Pedido em Lote

> Origem: reunião de teste ao vivo do sistema com a Débora (compradora real), conduzida pelo Filippo, em 04/08/2026 — `02-Reunioes/14. Lucenera (Filippo) - 04.08.2026 - necessidade de compra debora/Renuião.01.txt` e `Reunião.02.txt`. Cruzado com os documentos de referência do sistema legado Connect em `01-Documento/02 - Descritivo Connect/PDF/` (pedidos 1743 e 1765, e o e-mail padrão de solicitação de orçamento).

## Checklist de Ação

### Banco

- [x] Coluna `pedidos_compra.empresa_id` já existia, mas era preenchida só a partir de `usuarios.empresa_id` — confirmado que nenhum dos 9 usuários tem essa coluna preenchida, então todo pedido criado pelo app gravava `empresa_id = NULL` silenciosamente. Migration `20260804_072_pedido_compra_empresa_explicita/001_empresa_id_explicito.sql`: adiciona `p_empresa_id uuid DEFAULT NULL` explícito às RPCs `criar_pedido_compra_lote` e `criar_pedido_compra_de_necessidade`, com fallback para `usuarios.empresa_id` quando não informado. **Aplicada no Supabase real.**
  - Achado ao aplicar: `CREATE OR REPLACE FUNCTION` com parâmetro novo no final **não substitui** a função — cria uma segunda sobrecarga (overload) ambígua para o PostgREST. Corrigido com `DROP FUNCTION` explícito da assinatura antiga antes do `CREATE OR REPLACE` (documentado na própria migration).
- [x] Numeração de `pedidos_compra.numero`: trocado o formato do trigger `set_pedido_compra_numero()` de `PC-<ano>-NNNN` (nunca usado de fato — 0 pedidos criados pelo app até hoje) para sequencial simples sem prefixo, igual ao sistema legado Connect (ex: 1766, 1767...). Migration `20260804_071_numeracao_pedido_compra_legado/001_numero_sequencial_legado.sql`: `CREATE SEQUENCE pedidos_compra_numero_seq START WITH 1768` (usuário confirmou 1767 como último número real do legado, acima do máximo dos 51 pedidos importados que é 1725). **Aplicada no Supabase real.**

### Frontend (`compras-lucenera-3o23t98ee`)

- [x] Tela "Necessidade de Compra" → aba "Por Produto" (`src/pages/NecessidadeCompra.tsx`): removidas as colunas **Fornecedor** ("o fornecedor vem automaticamente na hora de fazer o pedido, não precisa aparecer aqui"), **Comprometida** ("não me interessa"), **Empresa que comprou**, **Status do pedido** e **Entrega prevista** ("não deve estar nessa tela, porque ninguém pediu se está em necessidade" — colunas sempre vazias nesse contexto, já que a view só lista itens sem pedido suficiente). Coluna **Física** renomeada para **Estoque**. Coluna **Necessidade** removida por redundância com **Pendente** (mantida) — a view já filtra só itens com `pendente > 0`, tornando as duas quase sempre iguais.
- [x] Checkbox "selecionar todos" no cabeçalho da tabela: seleciona todos os itens atualmente filtrados (busca + marca) que resolvem para o mesmo fornecedor dos já selecionados (mesma regra do checkbox individual existente); itens de fornecedor diferente são ignorados com toast explicando quantos foram pulados. Resolve o pedido da Débora ("vou colocar a opção de selecionar todos da marca de uma vez sem ter que ir apertando um por um").
- [x] `src/components/compra/ModalPedidoLote.tsx` e `ModalRegistrarCompra.tsx`: novo campo obrigatório **Empresa** (Select populado por `getEmpresas()`, novo em `services/pedido-compra.ts`), enviado como `empresa_id` nas duas RPCs. Resolve "aí colocar a empresa que vai fazer o pedido, que aí não tem".
- [x] Quantidades (`Estoque`, `Disponível`, `Pendente` na lista; `Física`/`Comprometida`/`Disponível` no resumo do `ModalPedidoLote`; quantidade pré-preenchida nos dois modais) passam por arredondamento defensivo de 3 casas decimais antes de exibir/pré-preencher, para não propagar artefatos de ponto flutuante do tipo relatado pela Débora ("5906,9999...").

## Objetivo

Corrigir, a partir de teste ao vivo com a usuária real (Débora), o atrito identificado no fluxo de "Necessidade de Compra" → "Fechar Pedido em Lote": colunas com informação redundante ou sempre vazia nesse contexto, falta de seleção em massa após filtrar, e ausência de um campo essencial (qual empresa do grupo Lucenera está comprando) que hoje é preenchido silenciosamente como `NULL`.

## Decisões aprovadas

- **Numeração de pedido (decisão do usuário, 2026-08-04)**: continuar a sequência numérica simples do sistema legado Connect (sem prefixo `PC-`), começando em 1768 — não manter o formato `PC-2026-NNNN` que havia sido implementado na SPEC-038 mas nunca usado em produção. Usuário confirmou 1767 como o último número real emitido pelo legado.
- **Campo Empresa**: obrigatório, escolhido por pedido (não fixo por usuário) — os PDFs de referência (pedidos 1743 e 1765) mostram a mesma compradora emitindo pedidos em nome de empresas diferentes do grupo (FOCO ILUMINACAO, ISLIGHT).
- **Coluna Necessidade removida, Pendente mantida** — decisão da Débora/Filippo ao vivo, por redundância no contexto filtrado da tela.

## Achados de código (antes de implementar)

- `pedidos_compra.empresa_id` já existia na tabela e as RPCs já tinham lógica de auto-preenchimento (SPEC-039 P-03) — mas **nenhum dos 9 usuários tem `usuarios.empresa_id` definido**, então essa lógica nunca resolvia nada na prática. Não era um campo "faltando" no banco, era um campo "faltando na tela".
- `numero` do pedido **já era gerado automaticamente** quando deixado em branco (trigger `set_pedido_compra_numero`, SPEC-038 Item 2) — só o formato (`PC-2026-NNNN`) não batia com o que Débora/Filippo esperavam ver (numeração simples igual ao legado).
- `Data prevista de entrega` e `Condições de pagamento` já existiam nos dois modais — não precisaram de mudança, só foram confirmados como úteis durante o teste ao vivo.
- Bug "5906,9999" relatado pela Débora: **não foi possível reproduzir o valor exato** consultando o Supabase real — todas as colunas de quantidade envolvidas (`estoque_itens.quantidade/quantidade_reservada`, `vw_necessidade_compra.*`) são `numeric`, sem drift de ponto flutuante visível nos dados atuais, e nenhum valor com `9999` foi encontrado em nenhuma tabela relevante. Aplicado arredondamento defensivo de 3 casas decimais na exibição como mitigação preventiva, mas a causa raiz não foi confirmada — **se o problema reaparecer, pedir para a Débora indicar o produto/tela exatos no momento em que acontecer.**

## Análise de ecossistema

- **Depende de**: `pedidos_compra`, `empresas`, `vw_necessidade_compra`, RPCs `criar_pedido_compra_lote`/`criar_pedido_compra_de_necessidade`.
- **Afeta**: só o sistema Compras (`compras-lucenera-3o23t98ee`). Nenhum outro sistema lê `pedidos_compra.empresa_id` ou `pedidos_compra.numero` hoje (não confirmado exaustivamente — checar antes de assumir se outro sistema passar a consumir esses campos).
- **Não afeta** os 51 pedidos legado já importados (`PC-LEGADO-NNNN`) — a sequence nova só entra em jogo para pedidos novos criados pelo app a partir de agora.

## Critérios de aceite

- Um novo pedido criado (individual ou em lote) sem informar número recebe um número sequencial simples (1768, 1769, ...), sem prefixo.
- Um novo pedido não pode ser confirmado sem selecionar a Empresa.
- A tela "Por Produto" não mostra mais Fornecedor, Comprometida, Necessidade, Empresa que comprou, Status do pedido, Entrega prevista; mostra "Estoque" no lugar de "Física".
- Selecionar "todos" com um filtro de marca aplicado seleciona todos os itens daquele filtro que compartilham fornecedor; itens de fornecedor diferente ficam de fora com aviso.

## Testes obrigatórios

Verificação manual no navegador (não foi possível homologar com a Débora nesta sessão): criar um pedido em lote com 2+ itens da mesma marca usando "selecionar todos", escolher uma Empresa, confirmar, e verificar que o número gerado é sequencial (1768+) e que `pedidos_compra.empresa_id` foi gravado corretamente.

## Realizado

**2026-08-04 — implementação direta no Skip (sem agente implementador dedicado, sessão de correção ao vivo):**

- Banco: migrations `20260804_071_numeracao_pedido_compra_legado` e `20260804_072_pedido_compra_empresa_explicita` redigidas e aplicadas no Supabase real, incluindo a correção do bug de overload de função descoberto durante a aplicação.
- Frontend: `NecessidadeCompra.tsx`, `ModalPedidoLote.tsx`, `ModalRegistrarCompra.tsx`, `services/pedido-compra.ts` publicados no Skip (projeto "Necessidade de Compra", `projectId 40326`), versão `0.0.50` (`1b027fc`), QA completo (lint/build/testes) passou antes da publicação.
- Não testado no navegador com dados reais desta sessão — ver "Testes obrigatórios".

## Pendências

- [ ] Homologação manual da Débora no navegador (fluxo completo: filtrar por marca, selecionar todos, fechar pedido em lote, conferir número e empresa gravados).
- [ ] Causa raiz do bug "5906,9999" não confirmada — só mitigação defensiva aplicada. Reabrir se reaparecer, com o produto/tela específicos.
- [ ] Ideia discutida mas não implementada (fora do escopo desta SPEC): gerar automaticamente o PDF do pedido (formato de referência confirmado nos PDFs do Connect) e enviar por e-mail ao fornecedor ao finalizar o pedido, usando o e-mail cadastrado do fornecedor e um template de e-mail (referência: `01-Documento/02 - Descritivo Connect/PDF/Solicitação de Orçamento - Pedido N°_.eml`). Filippo ainda estava avaliando custo/viabilidade (e-mail vs. WhatsApp) — precisa de SPEC própria se for adiante.
