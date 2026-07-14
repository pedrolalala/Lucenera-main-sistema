---
titulo: "SPEC-023 — Fix: Filtro de Empresa não funciona em Lote de Recibos (VT)"
status: implementado
data_ultima_modificacao: 2026-07-14
sistemas_envolvidos:
  - dashboard-rh-lucenera-5fe9c (Vale Transporte)
dependencias: []
---

# SPEC-023 — Fix: Filtro de Empresa não funciona em Lote de Recibos (VT)

> Ao selecionar uma empresa específica no painel "Lote de Recibos" da tela de
> Gestão de Vale Transporte, o ZIP não é gerado e aparece a mensagem
> **"Nenhum funcionário encontrado"**.
> Quando "Todas as Empresas" está selecionado, o fluxo funciona normalmente.

---

## Checklist de Ação

### Correção imediata (frontend — sem migration)
- [x] Tornar comparação de nome de empresa case-insensitive e com trim em `fetchCalculos`
- [x] Filtrar `funcionarios` pela empresa selecionada antes de chamar `buildCalculos`
- [x] Corrigir mensagem de aviso: distinguir "nenhum funcionário ativo" de "nenhum funcionário nessa empresa"

### Melhoria estrutural (migration Supabase)
- [x] Adicionar coluna `empresa_id uuid REFERENCES empresas(id)` em `funcionarios_beneficios_empresas` (migration 039/001)
- [x] Migrar os dados existentes — 22/22 registros com FK (10 via ILIKE, 12 via patch "Foco"→"FOCO ILUMINACAO") (migration 039/002)
- [x] Atualizar `fetchCalculos` para filtrar por `empresa_id` primeiro, texto como fallback
- [ ] Tornar `empresa_id` NOT NULL após validação em produção

---

## Diagnóstico técnico

### Arquivo afetado

```
04-Sistemas/dashboard-rh-lucenera-5fe9c/src/pages/ValeTransporte.tsx
função: fetchCalculos() — linhas 84–162
```

### Raiz do problema

O campo `funcionarios_beneficios_empresas.empresa` é um `VARCHAR(100)` — texto
livre, sem FK para a tabela `empresas`. O filtro de empresa no frontend compara
esse texto com `empresas.nome` usando igualdade estrita (`===`):

```typescript
// ValeTransporte.tsx — linha 111
filteredBenef = filteredBenef.filter((b: any) => b.empresa === emp.nome)
```

| Problema | Causa |
|----------|-------|
| Comparação case-sensitive | `"LUCENERA" !== "Lucenera"` → sem match |
| Sem trim | `"Lucenera " !== "Lucenera"` → sem match |
| Sem normalização de acentos | `"São Paulo" !== "Sao Paulo"` → sem match |
| Campo sem FK | Texto cadastrado livremente, sem garantia de consistência |

Quando nenhum benefício passa no filtro → `filteredBenef` fica vazio → todos os
funcionários recebem `valor_vt_dia: 0` → `buildCalculos` os joga em `errors` →
`calculos` fica vazio → `handleGerarZip` exibe "Nenhum funcionário encontrado".

### Fluxo completo com o bug

```
fetchCalculos()
  │
  ├─ funcsData ← TODOS os funcionários ativos (sem filtro por empresa)
  │
  ├─ benefData ← benefícios de TODOS os funcionários
  │
  ├─ filteredBenef ← [empresa selecionada?]
  │     ├─ ALL_COMPANIES → mantém tudo ✓
  │     └─ empresa específica → b.empresa === emp.nome  ← FALHA AQUI
  │                              retorna [] se nomes divergem
  │
  ├─ funcionarios ← funcsData.map(...)
  │     → todos os funcionários
  │     → sem benefício correspondente: valor_vt_dia = 0
  │
  └─ buildCalculos(funcionarios, ...)
        → valor_vt_dia <= 0 → vai para errors (não calculos)
        → calculos = []
        → handleGerarZip: "Nenhum funcionário encontrado" ← mensagem errada
```

### Segundo problema: `errors` poluído

Quando uma empresa específica é selecionada, `funcionarios` ainda contém
funcionários de outras empresas (com `valor_vt_dia: 0`). O `buildCalculos`
adiciona todos eles em `errors` com "Sem registro de benefício". O resultado
é uma lista de erros confusa com funcionários que não têm relação com a empresa
selecionada.

---

## Correção

### Parte 1 — Comparação case-insensitive (resolve o bug principal)

**Arquivo:** `src/pages/ValeTransporte.tsx`

```typescript
// ANTES (linha ~111)
if (emp) filteredBenef = filteredBenef.filter((b: any) => b.empresa === emp.nome)

// DEPOIS
if (emp) {
  const nomeNorm = emp.nome.toLowerCase().trim()
  filteredBenef = filteredBenef.filter(
    (b: any) => (b.empresa ?? '').toLowerCase().trim() === nomeNorm,
  )
}
```

### Parte 2 — Filtrar `funcionarios` pela empresa selecionada

Após construir o array `funcionarios`, excluir os que não pertencem à empresa
selecionada. Isso evita que funcionários de outras empresas apareçam em `errors`.

