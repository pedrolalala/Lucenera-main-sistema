---
titulo: "SPEC-290 — Compras: vincular o pagamento já existente (Connect/antecipação) na entrada da NF, sem duplicar o Contas a Pagar"
status: pendente (SPEC aprovada nas recomendações; implementação não iniciada)
data_ultima_modificacao: 2026-11-12
sistemas_envolvidos:
  - Compras / Necessidade de Compra (04-Sistemas/compras-lucenera-3o23t98ee) — Entrada de Nota Fiscal e Pedidos
  - Banco (financeiro_ponte_pedido, registrar_entrada_nota_compra, pagamentos_antecipados, vw_financeiro_duplicatas)
  - Contas a Pagar (retorno-bancario-bradesco-5392a) — Consultar Duplicatas (selo/rastreio)
  - Importação do Connect (scripts/importar_contas_pagar_receber.py)
---

# SPEC-290 — Pedido já pago: vincular o pagamento que já existe

**Origem:** Reunião 52 (Débora) + Reunião 51 (Vinicius, Carol e Lana) + pedido do usuário em 12/11/2026 ("tenha o rastreio para não abrir um contas a pagar duplicado", pedido 1985).
Relacionadas: SPEC-215 (antecipação), SPEC-218 (cancelar entrada), SPEC-288 A (espelho da antecipação), SPEC-289 (opção "já pago").

## Checklist de Ação

**A. Detectar o pagamento existente (Compras)**
- [ ] A1. RPC `pagamentos_existentes_para_entrada(pedido)` (SECURITY DEFINER, devolve só duplicata, valor, data, origem, saldo): parcelas **pagas** de `pagar` do mesmo fornecedor e empresa, valor próximo (±R$ 1,00 ou até o total do pedido), data de pagamento a partir de (emissão do pedido − 3 dias), de origem `legado_connect` ou `adiantamento`, **sem vínculo** (ou com saldo) com outro pedido/nota
- [ ] A2. Entrada de NF mostra o quadro "Pagamento já feito para este fornecedor" (ex.: *Duplicata 8405 — R$ 2.204,30 — paga em 04/11/2026 — Connect*), pré-selecionando quando só há uma correspondência com valor igual ao do pedido
- [ ] A3. Pedido com condição "Antecipado" sem vínculo mostra aviso "Pago — falta vincular o pagamento" (lista de Pedidos e Entrada)

**B. Vínculo sem dinheiro novo**
- [ ] B1. Tabela `pagamento_existente_vinculos` (parcela_id do financeiro novo, pedido_compra_id, nota_id, valor_aplicado, criado_por/em, cancelado_em) com RLS, `REVOKE ALL FROM anon`, escrita só por RPC
- [ ] B2. `registrar_entrada_nota_compra` aceita `p_vinculos_pagamento` (lista parcela + valor): grava o vínculo, **não cria título, parcela nem baixa**; nota coberta integralmente fica sem parcelas, cobertura parcial gera parcelas só do restante (mesma regra B3 da SPEC-289)
- [ ] B3. Valida: valor aplicado ≤ saldo da parcela paga; mesma parcela não pode cobrir duas notas além do saldo; fornecedor/empresa coerentes; pedido não cancelado
- [ ] B4. `financeiro_ponte_pedido` e `vw_contas_pagar_pedidos_compra` contam o valor vinculado como "consumido" (abate a previsão do pedido), sem somar em dobro com antecipação nativa
- [ ] B5. `cancelar_entrada_nota_compra` (SPEC-218) cancela o vínculo; a duplicata da Connect permanece intacta

**C. Rastreio visível**
- [ ] C1. Consultar Duplicatas (Pagar): a duplicata vinculada mostra "Pago antecipado — Pedido 1985 / NF 11221" (coluna/selo, filtro por pedido)
- [ ] C2. Pedido (Compras): selo "Pago antecipado (dup. 8405)"
- [ ] C3. Só lê a duplicata; **nada é gravado na duplicata da Connect**

