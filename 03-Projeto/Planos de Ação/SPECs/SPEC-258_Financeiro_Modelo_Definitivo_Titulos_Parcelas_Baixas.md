---
titulo: "SPEC-258 — Financeiro: modelo definitivo (títulos, parcelas, baixas e cobranças) — uma fonte de verdade, tudo com id e vínculo real"
status: pendente
data_ultima_modificacao: 2026-11-06
sistemas_envolvidos:
  - Banco (Supabase SP) — financeiro (núcleo novo + migração do legado)
  - Orçamentos, Compras, Contas a Pagar, Contas a Receber, Adm. Bancária (CNAB), Dashboard Financeiro, RH (folha, comissão)
---

# SPEC-258 — Financeiro: modelo definitivo

> **Estado em 06/11/2026: modelo APROVADO EM PRINCÍPIO pelo usuário; NADA aplicado no banco.** O usuário pediu: (1) criar esta SPEC com todas as informações; (2) trocar para um modelo mais forte de IA; (3) **refazer a análise do banco do zero** com esse modelo; (4) só depois aplicar o banco novo. Antes de revisar, **nada deve ser enviado ao GitHub** sobre este assunto.
> Anexo visual (para o usuário ler): `03-Projeto/Planos de Ação/SPECs/SPEC-258_anexo_relatorio_visual_financeiro.html` (cópia para abrir fácil: `03-Projeto/Relatorio_Financeiro_Nova_Estrutura.html`).
> Linha de base reexecutável (só leitura): `scripts/financeiro/baseline_spec258.sql`.
> **Absorve** as partes 4b–4d da SPEC-246 (estrutura alvo) e a opção B da SPEC-248 item 3. Relacionadas: SPEC-245, SPEC-246, SPEC-248, SPEC-254, SPEC-209/215/222 (Compras), SPEC-152/233/234 (aprovação e tipos de operação).

## 0. COMO RETOMAR (leia primeiro — instruções para a próxima sessão)

**Pedido original do usuário (resumo fiel):** "as informações de dinheiro estão espalhadas em vários lugares sem vínculo entre si; na proposta eu quero que **tudo tenha ID e sincronização** entre as informações, **nenhuma ponta solta, nada aberto, sem erros**; isso vale para contas a receber, contas a pagar, histórico de contas pagas, **RT dos arquitetos** e **RT/comissão dos funcionários**; a migração não pode ter erro. As informações são 100% geradas no nosso sistema: orçamento gera a receber; necessidade de compra e pedido de compra geram a pagar. Quero receita, despesa, receita prevista e despesa prevista bem específicas."

**Ordem de trabalho combinada:**
1. Ler esta SPEC, a SPEC-246, o anexo HTML e os `AGENTS.md` (raiz, `supabase/`, `scripts/`, `03-Projeto/`).
2. Rodar `scripts/financeiro/baseline_spec258.sql` e **comparar com os números de 06/11** (estão nos comentários do script). Se mudou algo, descobrir por quê antes de seguir (o financeiro ainda recebe lançamentos, p.ex. aprovação de orçamento).
3. **Refazer a análise de forma independente** (não confiar cegamente nos números desta SPEC): reconferir o inventário dos 12 lugares, as dependências (seção 8), as chaves estrangeiras, as regras do legado e cada decisão da seção 9. Registrar divergências aqui.
4. Fechar as **decisões da seção 9** com o usuário (principalmente o **RT**, cuja regra o banco não guarda).
5. Escrever as migrations **em fases**, cada uma com `up.sql`, `rollback.sql` e `dry_run.sql` (termina em ROLLBACK), na pasta `supabase/db/migrations/YYYYMMDD_NNN_nome/`. **Próximo número livre: 302** (a 301 já está aplicada, ver abaixo).
6. **Cada migration só é aplicada com autorização explícita do usuário.** Conferir sempre antes × depois e registrar no CHANGELOG.

**Regras do usuário e do projeto que valem aqui:** nunca apagar (cancelar/estornar); tabela nova com `ENABLE ROW LEVEL SECURITY` e `REVOKE ALL ... FROM anon`; função nova com `REVOKE ALL ... FROM PUBLIC, anon`; nunca `USING (true)` para `authenticated` em dado financeiro/RH (usar `(SELECT pode_acessar_sistema('financeiro'))`); backups no schema `backup` (nunca em `public`); folha e comissão só para o RH; sempre ensaio com ROLLBACK, como usuário real, antes de aplicar; build dos sistemas com `VITE_SUPABASE_*` de São Paulo (o `.env` local de alguns sistemas aponta para Ohio).

