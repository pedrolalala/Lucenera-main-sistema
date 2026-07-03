# Adendo de Atualização — 23/06/2026

Este adendo registra a revisão feita após a atualização dos sistemas e chegada da planilha `Vendas 01012025 a 23062026.xlsx`.

Nota complementar: a leitura operacional mais recente esta no `04_ADENDO_ATUALIZACAO_24_06_2026.md`.

Nota de 24/06/2026: Hub/Central e Sistema de TI passam a ser tratados como sistemas diferentes. O portfolio prioritario de mapeamento foi atualizado para 9 sistemas prioritarios: Central/Hub, Sistema de TI, Administracao Bancaria, Gestao Financeira, CRM, RH, Logistica, PowerPoint e Cadastro. Ubiqua continua ativo, mas em baixa prioridade ate definicao melhor de abrangencia.

## 1. Sistemas analisados nesta atualização

Foram analisados somente os sistemas com última modificação em 23/06/2026:

| Sistema | Versão atual | Achado principal |
|---|---:|---|
| Hub / Central | `0.0.10` em 23/06; `0.0.14` local em 24/06 | já lê os cartões pela tabela `systems`; deve permanecer separado do Sistema de TI |
| Cadastro | `0.0.27` | produtos usam `produtos`, `marcas`, `categorias_produto`, fornecedores e `estoque_itens` |
| CRM | `0.0.252` | possui usuários/configurações, mas ainda sem fluxo configurável versionado |
| Orçamentos | `0.0.178` | já grava orçamento e itens, busca projeto por código e possui aprovação/sincronização |
| Financeiro/Retorno | `0.0.40` | já possui duplicatas, boletos, remessa, retorno e notas, mas ainda com partes simuladas |

RH e Logística não foram reanalisados em profundidade porque não tiveram modificação hoje. Ubiqua continua ativo, mas fica em baixa prioridade no mapeamento por enquanto. PowerPoint e Cadastro entram como sistemas de menor impacto operacional.

## 2. Supabase atual

O banco foi conferido diretamente pelo `.env`, sem usar migrations antigas como fonte de verdade. A introspecção retornou `standard public schema 14.4`.

Fotografia principal:

- 107 relações expostas entre tabelas e views;
- 20 funções/RPCs;
- 1.443 projetos;
- 3.848 contatos;
- 4.392 produtos ativos;
- 1.757 registros de estoque;
- 7 orçamentos;
- 17 itens de orçamento;
- 0 itens em `projeto_itens`;
- 411 registros em `vendas`;
- 9 boletos;
- 14.963 transações;
- 7 sistemas cadastrados em `systems` na fotografia administrativa de 23/06.

Observação de 24/06: consulta via anon key retornou zero linhas para as principais tabelas, indicando bloqueio por RLS/policies. A fotografia administrativa acima continua sendo a base confiável para contagens até nova consulta com perfil administrativo.

## 3. Planilha nova de vendas

Arquivo analisado: `Vendas 01012025 a 23062026.xlsx`.

Resumo:

- 22.171 linhas totais;
- 3.795 vendas únicas;
- período de 06/01/2025 a 22/06/2026;
- 16.621 linhas `VENDAS`;
- 2.042 vendas únicas dentro de `VENDAS`;
- 330 códigos de projeto extraídos das linhas `VENDAS`;
- 1.508 produtos únicos nas linhas `VENDAS`.

Regra mantida:

- `VENDAS` gera histórico aprovado de itens do projeto;
- demais grupos CFOP geram movimentos de estoque.

## 4. Cruzamento com o Supabase

Projetos:

- 213 códigos tiveram match exato com `projetos.codigo`;
- 66 códigos tiveram match por normalização de dígitos;
- 51 códigos ainda não encontraram projeto;
- 2.688 linhas `VENDAS` não possuem código de projeto no início de `NomeCliente`.

Produtos:

- 1.287 códigos de produto bateram em `produtos.codigo_legado`;
- nenhum código bateu diretamente em `produtos.codigo_produto`;
- 221 códigos de produto ainda não encontraram produto;
- 16.161 das 16.621 linhas `VENDAS` conciliam por `codigo_legado`.

Vendas e itens:

- `projeto_itens` está vazio;
- nenhum dos 2.042 `CodVenda` de `VENDAS` foi encontrado em `vendas.cod_venda`;
- a importação histórica deve criar ou reconciliar `vendas`, itens da venda e `projeto_itens`.

## 5. Impacto no plano

As decisões principais continuam válidas, mas com ajustes:

- o Hub deve evoluir a partir da tabela `systems` existente;
- Cadastro deve preservar `produtos.codigo_legado` como chave de conciliação com Connect;
- Orçamentos precisa endurecer a aprovação para ser idempotente por origem, versão e item;
- Estoque/Compras deve tratar 5.550 linhas não `VENDAS` como movimentos operacionais;
- Financeiro deve considerar que o histórico aprovado ainda não está reconciliado com `vendas.cod_venda`;
- o relatório de banco deve priorizar a carga histórica de `VENDAS` para preencher `projeto_itens`.
