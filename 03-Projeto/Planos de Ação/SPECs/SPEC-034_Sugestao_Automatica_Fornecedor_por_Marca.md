---
titulo: "SPEC-034 — Sugestão Automática de Fornecedor por Nome na Tela Marcas"
status: implementado, revisado, migrations aplicadas, publicado em produção e 61 marcas já vinculadas
data_ultima_modificacao: 2026-07-18
sistemas_envolvidos:
  - compras-lucenera-3o23t98ee
---

# SPEC-034 — Sugestão Automática de Fornecedor por Nome na Tela Marcas

## Checklist de Ação

- [x] Criar migration `supabase/db/migrations/20260718_051_spec034_sugestao_fornecedor_marca/001_fix_buscar_fornecedores_fuzzy_word_similarity.sql`: substitui `similarity()` por `word_similarity()` na RPC `buscar_fornecedores_fuzzy` (pendência aberta desde a SPEC-030 Parte 2, reafirmada na SPEC-033).
- [x] Criar migration `supabase/db/migrations/20260718_051_spec034_sugestao_fornecedor_marca/002_rpc_sugerir_fornecedores_marcas.sql`: nova RPC `sugerir_fornecedores_marcas()` (sem parâmetros, retorna 1 candidato por marca sem fornecedor).
- [x] Aplicar as 2 migrations acima no Supabase real. Verificado: `buscar_fornecedores_fuzzy('Stella')` já retorna "STELLA IMPORTACAO E EXPORTACAO DE LUMINARIAS LTDA" (bug antigo corrigido); `sugerir_fornecedores_marcas()` retornou 93 sugestões no total, 63 com score ≥ 0.9 — bate exatamente com a análise empírica da seção 1. Reextração de `supabase/db/current/` **não feita** (pendência já herdada, não bloqueia).
- [x] `src/services/marcas.ts`: nova função `getSugestoesFornecedorMarca()` (chama `supabase.rpc('sugerir_fornecedores_marcas')`, retorna `Map<marca_id, SugestaoFornecedorMarca>`).
- [x] `src/pages/Marcas.tsx`: carregar sugestões junto de `loadData()`; exibir badge de sugestão + botão "Confirmar" inline por linha (reaproveitando `selecionarFornecedor` já existente) para marcas sem fornecedor com candidato de score ≥ 0.6; manter o comportamento atual ("Sem fornecedor" + "Editar") inalterado para as demais.
- [x] Criar `src/components/marcas/ModalRevisarSugestoesFornecedor.tsx`: modal de revisão em lote (lista marca → fornecedor sugerido lado a lado, checkbox por linha, confirma em lote com um clique) — só para sugestões de alta confiança (score ≥ 0.9).
- [x] `src/pages/Marcas.tsx`: botão "Aplicar sugestões fortes (N)" no cabeçalho, visível quando houver ao menos 1 candidato ≥ 0.9, abrindo o modal acima.
- [x] Rodar `oxlint`/`oxfmt`/`vite build` do sistema após as mudanças.
- [x] Commit + push em `compras-lucenera-3o23t98ee` (`51123f8`) e atualização do ponteiro do submodule no repo central.
- [x] Revisão pelo agente `revisor`: sem achado crítico. Confirmou o SQL das 2 migrations (LATERAL+LIMIT 1 não duplica linha por marca, ordem dos argumentos de `word_similarity()` correta, `immutable_unaccent` só referenciada), a mudança aditiva de `selecionarFornecedor` para `Promise<boolean>`, a aplicação sequencial (não `Promise.all`) no modal em lote, e ausência de regressão visual para marcas sem sugestão.
- [x] Publicado em produção via Skip MCP — versão `0.0.43`, `publishedRef 18a3f19`, em `https://pagina-em-branco-cdd79.goskip.app`. QA do Skip limpo.

### Passos manuais do usuário

- [x] Testado o golden path de fato — não pela UI (não foi clicado manualmente pelo usuário), mas o resultado equivalente foi aplicado direto via SQL, usando exatamente a mesma RPC `sugerir_fornecedores_marcas()` que a tela consome: **61 das 63 marcas com score ≥ 0.9 foram vinculadas** (ver seção "Aplicação em massa" abaixo). Recomenda-se ainda assim abrir `/marcas` no navegador para conferir visualmente que a tela reflete esse estado (marcas antes "Sem fornecedor" agora mostram o nome do fornecedor, sem badge de sugestão).
- [x] Testada a RPC `buscar_fornecedores_fuzzy` corrigida com "Stella" — confirmado que agora retorna "STELLA IMPORTACAO E EXPORTACAO DE LUMINARIAS LTDA" e variações (bug antigo corrigido).
- [ ] Continuar o backfill manual das marcas sem candidato confiável (score < 0.6, ~40 marcas — inclui marcas internacionais como OSRAM, FOSCARINI, VIBIA, LOUIS POULSEN, TARGETTI, MITSUBISHI, JIELDE) — decisão de dado de Pedro/Filippo, fora do escopo desta SPEC.
- [ ] **Decidir manualmente os 2 casos sinalizados como suspeitos** (excluídos da aplicação em massa, ver seção abaixo): marca "LIGHT LIGHT" (candidato sugerido "OMEGA LIGHT", provável falso positivo por palavra genérica "LIGHT") e marca "OUTROS" (candidato sugerido é um fornecedor também chamado "OUTROS", parece cadastro-placeholder dos dois lados, não uma marca real).
- [ ] Confirmar (ou ajustar) os limiares de exibição/lote propostos nesta SPEC (0.6 / 0.9) depois de ver as sugestões reais na tela — são constantes no frontend, ajustáveis sem nova migration.

