# SPEC-009 — Prompt para Implementação no Frontend (Sistema de Orçamentos)

---

> **Bloqueio de reavaliação — 06/07/2026:** não executar este prompt literalmente. A SPEC-016 escolheu o contrato oficial `enviado_cliente -> Aprovação Financeira -> Orçamento Aprovado`, e a SPEC-017 substitui o desenho da aba financeira por um fluxo que edita o orçamento pelo mesmo modal/editor dos demais orçamentos.

## Contexto para o desenvolvedor

O Supabase foi atualizado com a SPEC-009: **Aprovação do Cliente no Orçamento**.
A aprovação do cliente agora é **obrigatória** antes da aprovação financeira/administrativa.

O frontend já possui as abas:
- **Todos** — lista geral
- **Aprovação do cliente** — aba existente a ser implementada
- **Aprovação Financeira** — aba existente a ser implementada
- **Aprovações** — histórico/aprovados

---

## O que mudou no banco

### Novos campos em `orcamentos`

| Campo | Tipo | Quando é preenchido |
|---|---|---|
| `enviado_cliente_em` | `timestamptz` | Quando o orçamento é enviado ao cliente |
| `enviado_cliente_por` | `uuid` | UUID do usuário que enviou |
| `aprovado_cliente_em` | `timestamptz` | Quando o cliente aprova |
| `recusado_cliente_em` | `timestamptz` | Quando o cliente recusa |
| `motivo_recusa_cliente` | `text` | Motivo da recusa |
| `token_aprovacao_cliente` | `text` | Token único para o link (apagado após uso) |

### Novos status em `orcamentos.status`

| Status | Significado |
|---|---|
| `aguardando_aprovacao` | Rascunho / em elaboração (status inicial, já existia) |
| `enviado_cliente` | Enviado — aguardando resposta do cliente |
| `Aprovação Financeira` | Cliente aprovou — pronto para aprovação financeira |
| `recusado_cliente` | Cliente recusou — precisa revisão e reenvio |
| `Orçamento Aprovado` | Aprovação financeira concluída |
| `cancelado` | Cancelado (já existia) |

Status legados/compatibilidade ainda encontrados no banco real em 06/07/2026 e que precisam de normalização pela SPEC-016:

| Status | Observação |
|---|---|
| `aprovado_cliente` | Desenho original da SPEC-009; deve virar `Aprovação Financeira` quando não houver efeitos financeiros |
| `aprovado` | Legado/compatibilidade; revisar conforme efeitos financeiros gerados |
| `aprovado_financeiro` | Legado/compatibilidade; deve normalizar para `Orçamento Aprovado` |

---

## Mapeamento de abas → status do banco

| Aba no frontend | Filtro por status | O que mostrar |
|---|---|---|
| **Todos** | todos (sem filtro) | Lista completa com badge colorido de status |
| **Aprovação do cliente** | `enviado_cliente` + `recusado_cliente` | Orçamentos aguardando ou que foram recusados pelo cliente |
| **Aprovação Financeira** | `Aprovação Financeira` | Orçamentos aprovados pelo cliente, prontos para aprovação financeira |
| **Aprovações** | `Orçamento Aprovado` | Orçamentos já aprovados financeiramente |

---

## RPCs disponíveis no Supabase

### 1. Enviar orçamento para o cliente

```typescript
const { data, error } = await supabase
  .rpc('enviar_orcamento_para_cliente', {
    p_orcamento_id: orcamento.id
  })

// Retorno:
// {
//   orcamento_id: "uuid",
//   numero: "ORC-0012",
//   status: "enviado_cliente",
//   token: "3f8a2b1c-...",   ← usar para montar o link
//   enviado_em: "2026-07-04T14:00:00Z"
// }
```

**Link de aprovação para enviar ao cliente:**
```
https://[sua-url]/aprovacao?orcamento_id={orcamento_id}&token={token}
```

**Status que permite chamar:** `aguardando_aprovacao`, `recusado_cliente`

---

### 2. Cliente aprova via link (rota pública)

```typescript
const { data, error } = await supabase
  .rpc('cliente_aprovar_orcamento', {
    p_orcamento_id: params.orcamento_id,
    p_token: params.token
  })

// Retorno em sucesso:
// Após SPEC-016:
// { status: "Aprovação Financeira", aprovado_em: "..." }

// Erro com token inválido: ERRCODE P0001
// Erro com status errado:  ERRCODE P0002
```

---

### 3. Cliente recusa via link (rota pública)

```typescript
const { data, error } = await supabase
  .rpc('cliente_recusar_orcamento', {
    p_orcamento_id: params.orcamento_id,
    p_token: params.token,
    p_motivo: "Valor acima do orçado"  // opcional
  })
```

---

### 4. ADM registra aprovação manual (presencial/verbal)

```typescript
// Usar quando o cliente aprovou por telefone/reunião, sem precisar de link
const { data, error } = await supabase
  .rpc('adm_aprovar_pelo_cliente', {
    p_orcamento_id: orcamento.id,
    p_observacao: "Cliente aprovou por telefone em 04/07/2026"
  })
```

**Status que permite chamar:** `aguardando_aprovacao`, `enviado_cliente`, `recusado_cliente`

