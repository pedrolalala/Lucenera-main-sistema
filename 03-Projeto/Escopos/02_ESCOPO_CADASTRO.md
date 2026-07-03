# Escopo — Sistema de Cadastro

## Versão atual

Pacote analisado: `cadastro-lucenera-b86fe`  
Versão declarada após atualização: `0.0.27`

O sistema possui telas de clientes, projetos e peças/produtos. A versão atual usa o banco em partes relevantes: produtos são lidos de `produtos`, com marca em `marcas`, categoria em `categorias_produto`, fornecedor em `contatos` e leitura de saldo por `estoque_itens`. Também há busca por projetos em `vw_projetos_dashboard`.

Ainda existem dados simulados residuais no store local e sobreposição com CRM e Estoque/Compras, especialmente porque Cadastro consegue exibir/editar projetos e consultar dados operacionais de estoque.

## Objetivo da evolução

Ser a interface principal de manutenção dos **dados cadastrais**:

- clientes e demais contatos;
- produtos;
- fornecedores;
- marcas;
- categorias;
- unidades e dados fiscais;
- aliases e códigos externos.

O sistema não será responsável por saldo, reservas, movimentos, cotações, pedidos ou recebimentos.

## SPEC-CAD-01 — Cadastro canônico de contatos

**Achado:** clientes, arquitetos, fornecedores e outros participantes aparecem em telas e estruturas diferentes.

**Evolução:** trabalhar sobre uma entidade de contato única, com múltiplos papéis.

**Justificativa:** a mesma pessoa ou empresa pode exercer mais de um papel e não deve ser duplicada. Além disso, "empresa" tem dois sentidos no ecossistema: `empresas` representa empresas do grupo Lucenera, enquanto a empresa/PJ de um cliente, fornecedor ou arquiteto deve continuar sendo representada como um registro em `contatos`.

**Relação com o banco:** `contatos`, `contato_tipos`, `contatos.empresa_id -> contatos.id` para empresa/PJ vinculada a uma pessoa, `empresas` para empresas do grupo Lucenera e identificadores externos.

**Ação a ser realizada:** ajustar formulários e filtros para manter a entidade canônica e seus papéis, removendo a dependência de uma única coluna fixa de tipo. Não alterar `contatos.empresa_id` para apontar para `empresas.id`; esse campo deve continuar representando a empresa/PJ relacionada ao contato.

**Critério de aceite:** um contato pode ser cliente e fornecedor sem duas fichas desconectadas.

## SPEC-CAD-02 — Qualidade e conciliação dos clientes

**Achado:** existem registros sem documento ou e-mail e documentos repetidos.

**Evolução:** oferecer validação, indicação de possível duplicidade e fila de revisão.

**Justificativa:** impedir novas duplicidades é mais seguro do que tentar corrigi-las depois em todos os sistemas.

**Relação com o banco:** documentos normalizados, aliases, origem, código do Connect e fila de reconciliação.

**Ação a ser realizada:** validar documento, telefone e e-mail; pesquisar candidatos antes de criar; permitir confirmação assistida de duplicidade.

**Critério de aceite:** o usuário recebe alerta antes de cadastrar um documento ou código já existente.

## SPEC-CAD-03 — Cadastro mestre de produtos

**Achado:** produtos possuem códigos e campos legados, enquanto estoque e orçamento também dependem deles.

**Evolução:** manter uma ficha cadastral única com código interno, código legado do Connect, referência, descrição, marca, categoria, NCM, unidade, dados fiscais e fornecedor principal.

**Justificativa:** Orçamentos e Estoque/Compras devem consultar o mesmo produto.

**Relação com o banco:** `produtos`, `marcas`, `categorias_produto`, fornecedor e identificadores externos. Para a importação de vendas, `CodProduto` deve ser conciliado com `produtos.codigo_legado`.

**Ação a ser realizada:** separar campos cadastrais de campos operacionais e criar validação de código/SKU/código legado. Preservar `codigo_legado` como chave de conciliação com o Connect.