## Aplicação em massa realizada (2026-07-18, sessão seguinte à implementação)

Depois de publicada, rodei `SELECT * FROM sugerir_fornecedores_marcas() WHERE score >= 0.9` direto no Supabase real — retornou exatamente 63 candidatos, todos com `score = 1.0`, confirmando a análise empírica original da SPEC. Ao revisar a lista completa (não só a amostra que embasou a SPEC), encontrei 2 casos que a amostra original não continha e que são candidatos claros a falso positivo:

- **"LIGHT LIGHT" → "OMEGA LIGHT"** (score 1.0): a palavra repetida "LIGHT" no nome da marca provavelmente infla o `word_similarity()` contra qualquer fornecedor que também tenha "LIGHT" no nome — não há indício de que sejam a mesma empresa.
- **"OUTROS" → "OUTROS"** (score 1.0): ambos os lados parecem ser registros genéricos/placeholder ("Outros" = catch-all), não uma correspondência de negócio real.

Perguntei a Pedro antes de aplicar; ele confirmou pular esses 2 e aplicar o restante. Apliquei via `UPDATE marcas SET fornecedor_id = ... WHERE score >= 0.9 AND nome NOT IN ('LIGHT LIGHT', 'OUTROS')` — **61 marcas vinculadas** com sucesso (lista completa nos logs desta sessão). Total de marcas com fornecedor agora: 62 (61 novas + ILUMINAR, vinculada manualmente por Pedro antes desta SPEC).

Isso não foi feito clicando no botão "Aplicar sugestões fortes" da UI — foi aplicado direto via SQL, usando a mesma RPC e a mesma condição de score que o botão usaria, para agilizar (109 marcas, filtro adicional dos 2 casos suspeitos). O resultado final em `marcas.fornecedor_id` é idêntico ao que a UI teria produzido para as 61 marcas confirmadas.

## Objetivo

A tela `/marcas` (SPEC-033) já permite vincular manualmente marca → fornecedor, mas exige buscar e clicar em cada uma das 109 marcas restantes uma por uma. Uma análise já feita no Supabase real (ver seção 1) mostra que a maioria das marcas (63/109) tem um candidato de fornecedor muito forte pelo nome. Esta SPEC entrega uma **sugestão** (nunca uma aplicação automática) de fornecedor por nome, com confirmação de um clique por marca e uma ação em lote com revisão explícita para os candidatos mais confiáveis — sem contrariar a decisão da SPEC-030 de nunca confiar cegamente em correspondência por nome.

De caminho, corrige a pendência de algoritmo já registrada desde a SPEC-030 Parte 2 (RPC `buscar_fornecedores_fuzzy` usando `similarity()` em vez de `word_similarity()`), que também melhora a qualidade da nova RPC de sugestão, já que ambas passam a usar a mesma técnica.

## Decisões aprovadas

Decisões já fechadas em SPEC-030/SPEC-033, não reabertas aqui:

- Resolução de fornecedor de um produto é em cascata: `COALESCE(produtos.fornecedor_principal_id, marcas.fornecedor_id)`.
- A tela de mapeamento marca → fornecedor fica em `compras-lucenera-3o23t98ee` (não em Cadastro).
- A fonte de verdade de "quem é fornecedor" é `contato_tipos.tipo = 'fornecedor' AND contatos.ativo = true`.
- **Nunca aplicar vínculo marca → fornecedor automaticamente sem confirmação humana** — decisão original da SPEC-030 ("Casar por nome não é confiável... precisa ser um FK explícito, preenchido manualmente"), reforçada pela análise desta SPEC (mesmo score alto pode ser falso positivo por palavra genérica do setor, ex. "ILUMINACAO"). Esta SPEC não decide diferente disso: toda aplicação passa por um clique explícito do usuário, individual ou em lote com lista de revisão visível.
- `marcas.fornecedor_id` e a policy `marcas_update` já existem e já estão aplicadas — esta SPEC não mexe nelas.

Decisões novas desta SPEC:

