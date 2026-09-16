---
titulo: "SPEC-137 — Showroom: peças Ubiqua marcadas como pronta-entrega não aparecem por falta de foto"
status: concluído — migration aplicada no Supabase real (33 produtos), conferido ao vivo no site publicado (31/33 com foto; 2 pendências residuais documentadas abaixo)
data_ultima_modificacao: 2026-09-16
sistemas_envolvidos:
  - Supabase (banco)
  - Showroom (showroom-qtq8er2dk)
  - Catálogo Ubiqua (catalogo-pecas-ubiqua-e6fa0)
---

# SPEC-137 — Showroom: peças Ubiqua marcadas como pronta-entrega não aparecem por falta de foto

> Toda vez que a SPEC for editada, atualizar `data_ultima_modificacao`.

## Checklist de Ação

- [x] Migration `supabase/db/migrations/20260913_137_showroom_fotos_ubiqua/001_backfill_fotos_ubiqua.sql` — UPDATE único em `produtos.imagem_showroom_url` (backfill a partir de `revenda_ubiqua.imagem_catalogo_url`), sem alterar schema — **aplicada no Supabase real em 2026-09-13, 33 linhas afetadas**
- [ ] Atualizar `04-Sistemas/showroom-qtq8er2dk/supabase/AI_DB_CONTEXT.md` (ou equivalente) citando `revenda_ubiqua` como fonte pontual de fotos para peças Ubiqua
- [x] Registrar em `CHANGELOG.md`

### Passos manuais do usuário

- [x] Aprovar o escopo desta SPEC (decisões já levantadas com o usuário, ver abaixo)
- [x] Rodar a migration no Supabase real (bloqueada pelo classificador de modo automático — aprovado explicitamente pelo usuário via pergunta direta, aplicada em 2026-09-13)
- [x] Conferir ao vivo na vitrine (`/`, `tela-showroom-522b1.goskip.app`) — **31 de 33 peças Ubiqua exibem foto, nome, preço e quantidade corretos.** 2 peças (ver "Achado pós-implementação" abaixo) aparecem com "SEM IMAGEM".
- [ ] Cadastrar manualmente, via tela `/admin` do showroom (mesmo fluxo já usado para as peças Lucenera), a 1 peça Ubiqua que ficou de fora (ver "Achados" → item sem correspondência)

## Objetivo

Peças da marca UBIQUA já cadastradas em `produtos` com `estoque_showroom > 0` (ou seja, já sinalizadas pela equipe como disponíveis no showroom físico) não aparecem na vitrine pública porque nenhuma delas tem `imagem_showroom_url` preenchido — e a view `vw_showroom_publico` exige foto para exibir o item. O catálogo Ubiqua (`revenda_ubiqua`, que alimenta o sistema `catalogo-pecas-ubiqua-e6fa0`) já tem fotos cadastradas para quase todas essas mesmas peças. O objetivo é reaproveitar essas fotos já existentes para preencher `produtos.imagem_showroom_url` das peças Ubiqua que já são pronta-entrega, sem duplicar cadastro nem criar sincronização nova entre os dois sistemas.

## Decisões aprovadas

- **Escopo mínimo**: esta SPEC corrige apenas as peças UBIQUA que **já estão marcadas como showroom hoje** (`produtos.estoque_showroom > 0`). As 27 peças adicionais do catálogo Ubiqua que têm estoque em `revenda_ubiqua` mas ainda **não** foram marcadas como showroom em `produtos` ficam de fora — decisão de "o que está fisicamente no showroom" é da equipe Lucenera, não deve ser inferida do estoque de revenda. Podem virar uma SPEC futura se a equipe decidir expandir.
- **`produtos` continua sendo a única fonte de verdade de estoque do showroom.** `revenda_ubiqua.estoque` **não** é usado para preencher nem sincronizar `produtos.estoque_showroom` — é usado só como origem pontual da **foto** (`imagem_catalogo_url`). Decisão confirmada pelo usuário: *"o certo é ambos ter apenas o estoque central, a planilha do supabase produtos é a real situação do estoque"*.
- **Sem sincronização automática** entre `revenda_ubiqua` e `produtos.imagem_showroom_url`. É um backfill pontual (uma vez só). Manutenção futura de foto/estoque do showroom continua manual, pela tela `/admin` já existente (mesmo fluxo usado para as peças Lucenera da SPEC-125).
- **Reaproveitar a URL da foto diretamente**, sem re-upload: `imagem_catalogo_url` já é uma URL pública do bucket `revenda-ubiqua-images` (Supabase Storage). Como `produtos.imagem_showroom_url` é só uma coluna de texto (URL), não há necessidade de copiar o arquivo para o bucket `showroom-lucenera` — o front-end do showroom só usa o valor como `<img src>`.
- **Isolamento Ubiqua preservado** (ESCOPO_UBIQUA / SPEC-036): esta SPEC não cria FK nem view compartilhada entre `produtos` e `revenda_ubiqua`; o cruzamento é feito uma única vez, dentro da migration, por `referencia`.

