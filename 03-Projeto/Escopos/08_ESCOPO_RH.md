# Escopo — Sistema de RH

## Versão atual

Pacote analisado: `dashboard-rh-lucenera-5fe9c`  
Versão declarada: `0.0.189`

O sistema possui módulos de:

- funcionários;
- cargos;
- faltas;
- férias;
- vale-transporte;
- folha;
- avaliações;
- relatórios;
- configurações.

Existem estruturas paralelas de funcionários e funções de administração de usuários dentro do próprio projeto.

## Objetivo da evolução

Manter o RH como domínio separado e funcional, reduzindo duplicidades e integrando:

- identidade e permissões pelo Sistema de TI;
- eventos financeiros necessários com o Financeiro;
- dados canônicos de colaboradores;
- relatórios reais.

RH não faz parte do núcleo comercial, mas deve permanecer coerente com o ecossistema.

## SPEC-RH-01 — Consolidação dos colaboradores

**Achado:** existem tabelas e árvores paralelas, como `funcionarios`, `funcionarios_novo`, `funcionarios_rh` e detalhes associados.

**Evolução:** eleger uma entidade principal e relações complementares.

**Justificativa:** a mesma pessoa não deve possuir saldos e dados funcionais divergentes.

**Relação com o banco:** funcionário principal, detalhes, benefícios, financeiro e vínculo com usuário.

**Ação a ser realizada:** comparar registros e consumidores antes de migrar; criar relatório de correspondência e divergência.

**Critério de aceite:** cada colaborador ativo possui um único identificador principal.

**Atualização 29/06/2026:** criada a view `vw_funcionarios_completo`, juntando `funcionarios_novo` com detalhes, financeiro e benefícios, e RLS ligada nas 4 tabelas pela primeira vez (`20260629120922_vw_funcionarios_completo.sql`). **Alerta:** a mesma migration semeia 4 funcionários fictícios (nome, CPF, RG, endereço, salário fabricados) condicionado a `funcionarios_novo` estar vazia — risco de entrar como dado real se rodada antes da carga de colaboradores verdadeiros. Ver [Adendo 03/07/2026](../06_ADENDO_ATUALIZACAO_03_07_2026.md) e pendência 12 do checklist geral.

## SPEC-RH-02 — Separação entre funcionário e usuário

**Achado:** funcionário e acesso ao sistema são conceitos relacionados, mas diferentes.

**Evolução:** manter funcionário como pessoa do RH e usuário como identidade de acesso.

**Justificativa:** nem todo funcionário precisa de login e um usuário pode mudar de função.

**Relação com o banco:** vínculo opcional entre funcionário e usuário canônico.

**Ação a ser realizada:** retirar suposições de igualdade obrigatória e usar relacionamento explícito.

**Critério de aceite:** é possível cadastrar funcionário sem criar acesso.

## SPEC-RH-03 — Acessos pelo Sistema de TI

**Achado:** o RH possui rotas e funções administrativas próprias de usuário.

**Evolução:** usar o contrato central de permissões.

**Justificativa:** acesso e papel não devem ser administrados separadamente em cada aplicação.

**Relação com o banco:** papéis e permissões do Sistema de TI; RH mantém apenas perfis funcionais do colaborador.

**Ação a ser realizada:** migrar verificações de rota e remover criação de credenciais dentro do RH.

**Critério de aceite:** TI libera ou remove acesso ao RH pelo Sistema de TI.

## SPEC-RH-04 — Preservação dos módulos úteis

**Achado:** faltas, férias, benefícios, avaliações e folha possuem implementação ampla.

**Evolução:** manter os módulos, corrigindo apenas dados e contratos.

**Justificativa:** reescrever o sistema não contribui diretamente para substituir o Connect.

**Relação com o banco:** tabelas oficiais de RH após a consolidação.

**Ação a ser realizada:** revisar cada módulo contra a entidade principal e retirar referências às árvores descontinuadas.

**Critério de aceite:** módulos existentes continuam operando após a migração dos funcionários.

## SPEC-RH-05 — Folha e integração financeira

**Achado:** o processo de Lana inclui folha, recibos, lançamento e pagamento bancário.

**Evolução:** enviar ao Financeiro somente o evento necessário de obrigação ou pagamento.

**Justificativa:** RH calcula a folha; Financeiro controla o título e a realização.

**Relação com o banco:** período de folha, funcionário/beneficiário, valores e previsão/título financeiro.

**Ação a ser realizada:** definir comando de fechamento da folha que gere previsões ou títulos, sem duplicar cálculo.

**Critério de aceite:** o Financeiro recebe os valores aprovados com referência ao período e funcionário.

**Atualização 30/06/2026:** a migration central `20260630_012_equipe_projetos_comissao` criou a view `vw_comissao_mensal` (percentual da equipe × valor total dos projetos do mês), com `equipe_id` novo em `projetos` e trigger de vínculo automático por nome do responsável. **Avanço parcial e por fora do sistema**: nasceu no banco central, não em um commit deste repositório de RH, e nenhum frontend consome a view ainda — não há comando de fechamento de folha nem envio de evento ao Financeiro. Ver [Adendo 03/07/2026](../06_ADENDO_ATUALIZACAO_03_07_2026.md).

## SPEC-RH-06 — Relatórios

**Achado:** o sistema já exporta relatórios, mas depende de contratos que podem mudar.

**Evolução:** garantir que relatórios usem os dados consolidados.

**Justificativa:** a migração não pode alterar silenciosamente resultados de folha, férias ou faltas.

**Relação com o banco:** views oficiais de RH.

**Ação a ser realizada:** criar relatórios de comparação antes/depois para cada módulo.

**Critério de aceite:** totais e quantidades são reconciliados após a consolidação.

## SPEC-RH-07 — Eventos e saúde

**Achado:** falhas de relatório ou integração precisam aparecer para TI.

**Evolução:** registrar execuções relevantes no Hub.

**Justificativa:** RH pode estar acessível enquanto uma geração de relatório ou integração falha.

**Relação com o banco:** `integracao_execucoes` e health checks do sistema.

**Ação a ser realizada:** publicar sucesso, falha e volume das rotinas agendadas.

**Critério de aceite:** TI visualiza a última execução relevante do RH.

## Itens removidos ou adiados

- recriação completa do RH;
- expansão para recrutamento avançado;
- folha fiscal completa;
- gestão própria de identidade;
- novas automações sem relação com a substituição do Connect.

## Fundamentação

- `Sistema/dashboard-rh-lucenera-5fe9c/src/App.tsx`
- `Sistema/dashboard-rh-lucenera-5fe9c/src/pages/Funcionarios.tsx`
- `Sistema/dashboard-rh-lucenera-5fe9c/src/pages/Folha.tsx`
- `Consolidação/Mapeamento de Processos/Mapeamento Markdown/01_lana_financeiro_administrativo.md`
- `Consolidação/Mapeamento de Processos/Mapeamento Markdown/02_caroline_administrativo_suprimentos.md`