---

### 5. Aprovação financeira (normalizada pela SPEC-016)

```typescript
// Só funciona se status = 'Aprovação Financeira'
// Se tentar com status diferente: ERRCODE P0003 com mensagem clara
const { data, error } = await supabase
  .rpc('aprovar_orcamento_financeiro', {
    p_orcamento_id: orcamento.id
  })
```

---

## Comportamento esperado por aba

### Aba "Aprovação do cliente"

Mostra orçamentos em: **`enviado_cliente`** e **`recusado_cliente`**

```typescript
const { data } = await supabase
  .from('orcamentos')
  .select('*, contatos(nome), projetos(codigo, nome)')
  .in('status', ['enviado_cliente', 'recusado_cliente'])
  .order('enviado_cliente_em', { ascending: false })
```

**Para cada orçamento, mostrar:**
- Badge de status: "Aguardando cliente" (enviado) / "Recusado" (recusado_cliente)
- Data de envio: `enviado_cliente_em`
- Motivo de recusa (se recusado): `motivo_recusa_cliente`
- Botão **"Reenviar"** (se `recusado_cliente`) → chama `enviar_orcamento_para_cliente`
- Botão **"Aprovar manualmente"** → chama `adm_aprovar_pelo_cliente`
- Botão **"Copiar link"** → monta e copia o link com o token

**Nota:** o `token_aprovacao_cliente` é retornado pela RPC `enviar_orcamento_para_cliente`.
Após o cliente usar o link, o token é apagado do banco. Para reenviar, chamar a RPC novamente (gera novo token).

---

### Aba "Aprovação Financeira"

Mostra orçamentos em: **`Aprovação Financeira`**

```typescript
const { data } = await supabase
  .from('orcamentos')
  .select('*, contatos(nome), projetos(codigo, nome)')
  .eq('status', 'Aprovação Financeira')
  .order('aprovado_cliente_em', { ascending: false })
```

**Para cada orçamento, mostrar:**
- Badge amarelo/laranja: "Aprovação Financeira"
- Data de aprovação do cliente: `aprovado_cliente_em`
- Botão **"Ver/Editar"** → abre o mesmo editor/modal de orçamento usado nos demais fluxos
- Botão **"Aprovar Financeiramente"** → chama `aprovar_orcamento_financeiro`

---

### Aba "Aprovações"

Mostra orçamentos em: **`Orçamento Aprovado`**

```typescript
const { data } = await supabase
  .from('orcamentos')
  .select('*, contatos(nome), projetos(codigo, nome)')
  .eq('status', 'Orçamento Aprovado')
  .order('updated_at', { ascending: false })
```

---

### Aba "Todos" — badges de status sugeridos

| Status | Cor | Label |
|---|---|---|
| `aguardando_aprovacao` | Cinza | Em elaboração |
| `enviado_cliente` | Azul | Aguardando cliente |
| `Aprovação Financeira` | Amarelo/Laranja | Aprovação Financeira |
| `recusado_cliente` | Vermelho claro | Recusado pelo cliente |
| `Orçamento Aprovado` | Verde | Aprovado |
| `aprovado_cliente` | Amarelo/Laranja | Legado: tratar como Aprovação Financeira durante migração |
| `aprovado` / `aprovado_financeiro` | Verde | Legado: tratar conforme normalização da SPEC-016 |
| `cancelado` | Cinza escuro | Cancelado |

---

## Fluxo de ações — botões sugeridos por status

| Status atual | Ações disponíveis |
|---|---|
| `aguardando_aprovacao` | "Enviar para cliente" / "Aprovar manualmente" / "Cancelar" |
| `enviado_cliente` | "Aprovar manualmente" / "Copiar link" / "Cancelar" |
| `recusado_cliente` | "Reenviar para cliente" / "Aprovar manualmente" / "Cancelar" |
| `Aprovação Financeira` | "Ver/Editar" / "Aprovar Financeiramente" / "Cancelar" |
| `Orçamento Aprovado` | (somente leitura) / "Cancelar" |
| `cancelado` | (somente leitura) |

---

## Tratamento de erros das RPCs

| Código | Causa | Mensagem para o usuário |
|---|---|---|
| `P0001` | Orçamento não encontrado ou token inválido | "Link inválido ou expirado." |
| `P0002` | Status não permite a ação | Exibir mensagem da exceção (já é amigável) |
| `P0003` | Guard: cliente não aprovou ainda | "O cliente precisa aprovar antes da aprovação financeira." |

---

## Rota pública de aprovação (página do cliente)

Criar uma rota pública (sem login) para o cliente aprovar/recusar:

```
/aprovacao-orcamento?orcamento_id=UUID&token=TOKEN
```

Essa página deve:
1. Carregar as informações básicas do orçamento (número, valor, cliente, itens)
2. Exibir botões "Aprovar" e "Recusar"
3. Se recusar: pedir campo de texto para motivo (opcional)
4. Chamar `cliente_aprovar_orcamento` ou `cliente_recusar_orcamento`
5. Mostrar tela de confirmação após a ação

**Segurança:** a RPC valida o token — sem token válido, a ação falha. Não é necessário autenticação do cliente.
