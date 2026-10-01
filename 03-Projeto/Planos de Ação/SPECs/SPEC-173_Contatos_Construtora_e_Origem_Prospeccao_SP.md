---
titulo: "SPEC-173 — Contatos: tipo 'construtora' e origem 'PROSPECCAO_SAO_PAULO'"
status: "APLICADA (01/10/2026)"
data_ultima_modificacao: 2026-10-01
sistemas_envolvidos:
  - Supabase central — contatos, contato_tipos, contato_origens
---

## Pedido (usuário, 01/10/2026)
Permitir a origem `PROSPECCAO_SAO_PAULO` em `contato_origens` e o tipo `construtora` em `contato_tipos` e em
`contatos.tipo`, preservando todos os valores atuais.

## Realizado
Migration `supabase/db/migrations/20261001_173_contatos_construtora_prospeccao_sp`:
- enum `contato_tipo` (coluna `contatos.tipo`): `+ construtora`;
- `contato_tipos_tipo_check`: `+ construtora` (necessário: o trigger `handle_contato_tipo` copia `contatos.tipo`
  para `contato_tipos`);
- `contato_origens_origem_check`: `+ PROSPECCAO_SAO_PAULO`.
Dry-run com ROLLBACK, aplicada, e teste de cadastro (contato construtora + origem nova) com ROLLBACK: ok.

## Observações
- `contato_origens.codigo_legado` é NOT NULL e único por origem: toda linha com `PROSPECCAO_SAO_PAULO` precisa de um
  código próprio (ex.: nº da linha na planilha de prospecção).
- Pré-existente, fora do escopo: o enum já aceitava `eletricista`, mas `contato_tipos_tipo_check` não — cadastrar um
  contato com `tipo='eletricista'` falha no trigger.
- As telas (CRM etc.) ainda não oferecem "Construtora" nas listas de tipo; isso é mudança de frontend separada.
