---
titulo: "SPEC-289 — Compras (Reunião 52, 12/11): entrada parcial por peça e pedido já pago na entrada da NF"
status: implementada em código (12/11) — migration 343 redigida e ensaiada em ROLLBACK, NÃO aplicada; Compras não publicado, sem commit
data_ultima_modificacao: 2026-11-12
sistemas_envolvidos:
  - Compras / Necessidade de Compra (04-Sistemas/compras-lucenera-3o23t98ee) — Entrada de Nota Fiscal
  - Banco (registrar_entrada_nota_compra, pagamentos_antecipados, antecipacoes_para_entrada)
  - Contas a Pagar (só leitura: antecipação já espelhada pela migration 342)
---

# SPEC-289 — Reunião 52 (Débora): entrada parcial e pedido pago

**Origem:** Reunião 52 (Débora, 12/11/2026, "Necessidade de compra") — `02-Reunioes/52. Lucenera (Debora) - 12.11.2026_ Necessidade de compra/Reunião.01` — e dois pedidos abertos por ela na Central Lucenera em 12/11 (17:24 e 17:37).
Relacionadas: SPEC-209 E (entrada por item), SPEC-213, SPEC-215 (antecipação), SPEC-218 (cancelar entrada), SPEC-220, SPEC-231 B2, SPEC-286, SPEC-288 A.

## Checklist de Ação

**A. Entrada parcial: dizer o que chegou e o que não chegou**
- [x] A1. Na Entrada de Nota Fiscal (por pedido), "Chegou agora" começa **zerado** (hoje começa com o que falta: `EntradaNotaFiscal.tsx:362`) e cada peça ganha uma caixa "Chegou"; atalhos **"Marcar todas"** e **"Nenhuma"**
- [x] A2. Ao marcar a caixa, a quantidade vira o que falta (editável para menos); ao desmarcar, volta a 0
- [x] A3. Registrar sem nenhuma peça marcada é bloqueado; registrar com todas marcadas segue como hoje (pedido Concluído)
- [x] A4. Peça não marcada **permanece no pedido** (mesmo número, ex.: 1930) com "Falta" intacto; pedido fica "Concluído parcialmente" até zerar; a 2ª entrada traz só o que sobrou
- [x] A5. Valor total da nota, ST, parcelas e vínculo com cliente (entrega futura → reserva) calculam só pelo que chegou — conferir que peça em 0 não gera linha de vínculo nem aviso de "chegou sem vínculo"
- [x] A6. Teste da RPC `registrar_entrada_nota_compra` com peça em 0, em ROLLBACK (pedido de 3 peças, 2 entram, 1 volta; 2ª entrada fecha)

**B. Pedido já pago na entrada da NF**
- [x] B1. Na seção "Financeiro da nota" nova opção **"Este pedido já foi pago (antecipado / à vista)"**, com valor (sugere o total do pedido), data do pagamento e observação
- [x] B2. Ao registrar, a RPC cria o pagamento antecipado ligado ao pedido (`pagamentos_antecipados.pedido_compra_id`, fornecedor e empresa do pedido) e o vincula à nota na mesma transação — **vale direto**, sem aprovação prévia da Lana
- [x] B3. Pago integralmente → nota sem parcela, sem financeiro novo (regra C4 da SPEC-215); pago em parte → parcelas só do restante
- [x] B4. Se o pedido já tem antecipação ligada (lançada pela Lana), a tela mostra e usa essa, sem pedir de novo (evita duplicar)
- [x] B5. Lana enxerga o lançamento em Antecipações e em Consultar Duplicatas (migration 342, **já aplicada**) e pode cancelá-lo enquanto sem uso; cancelar a entrada (SPEC-218) devolve o saldo
- [x] B6. Permissão: Débora executa a opção sem ter acesso à Adm. Bancária (RPC `SECURITY DEFINER`, trava por papel `IS DISTINCT FROM`, `REVOKE ... FROM PUBLIC, anon`)

**Entrega**
- [x] Migration 343 (`20261112_343_spec289_entrada_parcial_pedido_pago`) redigida + `rollback.sql` + `dry_run.sql` ensaiado em ROLLBACK — **aplicar só com autorização (pendente)**
- [x] `vite build` do Compras (ok); [ ] publicar (só depois da migration aplicada); [ ] revisor antes do commit
- [x] CHANGELOG; [ ] contexto do sistema (`AI_DB_CONTEXT.md`) e snapshot do banco (só depois de aplicar a migration)
- [ ] Marcar os dois pedidos da Débora na Central após o teste dela