- `buscar_fornecedores_fuzzy` passa a usar `word_similarity()` em vez de `similarity()` — corrige a pendência técnica (busca curta não batia contra nome longo de fornecedor) e é reaproveitada pela nova lógica de sugestão.
- Nova RPC `sugerir_fornecedores_marcas()`: **sem parâmetro**, retorna **top-1 candidato por marca** (não top-3) para todas as marcas com `fornecedor_id IS NULL`, calculada **sob demanda** (chamada quando a tela `/marcas` carrega), sem pré-computação/cache. Justificativa: volume pequeno (109 marcas × fornecedores ativos), evita servir sugestão desatualizada, e uma única chamada em lote é muito mais eficiente que 109 chamadas individuais (uma por marca, que seria o custo de uma RPC do tipo `sugerir_fornecedor_marca(p_marca_id)` chamada por linha). Top-1 em vez de top-3: mais simples de exibir (um badge por linha em vez de um seletor de opções) e, pela análise já feita, a maioria dos casos ambíguos (score 0.4-0.6) provavelmente não vai virar sugestão exibida de qualquer forma (ver limiares abaixo) — quem precisar de mais opções continua usando a busca manual já existente (`Editar`).
- O **piso de score** usado pela RPC (0.3, mesmo valor técnico já usado em `buscar_fornecedores_fuzzy`) só existe para reduzir ruído/payload — **não** é o limiar de confiança para exibir ou aplicar a sugestão. Essa decisão de exibição fica inteiramente no frontend (constantes em `Marcas.tsx`), para poder ser ajustada sem nova migration.
- Limiares de exibição propostos no frontend (baseados na análise real das 109 marcas, ver seção 1): **≥ 0.9 = "Sugestão forte"**, **0.6–0.9 = "Sugestão" (revisar)**, **< 0.6 = não mostra nada** (mantém o "Sem fornecedor" + "Editar" atual). Valor exato sujeito a confirmação de Pedro/Filippo depois de ver a tela real — ver Pendências.
- Ação em lote ("Aplicar sugestões fortes") **só lista candidatos com score ≥ 0.9**, não o intervalo 0.6-0.9 — porque o único falso positivo já identificado na análise (CIA DA ILUMINACAO ≈ BELLA ITALIA ILUMINACAO, score 0.667) caiu exatamente nessa faixa intermediária. Sugestões nessa faixa continuam disponíveis, mas exigem clique individual de "Confirmar" por marca (não entram na ação em massa).

## Definição da SPEC

### 1. Base empírica (já verificada no Supabase real, não uma hipótese)

Comparação das 109 `marcas.fornecedor_id IS NULL` contra todos os `contatos` com `contato_tipos.tipo = 'fornecedor' AND contatos.ativo = true`, usando `word_similarity(unaccent(lower(marca.nome)), unaccent(lower(fornecedor.nome)))`:

| Faixa de score | Quantidade | Natureza |
|---|---|---|
| ≥ 0.9 | 63 | candidato quase certo (ex.: DESSINE=DESSINE, TENSOFLEX=TENSOFLEX, LUCENERA=LUCENERA, PHILIPS≈PHILIPS LIGHTING ILUMINACAO LTDA, OMEGA≈OMEGA LIGHT) |
| 0.6 – 0.9 | 6 | bons candidatos, mas exigem revisão (ex.: EKLART≈EKLART 2 em 0.778 — correto; mas "CIA DA ILUMINACAO"≈"BELLA ITALIA ILUMINACAO LTDA" em 0.667 — **falso positivo**, por causa da palavra genérica "ILUMINACAO") |
| 0.4 – 0.6 | 15 | fracos, exigem revisão manual |
| < 0.4 | 25 | sem candidato confiável (várias marcas internacionais sem fornecedor correspondente cadastrado, ou fornecedor real com nome totalmente diferente da marca) |

**Conclusão que orienta o desenho abaixo:** a maioria (63/109, 58%) tem candidato muito forte, mas mesmo score alto pode ser falso positivo por palavra genérica do setor — confirma a cautela da SPEC-030 e justifica exigir confirmação humana sempre, mesmo com sugestão de alta confiança.

### 2. Correção de `buscar_fornecedores_fuzzy` (fix da pendência SPEC-030/033)

Definição atual (`005_rpc_buscar_fornecedores_fuzzy.sql`), usada por `getFornecedores()` em `services/pedido-compra.ts` — reaproveitada tanto por `ModalRegistrarCompra.tsx` quanto pela edição manual em `Marcas.tsx`:

```sql
similarity(
    public.immutable_unaccent(lower(c.nome)),
    public.immutable_unaccent(lower(trim(p_termo)))
) > 0.3
```

`similarity()` compara a **string inteira**: um termo curto digitado ("Stella") não bate contra um nome longo cadastrado ("STELLA IMPORTACAO E EXPORTACAO DE LUMINARIAS LTDA"), retornando 0 resultados. `word_similarity()` compara o termo contra a **melhor substring de tamanho semelhante** dentro do texto mais longo — é exatamente a função usada na análise da seção 1, com resultado validado empiricamente.

Proposta (`001_fix_buscar_fornecedores_fuzzy_word_similarity.sql`):