**Dicas operacionais aprendidas nesta sessão:** `export PGCLIENTENCODING=UTF8` antes do `psql`; **não** colocar acento em literal na linha de comando do `psql` (quebra a codificação no Windows: use `LIKE 'em separa%'` ou arquivo `.sql`); no git-bash, blocos longos com aspas dentro de heredoc podem quebrar: usar a ferramenta de escrever arquivo e depois rodar; `git push` para o GitHub costuma demorar mais de 2 minutos: rodar em segundo plano e esperar; um `git add` em `04-Sistemas/<submódulo>` imprime aviso de "ignorado" mas o ponteiro entra no commit; só atualizar ponteiro de submódulo para commit **já enviado** ao GitHub.

**Já aplicado e relacionado (não refazer):** migration **301** (`20261106_301_spec248_previsao_transacoes`): coluna `transacoes.previsao`, coluna `previsao` no fim de `v_financeiro_realizado` (verdadeira só para parcela em aberto), função `definir_previsao_transacoes`. É **passo intermediário**: a situação `prevista` do modelo novo a substitui; na Fase 2 migra-se o que estiver marcado (hoje: 0 parcelas) e remove-se.

## 1. Diagnóstico (medido no banco em 06/11/2026)

**O dinheiro está em 12 lugares, cada um com o seu "pago", quase sem ligação por id:**

| # | Estrutura | O que guarda | Linhas |
|---|---|---|---|
| 1 | `negociacoes` | a duplicata (Connect até 05/11; nativo depois) | 14.028 |
| 2 | `transacoes` | a parcela + o pagamento (juntos) | 23.338 |
| 3 | `projeto_parcelas` | parcela da venda gerada pelo orçamento | 387 |
| 4 | `boletos` | cobrança bancária **e** contas a pagar cadastradas à mão | 4 |
| 5 | `pedido_compra_parcelas` | parcela do pedido de compra (previsão) | 70 |
| 6 | `nota_fiscal_compra_parcelas` | parcela da NF de compra (vira boleto) | 3 |
| 7 | `custos_recorrentes_lancamentos` | custo fixo mensal | 0 |
| 8 | `folha_pagamento` | salário líquido do mês | 771 |
| 9 | `vendas` (legado Connect) | venda com valor pago/pendente | 263 (R$ 7,54 mi pago · R$ 637 mil pendente) |
| 10 | `pedido_compra` (legado Connect) | pedido com parcela/vencimento | 247 (45 vigentes) |
| 11 | `staging_pedido_compra` | carga bruta do pedido | 435 |
| 12 | `remessas` / `retornos_processados` / `projeto_sinal` / `pagamentos_antecipados` | pagamento a fornecedor por CNAB, log de retorno, sinal e adiantamento | 0 / 2 / 0 / 0 |

(+ apoio/arquivo: `connect_contas_espelho` 19.372; `stg_duplicatas_vigentes` 10.403; `notas_fiscais_connect_duplicatas` 809; `financeiro_posicao_diaria` 18.667.)

**Consequências:** uma venda aprovada fica em **3 lugares** (`projeto_parcelas`, `boletos` e, por gatilho `trg_projeto_parcela_financeiro`, `negociacoes`+`transacoes`) com situações próprias; a compra segue outro caminho; **só cabe 1 pagamento por parcela** (sem parcial/estorno/histórico de baixas); "prevista" não existe; "receita/despesa" mistura direção e estado; nomes herdados da Connect não dizem o que são.

**Vínculos que faltam hoje:** títulos sem plano de contas 245; sem projeto 10.566; sem orçamento 14.027 (todo o legado; só 272 vendas existem no sistema novo, SPEC-246); pagamentos sem conta bancária 982 (1.923 parcelas); `transacoes.categoria_id` nunca usada (23.338 vazios); `boletos` sem parcela 4; `projeto_parcelas` sem título e sem orçamento 387 (as de 04/05, que o usuário confirmou **não serem teste**: nada será apagado); parcelas de pedido e de NF sem nenhuma ligação com o financeiro 70+3; códigos de parcela da Connect repetidos 2.768 (a chave da Connect **não serve** como id).

