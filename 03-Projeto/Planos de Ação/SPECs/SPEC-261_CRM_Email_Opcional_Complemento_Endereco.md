---
titulo: "SPEC-261 — CRM: e-mail do cliente opcional + complemento nos 3 endereços da ficha"
status: implementada_sem_deploy
---

# SPEC-261 — CRM: e-mail opcional e complemento de endereço

> Pedidos da Central de Solicitações (06/11/2026): (1) "Cadastro projeto — tirar como obrigatório o e-mail do cliente" (ao criar a pasta só chega o nome da cliente); (2) "Criar campo para complemento de endereço" em faturamento, entrega e cobrança, e separar visualmente os endereços.

## Achado
- E-mail obrigatório era só do schema do formulário (`clientSchema`, decisão da SPEC-061). `contatos.email` já aceita nulo; Edge Functions não exigem.
- O complemento já existia no **formulário de novo cliente** (3 blocos, SPEC-061) e no banco (`complemento`, `complemento_entrega`, `complemento_cobranca`), mas **não na ficha/edição do cliente** (`ContatoDetail`), onde os endereços vinham num grid corrido.

## Feito (CRM)
- [x] `ClientFormFields`: e-mail opcional (vazio vira nulo; se preenchido, continua validado); asterisco removido.
- [x] `ContatoDetail` (cliente): campos Complemento nos 3 endereços; títulos de seção "Endereço principal (faturamento)", "Endereço de entrega", "Endereço de cobrança".
- [x] Sem mudança de banco. Typecheck e build ok.

## Pendente / observação
- [ ] Publicar o CRM (deploy) e confirmar em tela.
- O Cadastro (`cadastro-lucenera`, `ClienteModal`) tem número de entrega mas não complemento; Logística/pedido de compra já leem `complemento_entrega`. Fora deste escopo — decidir se quer o complemento lá também.

## Rollback
Reverter o commit do CRM.
