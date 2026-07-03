# Inventario de Repositorios e Sistemas

Este inventario conecta o repositorio central aos repositorios proprios dos sistemas.

## Repositorio central

| Area | Valor |
| --- | --- |
| Nome local | `Lucenera - ADAPTA PASS` |
| Papel | Memoria compartilhada, documentos, reunioes, specs, contexto Supabase e inventario |
| Fonte de verdade de banco | `supabase/` |
| Fonte de verdade de specs | `03-Projeto/Planos de Ação/SPECs/` |

## Sistemas

| Prioridade | Sistema | Repo GitHub | Pasta no repo central | Pasta local principal | Observacao |
| --- | --- | --- | --- | --- | --- |
| 1 | Central Lucenera / Hub | `https://github.com/pedrolalala/central-lucenera` | `04-Sistemas/central-lucenera-dashboard-1c9ba/` | `Sistema/central-lucenera-dashboard-1c9ba/` | `.git` local encontrado |
| 2 | Administracao Bancaria / Financeiro | `https://github.com/pedrolalala/administra--o-bancaria` | `04-Sistemas/retorno-bancario-bradesco-5392a/` | `Sistema/retorno-bancario-bradesco-5392a/` | `.git` local encontrado |
| 3 | Orcamentos | `https://github.com/pedrolalala/Lucenera---Gest-o-Financeira` | `04-Sistemas/gestao-financeira-clone-544cb (1)/` | `Sistema/gestao-financeira-clone-544cb (1)/` | Repo ainda tem nome historico de gestao financeira |
| 4 | Lucenera CRM | `https://github.com/pedrolalala/lucenera-crm` | `04-Sistemas/lucenera-crm-3bd29 (1)/` | `Sistema/lucenera-crm-3bd29 (1)/` | `.git` local encontrado; estava 1 commit ahead em 2026-06-26 |
| 5 | Dashboard RH Lucenera | `https://github.com/pedrolalala/dashboard-rh-lucenera-6g2endmv7` | `04-Sistemas/dashboard-rh-lucenera-5fe9c/` | `Sistema/dashboard-rh-lucenera-5fe9c/` | `.git` local encontrado |
| 6 | Logistica Lucenera | `https://github.com/pedrolalala/lucenera-logistics-bz5s7xehm` | `04-Sistemas/lucenera-logistica-atual-backup/` e `04-Sistemas/lucenera-logistics-b7cd1/` | `Sistema/lucenera-logistica-atual-backup/` e `Sistema/lucenera-logistics-b7cd1/` | Migrar do backup atual para o novo app |
| 7 | Lucenera PowerPoint | `https://github.com/pedrolalala/Lucenera-Power-point` | Sem pasta em `04-Sistemas/` | Sem pasta local em `Sistema/` | Artefato de apoio |
| 8 | Cadastro Lucenera | `https://github.com/pedrolalala/cadastro-lucenera` | `04-Sistemas/cadastro-lucenera-b86fe/` | `Sistema/cadastro-lucenera-b86fe/` | Sistema de apoio cadastral |
| 9 | Ubiqua / Catalogo de Pecas | Nao mapeado | `04-Sistemas/catalogo-pecas-ubiqua-e6fa0/` | `Sistema/catalogo-pecas-ubiqua-e6fa0/` | Ativo, baixa prioridade de mapeamento |

## Espelho no repo central

A pasta `Lucenera - ADAPTA PASS/04-Sistemas/` espelha a lista acima para manter a estrutura completa junto da memoria central.

Antes de alterar codigo, confirmar se a pasta espelhada corresponde ao repositorio proprio do sistema. Quando houver `.git` dentro do sistema, tratar aquele sistema como repositorio separado.

## Status de submodules

Devem ser registrados como submodules em `04-Sistemas/`:

- `central-lucenera-dashboard-1c9ba`
- `retorno-bancario-bradesco-5392a`
- `gestao-financeira-clone-544cb (1)`
- `lucenera-crm-3bd29 (1)`
- `dashboard-rh-lucenera-5fe9c`
- `lucenera-logistics-b7cd1`
- `cadastro-lucenera-b86fe`

Pendentes:

- `catalogo-pecas-ubiqua-e6fa0`: falta repo GitHub mapeado.
- `lucenera-logistica-atual-backup`: deve permanecer como backup ate a migracao para `lucenera-logistics-b7cd1`.
- `Lucenera-Power-point`: repo de apoio, sem pasta local obrigatoria em `04-Sistemas/`.

Para registrar os submodules quando o repo central estiver inicializado, usar:

```bash
./scripts/submodules-register.sh
```

Para clonar todos os submodules ja registrados:

```bash
./scripts/submodules-clone-all.sh
```

## Regra de atualizacao

- Mudanca de codigo: atualizar o repositorio proprio do sistema e registrar a mudanca no repo central.
- Mudanca de banco: atualizar `supabase/` no repo central e o contexto local do sistema afetado.
- Mudanca de decisao/processo: atualizar docs centrais e `CHANGELOG.md`.
- Mudanca de repo, pasta ou prioridade: atualizar este inventario e `04-Sistemas/00 - Sumario Sistemas.md`.