**Pessoa de tipo incompatível:** despesas ligadas a contato "cliente" 1.723; receitas a "fornecedor" 11; funcionários (salário, vale-transporte, férias, 13º) ligados a contato "arquiteto" ≥ 14 títulos.

**Dados com defeito:** 1 paga com data de pagamento no futuro (19/12/2026); 22 vencimentos de ano absurdo (ex.: 0204); 5 pagas sem data de pagamento.

**Baseline de prova (migração tem que reproduzir exatamente):** `v_financeiro_realizado` = **18.316 linhas**, soma `vl_parcela` = **R$ 75.203.769,77**; `transacoes`: receita 0/1/2 = 459/4.592/3.602 (R$ 2,85 mi / 35,67 mi / 12,38 mi), despesa 0/1/2 = 1.238/12.376/1.071 (R$ 4,08 mi / 33,95 mi / 10,30 mi); **16.968 pagamentos** (16/08/2024 a hoje); contas bancárias 4 (Caixa Empresa, Bradesco Luce Nera, Bradesco Islight, Bradesco Foco).

## 2. Princípios

1. **Uma fonte de verdade por fato.** Obrigação e agenda num lugar; pagamento real (baixa) noutro; cobrança bancária é instrumento.
2. **O "pago" só existe em `baixas`.** Liquidada/parcial/vencida são **derivadas**, nunca digitadas.
3. **Dois eixos:** natureza (a receber | a pagar) × situação (prevista | firme | liquidada | cancelada). "Receita/despesa" contábil = classificação do plano de contas.
4. **Porta única:** todo dinheiro nasce por funções do banco; os sistemas não gravam direto.
5. **Todo dado com id próprio (`uuid`), imutável; ligações são chaves estrangeiras reais; ids da Connect em colunas `legado_*` imutáveis.**
6. **Nada em branco por acaso:** `NOT NULL` para o nativo; no legado, o que não ligar vai para a **fila de pendências** (nunca vazio em silêncio).
7. **Nada se apaga:** cancela-se com motivo; estorna-se; a auditoria guarda antes/depois.
8. **Os sistemas leem views, nunca cópias.**

## 3. Estrutura (4 tabelas centrais + 2 de apoio)

**3.1 `financeiro_titulos`** (a obrigação; substitui `negociacoes`): `id`; `natureza` (`receber`|`pagar`); `origem_tipo` + **uma FK real por origem** (`orcamento_id`, `pedido_compra_id`, `nota_fiscal_compra_id`, `folha_pagamento_id`, `custo_recorrente_id`, `regra_repasse_id`) com `CHECK` de **exatamente uma** preenchida e coerente com `origem_tipo`, e índice único por origem (+ `origem_seq` quando uma origem gera mais de um título); `especie` (venda, credito_devolucao, compra, nota_compra, adiantamento, despesa, salario, comissao, rt_arquiteto…); `empresa_id` (NOT NULL); `perfil`; `contato_id`/`funcionario_id` (tipo coerente); `plano_contas_id` (NOT NULL no nativo); `projeto_id`; `documento`; `descricao`; `substitui_titulo_id`; `titulo_base_id` (a venda que gerou um RT/comissão); `titulo_compensado_id` (crédito → venda); `cancelado_em/por/motivo`; `legado_cod_duplicata` (imutável); `criado_em/por`.

**3.2 `financeiro_parcelas`** (agenda; substitui a "agenda" de `transacoes`, `projeto_parcelas`, `pedido_compra_parcelas`, `nota_fiscal_compra_parcelas`, `custos_recorrentes_lancamentos`): `id`; `titulo_id`; `numero` (único por título); `vencimento`; `valor`; `situacao` (`prevista`|`firme`|`cancelada`|`substituida`); `confirmada_em/por`; `forma_prevista`; `valor_baixado` (mantido por gatilho a partir das baixas); `legado_cod_itens_duplicata` (imutável).

**3.3 `financeiro_baixas`** (o fato real; **nova**; é o histórico de contas pagas/recebidas): `id`; `parcela_id`; `tipo` (`pagamento`|`recebimento`|`compensacao`|`estorno`); `data`; `valor`; `juros`; `multa`; `desconto`; `forma`; `conta_bancaria_id` (**NOT NULL**); `cobranca_id`; `comprovante_url`; `origem_baixa` (`manual`|`retorno_bancario`|`antecipacao`|`legado`); `estorno_de`; `criado_em/por`.

