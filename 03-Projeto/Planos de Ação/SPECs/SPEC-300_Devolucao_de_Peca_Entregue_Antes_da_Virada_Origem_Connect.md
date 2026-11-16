---
titulo: "SPEC-300 — Devolução de peça entregue antes da virada (venda herdada da Connect sem o item no sistema)"
status: em andamento
data_ultima_modificacao: 2026-11-13
sistemas_envolvidos:
  - Orçamentos (gestao-financeira-clone)
  - Banco (Supabase) — orcamento_itens, replace_orcamento_itens, aprovar_orcamento_financeiro
---

# SPEC-300 — Devolução de peça entregue antes da virada

> **STATUS (13/11/2026): código e migration prontos e ensaiados; migration 357 APLICADA em SP em 13/11; falta publicar Orçamentos.**
>
> Limite conhecido: o título de crédito da devolução não é compensado automaticamente contra o título da venda CNX-2451 (não há item de origem); a conta fica como crédito de devolução do projeto.
>
> Origem: 13/11/2026, Giovanna Nori tentou a troca/devolução da **Roberta Demeterco (projeto 23.316)** — orçamento Connect **#8367** (PDF "AP OR_0008367 - DEV. 19.10.26", total −R$ 1.343,89). O XML importa certo (6 linhas), mas a busca "Buscar item do projeto" não acha nada.

## Causa (verificada no banco real, somente leitura)

- As 5 peças (10009 EKPF12, 12133, 11150, 11248, 12582) saíram da venda **CNX-2451** (orçamento CNX-3437), informação do usuário.
- A venda herdada está no sistema com **24 itens, nenhum dessas 5 peças**: a herança só trouxe reserva e entrega futura; o que já tinha sido entregue antes da virada ficou de fora.
- A devolução exige `projeto_item_origem_id` (zod em `BudgetFormPage.tsx`, `validarItensDevolucao`, e `aprovar_orcamento_financeiro` que dá `RAISE` para item sem origem). Sem item de origem não há como lançar.
- O XML não tem problema.

## Decisão do usuário (13/11/2026)

**Opção 1:** liberar a devolução de peça sem item de origem no sistema, só para venda herdada da Connect, com motivo obrigatório. A venda não é alterada. A opção 2 (lançar as peças como entregues na CNX-2451) foi descartada.

## Regras

- R1. Só vale quando o projeto da devolução tem venda `origem = 'connect'` na empresa da devolução. A linha guarda **o número da venda Connect** (ex.: CNX-2451) escolhido entre as vendas Connect do projeto.
- R2. Motivo obrigatório (texto livre), gravado na linha.
- R3. A linha é de produto do cadastro (`produto_id` obrigatório), quantidade > 0 e preço > 0.
- R4. Linha marcada fica **sem** `projeto_item_origem_id`. Nenhuma venda, `projeto_itens` ou saldo é alterado.
- R5. Aprovação financeira: crédito/parcelas da devolução saem normalmente; para a linha marcada **não** se chama `registrar_devolucao_projeto_item*`.
- R6. **Estoque (padrão conservador, a confirmar):** a linha marcada **não movimenta estoque** automaticamente (regra SPEC-244: Connect é herança e não mexe em quantidade). O retorno físico da peça é ajustado por Movimentação de Peças. Se o usuário quiser entrada automática no estoque geral, vira passo extra desta SPEC.
- R7. Linha normal (com origem) continua exatamente como hoje, com todas as travas.
- R8. A tela marca a linha ("Origem Connect — CNX-2451") e o PDF/Financeiro mostram o motivo.

## Checklist de Ação

- [x] A1 — Migration 357: colunas `orcamento_itens.origem_connect_venda text` e `origem_connect_motivo text` (+ GRANT/RLS já herdados da tabela).
- [x] A2 — Migration 357: `replace_orcamento_itens` grava e preserva as duas colunas (partir da versão da migration 332).
- [x] A3 — Migration 357: `aprovar_orcamento_financeiro` (partir da versão viva, migration 350) aceita item sem origem quando `origem_connect_venda` está preenchida e não chama o estoque para ela.
- [x] B1 — Orçamentos: banner "Peça entregue antes da virada (Connect)" na aba de itens (venda Connect + motivo, aplica às linhas sem origem — ex.: as do XML importado). Feito no código local; não commitado nem publicado.
- [x] B2 — Orçamentos: zod, `validarItensDevolucao` e salvar/carregar itens passam as duas colunas.
- [x] B3 — Marcar a linha na tela e no cartão do item.
- [x] C1 — Ensaio com ROLLBACK (13/11): up, salvar 6 linhas, aprovar (parcela −1.343,89, estoque igual), 3 casos barrados, rollback.sql.
- [x] C2 — CHANGELOG.md e `AI_DB_CONTEXT.md` do sistema.

### Passos manuais do usuário

- [ ] Confirmar R6 (estoque não movimenta automaticamente).
- [x] Autorizar aplicar a migration 357 no Supabase real depois do ensaio (autorizada e aplicada em 13/11).
- [ ] Autorizar publicar Orçamentos.

## Plano de rollback

Migration com `rollback.sql`: devolve as 3 funções às versões anteriores (332 e 350) e remove as 2 colunas (só se vazias; senão mantém).

## Documentos a atualizar

CHANGELOG.md; `04-Sistemas/gestao-financeira-clone-544cb (1)/supabase/AI_DB_CONTEXT.md`; `supabase/db/current/` depois de aplicada.
