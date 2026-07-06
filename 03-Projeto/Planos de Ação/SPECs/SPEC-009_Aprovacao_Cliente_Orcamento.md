---
titulo: "SPEC-009 — Aprovação do Cliente no Orçamento"
status: não iniciado
data_ultima_modificacao: 2026-07-04
sistemas_envolvidos:
  - Orçamentos
  - Supabase (banco central)
---

# SPEC-009 — Aprovação do Cliente no Orçamento

## Checklist de Ação

- [ ] Adicionar 6 colunas em `orcamentos` para rastrear o ciclo de aprovação do cliente
- [ ] Criar índice em `token_aprovacao_cliente`
- [ ] Criar RPC `enviar_orcamento_para_cliente(p_orcamento_id)`
- [ ] Criar RPC `cliente_aprovar_orcamento(p_orcamento_id, p_token)`
- [ ] Criar RPC `cliente_recusar_orcamento(p_orcamento_id, p_token, p_motivo)`
- [ ] Adicionar guard em `aprovar_orcamento_financeiro_base_spec001` — bloquear se status ≠ `'aprovado_cliente'`
- [ ] Executar migration no Supabase (SQL Editor)
- [ ] Ajustar sistema de Orçamentos: botão "Enviar para cliente" que chama a RPC e exibe link/token

### Passos manuais do usuário

- [ ] Confirmar decisão sobre compatibilidade retroativa (ver Ponto em aberto P-03)
- [ ] Confirmar se token de aprovação expira ou não (ver Ponto em aberto P-01)
- [ ] Confirmar se ADM pode aprovar pelo cliente sem token (ver Ponto em aberto P-02)
- [ ] Executar migration no Supabase SQL Editor após revisão
- [ ] Testar fluxo completo em ambiente de homologação antes de ativar guard em produção

## Objetivo

Hoje o orçamento vai direto da elaboração para aprovação administrativa, sem que o cliente tenha formalmente aceitado. Isso reserva estoque e gera pendências financeiras para projetos ainda não confirmados.

Esta SPEC introduz a fase de **aprovação do cliente** como etapa obrigatória antes que a ADM possa processar financeiramente um orçamento. O cliente recebe um link com token único e registra a aceitação ou recusa. A ADM só consegue aprovar o orçamento financeiramente após o status atingir `'aprovado_cliente'`.

## Decisões aprovadas

_(a preencher após alinhamento dos pontos em aberto)_

## Definição da SPEC

### Estado atual do banco

| Item | Situação |
|---|---|
| `orcamentos.status` | `text`, default `'aguardando_aprovacao'` — aceita valores livres, sem enum |
| Status conhecidos hoje | `'aguardando_aprovacao'`, `'aprovado'`, `'cancelado'` |
| `historico_status_orcamentos` | Existe — registra cada mudança de status |
| Colunas de rastreio do cliente | **Não existem** em `orcamentos` |
| Guard na RPC de aprovação ADM | **Não existe** — qualquer status permite aprovação hoje |
| Modelo de referência | `orcamentos_revenda_ubiqua` já tem `enviado_em`, `aprovado_em`, `aprovado_por`, `rejeitado_em`, `motivo_rejeicao` |

### Máquina de estados proposta

```
aguardando_aprovacao
        │
        │  enviar_orcamento_para_cliente()
        ▼
enviado_cliente           ← enviado_cliente_em = now()
        │
        ├──── cliente_aprovar_orcamento()
        │         ▼
        │    aprovado_cliente  ← aprovado_cliente_em = now()
        │         │
        │         │  aprovar_orcamento_financeiro()  [já existente — com guard novo]
        │         ▼
        │       aprovado  → estoque reservado, parcelas, boletos
        │
        └──── cliente_recusar_orcamento()
                  ▼
             recusado_cliente  ← recusado_cliente_em + motivo_recusa_cliente
                  │
                  │  enviar_orcamento_para_cliente()  [reenvio após revisão]
                  ▼
             enviado_cliente  (novo token gerado)
```

Transições bloqueadas após esta SPEC:
- `aguardando_aprovacao` → `aprovado` direto: **PROIBIDO**
- `enviado_cliente` → `aprovado` direto: **PROIBIDO**
- `cancelado` continua sendo permitido de qualquer status

### Novas colunas em `orcamentos`

```sql
ALTER TABLE public.orcamentos
    ADD COLUMN IF NOT EXISTS enviado_cliente_em      timestamp with time zone,
    ADD COLUMN IF NOT EXISTS enviado_cliente_por     uuid REFERENCES auth.users(id),
    ADD COLUMN IF NOT EXISTS aprovado_cliente_em     timestamp with time zone,
    ADD COLUMN IF NOT EXISTS recusado_cliente_em     timestamp with time zone,
    ADD COLUMN IF NOT EXISTS motivo_recusa_cliente   text,
    ADD COLUMN IF NOT EXISTS token_aprovacao_cliente text UNIQUE;

CREATE INDEX IF NOT EXISTS idx_orcamentos_token_aprovacao
    ON public.orcamentos (token_aprovacao_cliente)
    WHERE token_aprovacao_cliente IS NOT NULL;
```

