# Notas de Execução Detalhada — 11/08 a 13/08/2026

Registro de tudo que foi investigado, corrigido e publicado em produção nesse período, separado por quem levantou cada ponto: **Débora** (Necessidade de Compra), **Lana** (RH e Administração Bancária) e **Vinícius** (reunião gravada de 11/08, cobrindo CRM, Orçamentos, Separação Parcial e Logística).

---

## 1. Débora — Necessidade de Compra

### 1.1 Cadastro de fornecedor não existia (11/08)

Ao implementar preenchimento automático de CEP/CNPJ no sistema de Compras, foi descoberto que **não existia nenhum formulário de cadastro de fornecedor** — só um painel de busca/vínculo (`FornecedoresDaMarcaPanel.tsx`) que liga um fornecedor **já cadastrado** a uma marca, sem forma de criar um novo.

- Criado `FornecedorModal.tsx` do zero, com preenchimento automático de endereço via CEP e razão social/nome fantasia via CNPJ.
- Achado técnico: fornecedor é um registro em `contatos`, mas a busca usada no resto do sistema (`buscar_fornecedores_fuzzy`) consulta a tabela auxiliar `contato_tipos` (relação N:N — um contato pode ser cliente E fornecedor ao mesmo tempo), não só a coluna antiga `contatos.tipo`. Cadastrar um fornecedor exige gravar nas duas tabelas, senão ele nunca aparece nas buscas do sistema.
- Publicado: Skip 40326, v0.0.60.
- Pendência registrada na época: ainda não existe tela de listagem/edição dos fornecedores já cadastrados, só a criação.

### 1.2 "Acesso negado" na Necessidade de Compra (12/08)

Débora reportou que, mesmo com o papel `compras_e_entregas` concedendo `criar/editar/visualizar` corretamente, o sistema mostrava "Acesso negado" ao tentar abrir Necessidade de Compra.

- Causa raiz: bug de comparação com `NULL` em SQL na função central `hub_pode_executar` (usada por todos os 10 sistemas pra checar permissão). Quando um app pergunta "esse usuário tem acesso a este sistema, seja qual for a ação" (checagem de tela inteira), a comparação usada nunca dava certo pra papéis que só tinham ações específicas cadastradas (sem uma linha "acesso geral") — eram exatamente os papéis novos como o da Débora.
- **Escopo real do bug, descoberto na investigação**: não era só a Débora — 16 combinações de papel/sistema estavam com a mesma falha (`administracao_comercial`, `compras_e_entregas`, `equipe_entrega`, `equipe_projetos`, espalhados por Cadastro, Necessidade de Compra, Orçamentos, Separação Parcial, Logística e CRM). Na prática, só 2 pessoas realmente ficavam travadas de verdade (Débora e Caroline) — Lana e Mariane têm papéis extras (`gerente`) que já cobriam o acesso por outro caminho, então nunca perceberam o bug.
- Fix aplicado direto no banco (função corrigida), sem precisar publicar nenhum sistema — corrige os 16 casos de uma vez.
- Verificado: acesso da Débora e de um segundo papel afetado confirmados liberados depois do fix, sem abrir acesso a mais do que estava cadastrado.

### 1.3 Entrada de nota fiscal sem pedido de compra (13/08)

Na reunião do Vinícius, ficou registrado um caso real da rotina da Débora: peças que chegam fisicamente sem nunca ter passado por um pedido de compra formal no sistema, e mesmo assim precisam de entrada de nota fiscal registrada. Até então, a tela só liberava o registro depois de localizar um pedido existente — sem essa opção, ficava travado.

- Tela de Entrada de Nota Fiscal ganhou uma alternância: **"Tenho o número do pedido"** (fluxo de sempre) ou **"Não tenho pedido (entrada avulsa)"**.
- No modo avulso: escolhe fornecedor e empresa diretamente, com vínculo de produto opcional (pode ficar em branco e ser completado depois).
- Migration: 3 colunas novas em `notas_fiscais_compra` (fornecedor, empresa, produto), todas opcionais.
- Publicado: Skip 40326, v0.0.61.

---

## 2. Lana — RH e Administração Bancária

### 2.1 Módulo de Duplicatas — Administração Bancária (11/08)

Pedido inicial: "só ajustes de interface" em 3 telas do módulo de Duplicatas (Consultar/Baixar/Cadastrar), com especificação campo a campo.

- **Achado antes de codar**: a especificação batia quase campo a campo com as colunas das tabelas de importação do sistema legado Connect — ou seja, descrevia telas do sistema antigo que o app novo só tinha reconstruído parcialmente. "Consultar Duplicatas" já existia; **"Baixar Duplicata" e "Cadastrar Duplicatas" não existiam** no sistema novo, e vários campos pedidos não tinham coluna correspondente em `boletos`. Reportado antes de implementar (contradizia a instrução de "só interface, sem mudar schema"); autorizado construir as 2 telas novas e adicionar as colunas.
- Migration: 10 colunas novas em `boletos` (apropriação, conta bancária, forma de pagamento, bandeira, linha digitável, juros/multa, desconto, responsável, referência, grupo de conta, observação).
- Publicado: Skip 36395, v0.0.62.
- **Ficou pendente** (não implementado, sinalizado com aviso na tela): botões "Executar", "Acordo" e "Info" em Consultar Duplicatas — o sistema não define ainda o que cada um deve fazer.

### 2.2 Reconciliação do Plano de Contas — Apropriação (11/08)

O usuário passou uma lista oficial de ~116 categorias de "Apropriação" (nível 3 do plano de contas) pra reconciliar com as 103 que já existiam no banco.

