# Escopo — Sistema Ubiqua

> Atualizacao de 24/06/2026: Ubiqua continua ativo, mas fica em baixa prioridade no mapeamento ate definicao melhor de abrangencia. Este escopo permanece como referencia historica e nao deve gerar decisoes estruturais agora.

## Versão atual

Pacote analisado: `catalogo-pecas-ubiqua-e6fa0`  
Versão declarada: `0.0.76`

O sistema possui:

- catálogo;
- detalhe de produto;
- carrinho/novo orçamento;
- clientes;
- perfil e onboarding;
- área administrativa;
- imagens;
- orçamentos Ubiqua.

É o sistema mais claramente separado do fluxo operacional Lucenera e utiliza entidades próprias para revenda, clientes e orçamentos.

## Objetivo da evolução

Manter o Ubiqua como contexto separado, integrando apenas:

- identidade e acesso pelo Sistema de TI;
- cadastro do sistema e saúde;
- contratos explícitos quando algum dado precisar atravessar o domínio.

Não deve ser forçada a unificação entre catálogo Ubiqua e produtos operacionais Lucenera.

## SPEC-UBI-01 — Preservação do contexto separado

**Achado:** o sistema possui produto, cliente e orçamento com regras próprias de revenda.

**Evolução:** manter entidades Ubiqua identificadas e isoladas das entidades Lucenera.

**Justificativa:** os significados e usuários são diferentes, apesar do banco compartilhado.

**Relação com o banco:** `revenda_ubiqua`, `empresa_ubiqua`, `usuarios_ubiqua`, `orcamentos_revenda_ubiqua` e itens.

**Ação a ser realizada:** documentar as fronteiras e impedir reutilização acidental dessas tabelas por CRM ou Estoque Lucenera.

**Critério de aceite:** nenhuma rotina Lucenera depende diretamente do catálogo Ubiqua sem contrato aprovado.

## SPEC-UBI-02 — Identidade central e perfil de negócio

**Achado:** o sistema possui usuário/perfil próprio para onboarding e nível de acesso.

**Evolução:** usar a identidade central, preservando dados de perfil específicos do Ubiqua.

**Justificativa:** autenticação pode ser comum sem eliminar o perfil comercial B2B.

**Relação com o banco:** usuário canônico ligado a `usuarios_ubiqua` ou perfil equivalente.

**Ação a ser realizada:** separar credencial de acesso dos atributos de empresa, onboarding e nível Ubiqua.

**Critério de aceite:** TI controla o acesso e o sistema controla somente o perfil de negócio.

## SPEC-UBI-03 — Permissões pelo Sistema de TI

**Achado:** Ubiqua possui verificações próprias de administrador e nível de acesso.

**Evolução:** mapear as ações administrativas para permissões do Sistema de TI.

**Justificativa:** centraliza concessões sem eliminar regras comerciais específicas.

**Relação com o banco:** módulos e ações Ubiqua registrados no Sistema de TI, combinados com o perfil comercial.

**Ação a ser realizada:** substituir verificações de administração locais pelo contrato central.

**Critério de aceite:** remover o acesso no Sistema de TI bloqueia a entrada no Ubiqua.

## SPEC-UBI-04 — Orçamentos Ubiqua

**Achado:** o sistema possui fluxo próprio de orçamento.

**Evolução:** preservar esse fluxo sem misturá-lo ao Orçamento Lucenera.

**Justificativa:** são operações e públicos diferentes.

**Relação com o banco:** tabelas Ubiqua permanecem próprias; integrações futuras usam eventos ou tabelas de ponte explícitas.

**Ação a ser realizada:** manter nomes e serviços específicos e impedir que o novo comando de aprovação Lucenera processe esses orçamentos.

**Critério de aceite:** aprovações Ubiqua não geram `projeto_itens` Lucenera.

## SPEC-UBI-05 — Catálogo e imagens

**Achado:** catálogo e administração de imagens já são funções centrais.

**Evolução:** manter a operação atual e revisar apenas consistência dos dados.

**Justificativa:** não há benefício em mover essa responsabilidade para Cadastro Lucenera.

**Relação com o banco:** catálogo e armazenamento específicos.

**Ação a ser realizada:** validar códigos, slugs, imagens e produtos órfãos antes de qualquer limpeza.

**Critério de aceite:** catálogo público/interno continua operando sem depender do cadastro Lucenera.

## SPEC-UBI-06 — Saúde e integrações

**Achado:** TI precisa saber se o catálogo e o orçamento estão operacionais.

**Evolução:** registrar checks e execuções relevantes no Hub.

**Justificativa:** Ubiqua segue ativo e separado do fluxo principal. Pela atualizacao de 24/06/2026, ele fica em baixa prioridade no mapeamento ate definicao melhor de abrangencia.

**Relação com o banco:** sistema, ambiente, checks e integrações.

**Ação a ser realizada:** configurar disponibilidade da aplicação, conexão com banco e última operação relevante.

**Critério de aceite:** o Hub mostra o estado do Ubiqua e sua última verificação.

## SPEC-UBI-07 — Limpeza sem fusão de domínios

**Achado:** o banco compartilhado pode sugerir que tabelas semelhantes devam ser unificadas.

**Evolução:** consolidar apenas identidade e infraestrutura comum.

**Justificativa:** unificação de entidades com regras diferentes gera mais complexidade do que benefício.

**Relação com o banco:** manter chaves e nomes claros; usar ponte somente quando existir caso real de integração.

**Ação a ser realizada:** revisar dependências e documentar quais tabelas são exclusivas do Ubiqua.

**Critério de aceite:** relatórios e migrations futuras distinguem claramente os dois domínios.

## Itens removidos ou adiados

- fusão do catálogo Ubiqua com o estoque Lucenera;
- migração do orçamento Ubiqua para o sistema de Orçamentos Lucenera;
- criação automática de projeto Lucenera a partir de pedido Ubiqua;
- integrações sem caso de negócio confirmado.

## Fundamentação

- `Sistema/catalogo-pecas-ubiqua-e6fa0/src/App.tsx`
- `Sistema/catalogo-pecas-ubiqua-e6fa0/src/pages/NewQuote.tsx`
- `Sistema/catalogo-pecas-ubiqua-e6fa0/src/pages/admin/AdminPage.tsx`
- `Consolidação/Relatórios/RELATORIO_CONSOLIDADO_ECOSSISTEMA_LUCENERA.md`