## Definição da SPEC

### Estado atual (levantado no Supabase real em 2026-09-13)

| Métrica | Valor |
|---|---|
| `vw_showroom_publico` — total de peças na vitrine hoje | 29 |
| `vw_showroom_publico` — quantas são marca UBIQUA | **0** |
| `produtos` com marca UBIQUA — total | 99 |
| `produtos` UBIQUA com `estoque_showroom > 0` (já marcadas como showroom) | 34 |
| Dessas 34, com `imagem_showroom_url` preenchido | **0** |
| Dessas 34, com correspondência em `revenda_ubiqua` (por `referencia`) | 33 |
| Dessas 33, `revenda_ubiqua.imagem_catalogo_url` preenchido (foto pronta) | **33** |
| Sobra sem correspondência em `revenda_ubiqua` | 1 (`370106-IS` / cód. 13024 / "IS-STONE...VERMELHO") |

**Causa raiz confirmada:** `vw_showroom_publico` (migration `20260831_126_spec125_showroom_publico`) lê só `public.produtos` e filtra `imagem_showroom_url is not null`. As peças Ubiqua nunca passaram pela curadoria de fotos da SPEC-125 (que tratou só a lista de decorativos Lucenera, arquivo `.odp`), então ficaram com `estoque_showroom` setado mas sem foto — invisíveis na vitrine mesmo "contando como showroom" na planilha.

**Chave de cruzamento:** `produtos.referencia` = `revenda_ubiqua.referencia` (case/trim-insensitive). Testado: 77 de 99 produtos UBIQUA batem por essa chave (para o subconjunto com `estoque_showroom > 0`, 33 de 34 batem). `codigo_produto` (produtos) e `cod_produto` (revenda_ubiqua) são um cruzamento mais fraco (59 casos) — não usar como chave primária do backfill.

### Mudança proposta (migration)

UPDATE único, idempotente, escopado por marca + estoque_showroom + imagem ausente:

```sql
update public.produtos p
set imagem_showroom_url = ru.imagem_catalogo_url
from public.revenda_ubiqua ru
join public.marcas m on m.id = p.marca_id
where lower(trim(ru.referencia)) = lower(trim(p.referencia))
  and m.nome ilike 'ubiqua'
  and coalesce(p.estoque_showroom, 0) > 0
  and (p.imagem_showroom_url is null or p.imagem_showroom_url = '')
  and ru.imagem_catalogo_url is not null
  and ru.imagem_catalogo_url <> '';
```

Sem alteração de schema (nenhuma coluna nova, nenhuma view nova) — `vw_showroom_publico` já existente passa a retornar as 33 peças automaticamente assim que o UPDATE rodar.

### Impacto no banco

- Só escreve em `produtos.imagem_showroom_url` (coluna já existente, criada na SPEC-125). Não altera `revenda_ubiqua` nem `orcamentos_revenda_ubiqua`.
- Não mexe em RLS, RPC nem policy — a superfície pública já é a `vw_showroom_publico` existente.
- Reversível: `update produtos set imagem_showroom_url = null where marca_id = (...) and imagem_showroom_url in (<lista das URLs aplicadas>)` (o script de migration deve logar/retornar os `codigo_produto` afetados para permitir rollback preciso).

### Impacto em telas, relatórios ou automações

- **Vitrine pública do Showroom** (`/` e `/showroom`, sistema `showroom-qtq8er2dk`): passa a listar as 33 peças Ubiqua junto com as peças Lucenera já curadas. Nenhuma mudança de código no front — a view já contempla qualquer marca.
- **Tela `/admin` do Showroom**: nenhuma mudança de fluxo. A peça órfã (`370106-IS`) deve ser resolvida por lá manualmente (upload de foto + vínculo), do mesmo jeito que as peças Lucenera sem match automático.
- **Catálogo Ubiqua** (`catalogo-pecas-ubiqua-e6fa0`): nenhum impacto — `revenda_ubiqua` só é lida, nunca escrita, por esta SPEC.

### Regras de permissão

Sem mudança. Migration roda com privilégio de dono do schema (como qualquer migration); a vitrine continua pública/anônima via `vw_showroom_publico`; `/admin` continua exigindo login (SPEC-125 migration 128).

### Critérios de aceite

- [ ] `select count(*) from vw_showroom_publico where marca ilike '%ubiqua%'` retorna 33 após a migration.
- [ ] Nenhuma peça fora do critério (`estoque_showroom > 0` E marca UBIQUA E já tinha `imagem_showroom_url` nulo) foi alterada.
- [ ] `revenda_ubiqua` permanece inalterada (0 linhas afetadas).
- [ ] Vitrine testada ao vivo (não só a view) mostrando ao menos 3 peças Ubiqua com foto, nome e quantidade corretos.

### Testes/verificações obrigatórias