**3.4 `financeiro_cobrancas`** (instrumento; absorve `boletos`, `remessas`): `id`; `parcela_id`; `sentido` (receber|pagar); `meio` (`boleto`|`pix`|`cartao`|`deposito`|`carteira`); `nosso_numero`; `linha_digitavel`; `remessa_sequencial`; `conta_bancaria_id`; `status_banco`. O **retorno bancário gera baixa**; a cobrança não é fonte de valor nem de "pago".

**3.5 `financeiro_regras_repasse`** (apoio; RT e comissão): quem recebe (arquiteto, funcionário ou equipe), `percentual`, `base` (bruto|líquido|recebido…), `gatilho`, `prazo`, `vigencia`. Quando dispara, a porta única cria um título a pagar (`origem_tipo = rt_arquiteto|comissao`) ligado à venda por `titulo_base_id`.

**3.6 `financeiro_pendencias`** (apoio; fila "nada fica aberto"): `id`; `titulo_id`/`parcela_id`/`baixa_id` (FK real); `tipo` (sem_plano_contas, sem_conta_bancaria, pessoa_incompativel, data_invalida, rt_sem_venda, legado_sem_vinculo…); `status` (`aberta`|`resolvida`|`aceita`); `motivo_aceite`; `aceita_por/em`; `responsavel`; `resolvida_por/em`. **Só o administrador aceita, sempre com motivo.**

**3.7 Enumerações:** `fin_natureza`, `fin_situacao`, `fin_origem`, `fin_especie`, `fin_baixa_tipo`, `fin_cobranca_meio`.

## 4. Os 4 nomes do negócio (views)

| | Prevista | Firme | Liquidada |
|---|---|---|---|
| **A receber** | **Receita prevista** | A receber | **Receita realizada** |
| **A pagar** | **Despesa prevista** | A pagar | **Despesa realizada** |

Views: `vw_contas_a_receber`, `vw_contas_a_pagar`, `vw_historico_baixas`, `vw_fluxo_caixa` (mensal e diário: receita prevista/realizada, despesa prevista/realizada, saldo), `vw_financeiro_integridade`. Derivados: **vencida** = firme com vencimento passado e saldo; **parcial** = baixas < valor. A coluna "Previsão" do Fluxo Futuro (SPEC-248 item 3) é a soma das parcelas **previstas** do mês.

## 5. Identidade, vínculos e sincronização

**5.1 Mapa de ids** (informação → id → chave estrangeira → obrigatório): título (`financeiro_titulos.id` → `parcelas.titulo_id`); parcela (→ `baixas.parcela_id`, `cobrancas.parcela_id`); baixa (→ `baixas.estorno_de`); cobrança (→ `baixas.cobranca_id`; retorno bancário → cobrança); pessoa (`contatos.id` → `titulos.contato_id`, obrigatório exceto folha); funcionário (`funcionarios.id` → `titulos.funcionario_id`, folha/comissão); empresa (`empresas.id`, sempre); conta bancária (`contas_bancarias.id` → `baixas.conta_bancaria_id`, **toda baixa**); plano de contas (sempre); projeto; venda (`orcamentos.id` → `titulos.orcamento_id`); pedido (`pedidos_compra.id`); NF (`notas_fiscais_compra.id`); folha (`folha_pagamento.id`); custo recorrente (`custos_recorrentes.id`); regra de repasse; previsão substituída (`substitui_titulo_id`); crédito de devolução (`titulo_compensado_id`); pessoa da Connect (`contato_legado_ids`: espaço + `cod_connect` → `contatos.id`, SPEC-246 4a).

**5.2 Sincronização — tudo na mesma transação (tudo ou nada):** baixa registrada → recalcula `valor_baixado` e a situação derivada; baixa estornada → cria baixa de estorno e recalcula; orçamento aprovado → cria título + parcelas firmes + cobranças juntos; orçamento cancelado/aprovação desfeita → cancela título/parcelas/cobranças e **bloqueia se já houver baixa** (exige estorno); pedido aprovado/editado/voltado → cria/recalcula parcelas previstas (bloqueia edição depois de NF ligada); NF lançada → cria título firme e marca a prevista do pedido como `substituida`; NF cancelada → cancela o título da NF e **reativa** a prevista; retorno do banco → baixa ligada à cobrança, **idempotente**; parcela da venda recebida → libera RT/comissão proporcionais; devolução aprovada → crédito ligado à venda e ajuste de RT/comissão; folha gerada → título por funcionário/mês (só RH); qualquer regra ferida → operação inteira recusada com mensagem.