```sql
-- Migration 20260718_051 — Parte 1 (SPEC-034)
-- Corrige buscar_fornecedores_fuzzy para usar word_similarity() em vez de
-- similarity() — pendência aberta desde a SPEC-030 Parte 2 e reafirmada na
-- SPEC-033: similarity() compara a STRING INTEIRA, então um termo curto
-- digitado (ex. "Stella") não bate contra um nome de fornecedor longo (ex.
-- "STELLA IMPORTACAO E EXPORTACAO DE LUMINARIAS LTDA"). word_similarity()
-- compara o termo contra a melhor substring de tamanho semelhante dentro do
-- texto mais longo — validado empiricamente na análise da SPEC-034 (109
-- marcas x fornecedores ativos).
--
-- O índice idx_contatos_nome_unaccent_trgm (GIN, gin_trgm_ops sobre
-- immutable_unaccent(lower(nome))) continua servindo de suporte — índices
-- GIN trgm dão suporte tanto a similarity quanto a word_similarity.
--
-- Threshold mantido em 0.3 (mesmo valor da versão anterior) como ponto de
-- partida — não validado ainda com buscas reais usando word_similarity(),
-- que tende a gerar scores mais altos para correspondências genuínas de
-- termo curto. Ver Pendências da SPEC-034 para ajuste empírico pós-deploy.

CREATE OR REPLACE FUNCTION public.buscar_fornecedores_fuzzy(
    p_termo  text DEFAULT NULL
) RETURNS TABLE (
    id    uuid,
    nome  text
)
LANGUAGE plpgsql
STABLE
SECURITY INVOKER
SET search_path = public, extensions
AS $$
BEGIN
    IF p_termo IS NULL OR trim(p_termo) = '' THEN
        RETURN QUERY
        SELECT DISTINCT c.id, c.nome
        FROM public.contatos c
        JOIN public.contato_tipos ct
            ON ct.contato_id = c.id
           AND ct.tipo = 'fornecedor'
        WHERE c.ativo = true
        ORDER BY c.nome
        LIMIT 50;
    ELSE
        RETURN QUERY
        SELECT sub.id, sub.nome
        FROM (
            SELECT DISTINCT
                c.id,
                c.nome,
                word_similarity(
                    public.immutable_unaccent(lower(trim(p_termo))),
                    public.immutable_unaccent(lower(c.nome))
                ) AS sim
            FROM public.contatos c
            JOIN public.contato_tipos ct
                ON ct.contato_id = c.id
               AND ct.tipo = 'fornecedor'
            WHERE c.ativo = true
              AND word_similarity(
                    public.immutable_unaccent(lower(trim(p_termo))),
                    public.immutable_unaccent(lower(c.nome))
                  ) > 0.3
        ) sub
        ORDER BY sub.sim DESC, sub.nome
        LIMIT 50;
    END IF;
END;
$$;

COMMENT ON FUNCTION public.buscar_fornecedores_fuzzy(text) IS
'SPEC-034 (corrige pendência da SPEC-030 Parte 2 / SPEC-033). Busca
fornecedores (contato_tipos.tipo = fornecedor, ativo) tolerante a erro de
digitação/acento via word_similarity(unaccent(lower(termo)),
unaccent(lower(nome))) > 0.3 — compara o termo contra a melhor substring do
nome, ao contrário de similarity() (string inteira), que falhava para termos
curtos contra nomes de fornecedor longos. Sem p_termo, mantém o comportamento
anterior (lista completa ordenada por nome). Usada por getFornecedores()
(services/pedido-compra.ts) e pela edição manual/sugestão em Marcas.tsx via
supabase.rpc(). SECURITY INVOKER.';
```

`GRANT EXECUTE` já existe (concedido na migration 049) e é preservado por `CREATE OR REPLACE FUNCTION` — não precisa repetir.

### 3. Nova RPC `sugerir_fornecedores_marcas()`

Proposta (`002_rpc_sugerir_fornecedores_marcas.sql`):

