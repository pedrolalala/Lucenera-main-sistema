---
titulo: "SPEC-216 — Todos os sistemas: Enter pula para o próximo campo; salvar/confirmar só com clique"
status: não iniciado
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

- [ ] Confirmar com o usuário os 3 pontos em "Pontos para confirmar"
- [ ] Criar o comportamento único (`enter-pula-campo.ts`) e testar num sistema piloto (Necessidade de Compra)
- [ ] Copiar o mesmo arquivo para os demais sistemas e ligar no `main.tsx`/`App.tsx` de cada um (uma linha)
- [ ] `vite build` de cada sistema
- [ ] Teste por sistema: um formulário de cadastro, uma janela (modal) de edição e uma tela com busca
- [ ] Publicar (Cloudflare; Sistema de Entregas pelo Lovable) e atualizar CHANGELOG

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

## Realizado

(vazio)
