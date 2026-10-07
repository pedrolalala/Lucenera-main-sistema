# Status, enums e campos de seleção do DB atual

Status: atualizado com base no schema real extraído do Supabase em 2026-07-06.

Fonte principal: `supabase/db/current/01_schema_full.sql`.

Observação importante: as migrations dispersas dos sistemas não são fonte de verdade neste momento. A fonte de verdade é o banco real documentado na pasta central `supabase/`.

## Enums públicos existentes

Estes tipos existem como `CREATE TYPE ... AS ENUM` no schema `public`.

| Enum do DB | Valores atuais | Uso lógico |
| --- | --- | --- |
| `projeto_status` | `Estudo Inicial`, `Proposta Sinal`, `Elaboração Orçamento`, `Informações necessárias`, `Projeto executivo`, `Entrega materiais`, `Ajustes finais`, `Finalizado`, `Arquivado`, `Não Fechou`, `Venda Docusign`, `Obra Finalizada`, `Contrato de Projeto`, `Ajustes Finais`, `Emissão Projeto Executivo` | Status macro de projetos/CRM atual. |
| `parcela_status` | `pendente`, `paga`, `atrasada`, `cancelada` | Parcelas financeiras em `projeto_parcelas`. |
| `separacao_status` | `Rascunho`, `Pendente`, `Em separação`, `Pronto`, `Enviado`, `Cancelado`, `finalizado`, `separado`, `material_solicitado` | Separação/logística. Mistura valores legados com novos valores usados pelo sistema de logística. |
| `entrega_status` | `Pendente`, `Em rota`, `Entregue`, `Cancelado` | Entregas geradas a partir da separação. |
| `sinal_status` | `pendente`, `recebido`, `creditado`, `receita_servico` | Controle de sinal do projeto. |
| `solicitacao_status` | `pendente`, `aprovada`, `rejeitada`, `comprada`, `cancelada` | Solicitações de compra. Existe como enum, mas nem toda tabela de compra usa esse enum diretamente hoje. |
| `lancamento_status` | `pendente`, `pago`, `cancelado` | Lançamentos recorrentes financeiros. |
| `status_pagamento` | `Pendente`, `Parcialmente Pago`, `Pago`, `Atrasado`, `Cancelado` | Status de pagamento em vendas. |
| `conta_tipo` | `Corrente`, `Poupança`, `CDB`, `Investimento`, `Caixa` | Tipo de conta bancária. |
| `contato_tipo` | `cliente`, `arquiteto`, `engenheiro`, `eletricista`, `fornecedor`, `outro` | Tipo principal de contato. |
| `estoque_local` | `Estoque`, `Showroom`, `Em trânsito`, `Reservado`, `Estoque Geral`, `Estoque Luce Nera`, `Estoque Islight`, `Estoque Foco`, `Estoque Garantia`, `Estoque Casa Cor`, `Reserva`, `Separação`, `Entrega Futura`, `Devolução`, `Estoque Defeito`, `Amostra / Emprestado`, `Estoque Citel` | Locais/estados operacionais de estoque. |
| `frequencia_tipo` | `mensal`, `trimestral`, `semestral`, `anual` | Frequência de custos/recorrências. |
| `funcao_separacao_type` | `admin`, `operador`, `entregador`, `user` | Perfil/função na operação de separação. |
| `nivel_acesso_tipo` | `revendedor`, `interno`, `admin` | Nível de acesso em contexto Ubiqua/revenda. |
| `pagamento_forma` | `pix`, `cartao`, `boleto`, `transferencia`, `cheque`, `dinheiro` | Forma de pagamento. |
| `projeto_nivel` | `1`, `2`, `3`, `4` | Nível/classificação de projeto. |
| `tipo_operacao` | `CR`, `CP` | Contas a receber / contas a pagar. |
| `tipo_projeto` | `Residential`, `Corporativo`, `Exposição Comercial`, `Paisagismo` | Tipo/área do projeto. |
| `transacao_tipo` | `receita`, `despesa`, `transferencia` | Tipo de transação financeira. |
| `usuario_role` | `admin`, `gerente`, `operador`, `funcionario`, `viewer` | Papel do usuário no ecossistema. |