- Aplicado: 23 renomeações (preservando o histórico já lançado) + 34 categorias novas.
- **Achado importante**: toda categoria do plano de contas, mesmo as mais obscuras, tem lançamentos financeiros reais vinculados — de 1 a 2.261 registros cada. Não existe categoria "órfã e segura pra apagar" nessa tabela; qualquer mudança futura precisa checar os lançamentos vinculados antes.
- **Pedido registrado pra o futuro** (ainda não implementado): permitir que os próprios usuários cadastrem Grupo/Sub Grupo/Apropriação novos pela tela, em vez de precisar de alteração direta no banco.

### 2.3 Ajustes de UX (duplo-clique) — RH e Administração Bancária

Dentro de uma rodada geral de padronização de UX (duplo-clique pra editar linhas de tabela, aplicada em vários sistemas), passou também pelas telas de RH (funcionários, férias, faltas) e Administração Bancária (boletos) — ajuste pontual de interatividade, sem mudança de regra de negócio.

---

## 3. Vinícius — reunião gravada de 11/08/2026

A reunião de 11/08 (3 gravações — `02-Reunioes/17. Lucenera (vinicius) - 11.08.2026_ estruturas falhas do sistema/`) foi um teste ao vivo do sistema, cobrindo CRM, Orçamentos, Compras/Separação Parcial e Logística. Boa parte já tinha sido corrigida nos dias seguintes sem o vínculo com a reunião ter sido documentado — esta seção fecha esse registro.

### 3.1 Já resolvido nos dias seguintes à reunião (11 e 12/08)

| Item relatado na reunião | O que foi corrigido |
|---|---|
| CNPJ/CEP não preenchiam automático no cadastro de cliente | Preenchimento automático implementado em Orçamentos e CRM (mesma leva da correção 1.1 da Débora) |
| "Perfil Ribeirão/São Paulo" precisa aparecer em todo lugar | Rótulo de perfil implementado em 6 sistemas |
| Selecionar 1 produto e repetir em vários L's sem bagunçar a lista | Nova tela de seleção de quantidade de L's dentro da busca de produto, antes de cair no orçamento |
| "Não me puxou" o projeto ao criar; Responsável vem vazio; cliente some da busca | Causa raiz: o Supabase corta silenciosamente qualquer resposta em 1.000 linhas — o app não sabia disso e tentava continuar com dado incompleto. Corrigido em Orçamentos e CRM |
| Campo "vendedor"/"responsável" devia vir do cadastro de funcionários; permitir mais de 1 arquiteto | Responsável e Vendedor passaram a vir do cadastro de Funcionários (antes era texto livre); projeto e orçamento passam a aceitar múltiplos arquitetos com % de divisão de lucro cada |
| "Projeto sem empresa vinculada" parecendo travar a criação | Investigado em 13/08: a trava nunca existiu no CRM — é do Orçamentos, e é proposital (a empresa escolhida alimenta o boleto/nota fiscal real). A tela já orienta o preenchimento manual quando falta, sem travar; venda cruzada entre perfis (ex. vender item de SP pela Manoella) já é livre, sem restrição |

*(Além desses, nos mesmos dias também foram corrigidos: erro genérico ao salvar projeto no CRM, botões "Aprovar Manualmente"/"Voltar para Rascunho" quebrados em Orçamentos, "Voltar" disponível em todos os status do funil, vencimento de parcelas recalculado por mês em vez de a cada 3 dias com edição individual por parcela, aba "Gerenciamento" para admin/gerente ver lucro por peça, e o PDF do orçamento passou a trazer logo, endereço do cliente e Arquiteto Externo.)*

### 3.2 Corrigido em 13/08 (fechamento dos itens ainda em aberto)

**Separação Parcial**

- **Integração automática com Logística**: ao terminar de separar uma venda por completo (informando a data de entrega), o sistema agora cria a entrega automaticamente no sistema de Logística — sem precisar reentrar os dados lá. Achado técnico: essa automação já existia no banco pra outro fluxo mais antigo, só nunca tinha sido conectada ao fluxo novo de Separação Parcial.
- **Estorno de separação**: botão "Estornar" em cada separação já registrada — devolve a quantidade pra reserva, exige motivo por escrito, e deixa um aviso registrado na entrega vinculada (se já existir) pra não pegar o pessoal da Logística de surpresa.
- **Impressão automática**: ao confirmar uma separação, o sistema já abre a impressão da lista (o usuário escolhe "Salvar como PDF" ou imprimir direto).
- **Código da parcial**: antes era um trecho de código aleatório sem relação com a venda; agora segue o número da venda (ex.: venda 3667 → parciais 3667-P1, 3667-P2...).

**Orçamentos**

- Busca de produto ganhou filtro por fornecedor (já tinha marca, categoria e busca por nome/SKU).
- Validade do orçamento passou a ser calculada automaticamente (data de emissão + 10 dias), continuando editável manualmente se precisar de um prazo diferente.

**CRM**

- Reorganização do cadastro de cliente: campo "Tipo Cliente" subiu pra logo perto de CPF/CNPJ; RG e Inscrição Estadual ficaram lado a lado (antes um campo entrava no meio dos dois).

---

## Resumo por sistema publicado

| Sistema | Versões publicadas no período |
|---|---|
| Compras / Necessidade de Compra | v0.0.60 → v0.0.61 |
| Administração Bancária | v0.0.62 |
| Separação Parcial | v0.0.7 → v0.0.20 |
| Orçamentos | v0.0.310 → v0.0.328 |
| CRM | v0.0.296 → v0.0.302 |
| Cadastro | v0.0.60 |

Todas as SPECs formais correspondentes estão em `03-Projeto/Planos de Ação/SPECs/` (073 a 096).