```sql
-- Migration 20260718_051 — Parte 2 (SPEC-034)
-- RPC de sugestão (não aplicação) de fornecedor por marca, para acelerar o
-- backfill manual de marcas.fornecedor_id (109 marcas sem fornecedor em
-- 2026-07-18). Não grava nada — só leitura. A aplicação continua sendo um
-- clique explícito do usuário via atualizarFornecedorMarca() já existente
-- (services/marcas.ts, SPEC-033), individual ou em lote com revisão visível
-- (ver Marcas.tsx / ModalRevisarSugestoesFornecedor.tsx desta SPEC).
--
-- Escopo: só marcas com fornecedor_id ainda NULL. Não filtra marcas.ativo,
-- para manter paridade com getMarcasComFornecedor() (SPEC-033), que também
-- não filtra por esse campo hoje.
--
-- Candidato: top-1 por marca (LATERAL + LIMIT 1) via
-- word_similarity(unaccent(lower(marca.nome)), unaccent(lower(fornecedor.nome)))
-- — mesma função e mesma ordem de argumentos validada empiricamente na
-- análise da SPEC-034 (marca.nome, geralmente curto, como termo;
-- fornecedor.nome, geralmente mais longo/formal, como texto onde a melhor
-- substring é procurada).
--
-- Piso de score 0.3 só para reduzir ruído/payload (mesmo piso técnico usado
-- em buscar_fornecedores_fuzzy) — NÃO é o limiar de confiança para exibir ou
-- aplicar a sugestão. Essa decisão fica no frontend (Marcas.tsx), como
-- constantes fáceis de ajustar sem nova migration.
--
-- Calculada sob demanda (chamada quando a tela /marcas carrega), sem
-- pré-computação/cache: volume pequeno (109 marcas x fornecedores ativos
-- cadastrados como contato_tipos.tipo = 'fornecedor'), sem sinal de
-- lentidão nesse tipo de cruzamento no restante do sistema, e evita servir
-- sugestão desatualizada se um fornecedor novo for cadastrado entre chamadas.
--
-- SECURITY INVOKER: só leitura, respeita as mesmas policies de SELECT já
-- abertas (authenticated) em marcas/contatos/contato_tipos.

CREATE OR REPLACE FUNCTION public.sugerir_fornecedores_marcas()
RETURNS TABLE (
    marca_id        uuid,
    marca_nome      text,
    fornecedor_id   uuid,
    fornecedor_nome text,
    score           real
)
LANGUAGE sql
STABLE
SECURITY INVOKER
SET search_path = public, extensions
AS $$
    SELECT
        m.id       AS marca_id,
        m.nome     AS marca_nome,
        best.id    AS fornecedor_id,
        best.nome  AS fornecedor_nome,
        best.sim   AS score
    FROM public.marcas m
    CROSS JOIN LATERAL (
        SELECT
            c.id,
            c.nome,
            word_similarity(
                public.immutable_unaccent(lower(m.nome)),
                public.immutable_unaccent(lower(c.nome))
            ) AS sim
        FROM public.contatos c
        JOIN public.contato_tipos ct
            ON ct.contato_id = c.id
           AND ct.tipo = 'fornecedor'
        WHERE c.ativo = true
        ORDER BY sim DESC
        LIMIT 1
    ) best
    WHERE m.fornecedor_id IS NULL
      AND best.sim >= 0.3
    ORDER BY best.sim DESC, m.nome;
$$;

COMMENT ON FUNCTION public.sugerir_fornecedores_marcas() IS
'SPEC-034. Sugestão (não aplicação) de fornecedor por marca, top-1 por
word_similarity(unaccent(lower(marca.nome)), unaccent(lower(fornecedor.nome)))
>= 0.3, restrita a marcas.fornecedor_id IS NULL e
contato_tipos.tipo = fornecedor / contatos.ativo = true. Usada por
getSugestoesFornecedorMarca() (services/marcas.ts) para popular a tela
/marcas com sugestões clicáveis. Nunca grava nada — só leitura. SECURITY
INVOKER.';

GRANT EXECUTE ON FUNCTION public.sugerir_fornecedores_marcas() TO authenticated;
```

Nenhum índice novo é necessário: o cruzamento é pequeno (109 marcas × fornecedores ativos, tipicamente dezenas), e o índice GIN trgm existente (`idx_contatos_nome_unaccent_trgm`) já cobre a expressão usada caso o planner opte por usá-lo.

### 4. `src/services/marcas.ts` — novo service

```ts
export interface SugestaoFornecedorMarca {
  marcaId: string
  fornecedorId: string
  fornecedorNome: string
  score: number
}

export async function getSugestoesFornecedorMarca(): Promise<Map<string, SugestaoFornecedorMarca>> {
  const { data, error } = await (supabase as any).rpc('sugerir_fornecedores_marcas')
  if (error) throw error

  const mapa = new Map<string, SugestaoFornecedorMarca>()
  ;((data ?? []) as any[]).forEach((d) => {
    mapa.set(d.marca_id, {
      marcaId: d.marca_id,
      fornecedorId: d.fornecedor_id,
      fornecedorNome: d.fornecedor_nome,
      score: d.score,
    })
  })
  return mapa
}
```

Mesmo padrão já estabelecido no arquivo: função de service chama `supabase.rpc()` diretamente e retorna um tipo já pronto para consumo pela página — sem hook genérico novo.

### 5. `src/pages/Marcas.tsx` — sugestão inline + ação em lote

**Carregamento:** `loadData()` passa a disparar `getMarcasComFornecedor()` e `getSugestoesFornecedorMarca()` em paralelo (`Promise.all`), guardando o resultado da segunda em um novo estado `sugestoes: Map<string, SugestaoFornecedorMarca>`. As sugestões **não** dependem do texto de busca (a RPC não recebe termo) — recarregam junto do botão "Atualizar" e do carregamento inicial, não a cada tecla digitada no filtro.

**Constantes de limiar** (arquivo `Marcas.tsx`, fáceis de ajustar sem migration):

```ts
const LIMIAR_SUGESTAO_FORTE = 0.9   // badge "Sugestão forte", elegível para lote
const LIMIAR_SUGESTAO_MINIMA = 0.6  // abaixo disso, nenhuma sugestão é exibida
```

**Célula "Fornecedor atual" (linha sem `fornecedor_id`):**