### Passos manuais do usuário
- [ ] **Autorizar e aplicar a migration 343** (`python scripts/aplicar_migration_sql.py 20261112_343_spec289_entrada_parcial_pedido_pago`) antes de publicar o Compras: a tela nova envia `p_pagamento`, que a RPC atual (7 parâmetros) não conhece
- [ ] Publicar o Compras (wrangler) e rodar o agente `revisor` antes de qualquer commit
- [ ] Débora testar: pedido de 3 peças com 2 entrando; depois o mesmo pedido com a 3ª
- [ ] Débora testar o pedido 1985 (R$ 2.204,31, hoje `aguardando_aprovar`) marcado como pago
- [ ] Lana conferir que o pagamento aparece em Antecipações e na consulta

## Realizado (12/11/2026)

- **Compras** (`04-Sistemas/compras-lucenera-3o23t98ee`, só local): `src/pages/EntradaNotaFiscal.tsx` (Chegou começa em 0, caixa "Chegou" por peça, "Marcar todas"/"Nenhuma", mensagem "Marque o que chegou", seção de registro só abre com peça marcada, estado/valores do pagamento "já foi pago" nas contas de parcelas), `src/components/compra/FinanceiroNotaEntrada.tsx` (opção "Este pedido já foi pago (antecipado / à vista)": valor sugerido = total do pedido, data não futura, observação; some quando o pedido já tem antecipação ligada com saldo e mostra aviso para marcar a existente), `src/services/notas-fiscais-compra.ts` (`pagamento` -> `p_pagamento`). `tsc --noEmit`, `oxlint` e `vite build` ok; `oxfmt --check` já acusava os 3 arquivos antes (não reformatados).
- **Banco**: migration `supabase/db/migrations/20261112_343_spec289_entrada_parcial_pedido_pago/` (`up.sql`, `rollback.sql`, `dry_run.sql`). A entrada parcial (A) não exigiu mudança de RPC: `registrar_entrada_pedido_compra` já ignora peça em 0 e recusa nenhuma peça. B: `registrar_entrada_nota_compra` + `p_pagamento` (DROP da assinatura de 7 parâmetros + CREATE de 8, `SECURITY DEFINER`, `REVOKE ALL FROM PUBLIC, anon`, `GRANT` a `authenticated`). Achado: o espelho da 342 falhava para quem não tem `financeiro` (Débora) — `financeiro_espelhar_pagamento_antecipado` agora roda sem o usuário da sessão (corrigido na 343).
- **Ensaio em ROLLBACK (SP, como a Débora: Compras sim, financeiro não)**: nenhuma peça marcada recusada; pedido de 3 peças com 2 entrando -> `parcialmente_recebido`, a 3ª com `qtd_recebida` 0 e fora de `nota_fiscal_compra_itens`; 2ª entrada fecha (`recebido`); pago integral R$ 200 -> antecipação (fornecedor/empresa do pedido, `criado_por` = Débora) + vínculo 200, 0 parcela, título no financeiro novo (sem falha na ponte); pago parcial 80 de 200 -> 1 parcela de 120; antecipação já ligada (150) reaproveitada, sem duplicar; pago 200 com nota de 100 -> aplica 100 e sobra saldo; pago sem data recusado; pago + parcelas que não fecham recusado e sem antecipação gravada; `anon` recusado (permission denied); usuário sem papel recusado; 1 só overload; `rollback.sql` ensaiado (volta à assinatura de 7 parâmetros).
- **Correções do revisor (12/11)**:
  1. **Teto no "já pago"**: a RPC recusa `p_pagamento.valor` maior que `pedidos_compra.valor_total` + R$ 0,01 ("O valor pago (X) nao pode passar do valor total do pedido (Y)"; sem total no pedido, não trava). A tela limita o campo ao total do pedido (clamp ao digitar), mostra "Máximo: total do pedido" / mensagem de erro e bloqueia o registro acima do teto. Valor maior que o da nota continua deixando o excedente de saldo.
  2. **Dupla cobrança na 2ª nota**: com antecipação ligada ao pedido e com saldo, a RPC aplica `min(saldo, restante da nota)` sozinha, mesmo sem `p_pagamento` (e não cria outra antecipação se vier `p_pagamento`). A antecipação que a tela mandar em `p_antecipacoes` (valor editado ou 0 = desmarcada) a RPC respeita e não mexe. Na tela, a antecipação ligada ao pedido vem **pré-marcada** com `min(saldo, restante)`, segue o valor da nota enquanto a pessoa não mexer, e é editável/desmarcável (desmarcada vai com valor 0).
  3. **Cancelamentos no dry-run**: ver ensaio abaixo.
