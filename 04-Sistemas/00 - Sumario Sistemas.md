# Sumário dos Sistemas Lucenera

Criado em 10/11/2026 (resposta à análise do Filippo: o `AGENTS.md` citava este arquivo e ele não existia). Fonte: tabela `systems` do banco de São Paulo (nome, slug e link) + pastas e repositórios de `04-Sistemas/`. Se um sistema novo nascer, atualizar aqui.

**Banco oficial:** Supabase São Paulo (`bgtfrcbipuxnsexbppsh`), desde 14/10/2026. Ohio é só reserva.
**Deploy:** `wrangler pages deploy` com as variáveis de São Paulo no build. Migrations e Edge Functions oficiais: só no repositório central (`supabase/`).

| Sistema (nome no Hub) | Slug | Pasta em `04-Sistemas/` | Repositório | Endereço |
|---|---|---|---|---|
| Hub / Central | `hub` | `central-lucenera-dashboard-1c9ba` | central-lucenera | central-lucenera.pages.dev |
| Orçamentos Lucenera | `orcamentos` | `gestao-financeira-clone-544cb (1)` | Lucenera---Gest-o-Financeira | financeiro-lucenera.pages.dev |
| Venda Parcial | `separacao-parcial` | `separacao-parcial` | separacao-parcial | separacao-lucenera.pages.dev |
| Vendas | `vendas` | `vendas-lucenera` | Vendas-Lucenera | vendas-lucenera.pages.dev |
| CRM Lucenera | `crm` | `lucenera-crm-3bd29 (1)` | lucenera-crm | crm-lucenera.pages.dev |
| Consultar Produtos (Cadastro) | `cadastro` | `cadastro-lucenera-b86fe` | cadastro-lucenera | cadastro-lucenera.pages.dev |
| Necessidade de Compra (Compras) | `necessidade-de-compra` | `compras-lucenera-3o23t98ee` | compras-lucenera-3o23t98ee | compras-lucenera.pages.dev |
| Movimentação de Peças | `movimentacao-pecas` | `movimentacao-pecas` | movimentacao-pecas | movimentacao-lucenera.pages.dev |
| Sistema de Entregas (Logística) | `logistica` | `lucenera-logistics-b7cd1` | lucenera-logistics-bz5s7xehm | logistica-lucenera.pages.dev |
| Administração Bancária | `financeiro` | `retorno-bancario-bradesco-5392a` | administra--o-bancaria | adm-bancaria-lucenera.pages.dev |
| Contas a Pagar | `contas-pagar` | `retorno-bancario-bradesco-5392a` (mesmo código, modo no build) | administra--o-bancaria | contas-pagar-lucenera.pages.dev |
| Contas a Receber | `contas-receber` | `retorno-bancario-bradesco-5392a` (mesmo código, modo no build) | administra--o-bancaria | contas-receber-lucenera.pages.dev |
| Dashboard Financeiro | `dashboard-financeiro` | `dashboard-lucenera-b02z85wa3` | dashboard-lucenera-b02z85wa3 | dashboard-lucenera.pages.dev |
| RH Lucenera | `rh` | `dashboard-rh-lucenera-5fe9c` | dashboard-rh-lucenera-6g2endmv7 | rh-lucenera.pages.dev |
| Central de Solicitações | `solicitacoes` | `central-de-solicitacoes` | central-de-solicitacoes | solicitacoes-lucenera.pages.dev |
| Controle de Produção | `controle-producao` | `controle-de-producao` | Controle-de-producao | producao-lucenera.pages.dev |
| Controle de Garantia | `controle-garantia` | `controle-de-garantia` | controle-de-garantia | garantia-lucenera.pages.dev |
| Showroom Lucenera | `showroom` | `showroom-qtq8er2dk` | showroom-qtq8er2dk | showroom-lucenera.pages.dev |
| Memória Lucenera | `memoria` | `memoria-lucenera` | memoria-lucenera | memoria-lucenera.pages.dev |
| Fichas Técnicas (Catálogo Ubiqua) | `ubiqua` | `catalogo-pecas-ubiqua-e6fa0` | cat-logo-pe-as-ubiqua- | sistema.apilucenera.site |

## Observações
- Contas a Pagar, Contas a Receber e Administração Bancária são **o mesmo código** publicado em 3 endereços; muda só o modo no build.
- `lucenera-power-point` e `script python power point` são o gerador de apresentações e não aparecem no Hub.
- Nomes de pasta com código aleatório ou "(1)" vêm da origem no Skip. Não renomear sem combinar: o nome da pasta é referência de deploy.
- Acesso por sistema: tabela `systems` + papéis do Hub (SPEC-069) + Acesso a Sistemas (SPEC-183).
