---
titulo: "SPEC-154 — Integração Focus NFe (emissão real de Nota Fiscal a partir do sistema Vendas)"
status: não iniciado
data_ultima_modificacao: 2026-09-17
sistemas_envolvidos:
  - Vendas (sistema novo, ver SPEC-153) — consumidor da integração
  - Supabase (Edge Functions novas + colunas em `notas_fiscais`/`notas_fiscais_itens`/`produtos`)
  - Cadastro (cadastro-lucenera-b86fe) — dono do cadastro de `produtos`, possível responsável por preencher CFOP/NCM
dependencias:
  - SPEC-153 (cria `notas_fiscais_itens`, `notas_fiscais.cliente_id`/`nome_destinatario` — esta SPEC só adiciona colunas em cima dessa base)
  - SPEC-132 (campos fiscais de produtos — `ncm`, `cst`, `cest`, `tipo_fiscal`, `icms_entrada`, `ipi_entrada`, `porc_st` já existem e são reaproveitados aqui, não recriados)
---

# SPEC-154 — Integração Focus NFe (emissão real de Nota Fiscal a partir do sistema Vendas)

> Origem: mesma reunião da SPEC-153 ([31:36]-[34:53] — *"vai abrir já naquela API lá o negócio de nota"*, *"a CFAZ ia dar o retorno que a nota fiscal foi emitida"*) + decisão do usuário, tomada depois do rascunho original desta SPEC, de usar **Focus NFe** (`https://doc.focusnfe.com.br`) como provedor. Isto substitui a pendência antiga "decidir ferramenta/API de emissão de nota fiscal" registrada em `supabase/docs/ai_context_global.md` (linha 46) e `supabase/db/domains/financeiro.md`.

## Checklist de Ação

### Banco

- [ ] Migration (`supabase/db/migrations/20260917_154_focus_nfe_integracao/`), em cima da base criada pela SPEC-153:
  - `notas_fiscais.ambiente text NOT NULL DEFAULT 'homologacao' CHECK (ambiente IN ('homologacao','producao'))`.
  - `notas_fiscais.focus_nfe_ref text` — referência única gerada pelo NOSSO sistema (ex. o próprio `id` da nota em texto, ou `numero_venda || '-N' || sequencial`), usada para consultar/cancelar depois na API. `UNIQUE` quando não nulo.
  - `notas_fiscais.status_emissao text NOT NULL DEFAULT 'nao_emitida' CHECK (status_emissao IN ('nao_emitida','processando_autorizacao','autorizado','erro_autorizacao','cancelado'))`.
  - `notas_fiscais.chave_nfe text` — chave de acesso de 44 dígitos, preenchida quando `status_emissao = 'autorizado'`.
  - `notas_fiscais.caminho_xml text` — URL do XML retornado pela Focus NFe (o DANFE/PDF reaproveita a coluna já existente `notas_fiscais.arquivo_url`, sem duplicar).
  - `notas_fiscais.mensagem_erro text` — populada quando `status_emissao = 'erro_autorizacao'` (payload de erro da Focus NFe, `erros[{campo,mensagem}]` serializado).
  - `notas_fiscais.atualizado_via_webhook_em timestamptz` — última vez que o webhook atualizou o status.
  - **Não** cria `numero`/`serie`/`valor`/`data_emissao` novos — `notas_fiscais` já tem `numero_nf`, `serie`, `valor`, `data_emissao`; a resposta da Focus NFe passa a preencher essas colunas existentes em vez de duplicá-las.
  - `notas_fiscais_itens.cfop_aplicado text NOT NULL` (default vazio até implementar, ou `NOT NULL` só depois do backfill) — snapshot do CFOP realmente enviado à SEFAZ para aquele item nessa nota específica. É um dado de auditoria fiscal legítimo (não é duplicação indevida): o CFOP "sugerido" pode mudar de regra no futuro, mas o que foi de fato declarado numa nota já emitida não pode.
  - `produtos.cfop_padrao text` nullable — valor de pré-preenchimento editável por nota/item na tela de emissão (ver "Gap de CFOP" abaixo). **Não** cria coluna de NCM nova — `produtos.ncm` já existe (SPEC-132).
