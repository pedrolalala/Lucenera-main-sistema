---
titulo: "SPEC-165 — Correções da Administração Bancária (CNAB remessa/retorno, duplicatas) + JSON da NF-e (Focus)"
status: "IMPLEMENTADA (28/09/2026) — Fases 1 e 2 aplicadas e publicadas (Adm. Bancária Skip 36395 v0.0.75);
  Fase 3 gravada no Skip 59346, Edge Function emitir-nota-fiscal AINDA NÃO deployada (deploy manual). Incidente
  de reexecução de migration legada revertido (migration 20260928_165)."
data_ultima_modificacao: 2026-09-28
sistemas_envolvidos:
  - Administração Bancária (`retorno-bancario-bradesco-5392a`, Skip 36395) — Fases 1 e 2
  - Vendas (`vendas-lucenera`, Skip 59346) — Fase 3 (payload Focus NFe)
  - Supabase central — contas_bancarias, boletos, RPCs de remessa/retorno
fonte:
  - "Auditoria de 28/09/2026 (relatório: https://claude.ai/artifact/25CJLxqd617KVJKExh4mF5)"
relacionado: [SPEC-073, SPEC-116, SPEC-117, SPEC-153, SPEC-154, SPEC-164]
---

## Pedido (usuário, 28/09/2026)

> "vamos criar uma Spec com todos [os problemas] e corrigir o código!"

Auditoria completa da Administração Bancária (teste no Chrome + leitura do código REAL publicado no Skip + dados
reais do Supabase) antes de ligar o emissor Focus NFe. Todos os achados abaixo foram confirmados no código/banco.

---

## Fase 1 — Banco (migration `20260928_164_adm_bancaria_cnab`)

### 1.1 Dados de cobrança por conta bancária
`contas_bancarias` tem as 3 contas Bradesco (Luce Nera, Islight, Foco) mas `agencia`/`conta` vazios e nenhum
campo de cobrança. Novas colunas: `agencia_digito`, `conta_digito`, `carteira` (ex.: `09`),
`codigo_empresa_banco` (código da empresa/convênio Bradesco, 20 posições), `proximo_nosso_numero` (bigint,
sequência própria de 11 dígitos), `sequencial_remessa` (int, último enviado).

### 1.2 Boleto com nosso número bancário e pagador rastreável
Hoje `boletos.nosso_numero` é um identificador interno (`ORC-ORC0005-P1`, `DUP002`) — inválido pro banco. Novas
colunas: `nosso_numero_banco` (11 dígitos, atribuído na remessa, único), `conta_bancaria_remessa_id`,
`remessa_sequencial`, `contato_id` (FK `contatos`, pagador de duplicata manual).

### 1.3 RPC `reservar_remessa_cnab(p_conta_bancaria_id, p_boleto_ids)`
Atômica (trava a linha da conta): valida dados de cobrança, incrementa `sequencial_remessa`, atribui
`nosso_numero_banco` aos boletos que ainda não têm (reenvio mantém o mesmo número), devolve sequencial +
mapeamento. Evita dois arquivos com o mesmo sequencial ou o mesmo nosso número.

### 1.4 RPC `processar_retorno_bancario` reescrita
Bugs confirmados na função atual:
- grava `status = 'pago'` (minúsculo); as telas testam `'Pago'` → boleto pago continua "em aberto";
- trata TODA linha como pagamento (inclusive 02 entrada confirmada, 03 rejeitada, 09 baixa);
- pagamento com juros (recebido > valor) vira "divergente" e nunca é baixado;
- reprocessar boleto já pago cria outra `transacoes` (status `ja_processado` existe e nunca é usado);
- casa só por `nosso_numero` interno.
Nova regra: casa por `nosso_numero_banco` e depois `nosso_numero`; liquidação = ocorrências 06/15/17; recebido ≥
valor → aplica (diferença vai em `juros_multa`); recebido < valor → divergente; já `Pago` → `ja_processado`;
02 → `status='Registrado'`; 03 → registra rejeição com motivo; demais → registra sem alterar o boleto.

