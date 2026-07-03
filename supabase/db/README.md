# Banco de Dados — organização central

Esta pasta separa o banco em três camadas de entendimento:

1. `current/`: fotografia consolidada do banco atual.
2. `domains/`: explicação lógica por área do negócio.
3. `migrations/`: alterações centrais planejadas/aplicadas, organizadas por grupo.

## Princípios

- Não usar as migrations dispersas dos sistemas como fonte de verdade.
- Não duplicar a mesma regra de banco em vários projetos.
- Registrar decisões de relacionamento de forma legível para cliente, equipe e IA.
- Separar o que é dado cadastral do que é dado operacional.
- Preferir alterações idempotentes em SQL quando possível.

## Ordem mental do banco

1. Usuários, empresas e permissões.
2. Cadastros base: clientes, fornecedores, produtos, funcionários e sistemas.
3. Orçamentos e projetos.
4. Itens aprovados de projeto.
5. Financeiro: parcelas, boletos, notas fiscais, remessa e retorno.
6. Estoque/compras: movimentações operacionais ligadas a clientes/projetos.
7. CRM configurável.
8. Logística, RH e Hub/TI.