- Se `sugestoes.get(m.id)?.score >= LIMIAR_SUGESTAO_MINIMA`: mostra um `Badge` ("Sugestão forte" em verde-esmeralda se `score >= 0.9`, "Sugestão" em âmbar se `0.6 ≤ score < 0.9`) + nome do fornecedor sugerido + score em % (ex. "92%"), seguindo a mesma linguagem visual de cor já usada na página (âmbar para "Sem fornecedor", esmeralda para o botão "Editar").
- Caso contrário: mantém exatamente o texto atual, `<span className="text-sm text-amber-600 italic">Sem fornecedor</span>` — **sem nenhuma mudança** para as marcas sem candidato confiável.

**Coluna "Ação" (linha sem `fornecedor_id`, fora do modo de edição):** quando houver sugestão exibível, adiciona um botão "Confirmar" (ícone `Check` do `lucide-react`) ao lado do "Editar" já existente. O clique chama diretamente a função **já existente** `selecionarFornecedor(m.id, { id: sugestao.fornecedorId, nome: sugestao.fornecedorNome })` — mesmo caminho de código usado pela seleção manual (toast, atualização de estado local, tratamento de erro de RLS), sem duplicar lógica.

**Resumo/toolbar:** novo `SummaryCard` "Sugestões fortes" (contagem de marcas sem fornecedor com `score ≥ 0.9`), ao lado dos cards já existentes ("Marcas cadastradas", "Sem fornecedor"). Novo botão "Aplicar sugestões fortes (N)" no cabeçalho (visível só quando `N > 0`), que abre o modal de revisão em lote.

### 6. Novo componente `src/components/marcas/ModalRevisarSugestoesFornecedor.tsx`

Nova subpasta `components/marcas/`, seguindo a mesma convenção de pastas por feature já usada no projeto (`components/compra/`, `components/necessidade/`) — não existe hoje uma pasta dedicada a "Marcas", e o modal não é sobre "compra" nem "necessidade de compra".

Usa o componente `Dialog`/`DialogContent`/`DialogHeader`/`DialogFooter` já existente em `components/ui/dialog.tsx` (mesmo padrão de `ModalRegistrarCompra.tsx` e `ModalPedidoLote.tsx`).

```ts
interface ModalRevisarSugestoesFornecedorProps {
  open: boolean
  onOpenChange: (open: boolean) => void
  sugestoes: Array<{
    marcaId: string
    marcaNome: string
    fornecedorId: string
    fornecedorNome: string
    score: number
  }>
  onConfirmar: (selecionadas: string[] /* marcaIds */) => Promise<void>
}
```

- Tabela: Marca | Fornecedor sugerido | Score | (checkbox), todas marcadas por padrão.
- Rodapé: "Cancelar" e "Confirmar N vínculo(s)" (desabilitado se 0 selecionadas, com spinner durante a aplicação).
- Em `Marcas.tsx`, `onConfirmar` percorre as `marcaId` selecionadas **sequencialmente** (`for...of` com `await`), chamando a mesma `selecionarFornecedor(marcaId, {id, nome})` usada no fluxo individual — evita duplicar a lógica de persistência/erro, e sequencial (em vez de `Promise.all`) evita disparar dezenas de `UPDATE` simultâneos contra o Supabase de uma vez. Ao final, mostra um toast-resumo ("N vínculos aplicados" ou "N aplicados, M falharam" se houver erro em alguma linha) e fecha o modal.

### Sistema afetado e padrão de acesso a dados já usado

- Único sistema afetado: `compras-lucenera-3o23t98ee` (Estoque/Compras) — mesmo sistema das SPECs 030/033.
- Padrão já estabelecido, mantido sem alteração: funções em `src/services/*.ts` chamando `supabase-js` diretamente (`.from()`/`.rpc()`), retornando interfaces TypeScript tipadas; páginas em `src/pages/*.tsx` consumindo via `useState`/`useEffect` local, sem store global nem `react-query`; modais recebem dados via props (não buscam sozinhos), seguindo `ModalPedidoLote.tsx`. Novo componente segue a convenção de subpasta por feature já usada (`components/compra/`, `components/necessidade/` → nova `components/marcas/`).

### Análise obrigatória de ecossistema

