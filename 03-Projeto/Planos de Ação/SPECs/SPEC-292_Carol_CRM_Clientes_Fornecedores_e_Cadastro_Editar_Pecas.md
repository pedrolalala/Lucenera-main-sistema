---
titulo: "SPEC-292 — Carol: CRM só Clientes/Fornecedores (ver) + criar/editar peças no Cadastro"
status: banco APLICADO 12/11/2026 (migration 346); front do CRM buildado, deploy pendente
---
# SPEC-292
Pedido (12/11/2026): a Carol (`assistente_administrativa`) precisa (1) acessar o CRM vendo só Clientes e Fornecedores; (2) criar/editar peças no Cadastro (a SPEC-269 deixou só consulta).

- Migration `20261112_346_spec292_carol_crm_clientes_fornecedores_cadastro_editar` (up/rollback): módulo `crm.clientes`; papel ganha `crm` clientes+fornecedores `visualizar` e `cadastro` criar+editar; Acesso a Sistemas `crm` para a Carol. RLS não muda (contatos só grava com `crm` editar, que ela não tem; produtos já aceita `cadastro` criar/editar).
- CRM: `use-auth` devolve `modulosPermitidos`; `Layout` mostra só as abas liberadas (generaliza a SPEC-266).
- Efeito colateral: com `cadastro` editar ela também consegue editar fornecedor pelas políticas de `contatos` (spec069), como já ocorre com a Débora.
- Pendente: deploy do CRM (`wrangler pages deploy dist --project-name crm-lucenera`, build com VITE_* de SP), teste real da Carol, CHANGELOG.
