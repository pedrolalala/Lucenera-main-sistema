---
titulo: "SPEC-216 — Todos os sistemas: Enter pula para o próximo campo; salvar/confirmar só com clique"
status: pendente
data_ultima_modificacao: 2026-10-21
sistemas_envolvidos:
  - Hub / Central (central-lucenera-dashboard-1c9ba)
  - Consultar Produtos / Cadastro (cadastro-lucenera-b86fe)
  - Catálogo Ubiqua (catalogo-pecas-ubiqua-e6fa0)
  - Central de Solicitações (central-de-solicitacoes)
  - Necessidade de Compra (compras-lucenera-3o23t98ee)
  - Controle de Garantia (controle-de-garantia)
  - Controle de Produção (controle-de-producao)
  - Dashboard Financeiro (dashboard-lucenera-b02z85wa3)
  - RH Lucenera (dashboard-rh-lucenera-5fe9c)
  - Orçamentos Lucenera (gestao-financeira-clone-544cb (1))
  - CRM Lucenera (lucenera-crm-3bd29 (1))
  - Sistema de Entregas (lucenera-logistics-b7cd1 — publicado no Lovable)
  - Memória Lucenera (memoria-lucenera)
  - Administração Bancária (retorno-bancario-bradesco-5392a)
  - Separação Parcial (separacao-parcial)
  - Showroom Lucenera — área /admin (showroom-qtq8er2dk)
  - Vendas (vendas-lucenera)
---

# SPEC-216 — Enter pula campo; salvar e confirmar só no clique

## Checklist de Ação

- [x] Confirmar com o usuário os 3 pontos em "Pontos para confirmar" (21/10: sim para os três)
- [x] Criar o comportamento único (`enter-pula-campo.ts`) e testar no navegador (15 casos)
- [x] Copiar o mesmo arquivo para os 17 sistemas e ligar no `main.tsx` de cada um
- [x] `vite build` de cada sistema (17 ok)
- [ ] Teste por sistema com o usuário: um formulário de cadastro, uma janela (modal) de edição e uma tela com busca
- [x] Publicar (push no GitHub → Cloudflare) e atualizar CHANGELOG
- [ ] Sistema de Entregas: publicar no Lovable (o push no GitHub não publica sozinho lá)

### Passos manuais do usuário

- [ ] Testar com o administrador em um sistema piloto antes de espalhar para todos
- [ ] Depois de publicado: avisar a equipe que o Enter não salva mais (só o clique)

## Objetivo

Pedido do usuário em **21/10/2026**: o administrador usa **Enter** e **Tab** para pular de campo. Hoje, em todos os
sistemas, o Enter **finaliza**: fecha a janela/campo e salva o que estava sendo feito. O pedido é trocar:

- **Enter** = pular para o próximo campo (igual ao Tab);
- **Tab** = pular para o próximo campo (continua como é);
- **Salvar ou confirmar** qualquer coisa = **só com clique** do mouse no botão.

Vale para **todos os sistemas** do ecossistema.

## Definição da SPEC

### Por que o Enter salva hoje

Os formulários das telas usam `<form onSubmit>`; o navegador envia o formulário sozinho quando se aperta Enter num
campo de texto. Além disso, com o foco num botão, o Enter "clica" nele.

### Como vai ficar (uma regra só, igual em todos os sistemas)

Um único arquivo (`src/lib/enter-pula-campo.ts`), ligado uma vez na abertura do sistema, escuta a tecla Enter na
página inteira, antes das telas:

1. **Enter num campo** (texto, número, data, seleção, caixa de marcar, botão): **não envia o formulário e não clica
   no botão**; o cursor vai para o **próximo campo** da mesma janela (se houver uma janela aberta) ou do mesmo
   formulário, na mesma ordem do Tab. Pula campos desabilitados, escondidos e só de leitura. No último campo, fica
   onde está (não salva).