| Coluna | Tipo | Descrição |
|---|---|---|
| `enviado_cliente_em` | `timestamptz` | Quando foi enviado ao cliente (última vez) |
| `enviado_cliente_por` | `uuid → auth.users` | Usuário interno que enviou |
| `aprovado_cliente_em` | `timestamptz` | Quando o cliente aprovou |
| `recusado_cliente_em` | `timestamptz` | Quando o cliente recusou (mais recente) |
| `motivo_recusa_cliente` | `text` | Razão da última recusa |
| `token_aprovacao_cliente` | `text UNIQUE` | Token de uso único para o link de aprovação |

### RPC: `enviar_orcamento_para_cliente`

**Assinatura:**
```sql
CREATE OR REPLACE FUNCTION public.enviar_orcamento_para_cliente(
    p_orcamento_id uuid
) RETURNS jsonb
```

**O que faz:**
1. Valida que o orçamento existe e o status é `'aguardando_aprovacao'` ou `'recusado_cliente'`
2. Gera um `token_aprovacao_cliente` único (`gen_random_uuid()::text`)
3. Atualiza `status = 'enviado_cliente'`, `enviado_cliente_em = now()`, `enviado_cliente_por = auth.uid()`
4. Registra em `historico_status_orcamentos`
5. Retorna o token para o frontend montar o link de aprovação

**Retorno:**
```json
{
  "orcamento_id": "...",
  "numero": "ORC-0012",
  "status": "enviado_cliente",
  "token": "3f8a2b1c-...",
  "enviado_em": "2026-07-04T14:00:00Z"
}
```

**Erros:**
- `P0001` — Orçamento não encontrado
- `P0002` — Status não permite envio (ex: já `aprovado_cliente` ou `aprovado`)

---

### RPC: `cliente_aprovar_orcamento`

**Assinatura:**
```sql
CREATE OR REPLACE FUNCTION public.cliente_aprovar_orcamento(
    p_orcamento_id uuid,
    p_token        text
) RETURNS jsonb
```

**O que faz:**
1. Valida que `token_aprovacao_cliente = p_token` e status é `'enviado_cliente'`
2. Atualiza `status = 'aprovado_cliente'`, `aprovado_cliente_em = now()`
3. Limpa o token (`token_aprovacao_cliente = NULL`) — uso único
4. Registra em `historico_status_orcamentos`

**Retorno:**
```json
{
  "orcamento_id": "...",
  "numero": "ORC-0012",
  "status": "aprovado_cliente",
  "aprovado_em": "2026-07-04T15:00:00Z"
}
```

**Erros:**
- `P0001` — Token inválido ou orçamento não encontrado
- `P0002` — Status inválido (já aprovado, cancelado, etc.)

---

### RPC: `cliente_recusar_orcamento`

**Assinatura:**
```sql
CREATE OR REPLACE FUNCTION public.cliente_recusar_orcamento(
    p_orcamento_id uuid,
    p_token        text,
    p_motivo       text DEFAULT NULL
) RETURNS jsonb
```

**O que faz:**
1. Valida token e status `'enviado_cliente'`
2. Atualiza `status = 'recusado_cliente'`, `recusado_cliente_em = now()`, `motivo_recusa_cliente = p_motivo`
3. Limpa o token
4. Registra em `historico_status_orcamentos`

**Retorno:**
```json
{
  "orcamento_id": "...",
  "numero": "ORC-0012",
  "status": "recusado_cliente",
  "motivo": "Valor acima do orçado pelo cliente"
}
```

---

### Alteração em `aprovar_orcamento_financeiro_base_spec001`

Adicionar guard logo após carregar o orçamento:

```sql
IF v_orcamento.status <> 'aprovado_cliente' THEN
    RAISE EXCEPTION
        'Orçamento % não pode ser aprovado administrativamente: '
        'cliente ainda não aprovou. Status atual: %',
        v_numero_orcamento, v_orcamento.status
        USING ERRCODE = 'P0003';
END IF;
```

> Impacto: orçamentos existentes com `status = 'aguardando_aprovacao'` ficarão bloqueados. Ver compatibilidade retroativa abaixo.

---

### Regras de negócio

| # | Regra |
|---|---|
| RN-01 | Aprovação administrativa (estoque + parcelas + boletos) só é possível após `status = 'aprovado_cliente'` |
| RN-02 | Token de aprovação é de uso único — invalidado após qualquer uso (aprovar ou recusar) |
| RN-03 | Vendedor pode reenviar após recusa (`recusado_cliente → enviado_cliente`), gerando novo token |
| RN-04 | `cancelar_orcamento()` continua funcionando de qualquer status |
| RN-05 | Cada mudança de status deve ser registrada em `historico_status_orcamentos` |

---