- **Ensaio em ROLLBACK (dry_run.sql, bloco 2)**: teto (300,02 em pedido de 300 recusado, sem antecipação gravada; 300,01 passa); 1ª nota paga com 300,01 cobre só 100 e sobra saldo; 2ª nota sem `p_pagamento` e sem parcelas aplica 100 sozinha (0 parcela, total aplicado 200); 3ª nota com antecipação zerada pela tela respeita (0 aplicado, 1 parcela); valor editado (40 de 150) respeitado; Débora cria antecipação "já pago" (espelho com título); Lana tenta cancelar com a antecipação vinculada à nota: recusado ("já vinculado a nota fiscal", regra da SPEC-215); Débora cancela a entrada pela `cancelar_entrada_nota_compra` (SPEC-218): `antecipacao_devolvida` 200, pedido volta a `aguardando_aprovar`, 0 vínculos, antecipação ativa com o título do espelho, sem falha nova em `financeiro_ponte_falhas`; Lana (financeiro) cancela a antecipação agora sem uso: antecipação e título cancelados, baixa estornada (1 estorno), 0 falhas em `financeiro_ponte_falhas`. `rollback.sql` ensaiado de novo.
- **Auditoria do espelho (achado, não implementado)**: como o espelho roda com `request.jwt.claims` esvaziado, os eventos de `financeiro_eventos` do título/parcela/baixas do espelho gravam `usuario_id` NULL (9 eventos no ensaio, 0 com usuário). O usuário real continua em `pagamentos_antecipados.criado_por`, `cancelado_por`, `pagamento_antecipado_vinculos.criado_por` e na auditoria da própria tabela de origem. **Alternativa proposta (aguarda confirmação)**: em vez de esvaziar o JWT, o espelho liga uma flag local à transação (`set_config('app.financeiro_ponte', 'on', true)`) e `financeiro_exige` passa a liberar quando a flag estiver ligada; assim `auth.uid()` continua preenchido nos eventos e em `criado_por` do título. Custo: mexer em `financeiro_exige` (função da 303, base de toda a porta única do financeiro), e só funções internas `SECURITY DEFINER` podem ligar a flag.

## Contexto verificado (12/11/2026, somente leitura)

- Entrada por peça já existe (coluna "Chegou agora", status "Concluído parcialmente"); o defeito é o **padrão cheio** + falta de um jeito claro de dizer "não veio". Na reunião: 3 peças, 2 entraram, 1 não; a entrada foi cancelada e o material ficou "livre no estoque".
- Pedido 1985 (`1985 CONNECT`): `aguardando_aprovar`, 1 item, R$ 2.204,31; o fornecedor dele **não tem** pagamento antecipado lançado — por isso não há o que vincular hoje.
- Pedido 1930 (`1930 CONNECT`) citado na reunião: `aguardando_aprovar`.
- Hoje só a Lana lança antecipação (Adm. Bancária); a Débora não tem esse acesso.

## Decisões (recomendações do usuário, 12/11/2026)

1. "Pedido pago" é marcado **na entrada da NF**, com valor e data; gera antecipação ligada ao pedido e vínculo automático (um registro só).
2. **Sem confirmação da Lana:** vale direto; ela vê o lançamento e pode cancelar se sem uso.
3. Peças começam **desmarcadas**; botões "Marcar todas" / "Nenhuma".
4. A migration 342 (espelho da antecipação no Contas a Pagar) já está aplicada (CHANGELOG 12/11) e é aproveitada aqui; a SPEC-288 ainda lista o item A como "não aplicada" — atualizar o texto dela.

## Riscos / atenção

- **Duplicidade:** Connect continua lançando a nota; antecipação nossa + duplicata do Connect podem duplicar no fluxo (pendência 1 da SPEC-215 — confirmar com Lana/Carol).
- Defaults zerados mudam o hábito de quem só confere a nota: mensagem clara na tela ("Marque o que chegou").
- Pedido `aguardando_aprovar` (como 1985/1930): confirmar se a entrada exige pedido aprovado e como a tela se comporta antes disso.

## Rollback

Telas: reverter os commits de Compras. Banco: `rollback.sql` da migration devolve a RPC anterior (antecipações criadas pela opção continuam e podem ser canceladas se sem uso).