**5.3 Os 15 testes de tolerância zero** (`vw_financeiro_integridade`, diários; a migração só segue com todos em zero ou aceitos na fila): *para frente* — (1) título sem exatamente uma origem válida; (2) título sem empresa/pessoa/plano de contas; (3) parcela órfã e título sem parcela ativa; (4) soma das parcelas ativas ≠ total; (5) baixa sem conta bancária e baixa em parcela cancelada/substituída; (6) `valor_baixado` ≠ soma das baixas; (7) cobrança sem parcela e baixa por retorno sem cobrança; (8) pessoa de tipo incompatível. *Para trás* — (9) **orçamento aprovado sem título a receber**; (10) **pedido aprovado sem despesa prevista**; (11) **NF de compra sem título** e folha-mês sem título; (12) **venda recebida sem RT/comissão gerado** (quando há regra). *Coerência e legado* — (13) origem cancelada com título ativo; (14) prevista vencida há muito tempo e substituída sem substituta; (15) legado: totais por tipo, situação, mês, empresa e perfil **diferentes** do banco antigo.

## 6. De onde vem cada informação (todas pela porta única)

| Origem | Gera | Situação ao nascer → muda quando |
|---|---|---|
| **Orçamento** (venda) | a receber, espécie venda | prevista na aprovação da equipe → **firme** na aprovação financeira (cobranças criadas; carteira/permuta sem boleto) |
| **Pagamento no ato** (Pix com comprovante, SPEC-254) | **baixa** na parcela, já com o comprovante | liquidada |
| **Devolução** | título a receber `credito_devolucao` (valor negativo só nessa espécie) ligado à venda de origem | firme; compensa a venda |
| **Permuta** | contrapartida a pagar ligada à venda | firme |
| **Necessidade de compra** | a pagar, espécie compra | **prevista** |
| **Pedido de compra aprovado** | a pagar (as parcelas do pedido **viram** parcelas do financeiro; `pedido_compra_parcelas` guarda só a condição de pagamento) | prevista → **substituída** pela NF |
| **NF de entrada** | a pagar, espécie nota_compra | **firme** (vencimento real); substitui a prevista do pedido |
| **Adiantamento a fornecedor** | título a pagar com baixa; **compensação** abate a NF | liquidada |
| **Custo recorrente** | uma prevista por mês | prevista → firme no vencimento/confirmação |
| **Folha** | a pagar por funcionário/mês | firme (só RH) |
| **RT do arquiteto** | a pagar, `rt_arquiteto`, ligado à venda | prevista na venda → firme proporcional ao recebido (**regra a definir, seção 9**) |
| **Comissão do funcionário** | a pagar, `comissao`, ligado à venda | idem (**a definir**) |
| **Lançamento manual** | a pagar ou a receber | prevista (check) ou firme |
| **Legado Connect** | título + parcelas + baixas | firme/liquidada/cancelada conforme estava; ids imutáveis |

## 7. RT dos arquitetos, comissão e folha (achados medidos)

- **Arquitetos:** `projeto_arquitetos` (2.276 vínculos, 633 arquitetos) guarda **só a divisão** entre arquitetos do projeto (todos em 100% hoje); `orcamento_arquitetos` 1 linha. **O percentual de RT, a base de cálculo, o momento do pagamento e o controle do que foi repassado não existem no banco.**
- **RT histórico:** a Connect o registrava como conta a pagar comum no plano de contas **"RT"**: **1.168 títulos, R$ 1,81 mi** (762 = R$ 1,38 mi a contato tipo arquiteto; **93 = R$ 305 mil a contato "fornecedor" e 78 = R$ 127 mil a "cliente"**; 3 sem tipo) e **20 títulos (R$ 107 mil) lançados como receita**. **Nenhum está ligado à venda/projeto que o gerou** (956 com `cod_venda = 0`, 212 vazio, 0 com projeto, 0 com orçamento) → **não dá para calcular o percentual real do histórico nem saber venda a venda o que foi repassado.**
- **Comissão:** `funcionarios_financeiro.comissao_percentual` (13 funcionários, máx. 5,5%), por **equipe**; `vw_comissao_mensal` calcula percentual × valor total dos projetos da equipe no **mês de entrada do projeto** (vendido, não recebido); `folha_pagamento.comissao` está **zerada nas 771 folhas** → a comissão é calculada e **nunca paga pela folha**.
- **Folha:** 771 folhas, 49 meses, salário líquido total R$ 6,18 mi; **não gera conta a pagar nem baixa**. Existe campo de salário "por fora" em `funcionarios_financeiro`: **dado sensível, só RH**, nunca nas visões financeiras gerais.

