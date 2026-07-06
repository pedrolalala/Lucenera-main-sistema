# SPEC-009 — Prompt para Implementação no Frontend (Sistema de Orçamentos)

---

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
| `aprovado_cliente` | Cliente aprovou — pronto para aprovação financeira |
| `recusado_cliente` | Cliente recusou — precisa revisão e reenvio |
| `aprovado` | Aprovação financeira concluída (já existia) |
| `cancelado` | Cancelado (já existia) |

---

## Mapeamento de abas → status do banco

| Aba no frontend | Filtro por status | O que mostrar |
|---|---|---|
| **Todos** | todos (sem filtro) | Lista completa com badge colorido de status |
| **Aprovação do cliente** | `enviado_cliente` + `recusado_cliente` | Orçamentos aguardando ou que foram recusados pelo cliente |
| **Aprovação Financeira** | `aprovado_cliente` | Orçamentos aprovados pelo cliente, prontos para aprovação ADM |
| **Aprovações** | `aprovado` | Orçamentos já aprovados financeiramente |

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
// { status: "aprovado_cliente", aprovado_em: "..." }

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

### 5. Aprovação financeira (já existia — agora com guard)

```typescript
// Só funciona se status = 'aprovado_cliente'
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

Mostra orçamentos em: **`aprovado_cliente`**

```typescript
const { data } = await supabase
  .from('orcamentos')
  .select('*, contatos(nome), projetos(codigo, nome)')
  .eq('status', 'aprovado_cliente')
  .order('aprovado_cliente_em', { ascending: false })
```

**Para cada orçamento, mostrar:**
- Badge verde: "Aprovado pelo cliente"
- Data de aprovação do cliente: `aprovado_cliente_em`
- Botão **"Aprovar Financeiramente"** → chama `aprovar_orcamento_financeiro`

---

### Aba "Aprovações"

Mostra orçamentos em: **`aprovado`**

```typescript
const { data } = await supabase
  .from('orcamentos')
  .select('*, contatos(nome), projetos(codigo, nome)')
  .eq('status', 'aprovado')
  .order('updated_at', { ascending: false })
```

---

### Aba "Todos" — badges de status sugeridos

| Status | Cor | Label |
|---|---|---|
| `aguardando_aprovacao` | Cinza | Em elaboração |
| `enviado_cliente` | Azul | Aguardando cliente |
| `aprovado_cliente` | Amarelo/Laranja | Aprovado pelo cliente |
| `recusado_cliente` | Vermelho claro | Recusado pelo cliente |
| `aprovado` | Verde | Aprovado |
| `cancelado` | Cinza escuro | Cancelado |

---

## Fluxo de ações — botões sugeridos por status

| Status atual | Ações disponíveis |
|---|---|
| `aguardando_aprovacao` | "Enviar para cliente" / "Aprovar manualmente" / "Cancelar" |
| `enviado_cliente` | "Aprovar manualmente" / "Copiar link" / "Cancelar" |
| `recusado_cliente` | "Reenviar para cliente" / "Aprovar manualmente" / "Cancelar" |
| `aprovado_cliente` | "Aprovar Financeiramente" / "Cancelar" |
| `aprovado` | (somente leitura) / "Cancelar" |
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