- [ ] Não propor nenhuma tabela de "token por empresa" no banco relacional — tokens Focus NFe são segredo, devem viver em Supabase Secrets (Edge Function env), nunca em coluna de tabela. Ver "Gap de múltiplas empresas emissoras" abaixo.

### Edge Functions novas

- [ ] `emitir-nota-fiscal` (chamada pelo frontend de Vendas, autenticada): recebe `nota_fiscal_id` (já criado como rascunho pela RPC da SPEC-153, com itens e pagador definidos), monta o payload Focus NFe a partir de:
  - Emitente: `orcamentos.empresa_id → empresas` (CNPJ, nome, endereço, IE, `regime_tributario` — já existem; falta `codigo_municipio` IBGE, ver gap abaixo).
  - Destinatário: `notas_fiscais.cliente_id → contatos` (ou `nome_destinatario` texto livre quando não há cadastro — nesse caso a Focus NFe pode exigir um CPF/CNPJ mínimo; se o pagador realmente não tiver documento, a nota não pode ser uma NFe fiscalmente válida para SEFAZ — **decisão do usuário necessária, não decidida aqui**: bloquear emissão real sem CPF/CNPJ do pagador, ou permitir e registrar como "nota interna" sem valor fiscal, replicando o "espelho" manual que ele descreveu na reunião).
  - Itens: `notas_fiscais_itens → orcamento_itens → produtos`, usando `produtos.ncm` (já existe) e `cfop_aplicado` calculado (ver abaixo).
  - `POST /v2/nfe?ref=<focus_nfe_ref>` via HTTP Basic Auth (token como usuário, senha vazia), ambiente definido por `notas_fiscais.ambiente` (URL base `homologacao.focusnfe.com.br` ou `api.focusnfe.com.br`, sempre com prefixo `/v2`).
  - Trata resposta síncrona (HTTP 201, `status: autorizado`) atualizando `notas_fiscais` direto; trata resposta assíncrona (HTTP 202, `processando_autorizacao`) deixando o status pendente até o webhook confirmar.
  - Trata erro HTTP 422 (`erros[{campo,mensagem}]`) gravando em `mensagem_erro` e `status_emissao = 'erro_autorizacao'`, sem derrubar a UI.
- [ ] `focus-nfe-webhook` (endpoint público, sem autenticação Supabase — validar pelo `focus_nfe_ref` presente no corpo): recebe atualização de status da Focus NFe, localiza a nota por `focus_nfe_ref`, atualiza `status_emissao`, `chave_nfe`, `numero_nf`, `serie`, `caminho_xml`, `arquivo_url` (DANFE), `atualizado_via_webhook_em`. Focus NFe não documenta assinatura HMAC no material levantado — validar contra `https://doc.focusnfe.com.br/reference/webhooks` antes de implementar; na ausência de assinatura, validar pelo menos que o `ref` recebido corresponde a uma nota em `status_emissao = 'processando_autorizacao'` antes de aceitar a atualização.
- [ ] Ambas as functions seguem a regra já documentada em `supabase/functions/README.md` ("toca o mundo externo → Edge Function", nunca chamar API externa direto do frontend, pra não expor o token no browser).

### Gap de CFOP (não decido a regra completa sozinho)