## 8. Dependências que a migração precisa religar (inventário nomeado)

- **Sistemas (leem as tabelas antigas):** dashboard (`pages/Transacoes.tsx`, `services/cash-flow.ts`); retorno-bancário/Contas a Pagar e Receber (`ConsultarDuplicatas.tsx`, `ContasEmAberto.tsx` + 7 arquivos que leem `boletos`); compras (2 arquivos), CRM (1), separação parcial (1) — **13 arquivos em 4 sistemas** leem boletos/parcelas.
- **11 funções que citam `negociacoes`/`transacoes`:** `_valor_venda_connect`, `aplicar_xml_connect_orcamentos`, `carregar_connect_reserva_ambiente`, `congelar_posicao_financeira`, `criar_transacao_da_parcela_projeto`, `definir_previsao_transacoes`, `desfazer_aprovacao_financeira`, `get_dashboard_kpi`, `ligar_projeto_connect`, `processar_retorno_bancario`, `trg_projeto_parcela_financeiro`.
- **21 funções que tocam parcelas/boletos/folha/pedido:** `aprovar_orcamento_financeiro` (+ `_base_spec001`), `cancelar_orcamento`, `desfazer_aprovacao_financeira`, `aprovar_pedido_compra`, `cancelar_pedido_compra`, `editar_pedido_compra`, `gerar_parcelas_pedido_compra`, `atualizar_parcela_pedido_compra`, `voltar_pedido_compra_para_edicao`, `fn_nota_compra_parcela_gera_contas_pagar`, `fn_nota_compra_parcela_remove_contas_pagar`, `processar_retorno_bancario`, `reservar_remessa_cnab`, `criar_transacao_da_parcela_projeto`, `get_dashboard_crm_by_closing`, `auditoria_registrar_acao`, `aplicar_xml_connect_orcamentos`, `carregar_connect_reserva_ambiente`, `desvincular_orcamento_connect`, `ligar_projeto_connect`.
- **Views:** `v_cash_flow_lucenera`, `v_financeiro_realizado`, `vw_conferencia_financeira`, `vw_contas_pagar_pedidos_compra`, `vw_financeiro_integridade`, `vw_transacoes_completas` (citam `negociacoes`/`transacoes`); `vw_fluxo_caixa_projetado`, `vw_orcamentos_aprovacao_financeira_auditoria` (leem parcelas); `vw_comissao_mensal` (comissão).
- **16 scripts Python:** `importar_contas_pagar_receber`, `conferencia_diaria_financeiro`, `bater_supabase_financeiro`, `auditar_financeiro_vs_planilha`, `carregar_espelho_contas_connect`, `conferir_contas_pagar_receber`, `corrigir_campos_financeiro_planilha`, `corrigir_empresa_negociacoes_financeiro`, `corrigir_pessoas_financeiro`, `corrigir_receitas_copia_de_despesa`, `preencher_conta_projeto_financeiro`, `classificar_perfil_sao_paulo`, `importar_propostas_connect_rascunho`, `importar_reserva_entrega_futura_connect`, `importar_separacoes_lovable`, `reverter_orcamentos_teste`. Os de importação/correção da planilha **deixam de existir** (importador já travado pelo marco); os de conferência viram a conferência de integridade do sistema novo.
- **Chaves estrangeiras que apontam para as tabelas antigas:** `retorno_bancario_registros` (→ `boletos`, `projeto_parcelas`, **`transacoes` sem cascata**), `notas_fiscais` (→ `boletos`), `boletos` (→ `projeto_parcelas`), `transacoes` (→ `negociacoes`; → `projeto_parcelas` `ON DELETE SET NULL`), `projeto_parcelas` (→ `transacoes`), `projeto_sinal` (→ `transacoes`), `custos_recorrentes_lancamentos` (→ `transacoes`). Gatilho `trg_projeto_parcela_financeiro` e sequência `seq_cod_duplicata_nativa` (começa em **900000**, para não colidir com os números da Connect).