**D. Trava na opção "Este pedido já foi pago" (SPEC-289)**
- [ ] D1. Se a RPC de detecção achar pagamento equivalente, a opção **bloqueia** e manda vincular o existente
- [ ] D2. Só quem tem acesso a financeiro (Lana) pode forçar um lançamento novo, com observação obrigatória
- [ ] D3. Mesma trava na RPC (não só na tela)

**E. Importação do Connect**
- [ ] E1. Ao importar duplicata paga de despesa, se existir antecipação nativa equivalente (mesmo fornecedor, empresa, valor e data ±3 dias, sem vínculo), vincular/marcar como espelhada em vez de criar segunda saída (caso Omega Light R$ 2.608,52)
- [ ] E2. Confirmar com o ensaio do importador antes de qualquer alteração; sem decisão, fica só o aviso na conferência de integridade

**Entrega**
- [ ] Migration NNN + `rollback.sql` + dry-run em ROLLBACK (como Débora sem financeiro, Lana com financeiro e `anon`); aplicar **só com autorização**
- [ ] `vite build`, revisor antes do commit, publicar Compras e Contas a Pagar (wrangler), CHANGELOG, `AI_DB_CONTEXT.md`, snapshot

### Passos manuais do usuário
- [ ] Avisar a Débora para **não dar entrada** nos pedidos 1985, 1925 e 1733 até esta SPEC sair
- [ ] Débora testar o 1985 (vincular duplicata 8405) e conferir que nenhum Contas a Pagar novo aparece
- [ ] Lana conferir o rastreio em Consultar Duplicatas
- [ ] Confirmar com Lana/Carol o comportamento da importação (item E)

## Estado verificado (12/11/2026, somente leitura)

- **Pedido 1985** (`1985 CONNECT`, R$ 2.204,31, condição "Antecipado", `aguardando_aprovar`): a duplicata **8405** da Connect (RIBAS DAVILA, MANOELLA, R$ 2.204,30, emissão 03/11, **paga em 04/11**, `legado_connect`, sem `num_nota`) já é o pagamento. A NF 11221 gerou uma parcela de R$ 2.204,30 (vencimento 09/12) e foi cancelada pela Débora às 17:38 com o motivo "entrada de NF gerou o financeiro, sendo que foi pago de forma integral antecipadamente".
- Só 3 pedidos "Antecipado" abertos (1925, 1733, 1985); os três têm duplicata Connect paga de valor igual (8284 em 14/10; 7554 em 28/07; 8405 em 04/11) e **nenhum** tem antecipação nativa.
- A regra D3 da SPEC-215 (duplicata da Connect com mesmo `num_nota` remove a parcela da nota) **não protege** este caso: a 8405 não tem `num_nota`.
- A opção "Este pedido já foi pago" (SPEC-289, publicada em 12/11) criaria um **segundo pagamento** no 1985. A Débora não a usou (nenhuma antecipação ligada ao pedido; verificado).

## Decisões (recomendações do usuário, 12/11/2026)

1. SPEC própria (290), separada da 289.
2. Opção "já pago" **bloqueia** quando há equivalente; só a Lana força.
3. Aviso à Débora para não dar entrada nos três pedidos até sair.
4. O vínculo só marca cobertura; **nada é gravado na duplicata da Connect**.

## Riscos / atenção

- Casamento por valor ±R$ 1,00 pode sugerir pagamento errado: sempre confirmação humana; pré-seleciona só com correspondência única.
- Fornecedor do pedido x contato da duplicata: usar `contato_id` do financeiro (já casam nos 3 pedidos); fornecedor trocado na entrada (SPEC-215 A2) precisa recalcular a lista.
- Importador: mudança em script de produção; ensaiar em ROLLBACK.

## Rollback

Telas: reverter commits de Compras e Contas a Pagar. Banco: `rollback.sql` devolve a RPC e a view anteriores e apaga a tabela de vínculos (vínculos criados deixam de abater a previsão).