## Campos `status` com validação por `CHECK`

Estas colunas são `text`, mas o banco já limita os valores aceitos por constraint.

| Tabela | Campo | Valores aceitos |
| --- | --- | --- |
| `contas_bancarias` | `status` | `Ativa`, `Encerrada` |
| `controle_falta` | `status` | `presente`, `ausente`, `atraso`, `meio_periodo`, `atestado`, `licenca_maternidade`, `falta_injustificada`, `licenca_paternidade`, `licenca_obito`, `licenca_casamento`, `licenca_militar`, `licenca_medica` |
| `ferias` | `status` | `Pendente`, `Aprovado`, `Rejeitado`, `Cancelado` |
| `funcionarios` | `status` | `Ativo`, `Inativo`, `Afastado`, `Ferias` |
| `periodos_aquisitivos` | `status` | `Ativo`, `Concluído`, `Vencido` |

## Campos `status` ainda em texto livre ou legado

Estas tabelas têm campo `status` como `text` sem enum/check específico no schema atual. Portanto, não devem ser tratadas como enum rígido sem antes validar regra de negócio e dados reais.

| Tabela | Default atual | Observação |
| --- | --- | --- |
| `boletos` | `Pendente` | Usado no financeiro/administração bancária. Pode evoluir para status mais controlado em migration futura. |
| `fornecedores` | `ativo` | Cadastro. Atenção à diferença de caixa em relação a `Ativo` de funcionários. |
| `orcamentos` | `aguardando_aprovacao` | Tem CHECK constraint `orcamentos_status_check` (não é texto livre) com a lista: `rascunho`, `aguardando_aprovacao`, `enviado_cliente`, `recusado_cliente`, `expirado`, `cancelado`, `Aprovação Financeira`, `Orçamento Aprovado`, `aprovado_cliente`, `aprovado`, `aprovado_financeiro`, `pendente_aprovacao_financeira`, `Aprovação da Equipe`. Fluxo atual (SPEC-031, 18/07): `enviado_cliente -> Aprovação da Equipe -> Aprovação Financeira -> Orçamento Aprovado` (a etapa "Aprovação da Equipe" existe pra equipe confirmar peça/cor após visita à obra antes de mandar pro financeiro). Valores `aprovado_cliente`, `aprovado` e `aprovado_financeiro` são legados/compatibilidade. **Achado 2026-08-11**: a migration da SPEC-031 esqueceu de incluir `Aprovação da Equipe` no CHECK, quebrando toda aprovação de cliente por ~3 semanas até a migration `20260811_098` corrigir. |
| `orcamentos_revenda_ubiqua` | `rascunho` | Fluxo atual do sistema de orçamentos. A aprovação usada pela integração financeira trabalha com `aprovado`. |
| `pedido_compra` | `Pendente` | Compra/estoque. Ainda precisa ser consolidado com o novo sistema de Estoque/Compras. |
| `quotes` | `aberto` | Orçamentos/cotações legadas. |
| `remessas` | `pendente` | Administração bancária/remessa. |
| `solicitacoes_compra` | `Pendente` | Hoje é texto, apesar de existir `solicitacao_status` como enum. Precisa de decisão antes de normalizar. |

## Campos validados que não são `status`

Estas colunas não se chamam `status`, mas têm domínio validado por `CHECK` e devem ser tratadas como contrato de banco.

| Tabela | Campo | Valores/regra |
| --- | --- | --- |
| `orcamentos` | `frete_tipo` | `com_frete`, `sem_frete` ou `NULL` para dados antigos. A aprovação exige valor não nulo. |
| `orcamentos` | `frete_valor` | Coerente com `frete_tipo`: `sem_frete` exige valor `0`; `com_frete` exige valor `> 0`. |
| `orcamentos` | `prazo_inicio_cobranca_dias` | Inteiro `>= 0` quando preenchido. |

