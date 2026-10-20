---
titulo: "SPEC-210 — Adm. Bancária: botão Exportar Excel em Contas a Pagar e Contas a Receber"
status: pendente
data_ultima_modificacao: 2026-10-20
sistemas_envolvidos:
  - Adm. Bancária (retorno-bancario-bradesco-5392a, adm-bancaria-lucenera.pages.dev)
---

# SPEC-210 — Adm. Bancária: botão Exportar Excel em Contas a Pagar e Contas a Receber

## Checklist de Ação

- [x] Adicionar biblioteca de geração de `.xlsx` no sistema (nenhum sistema do projeto tem hoje; sugestão: `exceljs`, carregada só no clique — import dinâmico — para não pesar a tela)
- [x] Botão **"Exportar Excel"** no cabeçalho da tela Contas em Aberto, ao lado de "Atualizar"
- [x] Exportar as linhas filtradas (todas as páginas) com exatamente as 11 colunas da tabela, na mesma ordem
- [x] Nome do arquivo conforme o modo (Pagar/Receber) e a data
- [x] `vite build` ok e publicar (Cloudflare `adm-bancaria-lucenera.pages.dev`)

### Passos manuais do usuário

- [ ] Em Pagar: exportar sem filtro e conferir que a quantidade de linhas do Excel = "N registro(s)" da tela
- [ ] Em Receber: aplicar um filtro (ex.: empresa + Vencido), exportar e conferir que só vieram as linhas filtradas
- [ ] Abrir no Excel e conferir: colunas e ordem iguais à tela, Valor somável, datas reconhecidas como data

## Objetivo

Hoje o financeiro consulta as contas em aberto na tela, mas não consegue levar a lista para o Excel (conferência,
envio para contador/diretoria, cruzamento com banco). O botão gera um relatório `.xlsx` com **os mesmos campos já
exibidos** em Contas a Pagar e Contas a Receber, sem acrescentar, tirar ou renomear colunas.

## Decisões aprovadas

- Pedido do usuário em 20/10/2026: exportação em Excel nas áreas de contas a receber e contas a pagar do sistema
  de administração bancária, preservando exatamente os campos exibidos.
- Campos fixos (não alterar): Empresa, Tipo, Categoria, Pessoa, Descrição, Emissão, Vencimento, Dias em Atraso,
  Valor, Nº Duplicata, Parcela/Total. (O pedido escreveu "Parcela/Tota"; o cabeçalho real da tela é "Parcela/Total".)

## Definição da SPEC

### 1. Necessidade funcional

- Um clique gera e baixa um arquivo `.xlsx` com a lista que o usuário está vendo.
- Funciona igual para **Pagar** e **Receber** (a tela é a mesma, com a alternância Pagar/Receber no topo).
- Não muda nada no banco: é só leitura do que a tela já carregou (`transacoes` com `status_pago = 0`).

### 2. Onde o botão aparece

- Tela **Contas em Aberto** (`src/pages/ContasEmAberto.tsx`, rota `/contas-em-aberto`).
- No cabeçalho, à direita, **ao lado do botão "Atualizar"**: botão `outline`, ícone de planilha, texto "Exportar Excel".
- Desabilitado enquanto carrega e quando o filtro não tem nenhuma linha (com dica "Nada para exportar").
- Mesmo acesso da tela: quem vê Contas em Aberto pode exportar.

### 3. O que entra no arquivo

- **Linhas:** todas as linhas que passam pelos filtros atuais (Pagar/Receber, Empresa, Perfil Empresa, Situação,
  Venc. início/final, Pessoa/Fornecedor) — **todas as páginas**, não só as 50 da página aberta. Mesma ordem da tela.
- **Colunas — exatamente estas, nesta ordem, com estes títulos:**

| # | Coluna | Conteúdo (igual à tela) | Formato no Excel |
|---|---|---|---|
| 1 | Empresa | nome da empresa | texto |
| 2 | Tipo | Pagar / Receber | texto |
| 3 | Categoria | plano de contas | texto |
| 4 | Pessoa | cliente/fornecedor | texto |
| 5 | Descrição | descrição da transação | texto |
| 6 | Emissão | data de emissão | data `dd/mm/aaaa` (vazio se não houver) |
| 7 | Vencimento | data de vencimento | data `dd/mm/aaaa` (vazio se não houver) |
| 8 | Dias em Atraso | dias de atraso (vazio quando 0, como na tela) | número inteiro |
| 9 | Valor | valor da parcela | número com 2 casas, formato R$ (somável) |
| 10 | Nº Duplicata | número da duplicata | texto/número, "-" quando vazio |
| 11 | Parcela/Total | ex.: `2/5` | texto (para o Excel não virar data) |

- Nenhuma coluna a mais (ex.: perfil, id) e nenhuma a menos.
- Valores e datas são gravados como **número e data de verdade** (não texto), para o usuário somar e filtrar no Excel.
- Vencimento corrompido (ano fora de 2000–2100, regra já existente `isVencimentoValido`) sai como na tela.

### 4. Arquivo

- Nome: `Contas_a_Pagar_AAAA-MM-DD.xlsx` ou `Contas_a_Receber_AAAA-MM-DD.xlsx` (data do dia).
- Uma aba, com o nome "Contas a Pagar" ou "Contas a Receber".
- Linha 1 = cabeçalho em negrito, congelada (fica fixa ao rolar) e com autofiltro; largura das colunas ajustada.

### 5. Fora do escopo

- Exportar PDF/CSV; exportar os KPIs ou a tabela de faixas de atraso; exportação na tela Consultar Duplicatas.
- Alterar colunas, filtros ou regras da tela.

## Realizado

### 2026-10-20

- Adm. Bancária 7a5c18b, no ar em `adm-bancaria-lucenera.pages.dev`:
  - `exceljs` 4.4.0 adicionado (pnpm 11, mesmo da pasta); vira um arquivo à parte que só baixa no clique.
  - `src/lib/exportar-contas-excel.ts`: 11 colunas fixas; datas como data `dd/mm/aaaa`, Valor como número `R$ #,##0.00`, Parcela/Total como texto; cabeçalho em negrito, congelado e com autofiltro; arquivo `Contas_a_Pagar_AAAA-MM-DD.xlsx` / `Contas_a_Receber_AAAA-MM-DD.xlsx`.
  - `ContasEmAberto.tsx`: botão "Exportar Excel" ao lado de "Atualizar"; exporta `filteredData` (todos os filtros, todas as páginas).
- Teste: `vite build` ok; arquivo gerado e relido em Node (data, número e "2/5" como texto conferidos). Falta o teste na tela pelo usuário.
