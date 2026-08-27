---
titulo: "SPEC-096 — Reorganizar layout do cadastro de cliente no CRM (RG/IE + ordem dos campos)"
status: concluído
data_ultima_modificacao: 2026-08-13
sistemas_envolvidos:
  - CRM
dependencias:
  - 03-Projeto/Planos de Ação/SPECs/SPEC-086_Analise_Reunioes_Vinicius_11_08_2026.md (item 2.9)
---

# SPEC-096 — Reorganizar layout do cadastro de cliente no CRM

> Origem: reunião com Vinícius, 11/08/2026 (`02-Reunioes/17. Lucenera
> (vinicius) - 11.08.2026_ estruturas falhas do sistema/Reunião.03`,
> [02:09]-[02:37]). Catalogado como item 2.9 na SPEC-086.

## Checklist de Ação

- [ ] `ClientFormFields.tsx`: juntar RG e Inscrição Estadual num único
      `FormField`/linha (2 inputs lado a lado sob um único agrupamento),
      no mesmo estilo visual já usado para CPF/CNPJ
- [ ] Mover o campo "Tipo Cliente" pra antes de "Inscrição Estadual" e
      "Regime de Apuração" na ordem visual

### Passos manuais do usuário

- [ ] Nenhum — mudança só de layout/frontend

## Objetivo

Durante o teste ao vivo, o Vinícius comentou dois ajustes de layout no
cadastro de cliente: "essa inscrição estadual pode deixar junto com o RG,
igual o CPF barra CNPJ, vai ficar mais limpo" e "você traz esse tipo de
cliente pra cima, porque ele primeiro seleciona o tipo de cliente e depois
o regime de apuração".

## Achado técnico (2026-08-13, confirmado no código local — fresco, commit
2026-08-12)

Ordem atual dos campos em `ClientFormFields.tsx` (cada um é um `FormField`
isolado, um por célula do grid): `telefone → cpf_cnpj → rg → tipo_cliente →
inscricao_estadual → regime_apuracao`.

- **RG e Inscrição Estadual não são adjacentes** hoje — o campo
  `tipo_cliente` fica entre os dois, então a queixa de "juntar visualmente"
  ainda é válida.
- **Tipo Cliente já vem antes de Regime de Apuração** na ordem atual — essa
  parte específica da queixa já está resolvida (não precisa de mudança,
  fica só como confirmação).

## Definição da SPEC

Nova ordem proposta: `telefone → cpf_cnpj → tipo_cliente → [RG + Inscrição
Estadual numa linha combinada] → regime_apuracao`. A combinação de RG/IE
numa linha só precisa envolver os dois `<FormField>` dentro de um wrapper
`<div className="grid grid-cols-2 gap-4">` (mesmo padrão de outros pares já
usados no formulário), sem mudar nome de campo, validação nem schema.

## Realizado

### 2026-08-13

- Confirmado no Skip (não só no local) que o conteúdo batia com o
  esperado antes de editar.
- `ClientFormFields.tsx`: `tipo_cliente` movido pra logo após `cpf_cnpj`;
  `rg` e `inscricao_estadual` ficaram adjacentes no grid de 2 colunas
  (efeito de lado a lado sem precisar de wrapper novo, só reordenando).
- Publicado Skip 24580, v0.0.302, QA limpo.

### 2026-08-13 — correção (achada no teste ao vivo)

- **Bug real**: `ClientFormFields.tsx` não é o componente usado pela tela
  de ver/editar um cliente já existente (`/contatos/clientes/:id`) — essa
  tela é `ContatoDetail.tsx`, que tem seu próprio array
  `FIELD_CONFIGS.cliente` hardcoded, independente. A correção de
  v0.0.302 nunca alcançou a tela real que o Vinícius via na reunião.
  `ClientFormFields.tsx` continua existindo (usado em outro fluxo de
  cadastro), mas não é o formulário desta reclamação.
- Achado só via teste em navegador ao vivo, clicando em "Editar" num
  cliente real — não seria detectável só por build/lint/QA do Skip.
- Mesmo reordenamento aplicado em `ContatoDetail.tsx` →
  `FIELD_CONFIGS.cliente`: `tipo_cliente` movido pra logo após
  `cpf_cnpj`; `rg` e `inscricao_estadual` ficaram adjacentes.
- Publicado Skip 24580, v0.0.303, QA limpo. Confirmado visualmente no
  navegador após hard-reload (Ctrl+Shift+R).
- Sincronizado no submodule local `lucenera-crm-3bd29` (commit
  `e5cbd96`, push feito).

## Pendências

Nenhuma.
