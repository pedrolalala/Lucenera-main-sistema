---
titulo: "SPEC-150 — Catálogo Ubiqua: unificar cores da mesma peça num só card (família de produto)"
status: concluído
data_ultima_modificacao: 2026-09-15
sistemas_envolvidos:
  - Catálogo Ubiqua (catalogo-pecas-ubiqua-e6fa0)
---

# SPEC-150 — Catálogo Ubiqua: unificar cores da mesma peça num só card (família de produto)

> Toda vez que a SPEC for editada, atualizar `data_ultima_modificacao`.

## Checklist de Ação

- [x] Extrair uma "identidade de família" da descrição de cada peça (nome + forma do produto, ex.: `TORUS`, `TORUS DESK`, `FLORA MINI`), ignorando a parte da descrição que varia entre empresas/cores (`src/hooks/use-parts.ts`, `extractFamilyIdentity()`)
- [x] Trocar a chave de agrupamento de `groupCatalogItems()` pra usar essa família como chave principal (cores diferentes da mesma peça caem no mesmo card, com seletor de cor), mantendo `-V2` sempre separado explicitamente via referência
- [x] Manter fallback pra referência (comportamento da SPEC-147) quando a descrição não tem palavra de fronteira reconhecível (acessórios: cabo/carregador) — evita juntar itens genéricos que não têm texto suficiente pra se distinguir
- [ ] Testar visualmente no navegador (extensão Chrome ficou instável nesta sessão — validado só via script contra o banco real, ver "Realizado")

### Passos manuais do usuário

- [ ] Conferir visualmente no catálogo publicado que as famílias abaixo aparecem corretas antes de aprovar publicação
- [ ] Revisar se algum produto que hoje aparece "sozinho" deveria ter cores adicionais que não bateram com a regra de família (ver "Pendências")

## Objetivo

Depois da SPEC-147 (que unificou Manoella×Islight pela **referência exata**), o usuário reparou ao vivo que peças com a mesma forma física mas cores diferentes — cada cor com seu próprio número de referência (ex.: BLOK cimento=`100161`, mármore branco=`100162`; Torus Piso preta=`366302`, branca=`366301`) — continuavam aparecendo como cards separados. Pedido: juntar tudo isso num card só, com seletor de cor, e o representante escolhe a cor na hora da compra.

## Decisões aprovadas

- Peças da mesma "família" (mesmo nome+forma de produto, cores diferentes, referências diferentes) devem aparecer como 1 card, com seletor de cor — mesmoædrão que já existia pra cores dentro do mesmo grupo por referência (SPEC-147).
- Preço mostrado no card muda conforme a cor selecionada (já existia: `selectedVariant.valor_revenda`); só antes de escolher cor é que aparece um preço "default" (o da primeira linha retornada pelo banco, não necessariamente o menor — comportamento pré-existente, não alterado aqui). Padrão já usado pela SPEC-147.
- BLOK V2 (`100161` a `100164-V2-IS`): tinha `vl_venda_produto` nulo (lacuna de cadastro central, não existe BLOK V2 em `produtos`); usuário decidiu usar o preço do BLOK mais caro (R$1.788,24, acabamento mármore) pras 4 linhas — aplicado via `UPDATE` direto em `revenda_ubiqua` (ver "Realizado").
- Abordagem escolhida entre as opções discutidas: **automatizar com correspondência aproximada** (não é fuzzy-string genérico — ver "Definição da SPEC" pra explicação do porquê e como).

## Definição da SPEC

### Por que não deu pra usar fuzzy-string genérico nem descrição crua

Testei contra os dados reais antes de implementar:

- **Descrição sozinha não basta**: `366301` (Torus Piso, Manoella) tem `descricao`="TORUS LUMINÁRIA **LED** DE PISO BATERIA..." e `366302-IS` (mesmo Torus Piso, Islight) tem "TORUS LUMINÁRIA DE PISO BATERIA..." (sem a palavra "LED") — diferença real de palavra, não só formatação. Comparação exata de texto não junta esse par.
- **Fuzzy-string cru (Jaccard) é perigoso**: comparando token a token, o par correto (Torus Piso Manoella × Islight) dá ~91% de similaridade, mas o par **errado** (Torus Piso × Torus **Desk**, produtos diferentes!) dá ~77% — margem estreita demais pra um limiar de similaridade genérico ser seguro num catálogo ao vivo.
- **`cod_produto`** é único por cor (não serve de chave de família) e vem nulo pra fontes inteiras (ex.: todo o BLOK).