**Critério de aceite:** o produto alterado no Cadastro aparece atualizado em Orçamentos e Estoque/Compras.

## SPEC-CAD-04 — Cadastro mestre de fornecedores

**Achado:** fornecedores são necessários em cadastro, produto e compras.

**Evolução:** permitir criar e manter razão social, nome, documento, endereço, contatos, categoria e condições cadastrais.

**Justificativa:** Estoque/Compras deve reutilizar a mesma ficha e acrescentar somente informações operacionais.

**Relação com o banco:** contato com papel fornecedor, categorias e relações produto-fornecedor.

**Ação a ser realizada:** criar tela específica de fornecedores baseada no cadastro canônico.

**Critério de aceite:** o fornecedor criado no Cadastro fica imediatamente disponível para cotação e pedido.

## SPEC-CAD-05 — Separação entre cadastro e operação

**Achado:** campos de saldo e compra podem acabar sendo editados em mais de uma interface.

**Evolução:** Cadastro exibe informações operacionais apenas como resumo de leitura.

**Justificativa:** evita que uma edição cadastral altere saldos ou compromissos.

**Relação com o banco:** leitura de views/resumos de estoque e compras, sem propriedade de escrita.

**Ação a ser realizada:** retirar dos formulários de cadastro qualquer atualização direta de saldo, reserva, custo de pedido ou prazo operacional.

**Critério de aceite:** nenhuma ação do Cadastro cria movimento de estoque ou pedido de compra.

## SPEC-CAD-06 — Projetos fora da responsabilidade de cadastro

**Achado:** Cadastro e CRM possuem telas de projetos, e a tela de Cadastro lê `vw_projetos_dashboard`.

**Evolução:** manter no Cadastro somente pesquisa ou atalho para o projeto; criação e edição ficam no CRM.

**Justificativa:** o projeto é o eixo do processo e deve ter uma única interface principal.

**Relação com o banco:** leitura de `projetos` e abertura do CRM pelo identificador.

**Ação a ser realizada:** remover edição concorrente e redirecionar ações de projeto para o CRM, mantendo no Cadastro apenas consulta/atalho quando necessário.

**Critério de aceite:** alterações do projeto são executadas apenas no CRM.

## SPEC-CAD-07 — Importação e origem

**Achado:** dados cadastrais ainda serão reconciliados com Connect e planilhas.

**Evolução:** mostrar código e origem dos registros importados sem permitir sobrescrita silenciosa.

**Justificativa:** a origem é necessária para conferência durante o corte.

**Relação com o banco:** identificadores externos e lotes de importação.

**Ação a ser realizada:** exibir origem, última importação e divergências relevantes na ficha cadastral.

**Critério de aceite:** a equipe identifica se o registro nasceu no Connect, planilha ou novo sistema.

## SPEC-CAD-08 — Remoção de mocks residuais

**Achado:** o projeto ainda contém estruturas simuladas para projetos, peças e atividades.

**Evolução:** remover dados simulados das rotas de produção.

**Justificativa:** dados de demonstração podem ser confundidos com dados reais.

**Relação com o banco:** todos os módulos ativos devem consumir tabelas ou views oficiais.

**Ação a ser realizada:** retirar imports e estados baseados em `MOCK_*`, mantendo fixtures apenas em testes futuros.

**Critério de aceite:** nenhuma tela de produção exibe dados locais simulados.

## Itens removidos ou adiados

- controle operacional de estoque;
- solicitação e pedido de compra;
- edição de projeto;
- dashboard amplo de processos;
- atividades genéricas sem fonte real.

## Fundamentação

- `Sistema/cadastro-lucenera-b86fe/src/App.tsx`
- `Sistema/cadastro-lucenera-b86fe/src/stores/use-data-store.tsx`
- `Sistema/cadastro-lucenera-b86fe/src/services/produtos.ts`
- `Consolidação/Mapeamento de Processos/Mapeamento Markdown/03_debora_compras_cadastro_producao.md`