---

## Fase 2 — Administração Bancária (frontend)

### 2.1 Remessa CNAB 400 (crítico)
`cnab-generator.ts` era esqueleto: código da empresa, agência/conta/carteira, ocorrência, espécie, emissão,
CPF/CNPJ, endereço e CEP do pagador em branco; nome do pagador na posição 317; nosso número sem DV; sequencial
fixo 0000001. Reescrito no layout Bradesco cobrança 400 (header/detalhe tipo 1/trailer), com DV do nosso número
(módulo 11, base 7, sobre carteira + nosso número). `Remessa.tsx`: escolher a conta de cobrança, editar dados de
cobrança da conta, validar pagador (CPF/CNPJ, endereço, CEP) antes de gerar, reservar sequencial/nosso número via
RPC, e só marcar "Remessa Enviada" com checagem de erro.

### 2.2 Retorno CNAB 400 (crítico)
`cnab-parser.ts` lia nosso número em 74–83 (correto 71–82), "data de pagamento" num trecho que é nº do documento
(correto: data da ocorrência 111–116 / crédito 296–301) e valor do título em 127–139 (correto 153–165). Reescrito.
`RetornoBoletos.tsx`: contas vindas de `contas_bancarias` (não fixas "LUCENERA/ISLIGHT/SLIDE").

### 2.3 Editar duplicata (crítico)
Edição apagava e recriava parcelas (perdia baixa, zerava o nome do pagador, duplicava se a exclusão falhasse).
Agora: atualiza cada parcela existente no lugar, insere só as novas, remove só as retiradas e ainda não pagas;
parcela paga não é alterada; pagador recarregado (`contato_id`); erro de exclusão tratado; "Dia 31" limitado ao
último dia do mês.

### 2.4 Consultar Duplicatas
Abre em "Receber"; empresas do banco (não "FOC/SLIDE/LUCENERA"); filtros Venda/Fatura/Boleto funcionando e
"Funcionário 430" removido; colunas Par./Tot./Venda/Fatura/Emissão com dado real; painel "Baixado" mostra a baixa
da duplicata selecionada; grade com altura mínima (notebook mostrava 1 linha); carga paginada (>1000).

### 2.5 Baixa
"Executar" e "Baixar Duplicata" recusam duplicata já paga; Exportar→Baixar carrega as duplicatas pelos ids
recebidos (antes caía em "Pagar" e dizia "0 baixada(s)" como sucesso); coluna "Duplicata" consistente.

### 2.6 Controle de Boletos
Salvar confere erro do banco; excluir usa diálogo próprio (não `confirm()`) e bloqueia boleto de venda aprovada
já enviado/pago.

---

## Fase 3 — JSON da NF-e (Vendas → Focus NFe)

Implementado (sem decidir regra fiscal nova): `formas_pagamento` (obrigatório na NF-e 4.00, a partir de
`orcamentos.forma_pagamento`), `consumidor_final` (destinatário sem IE), `local_destino` (UF emitente × UF
destinatário), `cest`, `email_destinatario` (`valor_frete` ficou de fora: em nota parcial não se sabe a fração do
frete que cabe a cada nota — decisão pendente); bloqueio explícito quando
`empresas.regime_tributario` está vazio (sem regime não dá pra saber CST × CSOSN).

**Pendente de decisão do contador (não implementar às cegas):** regime de cada empresa; tabela de CFOP
interestadual e DIFAL; CST de PIS/COFINS; campos IBS/CBS (obrigatórios desde 03/08/2026 para Lucro
Presumido/Real, jan/2027 para Simples); texto de informações complementares do Simples.

