# Convenções de nomes

## Migrations centrais

Formato:

```text
YYYYMMDD_NNN_nome_do_grupo/
  README.md
  001_area.sql
  002_area.sql
```

Exemplo:

```text
20260625_002_spec001_orcamento_financeiro/
```

## Chaves e rastreio

- Usar `orcamento_id` para rastrear o fluxo orçamento aprovado -> financeiro.
- Evitar `venda_id` neste fluxo.
- Usar `projeto_id` onde a tabela realmente pertence à execução do projeto.
- Não duplicar chaves no financeiro quando elas puderem ser derivadas de `orcamento_id`.

## Configurações

Regras que o cliente pode mudar devem estar em tabelas de configuração e ser editáveis pela UI. Evite regras de negócios hardcoded nos casos que possam haver muitas alterações no decorrer dos meses, para evitar manutenção constante e complexidade de entendimento do código.

Exemplos de configurações:

- etapas do CRM;
- sub-status;
- checklists;
- bloqueios;
- SLA;
- responsáveis;
- permissões de acesso.

