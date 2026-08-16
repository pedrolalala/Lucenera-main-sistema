---
titulo: "SPEC-109 — PDF do orçamento: código real, 2 modelos de impressão, ordenar por L, datas"
status: concluído
data_ultima_modificacao: 2026-08-15
sistemas_envolvidos:
  - Orçamentos (gestao-financeira-clone-544cb, Skip 32554) — Edge Function `generate-report`
dependencias:
  - SPEC-084 (PDF do orçamento — logo/endereço/Arquiteto Externo, mesma Edge Function)
---

# SPEC-109 — PDF do orçamento: código real, 2 modelos de impressão, ordenar por L, datas

> Origem: reunião Vinícius 14/08/2026 ([25:12]-[31:51]).

## Objetivo

Quatro ajustes no PDF gerado pela Edge Function `generate-report`:

1. Mostrar os 2 arquitetos quando o orçamento tiver 2 cadastrados (hoje só mostra 1).
2. Trazer o **código interno real** do produto (`codigo_produto`) na coluna de código — hoje mostra `custom_id`("L")/`referencia`, nunca o código de verdade.
3. Ordenar os itens do PDF por L (hoje sai sem ordem clara, "bagunçado").
4. Mostrar "Data de Emissão" (criação do orçamento) além da "Data de Impressão" (momento de gerar o PDF) que já existe.

## Decisões aprovadas

Dois modelos de impressão distintos, confirmados na reunião ([26:41]-[28:37]), replicando um padrão que já existe no sistema legado Connect:

- **Modelo A** (pro cliente): sem referência — Quantidade, Unidade, Valor unitário, Valor total. É o que já é gerado hoje por padrão.
- **Modelo B** (uso interno): com Código (interno, real) + Referência — usado quando um item não tem cadastro (código vem "0", a referência ajuda a identificar a peça pra cadastrar depois). Citação: *"Porque, por exemplo, quando é um produto que não tem cadastro, o código vai vir zero, e a referência... teoricamente já é pra vir preenchida pra evitar a comunicação."*

## Definição da SPEC

### Estado atual confirmado no código

`04-Sistemas/gestao-financeira-clone-544cb (1)/supabase/functions/generate-report/index.ts`:

- **Arquiteto único** (linha 151): `arquiteto:contatos!orcamentos_arquiteto_id_fkey(nome)` — FK singular (`orcamentos.arquiteto_id`), não há segundo campo de arquiteto na query nem no render (linha 450-451). Se existir suporte a múltiplos arquitetos em outro lugar do sistema (SPEC-077 tratou "Arquitetos múltiplos %" no CRM), essa Edge Function não usa essa estrutura — precisa investigar se já existe uma tabela de vínculo N:N arquiteto↔orçamento/projeto ou se é um campo novo.
- **Código errado confirmado** (linha 492): `const cod = item.custom_id || item.produto?.referencia || '-'` — nunca usa `item.produto?.codigo_produto`, mesmo esse campo já vindo na query (linha 155: `produto:produtos(nome, referencia, sku, codigo_produto)`). Bug direto, fácil de confirmar a causa.
- **Sem ordenação por L**: não há nenhum `.order(...)` nem `sort()` visível nos itens antes de desenhar no PDF — usa a ordem que vier do banco (provavelmente ordem de inserção, não a coluna `ordem` que existe na tabela — linha 172 mostra que `ordem` é selecionado mas não achei uso dela pra ordenar antes do render).
- **Datas**: só existe "Data Impressão" (linha 353, `new Date()` no momento da geração). `budget.created_at` já é buscado pela query (usado em outro lugar, linha 645) — dá pra reaproveitar pra "Data de Emissão" sem nova consulta.

### Proposta (não implementar sem aprovação)

1. Investigar se existe estrutura de múltiplos arquitetos em algum lugar (SPEC-077) pra reaproveitar; se não existir, é uma mudança de modelo de dados maior (fora do escopo só de PDF) — reportar como achado, não implementar sem confirmar com o usuário.
2. Trocar `item.custom_id || item.produto?.referencia` por usar `item.produto?.codigo_produto` na coluna "Código", mantendo `custom_id` (o "L") como coluna separada, conforme já pedido: "tem que pôr aqui o L, a gente pode chamar de ID... aí o código tem que vir."
3. Ordenar os itens por `custom_id`/L antes de desenhar (`ordem` também pode ser critério secundário).
4. Adicionar "Data de Emissão" (`budget.created_at`) ao lado de "Data Impressão", tamanho pequeno, sem hora (confirmado que hora é opcional/dispensável).
5. Implementar os 2 modelos como parâmetro da função (`modelo: 'cliente' | 'interno'`), reaproveitando a mesma Edge Function — Modelo A esconde código+referência, Modelo B mostra os dois.

## Análise de ecossistema

- **Depende de**: `orcamentos`, `orcamento_itens`/`projeto_itens`, `produtos` (`codigo_produto`), `contatos` (arquiteto).
- **Afeta**: só a geração de PDF. Baixo risco pro resto do sistema — mudança isolada na Edge Function.

## Realizado

### 2026-08-15

- **P-1 resolvida**: `orcamento_arquitetos` (tabela junção, produto da SPEC-077) existe de verdade no Supabase real — a leitura do dump local (`supabase/db/current/01_schema_full.sql`) que a investigação original usou estava desatualizada e não tinha essa tabela. Confirmado direto no banco (`\dt`). PDF agora junta `orcamento_arquitetos(percentual, arquiteto:contatos(nome))`; se o orçamento tiver 2+ arquitetos cadastrados, mostra todos separados por " / "; senão cai no arquiteto único legado (`orcamentos.arquiteto_id`), sem quebrar nada.
- **P-2 resolvida (decisão própria)**: os 2 modelos viraram itens de um menu (⋮ do botão "Baixar PDF" virou dropdown) — "PDF para o cliente" e "PDF interno (com código e referência)". Modelo B soma uma coluna "Referência" às demais.
- **Código real + L separado**: coluna "Código" agora sempre usa `produto.codigo_produto` (nunca mais L nem referência); "L" (`custom_id`) virou coluna própria, sempre visível nos dois modelos.
- **Ordenar por L**: itens ordenados por número extraído do L ("L2" antes de "L10", corrigindo o problema de ordenação alfabética pura); itens sem L vão pro final.
- **Data de Emissão**: adicionada ao lado da "Data Impressão" já existente, sem hora.
- Publicado Skip 32554 v0.0.345. Testado via chamada direta à Edge Function (mesmo token de sessão do navegador) com o orçamento ORC-0020 (Terras Altas, 4+ itens com L02/L05/L10/L11 reais): os 2 modelos retornaram PDF válido (200, header `%PDF`), com o modelo interno maior que o cliente (5202 vs 4892 bytes — consistente com a coluna extra). Não consegui renderizar o PDF visualmente no sandbox do navegador desta sessão (Chrome bloqueia navegação top-level pra `data:` URL) — verificação ficou no nível funcional/dados, não visual.

## Pendências

Nenhuma.