**Solução adotada — identidade estrutural, não fuzzy-distância:** nos textos da Ubiqua, o nome+forma do produto (`TORUS`, `TORUS DESK`, `FLORA MINI`, etc.) sempre vem **antes** da palavra "LUMINÁRIA/LUM./LED/BATERIA"; tudo depois disso é especificação técnica que varia de texto entre as duas fontes de planilha sem mudar o produto. `extractFamilyIdentity()` corta a descrição na primeira dessas palavras e usa o que sobra como identidade da família:

```
"TORUS LUMINÁRIA LED DE PISO..."       → "TORUS"        (LED fica de fora, não afeta)
"TORUS DESK LUMINÁRIA LED DE MESA..."  → "TORUS DESK"    (DESK fica DENTRO, produto diferente)
"IS-FLORA MINI LUM. LED DE MESA..."    → "FLORA MINI"
"GOOD NIGHT LUMINARÁRIA LED DE MESA..."→ "GOOD NIGHT"
```

Quando nenhuma dessas palavras aparece na descrição (acessórios como "IS - CABO CARREGADOR"), a função retorna `null` e o código cai de volta no agrupamento por referência exata (comportamento da SPEC-147, inalterado) — evita juntar acessórios genéricos que não têm texto suficiente pra se diferenciar um do outro (ex.: duas referências de cabo carregador diferentes têm a **mesma** descrição genérica "CABO CARREGADOR").

V2 continua sempre separado, mas agora via checagem explícita na **referência** (`isV2Referencia()`, regex `-V2(-|$)`), não por texto — mais robusto, já que a palavra "V2" nem sempre aparece na descrição.

### Validação contra o banco real (antes de considerar pronto)

Rodei a função (copiada literalmente, fora do Vite) contra as 87 linhas reais de `revenda_ubiqua` via REST:

| Métrica | Antes (SPEC-147) | Depois (SPEC-150) |
|---|---|---|
| Cards na vitrine | 63 | **28** |

Conferido card a card que nada foi juntado errado:

- `TORUS` (Piso) / `TORUS DESK` / `TORUS GLASS` / `TORUS FLY` → **4 cards separados**, cada um com sua(s) cor(es) — exatamente o caso de risco identificado acima, resolvido corretamente.
- `FLORA` / `FLORA MINI` / `FLORA MINI_V2` → 3 cards separados (tamanho normal vs mini vs mini-V2).
- `STANDY` / `STANDY MINI` / `STANDY MINI_V2` → 3 cards separados.
- `PLISSE` / `PLISSE MINI` → 2 cards separados.
- `CRYSTAL` → 1 card juntando 2 cores (`CORTEN`, `BRONZE FOSCO`) × 2 empresas (4 linhas), incluindo o par de preço divergente da SPEC-147 (`332109`).
- `BLOK_V2` → 1 card juntando as 4 cores (cimento + 3 mármores).
- Acessórios (`P.CH.CABLE`, `C.CH.CABLE`, `F.CH.CABLE`, `S.CH.CABLE`, `T.CH.CABLE`, `H185`, `366902`) → continuam 1 card cada, sem tentativa de junção (caem no fallback por referência).

Script de validação: `scratchpad/test-grouping.mjs` (fora do repo, sessão local).

### Impacto no banco

Nenhuma mudança de schema. Um `UPDATE` de dados foi aplicado em `revenda_ubiqua.vl_venda_produto` pras 4 linhas do BLOK V2 (decisão do usuário, ver "Decisões aprovadas") — não é uma migration versionada, é correção pontual de dado faltante na importação original.

### Impacto em telas

- **Vitrine pública** (`Index.tsx`/`useParts()`) e **página de produto** (`ProductDetail.tsx`/`useProductDetail()`): cards de peças com múltiplas cores agora aparecem unificados com seletor de cor (mecanismo de seleção já existia desde a SPEC-147, só passou a ser acionado com mais frequência).
- Nenhuma mudança em `PartCard.tsx`, `PartDetailSheet.tsx`, `AdminCatalog.tsx`, `QuantityModal.tsx` além do já feito na SPEC-147.

### Critérios de aceite

