# SPEC-084: PDF do orçamento — logo, endereço do cliente e Arquiteto Externo

**Data:** 2026-08-12
**Sistema:** Orçamentos (`gestao-financeira-clone-544cb`, Skip projectId `32554`)
**Status:** Publicado em produção

## Relato do usuário

Ao baixar o PDF do orçamento, faltavam 3 coisas em relação ao formato correto (referência: PDF do fluxo antigo Connect):
1. Logo vertical da Lucenera no cabeçalho.
2. No bloco do cliente: nome do cliente com o código do projeto, endereço, CEP, cidade e telefone — dados já registrados no Supabase.
3. Logo abaixo, "Vendedor" e "Arquiteto Externo" lado a lado.

Usuário anexou 2 PDFs de referência: `Orcamento exportado do sistema.pdf` (estado atual, com os 3 problemas) e `Orçamento como deve ficar.pdf` (formato esperado, réplica do padrão Connect).

## Causa raiz

O PDF é gerado pela Edge Function `supabase/functions/generate-report/index.ts` (`reportType: 'orcamento'`), chamada por dois pontos do frontend: `BudgetTableRow.tsx::handleDownloadPdf` (botão "Baixar PDF") e `src/lib/envio-inicial-cliente.ts::downloadBudgetPdf` (SPEC-067, envio inicial ao cliente).

1. **Logo**: a Edge Function já tinha toda a lógica de desenhar uma imagem de logo (`if (logoBase64) { ... }`), mas **nenhum dos dois pontos do frontend enviava `logoBase64`** no corpo da requisição — o parâmetro sempre chegava `undefined`, então o bloco inteiro nunca rodava.
2. **Endereço do cliente**: a query da função só buscava `nome, email, telefone, cpf_cnpj` de `contatos` — **nunca buscava `endereco, cep, cidade, estado`**, e o desenho do PDF só escrevia CPF/CNPJ e telefone. Não é um problema de dado faltando no banco (82% dos ~2643 clientes têm endereço/CEP/cidade preenchidos) — o código simplesmente nunca pedia essas colunas nem as desenhava.
3. **Arquiteto Externo**: a query não buscava `arquiteto:contatos!orcamentos_arquiteto_id_fkey(nome)` (apesar da FK já existir e ser usada em outros pontos do sistema) e o desenho do PDF não tinha nenhuma linha para isso — só "Vendedor".

## Correções

- **Novo `src/lib/pdf-logo.ts`**: converte o logo já usado no cabeçalho do app (`lucenera-vertical-527dd.png`) pra data URL base64 (com cache em memória), e é chamado nos dois pontos que geram o PDF, passando `logoBase64` no corpo da requisição.
- **Query da Edge Function**: adiciona `razao_social, endereco, cep, cidade, estado` em `cliente`, `arquiteto:contatos!orcamentos_arquiteto_id_fkey(nome)` e `projeto:projetos!orcamentos_projeto_id_fkey(codigo)`.
- **Cabeçalho "Orçamento para"**: nome do cliente passa a vir prefixado com o código do projeto (`{código} {nome}`) — com uma checagem pra não duplicar quando o próprio nome do cliente legado já embute o código (padrão de import antigo do Connect, achado ao testar: cliente "26.007 CLINICA TARITA ABDALA" já tinha o código no nome).
- **Bloco de endereço**: linhas condicionais (só desenha o que existir) — razão social (quando diferente do nome), endereço, "CEP: xxx - cidade/UF", telefone. Substitui a antiga linha única de CPF/CNPJ, que o PDF de referência não mostra.
- **"Arquiteto Externo"**: nova coluna ao lado de "Vendedor", mostrando `arquiteto?.nome || '-'`.

## Verificação

- `npx tsc --noEmit` + `npx oxlint` + `npm run build` limpos.
- QA do Skip (setup/staticAnalysis/build/integrations/test) passou antes de cada publish.
- **Verificado ao vivo em produção**: chamada direta à Edge Function publicada (orçamento real `ORC-0018`, projeto `26.007`, cliente com endereço completo e arquiteto vinculado) — PDF baixado e lido confirma: endereço/CEP/cidade/telefone corretos, "Vendedor: Thairine Cristina da Silva" e "Arquiteto Externo: ROBERTA ALONSO" ambos presentes. Um bug de duplicação do código do projeto foi encontrado nessa mesma verificação (cliente com código já embutido no nome) e corrigido antes do publish final.
- **Logo**: verificado indiretamente — o fetch do logo (44.782 caracteres base64, arquivo PNG real) foi enviado com sucesso à função, e o PDF resultante cresceu de ~2.9KB pra ~44,5KB (exatamente a ordem de grandeza esperada pra uma imagem PNG embutida). Download real do PDF com logo não pôde ser confirmado visualmente nesta sessão — a automação do navegador bloqueou downloads repetidos na mesma aba (proteção anti-abuso do Chrome, não relacionada ao código). Recomenda-se conferência visual rápida por um usuário real.
- Publicado: Orçamentos (Skip 32554, v0.0.324, hash `536ef7b`), push pro GitHub.

## Achado à parte (não corrigido nesta SPEC)

`src/lib/envio-inicial-cliente.ts` e a versão local de `src/components/budgets/DraftBudgetsTab.tsx` implementam a SPEC-067 (download automático de PDF + `mailto:` pré-preenchido no envio inicial ao cliente) — mas o `DraftBudgetsTab.tsx` publicado no Skip é uma versão **mais antiga**, que nunca foi atualizada pra usar esse fluxo (o `handleEnviar` de produção só copia o link, sem baixar PDF nem abrir e-mail). Ou seja, a SPEC-067 parece ter sido implementada localmente/no GitHub mas **nunca publicada no Skip** — `envio-inicial-cliente.ts` ficou órfão em produção até agora (nada o chamava). Esta SPEC só corrigiu o `logoBase64` desse arquivo por completude; não tentou publicar a funcionalidade da SPEC-067 em si, por estar fora do escopo pedido (download de PDF) e exigir decisão própria sobre se/quando publicar.
