# SPEC-258 — Levantamento: quem usa o financeiro antigo e ordem de troca (06/11/2026)

Somente leitura (nada alterado). Estado: Fases 1A, 1B, 2 e 3 (passo 1) aplicadas; modelo novo tem o legado completo; ninguém lê o modelo novo ainda.

## 1. Quem LÊ hoje
| Quem | O que lê | Observação |
|---|---|---|
| Dashboard (`dashboard-lucenera`) `services/cash-flow.ts` | `v_financeiro_realizado` | Fonte do fluxo realizado, Contas a Pagar/Receber (Foco) e Index. **1 ponto de leitura**: trocar por `v_financeiro_realizado_novo` (mesmas colunas, 0 diferenças provadas, exceto 5 datas sem valor na Connect). |
| Dashboard `pages/Transacoes.tsx` | `transacoes` (2 consultas) | Tela de transações cruas; precisa de view compatível. |
| Dashboard `FluxoFuturo` / `services/pedidos-compra-futuro.ts` | `vw_contas_pagar_pedidos_compra`, `pedido_compra` | Previsão de compras: fonte à parte; entra no modelo novo como parcela **prevista** (Fase 4). |
| Retorno bancário `ConsultarDuplicatas`, `ContasEmAberto` | `transacoes` | Lê duplicatas em aberto. |
| Views do banco que leem `transacoes` | `v_cash_flow_lucenera`, `vw_conferencia_financeira`, `vw_contas_pagar_pedidos_compra`, `vw_financeiro_integridade` (antiga), `vw_transacoes_completas` | Cada uma precisa de equivalente ou de reescrita. |
| Scripts | `bater_supabase_financeiro.py`, `importar_contas_pagar_receber.py`, panorama | Importador está TRAVADO pelo marco de 05/11/2026 19:01 (não carrega mais). |

## 2. Quem ESCREVE hoje (o que impede a troca simples)
- **Retorno bancário** (`Boletos.tsx`, `CadastrarDuplicata.tsx`, `Index.tsx`): insere/atualiza `boletos`, `transacoes`, `projeto_parcelas`; função `processar_retorno_bancario`.
- **RPCs de dinheiro**: `aprovar_orcamento_financeiro`, `aprovar_projeto_financeiro` (orçamento aprovado → `transacoes`/`projeto_parcelas`), `gerar_parcelas_pedido_compra`, `atualizar_parcela_pedido_compra`, `cancelar_pedido_compra`, `cancelar_pagamento_antecipado`, `cancelar_entrada_nota_compra`.
- **CRM** (`services/projetos.ts`): atualiza `projeto_parcelas` direto.
- **RH** (`EmployeeFinance`, `Folha`): `folha_pagamento`, `funcionarios_financeiro`.

## 3. A conclusão que muda o plano
O importador da Connect está travado, então o **legado não muda mais sozinho**; mas o **sistema novo continua gravando no modelo antigo** (orçamento aprovado, pedido de compra, retorno bancário, baixa manual). Se o Dashboard passar a ler só o modelo novo **antes** dessas escritas apontarem para ele, tudo que for lançado depois de hoje **some do Dashboard**.

Portanto a ordem segura é: **primeiro a escrita (Fase 4), depois a leitura (Fase 3 passo 2)** — ou, se quiser trocar a leitura já, é preciso uma **ponte temporária** que espelhe no modelo novo cada gravação nova do modelo antigo (gatilho/rotina de sincronização), com prova diária de diferença zero.

## 4. Ordem proposta
1. **Fase 4a — Orçamento aprovado → título a receber** (função de porta única chamada por `aprovar_orcamento_financeiro`; sinal/parcelas previstas e firmes). Mantém `transacoes` em paralelo durante a transição (escreve nos dois) e valida diferença = 0.
2. **Fase 4b — Pedido de compra / nota de entrada → título a pagar** (parcelas previstas do pedido viram firmes na nota).
3. **Fase 4c — RT e comissão** (regras de repasse; depende da planilha de % de RT e da confirmação da nota fiscal do arquiteto) e **folha** (agregada no fluxo).
4. **Fase 3 passo 2 — Dashboard lê a view nova** (troca de 1 arquivo) quando 4a e 4b estiverem escrevendo nos dois modelos.
5. **Fase 5 — Retorno bancário e baixa manual** passam a usar `financeiro_baixar`/cobranças; telas de renegociação/estorno; depois aposentar a escrita em `transacoes`.

## 5. Decisão pedida
Escolher entre (A) seguir a ordem acima (recomendada: sem risco de dado sumir) ou (B) trocar a leitura do Dashboard já, com ponte temporária de sincronização (mais rápido para o usuário ver o novo, mais uma peça para manter).

## 6. Fase 4b — levantamento do "a pagar" nativo (07/11/2026, só leitura)
**Como o a pagar nativo funciona hoje (não passa por `transacoes`):**
- **Pedido de compra aprovado** → `pedido_compra_parcelas` = a PREVISÃO (26 pedidos aprovados, 82 parcelas pendentes, R$ 276.255,13; mais 2 recebidos). A view `vw_contas_pagar_pedidos_compra` mostra o "restante" de cada parcela depois de descontar notas de entrada e pagamentos antecipados (consumo proporcional, em ordem de parcela).
- **Nota de entrada** → `nota_fiscal_compra_parcelas` (3 hoje) → gatilho `fn_nota_compra_parcela_gera_contas_pagar` cria `boletos` com `tipo_operacao = 'CP'`, status Pendente (4 hoje, R$ 1.113,68). Ou seja, o "a pagar firme" nativo mora em `boletos`.
- **Pagamento antecipado** → `pagamentos_antecipados` + `pagamento_antecipado_vinculos` (0 hoje); abate o restante do pedido e a nota.
- Volume baixíssimo: dá para ligar com segurança, sem ponte pesada.

**Desenho proposto (4b):**
1. **Pedido aprovado** → título `pedido_compra` (a pagar, espécie `compra`) com parcelas **previstas** (uma por `pedido_compra_parcelas`, valor = restante). Pedido cancelado → título cancelado.
2. **Nota de entrada** → título `nota_fiscal_compra` (espécie `nota_compra`) com parcelas **firmes** (de `nota_fiscal_compra_parcelas`); no mesmo ato o título do pedido tem a previsão recalculada (`financeiro_substituir_previsao`: previstas antigas viram `substituida`, entram as novas com o restante). Nota cancelada → título cancelado e previsão restaurada.
3. **Pagamento antecipado** → título `adiantamento` + baixa de `compensacao` quando vinculado à nota.
4. **Baixa da nota (pagar)** → hoje é `boletos.status = 'Pago'`; vira `financeiro_baixar(... 'pagamento' ...)` (espelho do mesmo jeito da 4a: gatilho em `boletos` CP).
5. Prova: `vw_contas_a_pagar` x `vw_contas_pagar_pedidos_compra` + boletos CP = 0 diferenças; integridade da ponte estendida.

**Decisões do negócio que preciso confirmar antes de aplicar:** (a) a previsão do pedido deve mesmo diminuir quando a nota entra (como a view de hoje faz)? (b) quando a nota é paga e o pedido ainda tem restante, o restante continua previsto? (c) pedido "recebido" mantém parcelas previstas?