- [x] Torus Piso, Torus Desk, Torus Glass e Torus Fly aparecem como 4 cards distintos (validado via script).
- [x] Flora, Flora Mini e Flora Mini V2 aparecem como 3 cards distintos (validado via script).
- [x] BLOK (4 cores) aparece como 1 card só (validado via script).
- [ ] Confirmação visual ao vivo no navegador (pendente — extensão Chrome instável nesta sessão).
- [ ] Preço muda corretamente ao trocar de cor no card unificado do BLOK (mecanismo já existente e usado pela SPEC-147, mas não re-testado ao vivo nesta sessão especificamente pro caso de 4 cores com 2 preços diferentes).

## Realizado

**2026-09-15** — Implementado em `04-Sistemas/catalogo-pecas-ubiqua-e6fa0/src/hooks/use-parts.ts`:

- Novas funções `isV2Referencia()` e `extractFamilyIdentity()`.
- `groupCatalogItems()`: chave de agrupamento agora prioriza a identidade de família extraída da descrição (com sufixo `_V2` quando a referência indica variante V2); cai pra referência normalizada (comportamento SPEC-147) quando a descrição não tem palavra de fronteira reconhecível.
- Validado via script Node contra os dados reais do Supabase (87 linhas → 28 grupos), conferido caso a caso contra os riscos identificados (Torus Desk vs Piso vs Glass vs Fly, Flora vs Flora Mini, V2 vs normal) — todos corretos.
- **Correção de dado** (não é código): `UPDATE` em `revenda_ubiqua.vl_venda_produto = 1788.24` pras 4 linhas do BLOK V2 (`100161-V2-IS` a `100164-V2-IS`), que estavam nulas — decisão do usuário de usar o preço do BLOK mais caro (mármore) já que o BLOK V2 nunca foi cadastrado na tabela central `produtos` (só existe lá o BLOK sem V2).
- **Não testado ao vivo no navegador** nesta sessão — extensão Claude in Chrome ficou desconectada/instável; validação foi só via script contra o banco real (ver tabela acima) e leitura de código.
- **Commitado e publicado (2026-09-15)**: commit `c3b10ed` (+ `0842d77` doc) no submodule, push feito pro GitHub, publicado no Skip junto com a SPEC-147 (v0.0.88, `catalogo-pecas-ubiqua-e6fa0.goskip.app`), a pedido explícito do usuário, mesmo sem o teste visual ao vivo.

## Pendências

- [ ] Teste visual ao vivo no navegador (extensão Chrome não conectou nesta sessão) — confirmar visualmente que os cards aparecem como esperado e que o seletor de cor/preço funciona no BLOK (4 cores, 2 preços diferentes).
- [ ] `FAMILY_BOUNDARY_WORDS` foi calibrado só com os produtos existentes hoje no catálogo (87 linhas). Se o catálogo crescer com produtos de nome/formato diferente do padrão observado (ex.: um produto cujo nome contenha a palavra "LED" ou "BATERIA" como parte do nome, não como especificação técnica), a extração de família pode cortar errado — vale revisar se o catálogo mudar muito de formato.

## Revisão

**2026-09-15 (agente `revisor`):** confirmou build/lint limpos, só `use-parts.ts` alterado, `boundaryIndex`/ordem `descricao`||`desc_produto` corretos, e os 5 acessórios de cabo/carregador corretamente não unificados (fallback por referência). Apontou um 🟡: que a linha `323206` (GOOD NIGHT) teria `descricao` corrompida com `U+FFFD` e formaria um card extra "GOOD NIGHT LUMINAR RIA" separado dos irmãos, dando 29 grupos em vez de 28.

**Verificado e descartado**: dump dos codepoints reais de `revenda_ubiqua.descricao` da linha `323206` (via REST, id 117) mostra `has U+FFFD: false` — o caractere no lugar de "Á" é `0xC1` (U+00C1, "Á" válido), não um replacement character. Rodei a função `extractFamilyIdentity()` real (não uma reimplementação) contra essa string exata: retorna `"GOOD NIGHT"`, idêntico aos irmãos `323202`/`323204`. Reconfirmada a contagem original: **87 linhas → 28 grupos**, com `GOOD NIGHT` unificado em 1 card com as 3 cores. O achado do revisor foi falso positivo, provavelmente por um bug de encoding no script de verificação dele (dupla decodificação UTF-8), não um problema nos dados ou no código desta SPEC.