```typescript
// Após a construção de funcionarios[] (após linha ~136)
const funcionariosFiltrados =
  empresa === ALL_COMPANIES
    ? funcionarios
    : funcionarios.filter(
        (f) =>
          f.empresa_id === empresa ||
          (f.empresa_nome ?? '').toLowerCase().trim() ===
            (empresas.find((e) => e.id === empresa)?.nome ?? '').toLowerCase().trim(),
      )

// Substituir `funcionarios` por `funcionariosFiltrados` em buildCalculos
return buildCalculos(funcionariosFiltrados, faltasData, diasUteis, feriadosCount, empresasVT)
```

### Parte 3 — Mensagem de aviso mais clara

```typescript
// handleGerarZip — ANTES
if (!result || result.calculos.length === 0) {
  toast({ title: 'Nenhum funcionário encontrado', variant: 'destructive' })
  return
}

// DEPOIS
if (!result) {
  toast({ title: 'Sem funcionários ativos', description: 'Nenhum funcionário ativo no sistema.', variant: 'destructive' })
  return
}
if (result.calculos.length === 0) {
  toast({
    title: 'Nenhum funcionário com VT nessa empresa',
    description: 'Verifique se os funcionários desta empresa têm registro em benefícios.',
    variant: 'destructive',
  })
  return
}
```

O mesmo ajuste deve ser aplicado em `handleCalcular`.

---

## Melhoria estrutural recomendada (migration)

A correção acima é válida e resolve o problema imediatamente. Porém, a causa
raiz é a ausência de FK entre `funcionarios_beneficios_empresas.empresa` e
`empresas`. A solução definitiva é adicionar `empresa_id`:

```sql
-- Migration: 20260714_039_add_empresa_id_beneficios_empresas
ALTER TABLE public.funcionarios_beneficios_empresas
  ADD COLUMN empresa_id uuid REFERENCES public.empresas(id);

-- Popular empresa_id a partir do texto existente
UPDATE public.funcionarios_beneficios_empresas feb
SET empresa_id = e.id
FROM public.empresas e
WHERE e.nome ILIKE feb.empresa;

-- Verificar o que ficou sem match antes de tornar NOT NULL
SELECT * FROM public.funcionarios_beneficios_empresas WHERE empresa_id IS NULL;
```

Após validação, tornar `empresa_id NOT NULL` e atualizar `fetchCalculos` para
filtrar diretamente por UUID:

```typescript
// Com empresa_id, a query fica:
const { data: benefData } = await supabase
  .from('funcionarios_beneficios_empresas')
  .select('funcionario_id, empresa, empresa_id, valor_vt_dia')
  .in('funcionario_id', funcsData.map((f) => f.id))
  .or(empresa === ALL_COMPANIES
    ? 'empresa_id.not.is.null'
    : `empresa_id.eq.${empresa}`
  )
```

---

## Regras de negócio

| # | Regra |
|---|-------|
| RN-01 | O filtro por empresa deve ser case-insensitive e tolerante a espaços extras |
| RN-02 | Funcionários de outras empresas não devem aparecer em `errors` quando uma empresa específica é selecionada |
| RN-03 | A mensagem "Nenhum funcionário encontrado" deve distinguir entre "sem ativos no sistema" e "sem VT registrado nessa empresa" |
| RN-04 | O ZIP só deve ser gerado com funcionários que têm `valor_vt_dia > 0` e pertencem à empresa selecionada |

---

## Critérios de aceite

- [ ] Selecionar empresa específica → cálculo retorna apenas funcionários dessa empresa
- [ ] Selecionar empresa específica → ZIP gerado com recibos apenas dessa empresa
- [ ] Nomes com diferença de caixa (`"lucenera"` vs `"Lucenera"`) passam no filtro
- [ ] Nomes com espaços extras passam no filtro
- [ ] Seção "Inconsistências" lista apenas funcionários SEM VT da empresa selecionada (não de outras)
- [ ] Mensagem de aviso ao usuário é informativa e distingue os dois casos de "vazio"
- [ ] "Todas as Empresas" continua funcionando como antes

---

## Arquivos a alterar

| Arquivo | Tipo de mudança |
|---------|----------------|
| `src/pages/ValeTransporte.tsx` | Correção de bug (filtro case-insensitive + filtro de array) |
| `supabase/db/migrations/20260714_039_…` | Migration opcional (longo prazo) |

---

## Perguntas em aberto

| # | Pergunta | Impacto |
|---|----------|---------|
| P-01 | O campo `funcionarios_beneficios_empresas.empresa` está sempre preenchido para todos os funcionários ativos? Se não, a Parte 2 pode excluir funcionários válidos sem `empresa_nome` | Pode precisar de um terceiro critério de fallback |
| P-02 | A coluna `funcionarios.empresa` (tabela antiga, não `funcionarios_novo`) é usada ativamente ou é legado? | Pode ser removida na migration se for legado |
| P-03 | Após a migration com `empresa_id`, o campo texto `empresa` pode ser mantido como cache ou pode ser dropado? | Simplificação do schema |
