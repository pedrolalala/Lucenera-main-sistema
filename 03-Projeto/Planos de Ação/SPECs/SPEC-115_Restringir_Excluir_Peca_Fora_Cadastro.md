---
titulo: "SPEC-115 — Estoque: tirar \"Excluir\" do painel rápido de peça, deixar só dentro da edição completa"
status: concluído
data_ultima_modificacao: 2026-08-15
sistemas_envolvidos:
  - Cadastro (cadastro-lucenera-b86fe) — `Pecas.tsx`, `PecaDetailsPanel.tsx`
dependencias:
  - SPEC-069 (RBAC — matriz de perfis)
---

# SPEC-115 — Estoque: tirar "Excluir" do painel rápido de peça, deixar só dentro da edição completa

> Origem: reunião Vinícius 14/08/2026 ([52:10]-[52:46]).

## Objetivo

O botão "Excluir" peça/produto está exposto direto no painel de detalhes da listagem (um clique acidental apaga o cadastro) — o pedido é remover esse botão rápido e só permitir excluir de dentro da tela completa de edição da peça. Citação: *"O editar e excluir do peça e produto, sim [é questão de direito de acesso]... Excluir, cara, eu nem deixaria aqui... Certo seria o excluir só dentro da edição da peça, né?... Nem o editar também. Qualquer alteração aqui, só dentro do cadastro."* — o Vinícius aceita que "Editar" continue no painel rápido, já que ele já leva pro cadastro completo (*"na hora que você apertar em editar ali, ele vai subir para o cadastro"*), mas quer o "Excluir" **fora** do painel rápido de qualquer forma.

## Estado atual confirmado no código

`04-Sistemas/cadastro-lucenera-b86fe/src/components/pecas/PecaDetailsPanel.tsx` (linha 241-259):
- O painel lateral de detalhes de uma peça (aberto ao clicar num item da lista em `Pecas.tsx`) tem, lado a lado, dois botões sempre visíveis: **"Editar"** (linha 242-249, chama `onEdit`) e **"Excluir"** (linha 250-258, chama `onDelete`) — nenhum dos dois tem qualquer verificação de role/permissão.
- `Pecas.tsx` (linha 394-395): `onEdit` abre um modal de edição (`setActiveModal('peca', ...)`); `onDelete` seta `deleteId`, que dispara um diálogo de confirmação com botão "Excluir Peça" (linha 419) — ou seja, já existe uma confirmação de segurança, mas nenhuma restrição de quem pode chegar até ela.
- Não encontrada, em nenhum dos dois arquivos, nenhuma checagem de `role`/`hub_pode_executar` (busca por "role"/"permiss"/"admin"/"gerente" só retornou um texto não relacionado, "Role para carregar mais...").

## Proposta (não implementar sem aprovação)

1. Remover o botão "Excluir" do `PecaDetailsPanel.tsx` (painel rápido da listagem).
2. Manter "Excluir" **só** dentro da tela/modal de edição completa da peça (o `onEdit` já abre esse modal — a exclusão deve migrar pra lá).
3. Manter "Editar" no painel rápido, sem mudança — já é aceito pelo usuário.
4. Avaliar (pendência) se a exclusão dentro da edição completa deve, além disso, ser restrita por role (`admin`/`gerente`), já que o Vinícius citou isso como "direito de acesso" — não ficou 100% claro na reunião se ele quer só reposicionar o botão ou também travar por perfil.

## Análise de ecossistema

- **Depende de**: nenhuma tabela nova — mudança puramente de posicionamento de UI (e, se aprovado, checagem de role já existente via SPEC-069).
- **Afeta**: só a tela de Peças do Cadastro. Baixo risco — reduz superfície de erro, não remove funcionalidade.

## Realizado

### 2026-08-15

- **P-1 resolvida (usuário)**: só reposicionar por agora — sem restrição de role em cima do "Excluir" nesta SPEC.
- `PecaDetailsPanel.tsx` (painel rápido da listagem): removido o botão "Excluir" e a prop `onDelete`; "Editar" mantido sem alteração.
- `Pecas.tsx`: removidos `deleteId`/`isDeleting`, `handleDelete`, o `AlertDialog` de confirmação e a prop `onDelete` passada ao painel — a listagem não tem mais nenhuma via de exclusão.
- `PecaForm.tsx` (modal de edição completa, aberto via "Editar"): adicionado botão "Excluir Peça" no rodapé (só aparece quando `pecaId` existe, ou seja, edição — não aparece na criação de peça nova), com `AlertDialog` de confirmação própria antes de chamar `deleteProduto`.
- Achado à parte (drift, não bug desta SPEC): ao ler o conteúdo real publicado no Skip antes de editar, `Pecas.tsx` no Skip não tinha uma coluna "Código" que existia só no arquivo local (mudança local nunca publicada). O patch foi construído a partir do conteúdo real do Skip (sem essa coluna) e o arquivo local foi realinhado ao Skip — a coluna "Código" não fazia parte de nenhuma SPEC registrada e ficou de fora da publicação.
- Publicado Skip 36668 v0.0.62 (hash `a57336b`) — QA completo ok (setup/staticAnalysis/build/integrations/test). Testado ao vivo via DOM: painel rápido mostra só "Editar"; abrindo a edição, "Excluir Peça" aparece no rodapé, dispara confirmação e "Cancelar" fecha corretamente.

## Pendências

Nenhuma. (Restrição de "Excluir" por role admin/gerente ficou descartada pelo usuário — só reposicionamento.)