**Regras do legado que a migração herda (de `scripts/AGENTS.md` e decisões anteriores):** nunca apagar (cancelar com `status_pago = 2`); `LUCE NERA` = MANOELLA; **DEV TROCA = devolução** (505 títulos, R$ 1,79 mi, decisão de 07/10); duplicata presente em mais de uma empresa vale a MANOELLA/mais antiga (`rn = 1` da view); o importador da planilha e os corretores estão **travados pelo marco** (05/11/2026 19h01); em imports antigos despesas (COMPRAS-REVENDA, RT, RETIRADA DE LUCRO, ICMS) foram coladas dentro de negociações de receita (corrigido em parte; os 20 títulos de RT em receita são resquício).

## 9. Decisões de negócio pendentes (com recomendação)

1. **Receita prevista × firme:** prevista na aprovação da equipe; firme na aprovação financeira (**recomendado**).
2. **Despesa de compra:** necessidade = prevista; pedido aprovado = prevista; NF de entrada = firme e **substitui** (**recomendado**).
3. **RT do arquiteto (a maior ponta solta):** percentual — por arquiteto, por venda ou por projeto? base (bruto, líquido, sem frete, recebido)? quando paga — **A proporcional ao recebimento (recomendada)**, B só com a venda 100% recebida, C total na aprovação? na devolução/cancelamento o RT é reduzido/estornado? pago com NF do arquiteto? **Precisa do usuário contar como funciona na prática** (o histórico não permite deduzir).
4. **Folha** como título a pagar por funcionário/mês, só RH (**recomendado**); migrar as 49 folhas antigas como já pagas ou começar do mês atual?
5. **Comissão** sobre o **recebido**, proporcional a cada parcela, paga pela folha (**recomendado**) × sobre o vendido (como a view faz hoje).
6. **Uma tabela de títulos com `natureza` + duas views** (**recomendado**) × duas tabelas separadas.
7. **Migrar o legado da Connect** para o modelo novo (**recomendado**, ids `legado_*` imutáveis) × deixar nas tabelas antigas só para consulta.
8. **Crédito de devolução:** título com valor negativo compensado por baixa `compensacao` (**recomendado**) × abater direto nas parcelas.
9. **Dados com defeito do legado:** migrar marcando `inconsistente` sem alterar valor e listar na fila (**recomendado**).
10. **Retirada de lucro, aporte, transferência entre contas:** retirada segue como despesa com classificação própria (como hoje); transferência e conciliação por extrato ficam para fase posterior (**recomendado**).
11. **Pendências do legado:** migrar tudo com cada exceção na fila; o Financeiro resolve as que têm solução (plano de contas, conta bancária, pessoa) e o **administrador aceita com motivo** as que não têm (RT sem venda, parcelas de abril); migração "fechada" só com **zero pendências abertas** (**recomendado**) × resolver tudo antes de migrar.

## 10. Migração em fases (cada uma só com autorização)

0. **Decidir** a seção 9 e aprovar a SPEC (refeita a análise).
1. **Criar** tabelas, enums, funções e views novas **vazias** (ensaio com ROLLBACK). Nada muda para ninguém.
2. **Copiar o legado** com backup no schema `backup`: `negociacoes` → títulos; `transacoes` → parcelas + baixas (parcela paga gera 1 baixa com data, valor pago, juros, desconto e forma; cancelada → cancelada; aberta → firme); `projeto_parcelas`, `boletos`, parcelas de pedido/NF, `folha_pagamento` etc. conforme o de-para; pendências na fila. **Conferência por tipo, situação, mês, empresa e perfil contra a baseline.** Divergiu, **não segue**.
3. **Compatibilidade:** tabelas antigas viram **views com os mesmos nomes**; sistemas, funções, views e scripts religados **um por vez** conferindo os números.
4. **Ligar as origens nativas:** orçamento (troca o destino do gatilho atual), compra/NF, manual, recorrentes, folha, RT e comissão.
5. **Telas novas** (Fluxo Futuro com 4 colunas) e remoção das estruturas antigas **só depois de um período sem leitura**.

Plano de volta atrás em cada fase: `rollback.sql` por migration e o "antes" no schema `backup`.