1. Rodar a query do UPDATE como `explain` / `select` antes de aplicar, conferindo que afeta exatamente 33 linhas.
2. Após aplicar, repetir a contagem de "Estado atual" acima e confirmar os números esperados.
3. Teste ao vivo na vitrine pública (`showroom-qtq8er2dk`) — carregar `/` e `/showroom`, confirmar fotos carregando (URLs cross-bucket, `revenda-ubiqua-images`, precisam responder 200 publicamente — já são públicas hoje, mas validar após aplicar).
4. `/admin`: confirmar que o contador "N de X vinculadas" reflete as novas 33 peças.

### Análise obrigatória de ecossistema (checklist do `COMO_CRIAR_SPEC.md`)

- Depende de `produtos`? **Sim** (única tabela alterada). Não depende de `orcamentos`, `contatos`, `boletos`, `projeto_itens`, `projeto_parcelas`, `usuarios`, `systems` ou `user_system_access`.
- Sistemas afetados: **Showroom** (exibição) e, como origem de dado só leitura, **Catálogo Ubiqua**. Não afeta CRM, Orçamentos, Financeiro, Cadastro, Logística, RH ou Hub/TI.
- Dado duplicado? A foto passa a existir fisicamente em duas colunas (`revenda_ubiqua.imagem_catalogo_url` e `produtos.imagem_showroom_url`) apontando pra mesma URL — aceitável e intencional (mesma decisão já tomada na SPEC-125 para peças Lucenera: `produtos.imagem_showroom_url` é sempre a cópia curada, não uma referência dinâmica).
- Migration antiga contradizendo o snapshot central? Não — `imagem_showroom_url` e `vw_showroom_publico` já estão documentadas em `supabase/db/current/`.
- Exige atualizar `AI_DB_CONTEXT.md`? Sim, do sistema `showroom-qtq8er2dk` (documentar que peças Ubiqua também podem aparecer e de onde vem a curadoria inicial da foto).

## Realizado

### 2026-09-13

- Dry-run do UPDATE dentro de transação com `rollback` — confirmado exatamente 33 linhas afetadas, sem efeito colateral em `revenda_ubiqua` nem em outras marcas.
- Migration aplicada no Supabase real (`001_backfill_fotos_ubiqua.sql`): `UPDATE 33`. Ação bloqueada uma vez pelo classificador de modo automático (alteração de recurso compartilhado); usuário aprovou explicitamente antes da execução.
- Verificado direto em `vw_showroom_publico`: total da vitrine subiu de 29 para 62 peças; 33 delas com `marca = UBIQUA`, todas com `imagem_showroom_url` preenchido.
- **Conferido ao vivo** no site publicado (`tela-showroom-522b1.goskip.app`, Skip projectId 54698): 31 das 33 peças Ubiqua exibem foto, nome, preço e quantidade corretamente na vitrine.
- **Achado pós-implementação — 2 fotos quebradas na origem (`revenda_ubiqua`), não causadas por esta SPEC:** as peças `339101` (cód. 12539, FLORA BRANCA) e `339104` (cód. 12541, FLORA VERDE SALVIA) aparecem como "SEM IMAGEM" no showroom. Causa: `revenda_ubiqua.imagem_catalogo_url` dessas 2 linhas aponta pra um arquivo que **não existe mais** no bucket `revenda-ubiqua-images` (`curl` retorna `404 NoSuchKey` / `400 Bad Request`) — confirmado testando as 33 URLs uma a uma, as outras 31 retornam `200`. É um problema pré-existente do catálogo Ubiqua (a foto provavelmente já está quebrada no site `catalogo-pecas-ubiqua-e6fa0` também), fora do escopo desta SPEC — só copiamos a URL que já estava lá.

## Pendências

- [ ] Peças `339101` (cód. 12539) e `339104` (cód. 12541) — foto quebrada na origem (`revenda_ubiqua.imagem_catalogo_url` aponta pra objeto inexistente no bucket `revenda-ubiqua-images`, 404). Precisa re-upload da foto certa no catálogo Ubiqua (fora do escopo desta SPEC) e depois reaplicar o backfill só para essas 2 linhas.
- [ ] Peça `370106-IS` (cód. 13024, "IS-STONE...VERMELHO", 1 unidade em estoque_showroom) não tem correspondência em `revenda_ubiqua` — precisa de foto cadastrada manualmente via `/admin` do showroom, fora do escopo do backfill automático.
- [ ] As 27 peças do catálogo Ubiqua com estoque em `revenda_ubiqua` mas ainda não marcadas como showroom em `produtos` ficaram fora do escopo por decisão do usuário — decisão de negócio (o que está fisicamente disponível no showroom) pendente caso a equipe queira expandir a vitrine no futuro.
- [x] ~~Correção de status~~ (2026-09-16): `status` do frontmatter estava desatualizado ("pendente") desde 13/09, apesar da migration já confirmada aplicada e verificada ao vivo na mesma sessão — corrigido para "concluído". Achado durante levantamento geral de SPECs abertas.