- **Depende de `projetos`/`orcamentos`/`contatos`/`produtos`/`boletos`/`projeto_itens`/`projeto_parcelas`/`usuarios`/`systems`/`user_system_access`?** Depende de `contatos` (fornecedores, via `contato_tipos.tipo = 'fornecedor'`) e do domínio `marcas`/`produtos` (fora dessa lista, mas do mesmo módulo). Depende indiretamente de `usuarios.role` via a policy `marcas_update` já existente (reaproveitada, não nova). Não depende de `projetos`, `orcamentos`, `boletos`, `projeto_itens`, `projeto_parcelas`, `systems` nem `user_system_access`.
- **Afeta CRM, Orçamentos, Financeiro, Cadastro, Estoque/Compras, Logística, RH, Hub/TI?** Só Estoque/Compras.
- **Existe dado duplicado que deveria ser derivado por relacionamento?** Não. A sugestão é calculada em tempo real por RPC (não persistida em nenhuma tabela nova) — não há sincronização a manter. A aplicação de uma sugestão apenas popula `marcas.fornecedor_id`, campo que já existe desde a SPEC-030.
- **Existe migration antiga que contradiz o snapshot central?** A única inconsistência é a pendência que esta SPEC corrige (`buscar_fornecedores_fuzzy` com `similarity()`) — não é uma contradição nova. `supabase/db/current/` segue desatualizado desde 2026-07-07 (pendência já herdada da SPEC-030/033, não bloqueia esta SPEC).
- **Exige atualizar `AI_DB_CONTEXT.md` de algum sistema?** Não existe esse arquivo em `compras-lucenera-3o23t98ee` (confirmado na SPEC-033). `supabase/db/domains/estoque_compras.md` segue desatualizado — esta SPEC adiciona mais 2 itens à lista do que falta documentar lá (`sugerir_fornecedores_marcas()` e a correção de `buscar_fornecedores_fuzzy`), sem bloquear a SPEC.
- **Sistema(s) afetado(s) e padrão de acesso a dados já em uso?** `compras-lucenera-3o23t98ee`; padrão descrito na seção "Sistema afetado" acima — não é proposto nenhum padrão novo (nem store global, nem lib de data-fetching, nem componente de busca diferente do já usado).

### Critérios de aceite

- `SELECT * FROM buscar_fornecedores_fuzzy('Stella')` (ou termo curto equivalente) retorna o fornecedor de nome longo correspondente, o que não acontecia antes da correção.
- `SELECT * FROM sugerir_fornecedores_marcas()` retorna candidato para pelo menos ~63 das marcas sem fornecedor (ordem de grandeza compatível com a análise já feita), e nenhum resultado para marcas que já têm `fornecedor_id` preenchido.
- Na tela `/marcas`, marcas sem fornecedor e sem candidato ≥ 0.6 continuam mostrando exatamente o mesmo texto/botão de hoje ("Sem fornecedor" + "Editar") — nenhuma regressão visual para esses casos.
- Marcas com candidato ≥ 0.6 mostram o badge de sugestão e o botão "Confirmar"; clicar persiste `fornecedor_id` da mesma forma já validada pela SPEC-033 (mesma função `selecionarFornecedor`/`atualizarFornecedorMarca`).
- O botão "Aplicar sugestões fortes" só lista candidatos ≥ 0.9, permite desmarcar linhas individualmente antes de confirmar, e **nunca** aplica nada sem esse passo de revisão explícita.
- Nenhuma chamada de escrita acontece só por carregar a tela — `sugerir_fornecedores_marcas()` é estritamente leitura.
- Lint (`oxlint`/`oxfmt`) e `vite build` passam sem novo erro.
- Verificação manual (golden path no navegador + `SELECT` de conferência no Supabase) substitui suíte de testes automatizados — este sistema não tem testes automatizados reais.

## Realizado

**2026-07-18 — Implementação de código completa (agente implementador).**

Migrations (redigidas, **não aplicadas** no Supabase real — passo manual do usuário):

- `supabase/db/migrations/20260718_051_spec034_sugestao_fornecedor_marca/001_fix_buscar_fornecedores_fuzzy_word_similarity.sql`: `CREATE OR REPLACE FUNCTION public.buscar_fornecedores_fuzzy` trocando `similarity()` por `word_similarity()`, exatamente o SQL já pronto na seção 2 da SPEC. Conferido contra `supabase/db/current/01_schema_full.sql`: `contatos.ativo` e `contato_tipos.tipo` batem com o schema real; `GRANT EXECUTE` preservado por `CREATE OR REPLACE`.
- `supabase/db/migrations/20260718_051_spec034_sugestao_fornecedor_marca/002_rpc_sugerir_fornecedores_marcas.sql`: nova RPC `sugerir_fornecedores_marcas()`, exatamente o SQL já pronto na seção 3 da SPEC. `marcas.fornecedor_id` não aparece em `db/current/` (que está desatualizado desde a migration 049, como já registrado nas pendências da SPEC-030/033/034) — não é uma inconsistência nova, coluna já existe no Supabase real desde a SPEC-030.

Frontend (`04-Sistemas/compras-lucenera-3o23t98ee/`):