## 11. Riscos e pontos de atenção

- **Operação em paralelo com a Connect:** baixas feitas na Connect depois do marco **não entram** no sistema novo; a equipe baixa nos dois lados até a virada (SPEC-244/246).
- O financeiro **continua recebendo lançamentos** durante a análise (aprovação de orçamento gera título nativo): a baseline muda; comparar sempre pelo recorte "até o marco".
- `v_financeiro_realizado` filtra por `pode_acessar_sistema('dashboard-financeiro')` e usa o marco; a view de compatibilidade precisa **preservar essa regra** (RLS/portão), senão abre dado financeiro.
- Colunas sensíveis (folha, "salário por fora", comissão): visíveis só ao RH.
- `retorno_bancario_registros.transacao_id` **sem cascata**: a migração tem que religar antes de qualquer remoção.
- A migration 301 (`transacoes.previsao`) e a view `v_financeiro_realizado` já alteradas precisam entrar na migração de forma coerente.
- Número de duplicata não é único na Connect (2.768 códigos de parcela repetidos): nunca usar como chave.

## 12. Critérios de aceite globais

- Os 15 testes da seção 5.3 em **zero** (ou aceitos com motivo na fila); fila sem pendência **aberta**.
- Baseline reproduzida **exatamente** (18.316 linhas; R$ 75.203.769,77; 16.968 baixas; mesmos totais por tipo/situação/mês/empresa/perfil).
- Nenhum sistema quebra: dashboard e retorno-bancário funcionam sobre as views de compatibilidade antes de qualquer remoção.
- Toda tabela nova com RLS e `anon` sem acesso; funções só para quem tem acesso ao financeiro; folha/comissão só RH.
- Cada fase com ensaio ROLLBACK, `rollback.sql`, backup e registro no CHANGELOG.

## Checklist de Ação

- [x] Levantamento do banco (12 lugares, vínculos, defeitos, dependências, RT, comissão, folha) e anexo visual.
- [x] Script de linha de base reexecutável (`scripts/financeiro/baseline_spec258.sql`).
- [ ] **Refazer a análise com o modelo mais forte** (seção 0) e registrar divergências.
- [ ] Fechar as decisões da seção 9 com o usuário (**RT primeiro**).
- [ ] Aprovar a SPEC (versão final).
- [ ] Fase 1 — migrations vazias (ensaio) + autorização.
- [ ] Fase 2 — migração do legado com conferência de totais + autorização.
- [ ] Fase 3 — views de compatibilidade e religar consumidores.
- [ ] Fase 4 — origens nativas (orçamento, compra/NF, manual, recorrentes, folha, RT, comissão).
- [ ] Fase 5 — tela do Fluxo Futuro e remoção das estruturas antigas.

### Passos manuais do usuário

- [ ] Ler o anexo HTML e responder a seção 9 (principalmente como funciona o RT hoje na empresa).
- [ ] Trocar o modelo de IA e pedir a nova análise; autorizar cada migration separadamente.
- [ ] Combinar com o Financeiro quem resolve cada tipo de pendência do legado.

## Realizado

### 2026-11-06

- Levantamento completo no banco e escrita desta SPEC (v1 → v2 após a leitura do usuário): diagnóstico em 12 lugares, modelo de 4 tabelas + 2 de apoio, regras de identidade/sincronização, 15 testes, achados do RT/comissão/folha, inventário de dependências, de-para e fases.
- Anexo HTML para leitura (`SPEC-258_anexo_relatorio_visual_financeiro.html`), com decisões em aberto.
- Script de linha de base de leitura (`scripts/financeiro/baseline_spec258.sql`).
- Correções registradas durante a análise: eram 12 lugares (não 7); a origem do título precisa de **chave estrangeira real por origem** (não um id genérico); RT total R$ 1,81 mi (R$ 1,38 mi só a contato arquiteto); "9.714 negociações sem pessoa" era de 05/11 de manhã — hoje 1, mas com 1.734 de tipo incompatível.
- **Nada aplicado no banco além da migration 301 (já existente, intermediária).** Nada enviado ao GitHub depois do pedido de revisão do usuário.

## Pendências

- [ ] Nova análise independente do banco, com o modelo mais forte, antes de qualquer migration.
- [ ] Respostas do usuário à seção 9 (RT, folha, comissão e demais).
- [ ] Versão final da SPEC após a nova análise e as decisões.
