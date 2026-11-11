# Cópias de Edge Functions arquivadas em 10/11/2026

Estas pastas existiam dentro dos repositórios dos sistemas (`supabase/functions/`) e **diferiam** do repositório central. Foram retiradas dos sistemas (risco: publicar de um sistema com cópia velha reverte a função no ar) e guardadas aqui, uma por versão distinta (hash do conteúdo, fins de linha normalizados), para que nenhum código se perca. A fonte oficial é só `supabase/functions/`.

Se uma função no ar tiver comportamento que só existe numa destas versões, compare com o central e traga a diferença para lá antes de publicar.

| Função | Versão (hash) | Igual ao central? | Estava em |
|---|---|---|---|
| _shared | c10806cab2 | não (arquivada em `_shared/c10806cab2`) | retorno-bancario-bradesco-5392a |
| chat-agent | 389c0ed3c5 | não (arquivada em `chat-agent/389c0ed3c5`) | gestao-financeira-clone-544cb (1) |
| chat-agent | fac34c7212 | não (arquivada em `chat-agent/fac34c7212`) | cadastro-lucenera-b86fe, catalogo-pecas-ubiqua-e6fa0, central-lucenera-dashboard-1c9ba, compras-lucenera-3o23t98ee, dashboard-lucenera-b02z85wa3, dashboard-rh-lucenera-5fe9c, lucenera-crm-3bd29 (1), lucenera-logistics-b7cd1 |
| chat-consulta | 3595d8a845 | não (arquivada em `chat-consulta/3595d8a845`) | cadastro-lucenera-b86fe, catalogo-pecas-ubiqua-e6fa0, central-lucenera-dashboard-1c9ba, compras-lucenera-3o23t98ee, dashboard-lucenera-b02z85wa3, dashboard-rh-lucenera-5fe9c, lucenera-crm-3bd29 (1), lucenera-logistics-b7cd1 |
| chat-consulta | ed4ecf70d8 | não (arquivada em `chat-consulta/ed4ecf70d8`) | gestao-financeira-clone-544cb (1) |
| enviar-confirmacao-email | 8dae4bef62 | não (arquivada em `enviar-confirmacao-email/8dae4bef62`) | cadastro-lucenera-b86fe, catalogo-pecas-ubiqua-e6fa0, central-lucenera-dashboard-1c9ba, compras-lucenera-3o23t98ee, dashboard-lucenera-b02z85wa3, dashboard-rh-lucenera-5fe9c, lucenera-crm-3bd29 (1), lucenera-logistics-b7cd1 |
| enviar-confirmacao-email | fb8829c154 | não (arquivada em `enviar-confirmacao-email/fb8829c154`) | gestao-financeira-clone-544cb (1) |
| exchange-cross-system-code | 2be3b27921 | não (arquivada em `exchange-cross-system-code/2be3b27921`) | central-lucenera-dashboard-1c9ba, compras-lucenera-3o23t98ee, dashboard-lucenera-b02z85wa3 |
| exchange-cross-system-code | 57544ad7bd | não (arquivada em `exchange-cross-system-code/57544ad7bd`) | gestao-financeira-clone-544cb (1) |
| generate-cross-system-code | 2e74bcb202 | não (arquivada em `generate-cross-system-code/2e74bcb202`) | central-lucenera-dashboard-1c9ba, compras-lucenera-3o23t98ee, dashboard-lucenera-b02z85wa3 |
| generate-cross-system-code | 36ed7e0923 | não (arquivada em `generate-cross-system-code/36ed7e0923`) | gestao-financeira-clone-544cb (1) |
| generate-report | 184e48edf8 | não (arquivada em `generate-report/184e48edf8`) | gestao-financeira-clone-544cb (1) |
| generate-report | 8b8b528933 | não (arquivada em `generate-report/8b8b528933`) | catalogo-pecas-ubiqua-e6fa0, compras-lucenera-3o23t98ee |
| generate-report | a29f1911a6 | não (arquivada em `generate-report/a29f1911a6`) | cadastro-lucenera-b86fe, central-lucenera-dashboard-1c9ba, dashboard-lucenera-b02z85wa3, dashboard-rh-lucenera-5fe9c, lucenera-crm-3bd29 (1), lucenera-logistics-b7cd1 |
| parse-budget-pdf | 5a56210bcc | não (arquivada em `parse-budget-pdf/5a56210bcc`) | cadastro-lucenera-b86fe, catalogo-pecas-ubiqua-e6fa0, central-lucenera-dashboard-1c9ba, compras-lucenera-3o23t98ee, dashboard-lucenera-b02z85wa3, dashboard-rh-lucenera-5fe9c, lucenera-crm-3bd29 (1), lucenera-logistics-b7cd1 |
| parse-budget-pdf | a74599a257 | não (arquivada em `parse-budget-pdf/a74599a257`) | gestao-financeira-clone-544cb (1) |
| process-billing-automation | 6e67cf6d51 | não (arquivada em `process-billing-automation/6e67cf6d51`) | central-lucenera-dashboard-1c9ba, compras-lucenera-3o23t98ee, dashboard-lucenera-b02z85wa3 |
| process-billing-automation | bbac19813d | não (arquivada em `process-billing-automation/bbac19813d`) | gestao-financeira-clone-544cb (1) |
| process-budget-pdf | 5d75f52ab4 | não (arquivada em `process-budget-pdf/5d75f52ab4`) | lucenera-logistics-b7cd1 |
| process-budget-pdf | 9238b0439c | não (arquivada em `process-budget-pdf/9238b0439c`) | cadastro-lucenera-b86fe, central-lucenera-dashboard-1c9ba, compras-lucenera-3o23t98ee, dashboard-lucenera-b02z85wa3, dashboard-rh-lucenera-5fe9c, lucenera-crm-3bd29 (1) |
| process-budget-pdf | 9d99f8e385 | não (arquivada em `process-budget-pdf/9d99f8e385`) | catalogo-pecas-ubiqua-e6fa0 |
| process-budget-pdf | aab4f392b5 | não (arquivada em `process-budget-pdf/aab4f392b5`) | gestao-financeira-clone-544cb (1) |
| process-remittance | 180a4d35a7 | não (arquivada em `process-remittance/180a4d35a7`) | gestao-financeira-clone-544cb (1) |
| process-remittance | f55d2f7810 | não (arquivada em `process-remittance/f55d2f7810`) | cadastro-lucenera-b86fe, central-lucenera-dashboard-1c9ba, compras-lucenera-3o23t98ee, dashboard-lucenera-b02z85wa3, dashboard-rh-lucenera-5fe9c, lucenera-crm-3bd29 (1), lucenera-logistics-b7cd1, retorno-bancario-bradesco-5392a |
| salvar-projeto | 440199b16c | não (arquivada em `salvar-projeto/440199b16c`) | lucenera-crm-3bd29 (1) |
| salvar-projeto | 6bb8724283 | não (arquivada em `salvar-projeto/6bb8724283`) | cadastro-lucenera-b86fe, central-lucenera-dashboard-1c9ba, compras-lucenera-3o23t98ee, dashboard-lucenera-b02z85wa3, dashboard-rh-lucenera-5fe9c, lucenera-logistics-b7cd1 |
| salvar-projeto | 8beec1decb | não (arquivada em `salvar-projeto/8beec1decb`) | gestao-financeira-clone-544cb (1) |
| salvar-projeto | a06cffdcee | não (arquivada em `salvar-projeto/a06cffdcee`) | catalogo-pecas-ubiqua-e6fa0 |
| sync-teams | 21b3bcb160 | não (arquivada em `sync-teams/21b3bcb160`) | gestao-financeira-clone-544cb (1) |
| sync-teams | 2dbeab6206 | não (arquivada em `sync-teams/2dbeab6206`) | cadastro-lucenera-b86fe, catalogo-pecas-ubiqua-e6fa0, central-lucenera-dashboard-1c9ba, compras-lucenera-3o23t98ee, dashboard-lucenera-b02z85wa3, dashboard-rh-lucenera-5fe9c, lucenera-crm-3bd29 (1) |
| sync-teams | 9192aea15e | não (arquivada em `sync-teams/9192aea15e`) | lucenera-logistics-b7cd1 |
| update-project | 047dcf9be9 | não (arquivada em `update-project/047dcf9be9`) | catalogo-pecas-ubiqua-e6fa0 |
| update-project | 41b3ac74cc | não (arquivada em `update-project/41b3ac74cc`) | cadastro-lucenera-b86fe, central-lucenera-dashboard-1c9ba, compras-lucenera-3o23t98ee, dashboard-lucenera-b02z85wa3, dashboard-rh-lucenera-5fe9c, lucenera-crm-3bd29 (1), lucenera-logistics-b7cd1 |
| update-project | 6cd17eb903 | não (arquivada em `update-project/6cd17eb903`) | gestao-financeira-clone-544cb (1) |
| welcome-email | 94d965b890 | não (arquivada em `welcome-email/94d965b890`) | cadastro-lucenera-b86fe, catalogo-pecas-ubiqua-e6fa0, central-lucenera-dashboard-1c9ba, compras-lucenera-3o23t98ee, dashboard-lucenera-b02z85wa3, dashboard-rh-lucenera-5fe9c, gestao-financeira-clone-544cb (1), lucenera-crm-3bd29 (1), lucenera-logistics-b7cd1 |