## Fora de escopo / decisões pendentes
- Base única de contas (`transacoes` do Connect × `boletos`) — decisão de arquitetura do usuário.
- Onde fica a emissão de NF-e (Vendas, pela SPEC-153, ou Administração Bancária).
- Layout oficial da carteira Bradesco: confirmar posições com o manual do banco antes da 1ª remessa real.
- Cadastro fiscal (CPF/CNPJ de clientes, CST/CSOSN e CEST de produtos, IE/IBGE das empresas).

## Publicação — atenção
O Skip 36395 carrega cópias ANTIGAS de Edge Functions (`generate-report` sem parcelas/digitador, `salvar-projeto`
sem SPEC-077, `sync-sharepoint`); publicar sem removê-las reverte produção (ver
feedback_skip_publish_redeploya_edge_functions_copias_velhas). Remover `supabase/functions/*` desse projeto antes
do apply.

## Critérios de aceite
- Remessa: arquivo de 400 posições por linha, header/detalhe/trailer no layout Bradesco, sequencial incrementa
  por arquivo, nosso número com DV, pagador completo; bloqueio claro quando falta dado.
- Retorno: um arquivo com ocorrência 06 baixa o boleto como `Pago`, grava juros quando houver, reprocessar não
  duplica; 02 marca `Registrado`.
- Editar duplicata com parcela paga preserva a baixa e o pagador.
- Consultar Duplicatas abre com dados, filtros reais funcionam.

---

## Realizado (28/09/2026)

**Banco** — `20260928_164_adm_bancaria_cnab` aplicada (dry-run com cenário antes): colunas de cobrança em
`contas_bancarias`, `boletos.nosso_numero_banco/conta_bancaria_remessa_id/remessa_sequencial/contato_id`,
RPC `reservar_remessa_cnab`, `processar_retorno_bancario` reescrita. Teste: 02 → Registrado; 06 com R$ 2,50 a mais →
Pago + juros 2,50; reprocessar → não duplica (1 transação); reserva: sequencial 1 → 2, reenvio mantém o nosso número.

**Adm. Bancária** — gerador e leitor CNAB 400 reescritos (29 testes automatizados OK, inclusive o DV do exemplo do
manual Bradesco: carteira 19 / 00000000002 → 8); Remessa com conta de cobrança + diálogo "Dados de cobrança";
Retorno com contas do banco e datas certas; edição de duplicata no lugar; Consultar/Baixar/Boletos corrigidos.
Publicado v0.0.75. Cópias antigas de Edge Functions removidas do Skip 36395 (nenhuma função no ar mudou).

**Vendas (Fase 3)** — JSON com `formas_pagamento`, `consumidor_final`, `local_destino`, `regime_tributario_emitente`,
`cest`, `email_destinatario`; bloqueios explícitos para regime vazio, venda interestadual e CST × CSOSN incoerente
(testado com 4 cenários). `valor_frete` NÃO enviado (nota parcial não sabe a fração do frete — decisão pendente).
Gravado no Skip 59346 v0.0.13; a integração do Skip não publica funções neste projeto → **deploy manual pendente**.

### Incidente durante a publicação (revertido)
A 1ª aplicação no Skip 36395 reexecutou no banco real duas migrations legadas nunca registradas. Uma delas
(`20260623190000_billing_automation`) inseriu dados de teste (empresa, projeto PRJ-BILL, 2 parcelas, 1 orçamento,
2 itens), criou o bucket público `notas_fiscais` e recriou 4 policies permissivas que a SPEC-069 tinha removido.
Revertido por `20260928_165_reverter_reexecucao_billing_automation` (dados apagados, policies removidas de novo).
O projeto de teste NÃO chegou ao SharePoint. Pendente: apagar o bucket vazio `notas_fiscais` pela Storage API
(bloqueado para o assistente). Causa: toda publicação no Skip executa migrations de `supabase/migrations/` ainda não
registradas em `supabase_migrations.schema_migrations`. Retiradas do Skip: 1 em 36395, 3 em 32554 (a de 32554 fica
gravada na próxima aplicação). **Ainda pendentes (bombas-relógio):** RH (14), CRM (11), Logística (2).
