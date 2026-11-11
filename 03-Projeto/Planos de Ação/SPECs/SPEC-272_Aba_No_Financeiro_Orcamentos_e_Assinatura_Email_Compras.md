---
titulo: "SPEC-272 — Aba 'No financeiro' nos Orçamentos (Murillo) e assinatura LUCENERA no e-mail ao fornecedor (Debora)"
status: migration 324 APLICADA em SP (10/11); código commitado local; deploy pendente
data_ultima_modificacao: 2026-11-10
sistemas_envolvidos:
  - Orçamentos (gestao-financeira-clone-544cb): src/pages/Budgets.tsx
  - Compras (compras-lucenera-3o23t98ee): email-pedido-fornecedor.ts, compras-config.ts, entrega-pedido.ts, EnviarFornecedorDialog.tsx
  - Banco: compras_config.assinatura_email (migration 324)
---

# SPEC-272

## A. Aba "No financeiro" (Murillo, 09/11 17:52)
Pedido: ver o que está parado no financeiro, entre aprovação de equipe e aprovados.
- Já existia a aba "Revisão Financeira Pendente", mas só aparece para admin/gerente (é a aba de aprovar).
- **Novo:** quem não é admin/gerente ganha a aba "No financeiro (N)": só consulta, lista os orçamentos com status
  `Aprovação Financeira`. O que cada pessoa vê continua limitado pelo RLS (equipe só vê a própria, SPEC-200).
- Sem banco. Dado hoje: 12 orçamentos em Aprovação Financeira, 1 em Aprovação da Equipe.

## B. Assinatura do e-mail ao fornecedor (Debora, 09/11 14:17)
Pedido: configurar a assinatura "LUCENERA" no e-mail automático (SPEC-214, .eml).
- **Padrão novo (sem configurar nada):** o e-mail termina com `Atenciosamente, <remetente>, LUCENERA` (mais a empresa do pedido,
  quando for outra).
- **Configurável:** `compras_config.assinatura_email` (migration 324). Se preenchida, substitui a linha LUCENERA/empresa
  (continua com o nome do remetente). Só admin altera (política `compras_config_update`).
- **Pendente do usuário:** o texto oficial da assinatura (endereço, telefone, site) e a logo, se quiser. O e-mail é texto puro (.eml),
  então logo/imagem não entra sem mudar o formato.
- **Ordem de publicação:** aplicar a 324 ANTES do deploy do Compras (a leitura da config passa a pedir a coluna nova e, sem ela,
  cairia o WhatsApp do e-mail).

## Checklist
- [x] A: código e compilação
- [x] B: código, migration 324 (up/rollback) escrita
- [ ] Aplicar 322 (SPEC-271) e 323 em SP
- [ ] Build e deploy do Compras e dos Orçamentos (wrangler), commit nos sistemas, ponteiros no central
- [ ] Murillo e Debora testarem; usuário passar o texto da assinatura
