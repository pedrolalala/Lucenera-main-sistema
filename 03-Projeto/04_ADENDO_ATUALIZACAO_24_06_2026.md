# Adendo de Atualizacao - 24/06/2026

Este adendo atualiza a pasta `Versao Final - Lucenera` com a decisao mais recente sobre portfolio, separacao entre Hub/Central e TI, organizacao local dos sistemas, Ubiqua, Logistica e conferencia do banco.

## 1. Leitura ativa do portfolio

Para o mapeamento atual, os sistemas prioritarios sao:

| # | Sistema | Fonte/local | Observacao |
|---|---|---|---|
| 1 | Central Lucenera / Hub | `Sistema/central-lucenera-dashboard-1c9ba/` e `https://github.com/pedrolalala/central-lucenera` | Porta de entrada e cards autorizados. Consome catalogo, permissoes e saude do Sistema de TI. Versao local `0.0.14`. |
| 2 | Sistema de TI | Sem diretorio local exclusivo nesta rodada | Sistema separado do Hub. Administra catalogo, permissoes, saude, integracoes e auditoria. Pode reaproveitar telas/componentes da Central como base tecnica temporaria. |
| 3 | Administracao Bancaria | `Sistema/retorno-bancario-bradesco-5392a/` e `https://github.com/pedrolalala/administra--o-bancaria` | Base bancaria/financeira. Versao local `0.0.40`. |
| 4 | Gestao Financeira Lucenera | `Sistema/gestao-financeira-clone-544cb (1)/` e `https://github.com/pedrolalala/Lucenera---Gest-o-Financeira` | Sistema financeiro/orcamentario atual. Versao local `0.0.178`. |
| 5 | CRM Lucenera | `Sistema/lucenera-crm-3bd29 (1)/` e `https://github.com/pedrolalala/lucenera-crm` | Projetos, relacionamento, historico e acompanhamento. Versao local `0.0.252`. |
| 6 | Dashboard RH | `Sistema/dashboard-rh-lucenera-5fe9c/` e `https://github.com/pedrolalala/dashboard-rh-lucenera-6g2endmv7` | RH e pessoas. Versao local `0.0.189`. |
| 7 | Logistica Lucenera | `Sistema/lucenera-logistica-atual-backup/` e `Sistema/lucenera-logistics-b7cd1/` | Manter os dois durante a migracao: o backup e o sistema real usado hoje; `b7cd1` e o destino conectado ao banco. |
| 8 | PowerPoint Lucenera | `https://github.com/pedrolalala/Lucenera-Power-point` | Artefato/repositorio de apoio, sem pasta local dentro de `Sistema/`. |
| 9 | Cadastro Lucenera | `Sistema/cadastro-lucenera-b86fe/` | Cadastro existe e pode ser recriado/evoluido; tendencia de uso maior pelo CRM. Versao local `0.0.27`. |

Ubiqua continua ativo operacionalmente em `Sistema/catalogo-pecas-ubiqua-e6fa0/` (`0.0.76`), mas fica em baixa prioridade de mapeamento ate definicao melhor de abrangencia. Nao devem ser tomadas decisoes estruturais sobre Ubiqua nesta rodada.

## 2. Organizacao da pasta `Sistema/`

A pasta `Sistema/` deve conter apenas 9 diretorios de sistemas locais. Essa organizacao local nao e uma contagem 1:1 do portfolio conceitual, porque o Sistema de TI ainda nao tem diretorio dedicado e o PowerPoint esta em repositorio externo.

1. `cadastro-lucenera-b86fe`
2. `catalogo-pecas-ubiqua-e6fa0`
3. `central-lucenera-dashboard-1c9ba`
4. `dashboard-rh-lucenera-5fe9c`
5. `gestao-financeira-clone-544cb (1)`
6. `lucenera-crm-3bd29 (1)`
7. `lucenera-logistica-atual-backup`
8. `lucenera-logistics-b7cd1`
9. `retorno-bancario-bradesco-5392a`

Todos os demais prototipos e versoes antigas devem ficar em `Sistemas antigos/`.

## 3. Atualizacao sobre Logistica

O fluxo de Logistica deve preservar temporariamente os dois sistemas:

- `lucenera-logistica-atual-backup`: sistema real usado hoje na operacao.
- `lucenera-logistics-b7cd1`: sistema atual conectado ao banco e destino da consolidacao.

Mudanca importante: documentos, fotos, comprovantes e demais anexos da Logistica nao devem usar Supabase Storage. O destino correto e OneDrive via API. O banco deve guardar somente metadados, `driveItemId`, URL controlada, tipo, tamanho, hash quando disponivel e vinculo com projeto, separacao ou entrega.

## 4. Conferencia do banco em 24/06/2026

Foi feita uma conferencia via REST usando a anon key local. A API respondeu, mas as principais tabelas retornaram contagem `0` e `systems` retornou lista vazia. Isso e consistente com restricao por RLS/policies para anon/auth sem perfil administrativo, nao com ausencia real de dados.

Por isso, os numeros administrativos da fotografia de 23/06/2026 continuam sendo a ultima base confiavel para contagens: 107 relacoes expostas, 20 RPCs, 1.443 projetos, 3.848 contatos, 4.392 produtos, 1.757 itens de estoque, 7 orcamentos, 17 itens de orcamento, 411 vendas, 9 boletos e 14.963 transacoes.

O catalogo `systems` deve evoluir a partir da tabela existente. A Central agora possui migration para atualizar o catalogo-alvo com Administracao Bancaria, Cadastro, CRM, Gestao Financeira, Sistema de Entregas, RH, Ubiqua e PowerPoint. A propria Central conta como sistema do portfolio, mas nao precisa aparecer como card dentro dela mesma. O Sistema de TI deve administrar esse catalogo e publicar os contratos que o Hub consome.

## 5. Decisoes que alteram os documentos anteriores

- Onde os documentos falam em "8 sistemas atuais", a leitura correta passa a ser "9 sistemas prioritarios de mapeamento" quando Hub/Central e Sistema de TI forem contados separadamente, com Ubiqua ativo em baixa prioridade.
- Onde os documentos juntavam Hub e TI, a leitura correta e: Hub/Central e porta de entrada; Sistema de TI e sistema administrativo separado.
- Onde os documentos falam em `systems` com 7 registros, manter isso como fotografia administrativa de 23/06; o catalogo-alvo da Central passa a ter 8 cards externos.
- Onde os documentos falam em comprovantes ou fotos no Supabase Storage para Logistica, substituir por OneDrive via API.
- O Hub/Central local agora esta na versao `0.0.14`; RH local esta na versao `0.0.189`.