### Compatibilidade retroativa

Os orçamentos já em `status = 'aprovado'` **não são afetados** — o guard só bloqueia a transição para `aprovado`, não registros já nesse estado.

Orçamentos em `status = 'aguardando_aprovacao'` ficarão bloqueados pelo guard. Opções:

| Opção | Descrição |
|---|---|
| **A (recomendada)** | Backfill: setar `status = 'aprovado_cliente'` nos orçamentos `aguardando_aprovacao` que já têm aprovação verbal confirmada |
| **B** | Ativar guard apenas para orçamentos criados após a data da migration (coluna `created_at`) |
| **C** | Ativar guard como `WARNING` primeiro, transformar em `EXCEPTION` após período de transição |

**Decisão a confirmar com Pedro antes de implementar (Ponto P-03).**

---

### Pontos em aberto

| # | Questão | Impacto |
|---|---|---|
| P-01 | Token de aprovação expira? Se sim, em quanto tempo? | Segurança do link enviado por e-mail/WhatsApp |
| P-02 | ADM pode marcar `aprovado_cliente` manualmente (sem token) para casos presenciais/verbais? | Operação do dia a dia |
| P-03 | O que fazer com orçamentos `aguardando_aprovacao` existentes quando o guard for ativado? | Compatibilidade retroativa — ver opções A/B/C acima |
| P-04 | Frontend gera e envia o e-mail/WhatsApp com o link, ou Supabase Edge Function envia automaticamente? | Escopo da implementação no sistema de Orçamentos |
| P-05 | Ao reenviar após recusa, cria nova versão numerada do orçamento ou reenvia o mesmo? | Rastreabilidade de versões |

---

### Tabelas afetadas

| Tabela | Operação | Detalhe |
|---|---|---|
| `orcamentos` | `ALTER TABLE` + `UPDATE` via RPCs | +6 colunas + índice |
| `historico_status_orcamentos` | `INSERT` | Uma linha por transição |
| `aprovar_orcamento_financeiro_base_spec001` | `CREATE OR REPLACE` | Guard de status |

Não afetadas: `estoque_itens`, `projeto_itens`, `projeto_parcelas`, `boletos`.

---

### Migration planejada

```
supabase/db/migrations/20260704_018_aprovacao_cliente_orcamento/
  001_add_colunas_aprovacao_cliente.sql    — ALTER TABLE orcamentos + índice
  002_rpc_enviar_orcamento_cliente.sql     — CREATE FUNCTION enviar_orcamento_para_cliente
  003_rpc_cliente_aprovar_recusar.sql      — CREATE FUNCTION cliente_aprovar/recusar_orcamento
  004_guard_aprovacao_financeira.sql       — CREATE OR REPLACE aprovar_orcamento_financeiro (guard)
  005_backfill_compatibilidade.sql         — (conforme decisão P-03)
  README.md
```

---

### Critérios de aceite

- [ ] Orçamento em `aguardando_aprovacao` não pode ser aprovado financeiramente sem passar por `aprovado_cliente`
- [ ] `enviar_orcamento_para_cliente()` gera token único, muda status e registra histórico
- [ ] `cliente_aprovar_orcamento()` com token válido muda status para `aprovado_cliente` e invalida o token
- [ ] `cliente_aprovar_orcamento()` com token inválido ou status errado lança exceção
- [ ] `cliente_recusar_orcamento()` registra motivo, invalida token e permite reenvio posterior
- [ ] Reenvio após recusa gera novo token
- [ ] Orçamento já em `aprovado` não é afetado pelas novas RPCs
- [ ] `cancelar_orcamento()` continua funcionando de qualquer status
- [ ] Cada transição aparece em `historico_status_orcamentos`

---

### Fluxo visual

```mermaid
flowchart TD
    A[Orçamento criado\nstatus: aguardando_aprovacao] --> B[enviar_orcamento_para_cliente]
    B --> C[status: enviado_cliente\ntoken gerado]
    C --> D{Cliente decide}
    D -->|Aprova| E[cliente_aprovar_orcamento\ntoken válido]
    D -->|Recusa| F[cliente_recusar_orcamento\n+ motivo]
    E --> G[status: aprovado_cliente\ntoken invalidado]
    F --> H[status: recusado_cliente\ntoken invalidado]
    H --> B
    G --> I[ADM: aprovar_orcamento_financeiro\nguard: exige aprovado_cliente]
    I --> J[status: aprovado\nEstoque reservado\nParcelas + Boletos criados]
```

## Realizado

_(a preencher após execução)_

## Pendências

- [ ] Alinhar pontos em aberto P-01 a P-05 com Pedro antes de iniciar a implementação.
- [ ] Definir abordagem de compatibilidade retroativa (P-03) e incluir no script de backfill.
- [ ] Após decisões, criar migration `20260704_018` e executar no Supabase.
- [ ] Ajustar sistema de Orçamentos: botão "Enviar para cliente", exibição de status e geração do link.
