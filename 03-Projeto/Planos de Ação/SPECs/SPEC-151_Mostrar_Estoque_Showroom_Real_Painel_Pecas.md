---
titulo: "SPEC-151 — Mostrar estoque real do Showroom no painel de Peças e Produtos"
status: concluído
data_ultima_modificacao: 2026-09-16
sistemas_envolvidos:
  - cadastro-lucenera-b86fe
---

# SPEC-151 — Mostrar estoque real do Showroom no painel de Peças e Produtos

## Checklist de Ação

- [x] Ajustar `PecaDetailsPanel.tsx` para exibir a linha "Showroom" da tabela "Estoque por Local" com o valor real de `produtos.estoque_showroom`, em vez do valor sempre zerado de `estoque_itens` (local='Showroom').
- [x] Recalcular Total/Disponível exibidos no card considerando o showroom real.
- [ ] Testar ao vivo no produto CYLI MESA 1 - LED 6W 450LM 2700K MONOVOLT - PRETO (código 13387, referência DS00005-40) — publicado, falta confirmação visual do usuário em produção.

### Passos manuais do usuário

Nenhum — é só leitura/UI, não precisa de migration nem passo manual.

## Objetivo

O painel lateral de detalhe de peça (aba "Peças e Produtos") mostra a tabela "Estoque por Local" sempre com `Showroom: 0 / 0`, mesmo quando a peça está fisicamente no showroom. Isso confunde o usuário, que vê a peça marcada como disponível no showroom em outro lugar do sistema mas "zerada" aqui.

## Decisões aprovadas

- 2026-09-16 (usuário): corrigir só o painel (leitura), sem tocar em trigger de banco nem nos dados divergentes de `estoque_total`/`estoque_disponivel` (isso fica para decisão futura, sem SPEC aberta por ora).

## Definição da SPEC

### Causa raiz (investigação)

Achado ao investigar reclamação do usuário sobre o produto código 13387 (referência DS00005-40, CYLI MESA 1 - LED 6W 450LM 2700K MONOVOLT - PRETO), que aparecia com `Showroom: 0/0` na tela apesar de estar fisicamente no showroom.

- `PecaDetailsPanel.tsx` monta a tabela "Estoque por Local" a partir de `estoque_itens` (via `getEstoqueItens` → `buildEstoquePorSetor`).
- Desde a migration `20260716_046_link_produtos_estoque_itens` (ajustada em `20260716_048_fix_link_quantidade_disponivel`), o trigger `fn_sync_estoque_itens_from_produtos` **zera deliberadamente** qualquer linha `estoque_itens` com `local='Showroom'` a cada UPDATE de `produtos` — para não duplicar soma de estoque quando o link `produtos → estoque_itens(local='Estoque')` foi criado.
- A quantidade real de showroom vive só em `produtos.estoque_showroom` (nesse produto = 1), populada pelo script `scripts/importar_produtos_estoque.py` a partir da planilha do Connect legado. Esse painel nunca lê essa coluna.
- Confirmado em produção: **0 linhas** de `estoque_itens` no banco têm `local='Showroom'` com `quantidade > 0` — o campo está estruturalmente sempre zerado para todos os produtos nessa tabela. **230 produtos** têm `estoque_showroom > 0` em `produtos` e ficam com essa informação invisível nesta tela.
- O site público do Showroom (SPEC-125/126/148, `vw_showroom_publico`) **não tem esse problema** — lê `produtos.estoque_showroom` direto, sem passar por `estoque_itens`.

Achado relacionado (fora do escopo desta SPEC, decisão do usuário foi não tocar agora): 258 dos 4.726 produtos têm `produtos.estoque_disponivel > estoque_total` (colunas independentes vindas de colunas separadas da planilha do Connect, sem validação cruzada), o que o trigger converte em `quantidade_reservada` negativa em `estoque_itens` — aparece como um "Disponível" fantasma na linha "Estoque" da mesma tabela. É esse fenômeno que fez o card de resumo ("Total/Reservado/Disponível: 0/0/0", que usa a view de reserva real por projeto) parecer contradizer a tabela de baixo (que usa a fonte contaminada). Fica registrado aqui como pendência conhecida, sem ação nesta SPEC.

### Mudança proposta

Em `PecaDetailsPanel.tsx`:

- Buscar `produtos.estoque_showroom` (já vem no objeto `peca`/query de produto usada pela tela de listagem — confirmar campo disponível ou adicionar ao select) e usar esse valor como a linha "Showroom" da tabela "Estoque por Local", substituindo (ou somando a, se a linha de `estoque_itens` algum dia deixar de ser zerada) o valor lido de `estoque_itens`.
- Local "Showroom" nessa tabela não tem reserva própria rastreada (não existe granularidade de reserva por local de showroom) — exibir "Disponível" da linha Showroom igual à própria quantidade (sem subtrair nada), já que hoje não há como saber se uma peça específica do showroom está reservada.
- Recalcular `totalGeral`/`totalDisponivelPorLocal` do rodapé somando essa quantidade de showroom.

## Realizado

### 2026-09-16

- SPEC criada a partir de investigação ao vivo (usuário reportou contradição no card de estoque do produto código 13387).
- Implementado e publicado no Skip (`cadastro-lucenera-b86fe.goskip.app`, versão 0.0.83, ref `1f5ebbc`):
  - `src/services/produtos.ts`: `getProdutosEstoqueFiltradoBatched` agora busca `estoque_showroom` de `produtos` e devolve no `ProdutoEstoqueRow`.
  - `src/pages/Pecas.tsx`: `selectedPeca` passa `estoque_showroom` para o painel (patch aplicado sobre a versão do Skip, que já tinha a ordenação da SPEC-122 — não usar o submodule local `04-Sistemas/` como base, ele está desatualizado em relação ao Skip).
  - `src/components/pecas/PecaDetailsPanel.tsx`: a linha "Showroom" da tabela "Estoque por Local" agora vem de `produtos.estoque_showroom` (não mais de `estoque_itens`, que o trigger sempre zera); `hasStockRecords` passou a considerar showroom > 0 também.
  - QA do Skip (setup/lint/build/integrations/test) passou limpo antes do publish.
- Não alterado: os 258 produtos com "reservado negativo" fantasma (fora de escopo, decisão do usuário).

## Pendências

- [ ] Confirmação visual do usuário em produção (o teste ao vivo no CYLI MESA 1 ainda não foi feito por mim — sem acesso a browser autenticado nesta sessão).
- [ ] (Fora de escopo, registrado para decisão futura) 258 produtos com `estoque_disponivel > estoque_total` na tabela `produtos`, gerando "reservado negativo" fantasma em `estoque_itens` — requer decisão de negócio sobre qual coluna da planilha do Connect confiar quando divergem, antes de qualquer correção/migration.
- [ ] `04-Sistemas/cadastro-lucenera-b86fe` (submodule local) está desatualizado em relação ao Skip (falta pelo menos a ordenação por coluna da SPEC-122) — reconciliar git local em outro momento, não é bug de produção.
