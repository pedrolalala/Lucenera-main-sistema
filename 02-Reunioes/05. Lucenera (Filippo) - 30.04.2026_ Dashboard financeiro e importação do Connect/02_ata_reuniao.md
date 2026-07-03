# Ata de reunião

- Reunião: 05. Lucenera (Filippo) - 30.04.2026: Dashboard financeiro e importação do Connect
- Data: 2026-04-30
- Horário: 11:07
- Duração aproximada: 51:22
- Link tl;dv: https://tldv.io/app/meetings/69f3623f9ec3c90013df386c
- Fonte: transcrição e metadados retornados pela API do tl;dv.

## Assunto principal

Reunião técnica sobre migração/importação de dados do Connect e planilhas para Supabase, estruturação de financeiro, RH, estoque, produtos e dashboards executivos para Felipe.

## Participantes identificados

- Kimberly Prestes
- Filippo Giorgi
- Pedro / LAGHI Live

## Áreas envolvidas

- Financeiro
- RH
- Estoque/Produtos
- Projetos
- TI/Automação

## Ferramentas e sistemas citados

- Connect/Conecta
- Supabase
- Views
- SQL
- Google Drive
- VS Code
- Claude/Opus
- MCP Service
- Stitch
- Skip
- n8n
- Vercel
- Python

## Contexto

- A reunião tratou da dependência do sistema Connect e de restrições de acesso/exportação via Sérgio.
- Vinícius estava enviando planilhas administrativas para Pedro/Kimberly.
- Havia urgência em entregar dashboard financeiro para Felipe.

## Dados e regras discutidas

- Planilhas de estoque/produtos, fornecedores, contas a pagar/receber, RH e projetos precisam ser importadas/tratadas.
- Dados históricos devem ser importados como histórico; dados futuros devem vir de regras dos sistemas internos.
- Informações de RH/folha/bonificações não devem duplicar em importações do Connect se já forem geradas pelo sistema de RH.
- Projetos antigos podem continuar recebendo pagamentos anos depois, dificultando conciliação.

## Arquitetura proposta

- Criar tabelas normalizadas e views para dashboards.
- Usar categorias/tabelas auxiliares para evitar repetição.
- Conectar contas a receber/pagar, projetos, parcelas, produtos e estoque.
- Usar MCP Service/VS Code/Claude para ajudar em SQL e importações recorrentes.

## Outras oportunidades

- Apresentar Stitch/Skip para prototipar interfaces.
- Migrar gerador Python de PowerPoint/fichas técnicas para Vercel/cloud.

## Decisões

- Separar importação histórica de regras operacionais futuras.
- Montar dashboards a partir de views no Supabase.
- Criar pasta no Google Drive com planilhas necessárias para Kimberly analisar/importar.
- Mandar planilha completa de produtos/estoque e planilha de projetos com códigos.

## Pendências / próximos passos

- Pedro/LAGHI criar pasta no Google Drive com planilhas de produtos, estoque, projetos e contas a pagar/receber.
- Enviar planilha completa de produtos/estoque.
- Enviar planilha de projetos importada com códigos para relacionar arquitetos/projetos.
- Definir tabelas necessárias para entradas e saídas financeiras.