## Decisões de produto que afetam status

### CRM e projetos

As etapas do CRM, sub-status, checklists, bloqueios, paralelismo, sequência, SLA e responsáveis devem ser configuráveis pela UI.

Mesmo existindo `projeto_status` no DB atual, o plano de evolução não deve criar regra de negócio hardcoded para o fluxo do CRM. A tendência é manter o status macro compatível com o legado e criar/configurar camadas adicionais pela interface.

Ação a ser realizada: ao evoluir o CRM, criar tabelas/configurações para etapas, sub-status, checklists, regras de bloqueio, SLA e responsáveis configuráveis, relacionando essas configurações ao projeto e/ou à etapa do fluxo.

### Orçamentos aprovados e financeiro

No fluxo novo, o orçamento aprovado deve alimentar `projeto_itens` e abrir o caminho para a Administração Bancária emitir/registrar nota fiscal e boleto.

O vínculo principal decidido é `orcamento_id`. O financeiro deve conseguir exibir orçamento, projeto e cliente a partir desse vínculo, sem exigir `venda_id`.

Diretriz ativa: manter a integração baseada em `orcamento_id`, usando somente a aprovação financeira final para gerar ou atualizar itens do projeto e pendências financeiras conforme a SPEC-001/SPEC-016. O contrato único implementado é `enviado_cliente -> Aprovação Financeira -> Orçamento Aprovado`; `aprovado_cliente`, `aprovado` e `aprovado_financeiro` devem ser tratados como legados/compatibilidade.

### Logística

`separacao_status` está misturando nomes com acento/maiúscula e nomes técnicos em minúsculo.

Isso reflete a transição entre o fluxo antigo e o novo sistema de logística. Não padronizar no código de um sistema isolado sem migration planejada.

Ação a ser realizada: em uma futura etapa de limpeza do DB, decidir se logística continuará usando enum fixo, tabela de configuração ou migration de normalização dos status legados.

### Estoque/Compras

O novo sistema de Estoque/Compras deve possuir os dados operacionais. O Cadastro mantém apenas os dados cadastrais.

As vendas representam itens aprovados. O restante das movimentações relacionadas a clientes deve ser tratado como movimentação de estoque.

Ação a ser realizada: ao especificar o sistema de Estoque/Compras, revisar `estoque_local`, `solicitacao_status`, `pedido_compra.status` e `solicitacoes_compra.status` para evitar duplicidade entre compra, reserva, separação e entrega. A SPEC-010 já criou saldos numéricos por `projeto_item_id` (`q_reserva`, `q_entrega_futura`, `q_ag_separar`, `q_separado`, `q_entregue`, `q_devolvida`, `q_transferida_saida`) e `status_operacional` no banco real; antes de consumir esses campos em UI, aplicar o hardening `20260707_023` e definir a policy de RLS. `estoque_itens.quantidade_reservada` permanece como agregado de compatibilidade dos saldos abertos.

## Pendências de normalização

- Avaliar se `solicitacoes_compra.status` deve usar `solicitacao_status`.
- Avaliar se `boletos.status` e `remessas.status` precisam de enum/check próprio.
- Avaliar padronização de caixa/acentos em `separacao_status`.
- Homologar o fluxo completo de `orcamentos` depois da normalização da SPEC-016 e da UI das SPECs 017/018.
- Após a arrumação funcional do DB, fazer análise específica de segurança, permissões, RLS, roles e exposição pública.

## memoria.kb_* (SPEC-164 — aplicado em 2026-09-24)

- `memoria.kb_tipo`: `reuniao_projeto`, `visita_obra`, `teste_material`, `regra_material`, `padrao_projeto`, `procedimento`, `marca`, `designer`, `vivencia_evento`.
- `memoria.kb_categoria` (derivada do tipo): `tecnico`, `comercial`, `operacional`, `projeto`, `aprendizado`.
- `memoria.kb_status`: `rascunho`, `publicado`, `arquivado`.
- `memoria.kb_origem`: `manual`, `importada`.