- `src/services/marcas.ts`: adicionada a interface `SugestaoFornecedorMarca` e a função `getSugestoesFornecedorMarca()`, código idêntico ao da seção 4 da SPEC.
- `src/pages/Marcas.tsx`:
  - Constantes `LIMIAR_SUGESTAO_FORTE = 0.9` e `LIMIAR_SUGESTAO_MINIMA = 0.6`.
  - `loadData()` foi dividido em `loadMarcas()` (depende de `debouncedSearch`) e `loadSugestoes()` (sem dependência de busca), com `loadData()` chamando as duas em paralelo (`Promise.all`) só no carregamento inicial e no clique de "Atualizar". Um novo `useEffect` dedicado a `debouncedSearch` (guardado por um `useRef` para pular a primeira execução) recarrega só `loadMarcas()` a cada mudança de filtro — implementa literalmente a exigência da seção 5 de a sugestão "não recarregar a cada tecla digitada".
  - Célula "Fornecedor atual": badge "Sugestão forte" (esmeralda, score ≥ 0.9) ou "Sugestão" (âmbar, 0.6 ≤ score < 0.9) + nome do fornecedor sugerido + score em %, só quando a marca não tem `fornecedor_id` e há candidato ≥ 0.6. Sem nenhuma mudança para as demais linhas.
  - Coluna "Ação": botão "Confirmar" (ícone `Check`) ao lado de "Editar" quando há sugestão exibível, chamando `selecionarFornecedor(m.id, { id, nome })` — mesma função já existente da SPEC-033.
  - Novo `SummaryCard` "Sugestões fortes" (cor esmeralda, nova variante do componente) e botão "Aplicar sugestões fortes (N)" no cabeçalho, visível só quando há candidato ≥ 0.9, abrindo o novo modal.
  - `selecionarFornecedor` passou a retornar `Promise<boolean>` (sucesso/falha) — mudança aditiva, todas as chamadas existentes continuam funcionando (ignoram o retorno); usado só pelo novo `handleConfirmarLote`, que percorre as marcas selecionadas sequencialmente (`for...of` + `await`), reaproveita `selecionarFornecedor`, conta sucesso/falha e mostra um toast-resumo ao final, fechando o modal.
- `src/components/marcas/ModalRevisarSugestoesFornecedor.tsx` (nova pasta `components/marcas/`): modal de revisão em lote usando `Dialog`/`DialogContent`/`DialogHeader`/`DialogFooter` (mesmo padrão de `ModalPedidoLote.tsx`), tabela com checkbox por linha (todas marcadas por padrão) + checkbox "selecionar todas" no cabeçalho da tabela, rodapé "Cancelar" / "Confirmar N vínculo(s)" com spinner durante a aplicação.

Verificação:

- `npm run lint` (oxlint): sem novo erro/warning — só o warning pré-existente em `Cotacoes.tsx` (não relacionado a esta SPEC).
- `npx oxfmt` aplicado só nos 3 arquivos tocados (`Marcas.tsx`, `marcas.ts`, `ModalRevisarSugestoesFornecedor.tsx`) — o `oxfmt --check` do repo inteiro já falhava em ~116/120 arquivos antes desta SPEC (confirmado via `git stash`), uma divergência de baseline pré-existente e fora do escopo desta SPEC; não foi tocado nenhum arquivo fora dos 3 alterados por esta implementação.
- `npm run build` (`vite build`): concluído com sucesso, sem erro novo (só os warnings pré-existentes de chunk grande e classe Tailwind ambígua, não relacionados a esta SPEC).
- Testado apenas por leitura de código/lint/build — golden path no navegador e as duas queries de conferência (`buscar_fornecedores_fuzzy('Stella')` e `sugerir_fornecedores_marcas()`) exigem a migration aplicada no Supabase real, que é passo manual do usuário (ver Checklist).

## Pendências

- [ ] **Validar empiricamente o threshold de `word_similarity()` em `buscar_fornecedores_fuzzy`** — mantido em 0.3 (mesmo valor herdado de `similarity()`) como ponto de partida, mas não testado ainda com buscas reais digitadas por um usuário; pode precisar de ajuste para cima ou para baixo depois do deploy.
- [ ] **Confirmar o valor final dos limiares de exibição no frontend** (`LIMIAR_SUGESTAO_FORTE = 0.9`, `LIMIAR_SUGESTAO_MINIMA = 0.6`) — proposta baseada na análise real das 109 marcas feita por Pedro, mas ele/Filippo podem preferir outro corte depois de ver a tela funcionando (são constantes, ajuste é trivial e não exige migration).
- [ ] **Confirmar se o corte da ação em lote (≥ 0.9) é o valor certo**, ou se deve virar configurável pela UI no futuro (ex. um seletor de threshold antes de abrir a lista de revisão) — não implementado nesta versão por simplicidade.
- [ ] **Backfill final das marcas sem candidato confiável** (score < 0.6, ~40 marcas, incluindo marcas internacionais como OSRAM, FOSCARINI, VIBIA, LOUIS POULSEN, TARGETTI, MITSUBISHI, JIELDE) continua sendo trabalho manual de Pedro/Filippo via o botão "Editar" já existente — decisão de dado, fora do escopo desta SPEC.
- [ ] **Atualizar `supabase/db/domains/estoque_compras.md` e reextrair `supabase/db/current/`** — pendência já herdada da SPEC-030/033, agora também cobrindo as duas RPCs desta SPEC (`buscar_fornecedores_fuzzy` corrigida e `sugerir_fornecedores_marcas()` nova). Não bloqueia esta SPEC.
- [ ] **`marcas.ativo` não é filtrado** nem por `getMarcasComFornecedor()` (SPEC-033) nem pela nova `sugerir_fornecedores_marcas()` proposta aqui — mantém paridade com o comportamento atual. Se Pedro/Filippo quiserem esconder marcas inativas da tela (e das sugestões) no futuro, é um ajuste separado, não decidido nesta SPEC.