- **Estado atual**: `FiscalSummaryDialog.tsx` (Orçamentos) já calcula um CFOP simplificado (`5405` se `produtos.porc_st > 0`, senão `5102`) — cobre só operação dentro do estado (SP→SP), não trata interestadual (6xxx) nem finalidades especiais (garantia, devolução, permuta — já tratadas como natureza de operação distinta em `orcamentos.natureza_operacao`/SPEC-071/152).
- **Proposta desta SPEC**: calcular um CFOP sugerido na Edge Function `emitir-nota-fiscal`, comparando UF do emitente (`empresas.estado`) com UF do destinatário (`contatos.estado`/`estado_comercial`) para decidir prefixo `5` (dentro do estado) ou `6` (fora do estado), combinado com `produtos.porc_st` para o sufixo — e **sempre deixar editável por item na tela de emissão** antes de confirmar (o próprio usuário descreveu esse ajuste manual como parte do fluxo real: *"aqui, por exemplo, a gente poderia fazer tipo alguma alteração que precisasse fazer... na hora da nota mesmo"*, [33:22]).
- **Pendência explícita**: a tabela completa de CFOP (intra/interestadual × ST/não-ST × consumidor final × finalidade) precisa ser validada por quem cuida da parte fiscal (contador da Lucenera/Vinícius) antes de qualquer emissão em ambiente de produção real. Usar exclusivamente ambiente de homologação Focus NFe até essa validação acontecer.
- `produtos.cfop_padrao` (coluna nova) serve como override fixo opcional por produto, para os casos em que a regra automática não se aplica (decisão de quem cadastra o produto — provavelmente Débora, já responsável pelo cadastro de produtos segundo a reunião, mas **não decidido aqui**).

### Gap de endereço fiscal do emitente (IBGE)

- `empresas` não tem coluna de código de município IBGE, exigido pela Focus NFe no endereço do emitente. `contatos.ibge_cidade` existe (achado no schema), mas não há coluna equivalente em `empresas`. Migration desta SPEC deve incluir `empresas.codigo_municipio_ibge text` nullable, a ser preenchido manualmente pelo usuário para cada empresa emissora antes da primeira emissão real.

### Gap de múltiplas empresas emissoras

- `orcamentos.empresa_id` pode apontar para mais de uma empresa do grupo (Foco/Manoella/Islight, conforme achado da SPEC-144). Cada CNPJ emissor real normalmente precisa de cadastro e token próprios na Focus NFe. Esta SPEC não define ainda como mapear `empresa_id → qual secret de token usar` — proposta: um secret por empresa nomeado de forma previsível (ex. `FOCUS_NFE_TOKEN_<slug_empresa>_HOMOLOGACAO`), resolvido na Edge Function a partir de `empresas.codigo` ou `empresas.cnpj`. **Decisão final de nomenclatura/estrutura fica para quando o usuário tiver as contas Focus NFe criadas** (ver Passos manuais).

### Ambiente

- Toda emissão desta SPEC roda em **homologação Focus NFe** (`notas_fiscais.ambiente = 'homologacao'`, documentos sem validade fiscal) até o usuário confirmar explicitamente a virada para produção — a mudança é uma troca de secret/config, não de código.

### Passos manuais do usuário

- [ ] **Criar conta Focus NFe**, obter token de homologação (e de produção quando for a hora).
- [ ] **Cadastrar o(s) CNPJ(s) das empresas emissoras** (Foco/Manoella/Islight, conforme aplicável) no painel Focus NFe; providenciar certificado digital A1 se exigido pelo provedor para emissão real.
- [ ] **Configurar os secrets no Supabase** (`supabase secrets set FOCUS_NFE_TOKEN_...`) — nunca commitar token em código ou `.env` versionado.
- [ ] **Registrar a URL do webhook** (`POST /v2/webhooks` no painel Focus NFe) apontando para a Edge Function `focus-nfe-webhook`, depois que ela estiver deployada (URL só existe depois do deploy).
- [ ] **Preencher `empresas.codigo_municipio_ibge`** para cada empresa emissora, depois da migration aplicada.
- [ ] **Validar com contador/Vinícius a tabela de CFOP** antes de emitir a primeira nota real (mesmo em homologação, o objetivo é já simular o CFOP correto).
- [ ] **Decidir a política de pagador sem CPF/CNPJ** em nota parcial (bloquear emissão real ou manter como "nota interna"/espelho, replicando o processo manual atual) — ver Checklist, Edge Function `emitir-nota-fiscal`.
- [ ] Aplicar as migrations desta SPEC.
- [ ] Testar emissão ponta a ponta em homologação com um orçamento de teste antes de liberar para uso real.

## Objetivo