2. **Shift+Enter** volta para o campo anterior (igual Shift+Tab).
3. **Salvar, Confirmar, Aprovar, Registrar, Excluir…**: só com **clique** no botão.
4. **Exceções** (o Enter continua com o papel de hoje):
   - **Caixa de texto grande** (observação, descrição — várias linhas): Enter **quebra a linha**, como hoje.
   - **Lista de sugestões aberta** (autocomplete, busca de fornecedor/produto, seleção com lista): Enter
     **escolhe o item destacado** (escolher não é salvar).
   - Campos marcados de propósito pela tela com `data-enter="permitir"` (ver pontos para confirmar).

Não muda nada no banco. Não muda o Tab. Não muda atalhos com Ctrl/Alt.

### Onde fica o código

- Mesmo arquivo copiado em cada sistema (os sistemas são repositórios separados, sem pacote compartilhado).
- Ligado em `main.tsx` (ou `App.tsx`) com uma linha: `instalarEnterPulaCampo()`.
- Telas não precisam ser alteradas uma a uma; só as exceções recebem `data-enter="permitir"`.

## Pontos para confirmar (com recomendação)

1. **Campos de busca** (ex.: "Número do pedido…" + Buscar, busca de clientes): Enter continua **buscando**?
   Recomendação: **sim** — buscar não salva nada e é o uso mais comum do Enter nesses campos.
2. **Tela de login** (e-mail + senha): Enter continua **entrando** no sistema?
   Recomendação: **sim** — não salva dado e todo mundo está acostumado.
3. **Vale para todos os usuários** de todos os sistemas (não só para o administrador)?
   Recomendação: **sim**, uma regra única evita que o mesmo campo funcione diferente para cada pessoa.

## Riscos

- Quem hoje salva com Enter vai estranhar no começo (avisar a equipe).
- Telas com componente de lista próprio (sem `role="combobox"`/`listbox`) podem precisar de `data-enter="permitir"`;
  o teste por sistema pega isso.

## Rollback

- Tirar a linha `instalarEnterPulaCampo()` do `main.tsx` do sistema e publicar de novo.

## Decisões do usuário (21/10/2026)

- Sim para os três pontos: busca continua buscando com Enter, login continua entrando com Enter, regra vale para
  todos os usuários.
- "Tudo que estiver relacionado a fechar/salvar uma operação tem que ser no clique; se estiver fazendo algo, o Enter
  nunca pode salvar nada."

## Realizado

### 2026-10-21

- `src/lib/enter-pula-campo.ts` (idêntico nos 17 sistemas) + `instalarEnterPulaCampo()` no `main.tsx`.
  Escuta o Enter na janela (fase de captura), antes das telas:
  - Enter num campo: não envia formulário, não "clica" botão e não dispara o Enter da tela; vai para o próximo
    campo da janela aberta / do formulário (pula desabilitado, escondido, só leitura e botões de ação); Shift+Enter volta;
  - caixa de texto de várias linhas: só quebra a linha (o chat dos Orçamentos não envia mais com Enter);
  - Ctrl/Cmd/Alt+Enter: não faz nada (a Memória salvava com Ctrl+Enter);
  - continuam: lista de sugestões/seleção aberta (escolhe), busca (campo de busca fora de formulário de cadastro, ou
    formulário de um campo só com botão Buscar/Pesquisar/Filtrar), login (1 senha + e-mail/usuário + botão "Entrar";
    cadastro de usuário e troca de senha não contam) e `data-enter="permitir"`.
- Telas que salvavam com Enter e passam a salvar só no clique: Hub › Papéis (criar papel), Necessidade de Compra ›
  Cotações (preço e desconto — também deixaram de salvar ao sair do campo; salva no ✓, Esc cancela), Sistema de
  Entregas (adicionar item da separação), Memória (tag continua entrando com vírgula ou ao sair do campo).
- Teste no Chrome (página de teste com o mesmo código): 15 casos ok — cadastro pula campo e não salva nem no último
  campo nem com Enter no botão Salvar; clique no Salvar salva; busca busca; login entra; criar usuário e trocar senha
  não salvam; campo que salvava com Enter não salva; janela pula campo desabilitado e o OK não confirma; chat não envia.
