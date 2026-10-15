# SPEC-203 — Orçamento: importar XML com cliente não encontrado sem perder a importação

- **Data:** 2026-10-15
- **Status:** em andamento
- **Origem:** pedido do usuário em 15/10 (Orçamentos › Novo Orçamento › Importar XML Connect).
- **Sistema:** Orçamentos (`04-Sistemas/gestao-financeira-clone-544cb (1)`). Não mexe no banco.

## Problema

O XML da Connect traz só o `cod_cliente`, que é comparado com `contatos.codigo_legado`. Quando não bate, o modal fechava, descartava a importação e abria o cadastro de cliente à força. Se o cliente já estivesse cadastrado, com outro código ou sem código, não havia como escolher o cliente existente sem perder o XML.

## Solução

1. **A importação é aplicada mesmo sem cliente.** Itens, empresa e data entram no formulário. Se um cliente já estava escolhido, ele é mantido. Abre a aba Cliente com um aviso em âmbar: "cliente do XML (código Connect N) não encontrado". O aviso dá três caminhos: escolher um cliente já cadastrado na busca, cadastrar um novo pelo link, ou salvar como rascunho e escolher depois.
2. **Rascunho sem cliente.** `cliente_id` passa a ser opcional no schema quando o status é `rascunho`; nos demais status continua obrigatório (superRefine). O banco já aceita `orcamentos.cliente_id` NULL.
3. **Não sai sem cliente.** "Enviar para o Cliente" (store `enviarOrcamentoCliente`) recusa um rascunho sem cliente com uma mensagem. Salvar com "Vínculo Connect" também exige cliente.
4. **Aprende o código.** Ao salvar com um cliente escolhido à mão para um XML que não casou, se esse cliente não tem `codigo_legado` e nenhum outro cliente usa o código, grava o `cod_cliente` do XML nele. Assim o próximo XML desse cliente casa sozinho. O índice único `(codigo_legado, tipo)` protege contra duplicado.
5. O cadastro de cliente não reaplica mais o XML, porque os itens já entraram. Isso evita duplicar os itens.

Arquivos alterados: `BudgetFormPage.tsx`, `ImportConnectXmlModal.tsx` (texto) e `useBudgetStore.ts`.

## Critérios de aceite
1. Importar um XML com cliente desconhecido carrega os itens e mostra o aviso na aba Cliente.
2. Dá para escolher um cliente existente e salvar; o próximo XML com o mesmo código casa sozinho, se o cliente não tinha código.
3. Dá para salvar o rascunho sem cliente; "Enviar para o Cliente" recusa até escolher o cliente.
4. Cadastrar um novo cliente pelo aviso preenche o campo sem duplicar os itens.

## Checklist
- [x] Implementado (build ok; tsc sem erro novo: 186 contra 187 antes)
- [x] Publicado b89f275 (financeiro-lucenera.pages.dev, conferido no bundle)
- [ ] Teste pela tela