Substituir a pendência crônica "decidir ferramenta/API de emissão de nota fiscal" por uma integração real com Focus NFe, acionada a partir do sistema Vendas (SPEC-153): montar o payload fiscal a partir de dados já existentes no banco (empresa emitente, cliente/pagador, itens do orçamento), emitir via Edge Function (nunca do frontend, para não expor o token), tratar resposta síncrona/assíncrona e atualizar o status da nota via webhook.

## Decisões aprovadas

- Provedor escolhido: **Focus NFe** (decisão do usuário, comunicada fora da reunião gravada, registrada nesta reescrita).
- Ambiente de homologação até confirmação explícita de virada para produção.
- Emissão sempre via Edge Function (nunca token exposto no frontend) — consistente com a regra já documentada em `supabase/functions/README.md`.
- `produtos.ncm` já é a fonte correta de NCM (SPEC-132) — não recriar essa coluna.

## Definição da SPEC

Ver Checklist — já inclui o desenho completo (schema, Edge Functions, gaps de CFOP/IBGE/multi-empresa).

## Análise de ecossistema (obrigatória)

- **Depende de `orcamentos`, `contatos`, `produtos`, `orcamento_itens`, `boletos`?** Sim — `orcamentos.empresa_id` (emitente), `contatos` (destinatário), `produtos.ncm`/`cfop_padrao` (itens), `orcamento_itens`/`notas_fiscais_itens` (granularidade fiscal). Não depende de `boletos` diretamente (nota e boleto são independentes, conforme regra "boleto sem nota é permitido").
- **Afeta CRM, Orçamentos, Financeiro, Cadastro, Estoque/Compras, Logística, RH, Hub/TI?** Vendas (principal), Cadastro (possível responsável por `produtos.cfop_padrao`, mesma pessoa que já cuida de NCM/CST via SPEC-132 — provavelmente Débora, não confirmado).
- **Dado duplicado que deveria ser derivado?** `notas_fiscais_itens.cfop_aplicado` é intencionalmente um snapshot, não uma duplicação indevida — é o registro fiscal do que foi de fato declarado, que não pode mudar retroativamente mesmo que a regra de cálculo mude depois.
- **Migration antiga que contradiz o snapshot central?** Mesma observação da SPEC-153 — `supabase/db/current/` desatualizado, mas os campos fiscais de `produtos` (SPEC-132) já existem e batem com o que esta SPEC reaproveita.
- **Exige atualizar `AI_DB_CONTEXT.md`?** Sim — do sistema Vendas (assim que existir) e do domínio `supabase/db/domains/financeiro.md` (a pendência "decidir API de emissão de nota fiscal" deixa de existir, referenciar esta SPEC).
- **Padrão de acesso a dados**: Edge Functions novas seguem o padrão já estabelecido (`generate-report`, `process-remittance`) — lógica de integração externa isolada em Deno, nunca no frontend.

## Realizado

_(nada implementado — SPEC nova)_

## Pendências

- [ ] Tabela completa de CFOP (intra/interestadual, ST, finalidade) precisa validação de quem cuida da parte fiscal antes de emissão real — não decidido pelo planner por ser regra de negócio/fiscal sensível.
- [ ] Política de pagador sem CPF/CNPJ em nota parcial (bloquear emissão real vs. manter como nota interna/espelho) — decisão do usuário.
- [ ] Estrutura de múltiplos tokens Focus NFe por empresa emissora — desenho proposto, não fechado; depende de quantas empresas o usuário vai efetivamente cadastrar na Focus NFe.
- [ ] Confirmar assinatura/validação do webhook Focus NFe contra a documentação oficial antes de implementar (`https://doc.focusnfe.com.br/reference/webhooks`) — não bloqueante para o desenho, mas necessário antes do código.
- [ ] Quem preenche `produtos.cfop_padrao` por produto — provavelmente Débora (mesma pessoa da SPEC-132), não confirmado.
- [ ] Confirmar cobertura real de preenchimento de `produtos.ncm` (percentual de produtos com valor não nulo) antes de assumir que o cadastro fiscal está pronto para emissão em massa — verificação manual (SELECT de conferência), não posso rodar isso como planner.
