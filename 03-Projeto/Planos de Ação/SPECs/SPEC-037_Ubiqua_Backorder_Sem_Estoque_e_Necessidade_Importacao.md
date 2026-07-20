---
titulo: "SPEC-037 — Catálogo Ubiqua: texto 'Sem estoque', pedido sob encomenda (backorder), necessidade de importação e notificação por e-mail"
status: não iniciado
data_ultima_modificacao: 2026-07-19
sistemas_envolvidos:
  - Catálogo de Peças Ubiqua (catalogo-pecas-ubiqua-e6fa0)
---

# SPEC-037 — Catálogo Ubiqua: texto "Sem estoque", pedido sob encomenda (backorder), necessidade de importação e notificação por e-mail

> Toda a marca Ubiqua vendida neste catálogo é importada pela empresa do usuário para revenda no Brasil.
> "Sem estoque" e "aguardando importação" são, portanto, o mesmo conceito — não um subconjunto especial.

> **Atualização 2026-07-19:** o usuário respondeu duas Pendências abertas (teto de quantidade e campo manual de status de compras) e pediu duas coisas novas: (1) o aviso de backorder no `QuantityModal.tsx` ficar visualmente mais elaborado, usando o logo real da Ubiqua; (2) notificação por e-mail para Vinicius e Pedro em todo pedido salvo, além de consertar o disparo de e-mail já existente na aprovação do admin. A investigação de grounding para o item (2) encontrou uma Edge Function que já faz quase exatamente isso hoje (`process-budget-pdf`) — ver "Achado crítico de grounding" na Definição da SPEC antes de implementar qualquer disparo novo.

## Checklist de Ação

- [x] Trocar o texto do badge/label de estoque zerado para "Sem estoque" em todos os pontos onde hoje aparece "Não tem aquela peça em estoque" (`PartCard.tsx`, `QuantityModal.tsx`, `NewQuote.tsx`). **Feito em 2026-07-20**, publicado (`da6de95`), verificado no navegador em produção.
- [x] `PartCard.tsx`: remover `isOutOfStock` da condição `disabled` do botão "Adicionar ao Orçamento" (linha ~202) — botão sempre habilitado. **Feito em 2026-07-20.**
- [x] `QuantityModal.tsx`: substituir o bloco de aviso estático (linhas ~115-121) por um aviso real de backorder ("peça sem estoque — prazo estimado de até 3 meses para importação, pedido sob encomenda") com confirmação explícita (checkbox de ciência) que libera o botão "Confirmar". **Feito em 2026-07-20**, testado no navegador: botão "Confirmar" fica desabilitado até marcar o checkbox.
- [x] `QuantityModal.tsx`: redesenhar esse bloco de aviso como um card visual com o logo da marca (`public/og-image.png`, servido em `/og-image.png` pelo Vite — já existe, não precisa criar/pedir imagem nova) no topo, em vez de texto corrido — ver "Mudança 4". **Feito em 2026-07-20**, confirmado visualmente em produção.
- [x] `QuantityModal.tsx`: corrigir o cálculo de quantidade máxima (`Math.min(disponivel, ...)`) para não travar em 0 quando a peça está sem estoque — usar um teto de sanidade técnica em vez do `disponivel` quando `disponivel <= 0` (teto técnico provisório: **999** — ver Pendências sobre o valor de negócio real). **Feito em 2026-07-20** — teto ainda provisório, aguardando conversa do usuário com o gerente em 2026-07-20 para o valor de negócio real.
- [x] `use-cart.tsx` (`addToCart`): remover o guard `if (disponivel <= 0) return` — hoje isso bloqueia silenciosamente qualquer adição de item sem estoque, mesmo que a UI permita clicar. Manter o clamp `Math.min(disponivel, quantity)` apenas quando `disponivel > 0`. **Feito em 2026-07-20.**
- [x] `NewQuote.tsx`: alinhar o combobox de busca de produto (linhas ~546-579) com o mesmo comportamento — hoje tem `disabled={isOutOfStock}` e `onSelect` com early-return, um terceiro ponto de bloqueio silencioso não mencionado no pedido original. **Feito em 2026-07-20** — combobox permite selecionar peça sem estoque (mostra "Sem estoque" como indicador informativo, não bloqueia mais).
- [x] `NewQuote.tsx`: revisar os controles de quantidade do carrinho já adicionado (mobile linhas ~648-687, desktop ~727-763) — hoje capam incremento/edição em itens com `disponivel = 0`, o que impediria ajustar a quantidade de um item de backorder já confirmado. Nota: há uma inconsistência existente entre o fallback `|| 1` (linhas 664/741, usado no `max` do input) e `|| 0` (linhas 682/759, usado no `disabled` do botão `+`) que o implementador precisa reconciliar, não copiar cegamente. **Feito em 2026-07-20** — ambos os blocos usam agora `itemMaxQty` (disponivel > 0 ? disponivel : 999), reconciliando a inconsistência.
- [x] Migration `supabase/db/migrations/20260719_053_ubiqua_necessidade_importacao/`: adicionar `itens_orcamento_ubiqua.sem_estoque_no_pedido boolean NOT NULL DEFAULT false`. **Rascunhada em 2026-07-20** (`001_sem_estoque_no_pedido.sql`) — não aplicada no Supabase real, aplicação é passo manual do usuário.
- [x] Mesma migration: criar view `public.vw_necessidade_importacao_ubiqua` (agregada por produto/variante, `security_invoker`). **Rascunhada em 2026-07-20** (`002_vw_necessidade_importacao_ubiqua.sql`) — não aplicada.
- [x] `NewQuote.tsx` (`executeSaveQuote`): preencher `sem_estoque_no_pedido` no insert de `itens_orcamento_ubiqua` a partir do `disponivel` capturado no item do carrinho no momento do salvamento. **Feito em 2026-07-20** — só terá efeito real após a migration ser aplicada no Supabase.
- [x] `NewQuote.tsx` (`executeSaveQuote`): preencher `orcamentos_revenda_ubiqua.prazo_entrega` com um texto padrão de aviso de importação quando o orçamento contiver ao menos um item com `sem_estoque_no_pedido = true`. **Feito em 2026-07-20.**
- [ ] **[Bloqueado até resolver a Pendência crítica de sobreposição]** Reescrever a Edge Function `enviar-confirmacao-email` (existe em duas cópias hoje — `04-Sistemas/catalogo-pecas-ubiqua-e6fa0/supabase/functions/enviar-confirmacao-email/index.ts` e o espelho em `supabase/functions/enviar-confirmacao-email/index.ts` do repo central, ambas idênticas e ambas stub) para efetivamente enviar e-mail via Resend, no mesmo padrão de `welcome-email/index.ts` — incluindo HTML com o logo Ubiqua. Atualizar as **duas cópias** (ou esclarecer com o usuário qual é a fonte real de deploy) para não deixá-las divergentes.
- [ ] **[Depende da confirmação manual descrita no "Achado crítico de grounding"]** Decidir e, se aplicável, implementar em `NewQuote.tsx` (`executeSaveQuote`) o novo disparo de e-mail para `vinicius@lucenera.com.br` e `pedro@lucenera.com.br` em todo pedido salvo via `enviar-confirmacao-email` — só faz sentido como disparo novo se `process-budget-pdf` (que já roda nesse mesmo evento e já manda e-mail pros mesmos dois endereços) não estiver de fato entregando e-mail hoje.
- [ ] Alternativamente (dependendo da checagem acima): corrigir o bug de erro engolido em `process-budget-pdf` (`if (!res.ok) { console.error(...) }` sem `throw` — a function retorna `success: true` mesmo se o Resend falhar) e, opcionalmente, incluir o logo Ubiqua no HTML de e-mail que essa function já monta.
- [x] Registrar (sem corrigir necessariamente nesta leva) o bug de assinatura em `sendQuoteEmail` (`src/lib/api.ts`, 1 argumento `payload`) chamada com 3 argumentos em `NewQuote.tsx` (`handleSendEmail`, linha ~278) — fluxo diferente (envio do PDF ao e-mail que o cliente digita), não confundir com a notificação Vinicius/Pedro. Ver Pendências. **Registrado, não corrigido** — fora do escopo direto dos pedidos do usuário.
- [x] Atualizar `04-Sistemas/catalogo-pecas-ubiqua-e6fa0/supabase/AI_DB_CONTEXT.md` com a nova coluna e a nova view. **Feito em 2026-07-20.**
- [x] Atualizar `CHANGELOG.md` central. **Feito em 2026-07-20.**
- [ ] Atualizar a observação de `enviar-confirmacao-email` em `supabase/functions/AUTOMATION_INVENTORY.md` (hoje: "revisar envio real") após a correção. **Ainda bloqueado** — depende do teste manual do usuário e da correção real da function (ver Pendência crítica de e-mail).

### Passos manuais do usuário

- [ ] Aprovar (ou pedir ajuste de) a recomendação de modelagem de banco descrita em "Definição da SPEC" antes de qualquer implementação.
- [ ] **Testar manualmente, antes de decidir sobre o novo disparo de e-mail:** salvar um orçamento de teste no catálogo hoje e confirmar se `vinicius@lucenera.com.br`/`pedro@lucenera.com.br` já recebem e-mail (via `process-budget-pdf`). Esse teste decide o escopo real do "Novo requisito 2".
- [ ] Confirmar com o gerente, na conversa de segunda-feira 2026-07-20, o teto de negócio real de quantidade em pedido sob encomenda — o teto técnico de 999 é apenas provisório e não bloqueia o resto da implementação.
- [ ] Validar o texto final do aviso de "3 meses" exibido ao cliente (copy exata pode mudar).
- [ ] Confirmar se os endereços do fluxo `approvePurchase` devem mudar de `vinicius@ubiqua.com`/`josi@ubiqua.com` para `vinicius@lucenera.com.br`/`pedro@lucenera.com.br` (tirando o Josi), ou permanecer como estão.
- [ ] Confirmar a URL pública de produção a ser usada para o `og-image.png` no HTML do e-mail (ex.: domínio publicado do catálogo) ou decidir por hospedar via Supabase Storage.
- [ ] Confirmar que `RESEND_API_KEY` está configurado nas secrets deste projeto Supabase e que o remetente (`from`) usado está com domínio verificado no Resend — sem isso, nenhum e-mail (nem o existente, nem o novo) sai de verdade.
- [ ] Rodar a migration no Supabase real e reextrair `supabase/db/current/` após aplicação.
- [ ] Homologar manualmente o golden path no navegador (catálogo → peça sem estoque → aviso com logo → confirmar → carrinho → salvar orçamento → `SELECT` de conferência na view → conferir chegada real dos e-mails nas caixas de entrada).
- [ ] Commit/push no repositório próprio do submodule e atualização do ponteiro no repo central.

## Objetivo

1. Trocar a redação do badge de estoque zerado para "Sem estoque" (linguagem neutra, já que toda peça Ubiqua sem estoque é importável, não uma exceção).
2. Permitir que o cliente adicione ao orçamento uma peça sem estoque, mediante aviso explícito de prazo de importação de até 3 meses (pedido sob encomenda/backorder), em vez de bloquear a ação como hoje.
3. Dar ao time de compras uma forma de rastrear quais produtos têm demanda pendente de importação, com uma modelagem de banco compatível com o padrão arquitetural já adotado no ecossistema (agregação por produto, não por cliente).
4. Tornar o aviso de backorder visualmente mais elaborado, com identidade de marca (logo Ubiqua), em vez de um texto corrido de erro genérico.
5. Notificar Vinicius e Pedro por e-mail em todo pedido salvo no catálogo, e corrigir o disparo de e-mail de aprovação do admin, que hoje é um stub silenciosamente quebrado.

## Decisões aprovadas

- O texto "Não tem aquela peça em estoque" é substituído por "Sem estoque" em todos os pontos da UI.
- O botão "Adicionar ao Orçamento" passa a ficar **sempre habilitado**, mesmo para peças com `disponivel <= 0`.
- Ao clicar em "Adicionar ao Orçamento" numa peça sem estoque, o sistema deve avisar o cliente que a peça tem prazo estimado de até 3 meses para entrega (importação), permitindo confirmar e seguir adicionando ao orçamento mesmo assim.
- A modelagem de banco para "necessidade de importação" **não está fechada** — está proposta nesta SPEC como recomendação, pendente de aprovação do usuário (ver seção seguinte).
- O teto de quantidade em pedido sob encomenda usa, por ora, apenas uma guarda técnica de sanidade (999); o valor de negócio definitivo será decidido em conversa com o gerente em 2026-07-20 e **não bloqueia** a implementação do restante desta SPEC.
- Confirmado que **não é necessário** um campo manual de status de compras (ex.: "fornecedor contatado") — a empresa do usuário é a única importadora e o único vínculo com a marca Ubiqua na China; não existe fornecedor externo/terceiro para rastrear contato. Essa pendência está resolvida como "não se aplica".
- O aviso de backorder no `QuantityModal.tsx` deve usar o logo real (`public/og-image.png`) em destaque visual tipo card, com aparência de "aviso importante da marca", não de mensagem de erro genérica.
- Deve haver notificação por e-mail para `vinicius@lucenera.com.br` e `pedro@lucenera.com.br` em **todo pedido** salvo no catálogo — porém, ver "Achado crítico de grounding": esse comportamento pode já existir hoje via `process-budget-pdf`, e a implementação de um disparo novo/redundante fica condicionada à checagem manual dessa function.
- A Edge Function `enviar-confirmacao-email` deve ser corrigida para de fato enviar e-mail via Resend, valendo tanto para o disparo já existente em `approvePurchase` quanto para o eventual disparo novo.
- Os endereços do fluxo `approvePurchase` (`vinicius@ubiqua.com`/`josi@ubiqua.com`) permanecem como estão até resposta do usuário à pendência específica sobre trocá-los ou não.

## Definição da SPEC

### Achados de grounding no código atual (`04-Sistemas/catalogo-pecas-ubiqua-e6fa0`)

O ponto de bloqueio real de uma peça sem estoque **não é um único lugar** — são 4 pontos independentes, e uma implementação incompleta deixaria backorder "meio liberado":

| Arquivo | Linha (~) | O que faz hoje |
|---|---|---|
| `src/components/PartCard.tsx` | 136, 205 | Badge e label do botão mostram "Não tem aquela peça em estoque" |
| `src/components/PartCard.tsx` | 202 | `disabled={... || isOutOfStock}` — bloqueia o clique no card do catálogo |
| `src/pages/ProductDetail.tsx` | 208 | Badge já mostra **"Sem estoque"** (já correto, não precisa mudar) |
| `src/pages/ProductDetail.tsx` | 294 | Botão **não** é desabilitado por `isOutOfStock` — só por `!selectedVariant && detalhesPorCor.length === 0` — já abre o modal mesmo sem estoque |
| `src/components/QuantityModal.tsx` | 49-53 | `disponivel <= 0` trava incremento (`Math.min(disponivel, q+1)`), decremento e input em quantidade 0 |
| `src/components/QuantityModal.tsx` | 115-121, 127 | Mensagem de bloqueio e `disabled={isOutOfStock}` no botão "Confirmar" — **este é o bloqueio real e final**, tanto vindo do card quanto do detalhe |
| `src/hooks/use-cart.tsx` | 55-57 | `addToCart`: `if (disponivel <= 0) return` — **bloqueio silencioso adicional**, independente da UI |
| `src/pages/NewQuote.tsx` | 546, 551-553, 572 | Combobox de busca dentro do carrinho: `disabled={isOutOfStock}` e `onSelect` com early-return — **terceiro ponto de entrada**, não citado no pedido original, que também precisa ser alinhado |
| `src/pages/NewQuote.tsx` | 664/682, 741/759 | Controles de quantidade de item já no carrinho travam em `disponivel` — impede ajustar quantidade de item de backorder já confirmado; fallback inconsistente `\|\| 1` vs `\|\| 0` entre as duas linhas |

Conclusão: o modal `QuantityModal.tsx` é o ponto de confirmação natural e único hoje usado tanto pelo `PartCard` (via catálogo) quanto pelo `ProductDetail` (via página de produto) — recomenda-se que a busca do carrinho em `NewQuote.tsx` também passe a abrir esse mesmo modal em vez de chamar `addToCart` diretamente, para não duplicar a lógica de aviso em 3 lugares.

### Mudança 1 — Texto "Sem estoque" (sem impacto em banco)

Trocar a string em `PartCard.tsx` (badge e botão) e em `QuantityModal.tsx`/`NewQuote.tsx` (aviso e badge do combobox). Baixo risco, puramente de copy.

### Mudança 2 — Fluxo de backorder no `QuantityModal.tsx`

- Quando `isOutOfStock`, exibir aviso (exemplo de copy, ajustável pelo usuário): *"Esta peça está sem estoque no momento. Peças Ubiqua são importadas — o prazo estimado de entrega é de até 3 meses. Você pode confirmar o pedido mesmo assim."*
- Checkbox de ciência (`backorderAck`) resetado a cada abertura do modal, junto com o reset de `quantity`.
- Botão "Confirmar": `disabled={isOutOfStock ? !backorderAck : false}`.
- Quantidade: quando `isOutOfStock`, não usar `disponivel` (que é 0) como teto — usar um teto técnico de sanidade de input (proposta: 999) até que o negócio defina um teto real (ver Pendências). Este teto técnico não é uma regra de negócio de estoque, é só para impedir digitação absurda.

### Mudança 3 — Modelagem de banco para "necessidade de importação"

Três alternativas comparadas (conforme pedido do usuário):

| Alternativa | Descrição | Avaliação |
|---|---|---|
| **A. View agregada só sobre `revenda_ubiqua.disponivel` atual** | `SELECT ... WHERE disponivel <= 0` agrupado por produto | Simples, zero migration. **Problema:** perde o histórico — um produto pedido sem estoque e depois reabastecido desaparece da lista, mesmo que o pedido de backorder ainda esteja pendente de importação real. Não reflete demanda, só estoque momentâneo. |
| **B. Tabela nova cadastrada manualmente pelo time de compras** | Compras cadastra à mão quais peças precisam de importação | Contraria o precedente já documentado em `supabase/db/domains/estoque_compras.md` (reunião de 08/06/2026: "necessidade de compra é agregada por produto e não deve ficar amarrada a cliente/cadastro manual"). Gera dado duplicado e dessincronizado do que realmente foi pedido. |
| **C. Coluna snapshot booleana (`itens_orcamento_ubiqua.sem_estoque_no_pedido`) + view agregada por produto** | Grava no momento do pedido se a variante estava sem estoque; view soma a demanda pendente por produto | Preserva o histórico de demanda real (não se perde quando o estoque for reposto), é derivada por relacionamento (sem duplicação manual), e segue o mesmo padrão já usado em `vw_catalogo_ubiqua` e `vw_necessidade_compra` (agregação por produto, não por cliente). |

**Recomendação: alternativa C.** É a única que resolve o problema real levantado pelo usuário (compras tende a perder visibilidade de peças pedidas sem estoque assim que o estoque for reposto por outro motivo) e segue o padrão arquitetural já estabelecido no ecossistema.

Sobre `orcamentos_revenda_ubiqua.prazo_entrega` (coluna `text` já existente, hoje não usada pelo frontend): **recomenda-se reaproveitá-la como texto livre** (ex.: `'Contém item(ns) sem estoque — prazo estimado de até 90 dias para importação'`), preenchida automaticamente pelo `NewQuote.tsx` ao salvar, em vez de criar uma coluna numérica + view (padrão da SPEC-026) — porque, ao contrário do `orcamentos.prazo_entrega_dias` da Lucenera central (que é uma data-alvo calculada e variável por orçamento), aqui o prazo é uma constante de negócio (90 dias) usada só como aviso textual, não uma data de entrega comprometida calculada. Criar um segundo padrão (inteiro + view) para uma constante fixa seria complexidade desnecessária.

### Migration proposta (para o implementador aplicar, não aplicada por esta SPEC)

`supabase/db/migrations/20260719_053_ubiqua_necessidade_importacao/001_sem_estoque_no_pedido.sql`:

```sql
ALTER TABLE public.itens_orcamento_ubiqua
  ADD COLUMN IF NOT EXISTS sem_estoque_no_pedido boolean NOT NULL DEFAULT false;

COMMENT ON COLUMN public.itens_orcamento_ubiqua.sem_estoque_no_pedido IS
  'Snapshot no momento do pedido: true quando revenda_ubiqua.disponivel da variante
  escolhida era <= 0 no momento em que o item foi salvo no orçamento. Não é
  recalculado depois — não usar revenda_ubiqua.disponivel atual para saber se um
  pedido antigo era backorder. SPEC-037.';
```

`002_vw_necessidade_importacao_ubiqua.sql`:

```sql
CREATE VIEW public.vw_necessidade_importacao_ubiqua WITH (security_invoker='true') AS
SELECT
  r.id AS produto_id,
  r.referencia,
  r.descricao,
  r.cor,
  r.desc_marca AS marca,
  r.nm_fornecedor AS fornecedor,
  r.disponivel AS disponivel_atual,
  SUM(iou.quantidade) AS qtd_pendente_importacao,
  COUNT(DISTINCT iou.orcamento_id) AS orcamentos_pendentes
FROM public.itens_orcamento_ubiqua iou
JOIN public.orcamentos_revenda_ubiqua o ON o.id = iou.orcamento_id
JOIN public.revenda_ubiqua r ON r.id = iou.produto_id
WHERE iou.sem_estoque_no_pedido = true
  AND o.cancelado_em IS NULL
  AND o.rejeitado_em IS NULL
GROUP BY r.id, r.referencia, r.descricao, r.cor, r.desc_marca, r.nm_fornecedor, r.disponivel
HAVING SUM(iou.quantidade) > 0
ORDER BY SUM(iou.quantidade) DESC;

COMMENT ON VIEW public.vw_necessidade_importacao_ubiqua IS
  'Demanda agregada por produto/variante (revenda_ubiqua.id) de itens pedidos sob
  encomenda (sem_estoque_no_pedido = true) em orçamentos ativos (não
  cancelados/rejeitados). Time de compras usa esta view para priorizar importação.
  SECURITY INVOKER. SPEC-037.';

GRANT SELECT ON public.vw_necessidade_importacao_ubiqua TO authenticated;
```

Observação: não há como filtrar por um enum de `status` de `orcamentos_revenda_ubiqua` porque a coluna é `text` livre sem `CHECK` — o filtro usa os timestamps `cancelado_em`/`rejeitado_em`, que existem de fato na tabela.

### Achado crítico de grounding — o disparo de e-mail "todo pedido" já pode existir

Durante a investigação do "Novo requisito 2", foi encontrado que `NewQuote.tsx` (`executeSaveQuote`, linha ~229) já chama, **incondicionalmente em todo save de orçamento**, a Edge Function `process-budget-pdf`:

```
const { error: fnError } = await supabase.functions.invoke('process-budget-pdf', {
  body: { quote_id: activeQuoteId },
})
```

E essa função (`04-Sistemas/catalogo-pecas-ubiqua-e6fa0/supabase/functions/process-budget-pdf/index.ts`, idêntica ao espelho em `supabase/functions/process-budget-pdf/index.ts` do repo central, marcada como "ativa" em `AUTOMATION_INVENTORY.md`) já:
1. gera o PDF do orçamento;
2. sobe para o Storage (bucket `orcamentos`);
3. **se `RESEND_API_KEY` estiver configurado, envia e-mail via Resend, com o PDF anexado, para exatamente `['vinicius@lucenera.com.br', 'pedro@lucenera.com.br']`** (linha ~180-209) — os mesmos dois endereços pedidos no "Novo requisito 2".

Ou seja, o pedido "mandar e-mail pro Vinicius e Pedro em todo pedido salvo" **pode já estar tecnicamente coberto** por esta infraestrutura existente.

**Bug encontrado dentro de `process-budget-pdf`:** se a chamada ao Resend falhar (`!res.ok`), o código apenas faz `console.error(...)` e **não lança erro** — a função sempre retorna `{ success: true, url: fileUrl }`. Ou seja, mesmo que o e-mail falhe silenciosamente (chave inválida, domínio não verificado no Resend, etc.), o frontend nunca saberia; o toast "Orçamento gerado e PDF enviado com sucesso!" em `NewQuote.tsx` não reflete se o e-mail de fato chegou.

**Esta SPEC não decide qual caminho seguir** (constatação técnica, não regra de negócio) — mas recomenda, antes de escrever qualquer linha de código para o disparo novo:

- **Cenário 1 — `process-budget-pdf` já entrega e-mail hoje:** o "Novo requisito 2" quanto ao disparo "todo pedido" já está satisfeito por infraestrutura existente. O trabalho se reduz a (a) opcionalmente incluir o logo/branding Ubiqua no HTML desse e-mail já existente, e (b) corrigir o bug do erro engolido para que uma falha real do Resend seja reportada como erro de verdade. Criar um segundo disparo via `enviar-confirmacao-email` para o mesmo evento e os mesmos dois destinatários geraria e-mails duplicados.
- **Cenário 2 — `process-budget-pdf` não entrega e-mail hoje** (ex.: `RESEND_API_KEY` ausente neste projeto, remetente não verificado, etc.): o problema não é falta de código — o disparo em todo pedido já existe — é falha de configuração/infra ou o bug do erro engolido. Nesse caso, o caminho mais correto é consertar `process-budget-pdf` em vez de criar um caminho paralelo via `enviar-confirmacao-email` fazendo a mesma coisa.

Fica como Pendência crítica a confirmação manual (ver seção própria) antes de decidir a implementação do disparo novo.

### Mudança 4 — Aviso de backorder elaborado, com o logo da marca (`QuantityModal.tsx`)

Hoje o aviso da Mudança 2 é um bloco de texto simples (linhas ~115-121, classe `text-destructive`, estilo de erro). O usuário pediu que fique visualmente mais elaborado, usando o logo real da marca — que já existe em `public/og-image.png` (wordmark laranja "UBÌQUA", fundo transparente/branco), servido estaticamente pelo Vite em `/og-image.png` (mesmo caminho já referenciado em `index.html` como `og:image`). **Não é necessário criar nem pedir uma imagem nova.**

Diretriz de layout (sem prescrever CSS pixel a pixel):
- O logo (`<img src="/og-image.png" ... />`) deve aparecer no topo do bloco de aviso, em tamanho que dê destaque à marca sem dominar o modal.
- O bloco deve ter aparência de card/destaque (borda, fundo diferenciado, sombra leve) — **não deve reaproveitar o padrão visual de erro** (`text-destructive`/vermelho) já usado hoje, porque "sem estoque, pedido sob encomenda" não é um erro, é uma condição normal de venda da marca.
- O texto do aviso (copy da Mudança 2, ainda sujeita a validação — ver Pendências) fica abaixo do logo, dentro do mesmo card.
- O checkbox de ciência (`backorderAck`) permanece como elemento de confirmação, visualmente associado ao card (dentro ou logo abaixo dele), não solto na tela.
- Objetivo declarado pelo usuário: parecer um "aviso importante da marca", não um texto de erro genérico.

### Mudança 5 — Notificação por e-mail (correção do stub + eventual novo disparo)

#### Contexto: três pontos de disparo relacionados, três situações diferentes

| Ponto | Onde | Propósito | Situação hoje |
|---|---|---|---|
| **A** | `src/lib/api-admin.ts`, `approvePurchase` (linhas ~302-323) | Admin aprova orçamento (`status: 'aprovado'`) → notifica internamente | Chama `enviar-confirmacao-email` com `email_vinicius: 'vinicius@ubiqua.com'`, `email_josi: 'josi@ubiqua.com'` — **stub, não envia nada de verdade** |
| **B** | `src/lib/api.ts`, `sendQuoteEmail(payload: any)`, chamado por `NewQuote.tsx` (`handleSendEmail`, linha ~278) | Cliente escolhe mandar o PDF do próprio orçamento para o e-mail que ele digitar | Chamado com 3 argumentos (`sendQuoteEmail(emailRecipient, pdfBase64, savedQuote)`) contra uma função que só declara **1** parâmetro (`payload: any`) — divergência de assinatura confirmada; não há outra `sendQuoteEmail` sombreando em `pdf.ts` (que só exporta `generateQuotePDFBase64` e `downloadMockPDF`). Como o build usa esbuild (sem checagem de tipos bloqueante), isso não quebra o `build`, mas hoje o `payload` que chega na Edge Function é a *string* do e-mail digitado (não um objeto), e o PDF/`savedQuote` são descartados silenciosamente. **Fluxo já quebrado hoje, independente desta SPEC, e com propósito diferente (envio ao cliente, não notificação interna).** |
| **C** | `src/pages/NewQuote.tsx`, `executeSaveQuote` (linha ~229), via Edge Function `process-budget-pdf` | Notificação interna em todo pedido salvo | **Já funciona, contanto que `RESEND_API_KEY` esteja configurado** — envia para `vinicius@lucenera.com.br`/`pedro@lucenera.com.br`. Ver "Achado crítico de grounding". Bug do erro engolido (`!res.ok` não gera `throw`). |

#### O que esta SPEC propõe

1. Reescrever `enviar-confirmacao-email/index.ts` (nas duas cópias existentes — submodule e espelho central) seguindo o padrão de `welcome-email/index.ts`: usar `Deno.env.get('RESEND_API_KEY')`, montar HTML com o logo Ubiqua, `POST` para `https://api.resend.com/emails`, e **propagar erro real** (`throw`) se `!res.ok` — ao contrário do bug encontrado em `process-budget-pdf`, aqui o erro não deve ser engolido.
2. Referência do logo no e-mail: como a Edge Function roda no servidor (Deno) e não tem acesso ao filesystem do frontend, o `<img>` do e-mail precisa de uma URL pública. Duas opções, nenhuma aplicada por esta SPEC:
   - **Opção 1 (mais simples):** URL de produção publicada do catálogo, ex. `https://catalogo-pecas-ubiqua-e6fa0.goskip.app/og-image.png` — **domínio exato não confirmado nesta análise**, precisa ser validado pelo usuário antes da implementação.
   - **Opção 2:** subir `og-image.png` para um bucket público do Supabase Storage (ex.: reaproveitar o bucket `orcamentos` já usado por `process-budget-pdf`, ou criar um bucket de assets novo) e referenciar a `publicUrl` retornada — mais robusto a mudanças de domínio de deploy, porém exige criar/confirmar um bucket que hoje não existe para esse propósito.
   - Recomendação desta SPEC: Opção 1 por simplicidade, desde que o domínio de produção seja confirmado e estável; Opção 2 se o usuário preferir não depender do domínio do frontend.
3. **Ponto A (`approvePurchase`):** mantém o mesmo evento de disparo e os mesmos parâmetros de payload (`quote_id`, `email_vinicius`, `email_josi`) — a única mudança é a Edge Function passar a processar e enviar de verdade. Os endereços (`vinicius@ubiqua.com`/`josi@ubiqua.com`) permanecem como estão até resposta do usuário à pendência específica.
4. **Ponto C / novo disparo pedido pelo usuário (`executeSaveQuote`):** condicionado à confirmação manual descrita no "Achado crítico de grounding". Só deve virar um disparo novo via `enviar-confirmacao-email` se a checagem confirmar que `process-budget-pdf` **não** está entregando e-mail hoje. Caso contrário, o caminho é consertar `process-budget-pdf` (bug do erro engolido) e, opcionalmente, adicionar o logo Ubiqua no HTML que ele já monta — sem criar um segundo disparo redundante para o mesmo evento e os mesmos dois destinatários.
5. **Ponto B (`sendQuoteEmail`/`handleSendEmail`):** fora do escopo direto dos dois pedidos do usuário (é envio de PDF ao cliente, não notificação interna), mas fica registrado como bug pré-existente que usa a mesma Edge Function que estamos mexendo — decisão de corrigir junto ou tratar como item separado fica em Pendências.

### Ecossistema — respostas obrigatórias

- **Depende de `projetos`/`orcamentos`/`contatos`/`produtos`/`boletos`/`projeto_itens`/`projeto_parcelas`/`usuarios`/`systems`/`user_system_access`?** Não. Usa exclusivamente as tabelas próprias do domínio Ubiqua (`revenda_ubiqua`, `orcamentos_revenda_ubiqua`, `itens_orcamento_ubiqua`), que já são isoladas por decisão da Escopo Ubiqua (SPEC-UBI-01/07) e não têm relação com as tabelas centrais Lucenera. A Mudança 5 (e-mail) não toca nenhuma tabela central, só Edge Functions.
- **Afeta CRM/Orçamentos/Financeiro/Cadastro/Estoque-Compras/Logística/RH/Hub-TI?** Nenhum diretamente. É um domínio isolado (catálogo Ubiqua). A view nova é análoga em espírito a `vw_necessidade_compra` (domínio Estoque/Compras Lucenera), mas **não é a mesma tabela nem deve ser fundida com ela** — são públicos, produtos e catálogos diferentes.
- **Existe dado duplicado que deveria ser derivado por relacionamento?** Não introduzido por esta SPEC — pelo contrário, a alternativa B (tabela manual) foi descartada exatamente por criar esse tipo de duplicação; a alternativa C escolhida deriva tudo por relacionamento (`itens_orcamento_ubiqua` → `orcamentos_revenda_ubiqua` → `revenda_ubiqua`). Quanto ao e-mail: implementar um disparo novo via `enviar-confirmacao-email` sem antes checar `process-budget-pdf` criaria, na prática, "lógica de notificação duplicada" — mesmo risco de duplicação, só que em Edge Functions em vez de tabelas.
- **Existe migration antiga que contradiz o snapshot central?** Não identificada para esse domínio específico nesta análise.
- **Exige atualizar `AI_DB_CONTEXT.md`?** Sim — `04-Sistemas/catalogo-pecas-ubiqua-e6fa0/supabase/AI_DB_CONTEXT.md` precisa registrar a nova coluna e a nova view no domínio de 6 tabelas já documentado.
- **Sistema(s) afetados e padrão de acesso a dados já usado:** somente o catálogo Ubiqua. O padrão de acesso já estabelecido é `@supabase/supabase-js` chamado diretamente dos componentes/páginas (`supabase.from(...)`), sem camada de `services/` intermediária — visto em `NewQuote.tsx` (`supabase.from('orcamentos_revenda_ubiqua')...`, `supabase.from('itens_orcamento_ubiqua')...`) e no hook `use-cart.tsx` (estado local + `localStorage`, sem chamada ao banco). Esta SPEC não propõe criar uma camada de serviço nova — segue o padrão existente de chamada direta ao Supabase dentro do componente/página. Para Edge Functions, o padrão já estabelecido (`welcome-email`, `process-budget-pdf`) é `Deno.env.get('RESEND_API_KEY')` + `fetch` direto para a API do Resend, sem SDK intermediário — a correção de `enviar-confirmacao-email` segue esse mesmo padrão.
- **Nota adicional:** as Edge Functions deste domínio existem em duplicidade física — uma cópia dentro do submodule (`04-Sistemas/catalogo-pecas-ubiqua-e6fa0/supabase/functions/`) e um espelho no repo central (`supabase/functions/`, alimentado por `supabase functions list` do projeto remoto, conforme `AUTOMATION_INVENTORY.md`). Qualquer correção de `enviar-confirmacao-email` ou `process-budget-pdf` precisa considerar as duas cópias para não deixá-las divergentes — não ficou claro nesta análise qual cópia é de fato a fonte de deploy.

### Critérios de aceite (verificação manual — sem suíte automatizada)

- Catálogo (`/`): peça com `disponivel = 0` mostra badge "Sem estoque" (não mais "Não tem aquela peça em estoque"); botão "Adicionar ao Orçamento" está clicável.
- Clicar no botão de uma peça sem estoque abre o modal com o card de aviso (logo Ubiqua + texto de prazo de até 3 meses); "Confirmar" fica desabilitado até marcar a ciência; após marcar, item entra no carrinho com a quantidade escolhida.
- O card de aviso carrega a imagem `/og-image.png` corretamente (sem ícone de imagem quebrada) e tem aparência visual distinta de mensagem de erro (não usa o padrão vermelho/`destructive`).
- Página de produto (`/produto/:slug`): mesmo comportamento, badge já mostrava "Sem estoque" corretamente (sem regressão).
- Carrinho (`/novo-orcamento`): item de backorder aparece, quantidade pode ser ajustada, orçamento salva sem erro.
- `SELECT * FROM itens_orcamento_ubiqua WHERE orcamento_id = '<id do teste>';` mostra `sem_estoque_no_pedido = true` na linha do item testado.
- `SELECT * FROM orcamentos_revenda_ubiqua WHERE id = '<id do teste>';` mostra `prazo_entrega` preenchido com o texto de aviso.
- `SELECT * FROM vw_necessidade_importacao_ubiqua;` lista o produto testado com a quantidade correta.
- Regressão: peça **com** estoque continua com comportamento idêntico ao atual (sem aviso, quantidade limitada a `disponivel`, badge/preço normais).
- **Aprovar um orçamento como admin (`approvePurchase`) dispara e-mail real** — verificar a chegada na caixa de entrada dos endereços configurados (não só o retorno HTTP 200 da Edge Function).
- **Salvar um orçamento de teste no catálogo e confirmar manualmente que `vinicius@lucenera.com.br` e `pedro@lucenera.com.br` recebem e-mail** — checar explicitamente se não chegou duplicado (um de `process-budget-pdf` e outro de `enviar-confirmacao-email`), a menos que a duplicidade tenha sido uma decisão consciente do usuário após o "Achado crítico de grounding".
- Verificar nos logs da Edge Function (`enviar-confirmacao-email` e/ou `process-budget-pdf`, conforme o caso) que a chamada à API do Resend retornou sucesso (status 200 da própria API do Resend, não só da Edge Function que a envolve).
- `npm run lint` e `npm run build` do submodule `catalogo-pecas-ubiqua-e6fa0` passam sem erro.

### Plano de rollback

- Frontend: reverter os commits do submodule via git (mudança isolada em 4 arquivos de UI + 1 hook, mais o redesenho do aviso e o eventual novo disparo em `NewQuote.tsx`).
- Edge Functions: reverter `enviar-confirmacao-email/index.ts` (e `process-budget-pdf/index.ts`, se corrigido) via git nas duas cópias (submodule e central) e reimplantar a versão anterior.
- Banco: migration é aditiva e sem dependentes — rollback seguro via:
  ```sql
  DROP VIEW IF EXISTS public.vw_necessidade_importacao_ubiqua;
  ALTER TABLE public.itens_orcamento_ubiqua DROP COLUMN IF EXISTS sem_estoque_no_pedido;
  ```
  Nenhuma linha de dado existente é destruída (coluna nova com default `false`).

### Documentos a atualizar após implementação

- `04-Sistemas/catalogo-pecas-ubiqua-e6fa0/supabase/AI_DB_CONTEXT.md` (obrigatório — nova coluna e view no domínio).
- `CHANGELOG.md` central (obrigatório).
- `supabase/functions/AUTOMATION_INVENTORY.md` (obrigatório se `enviar-confirmacao-email` passar a enviar de verdade — atualizar a observação "revisar envio real").
- `supabase/db/domains/estoque_compras.md` — **opcional**, só como referência cruzada de uma linha ("ver também `vw_necessidade_importacao_ubiqua` no domínio Ubiqua, mesmo padrão de agregação por produto"). Não deve ser tratado como o mesmo domínio — a Escopo Ubiqua (SPEC-UBI-07) explicitamente veta fundir relatórios/domínios Ubiqua com Estoque/Compras Lucenera.
- Não existe `CHANGELOG.md` local no submodule `catalogo-pecas-ubiqua-e6fa0` hoje — não é obrigatório criar um só para esta SPEC.

## Realizado

_(nada implementado ainda — SPEC aguardando aprovação)_

## Pendências

- [ ] **Teto de quantidade em pedido sob encomenda (parcialmente resolvida):** mantido o teto técnico de sanidade de 999 como provisório para não bloquear a implementação. O valor de negócio real será decidido em conversa com o gerente em 2026-07-20 — não é bloqueante para o restante desta SPEC, só pode exigir trocar o número 999 depois.
- [x] ~~Confirmar se o time de compras precisa de um campo de status manual de acompanhamento por produto~~ — **resolvida:** não se aplica. A empresa do usuário é a única importadora e o único vínculo com a marca Ubiqua na China, não há fornecedor externo/terceiro para rastrear contato.
- [ ] Validar o texto final do aviso de "3 meses" exibido ao cliente no `QuantityModal.tsx` — a copy proposta nesta SPEC é um rascunho, sujeita a ajuste do usuário/Vinicius.
- [ ] Confirmar se `orcamentos_revenda_ubiqua.prazo_entrega` pode ser sobrescrito automaticamente pelo `NewQuote.tsx` sem risco de conflito com alguma edição manual futura desse campo (nenhuma UI de edição manual foi encontrada nesta análise, mas a área administrativa não foi auditada por completo).
- [ ] Decidir se os 3 pontos de entrada de adição ao orçamento (`PartCard`, `ProductDetail`/`QuantityModal`, busca dentro de `NewQuote`) devem obrigatoriamente compartilhar o mesmo componente/fluxo de confirmação de backorder, ou se a busca do carrinho pode usar um aviso mais simples (ex.: toast) — a recomendação desta SPEC é unificar via `QuantityModal`, mas não é bloqueante para a implementação.
- [ ] Itens de orçamento já salvos **antes** desta migration ficarão com `sem_estoque_no_pedido = false` por default — não há como saber retroativamente se estavam sem estoque no momento do pedido antigo (dado não existe historicamente); a view `vw_necessidade_importacao_ubiqua` só refletirá demanda de backorder a partir da aplicação desta migration em diante, sem backfill possível.
- [ ] **[CRÍTICA]** Confirmar manualmente se `process-budget-pdf` já entrega e-mail hoje para `vinicius@lucenera.com.br`/`pedro@lucenera.com.br` (salvando um orçamento de teste) antes de implementar um segundo disparo via `enviar-confirmacao-email` para o mesmo evento — decide o escopo real do "Novo requisito 2" (ver "Achado crítico de grounding").
- [ ] Confirmar se os endereços do fluxo `approvePurchase` devem trocar de `vinicius@ubiqua.com`/`josi@ubiqua.com` para `vinicius@lucenera.com.br`/`pedro@lucenera.com.br` (tirando o Josi), ou permanecer como estão hoje — usuário ainda não confirmou.
- [ ] Confirmar a URL pública de produção correta a ser usada no HTML do e-mail para o `og-image.png` (ex.: subdomínio real de deploy) ou decidir por hospedar via Supabase Storage.
- [ ] Decidir se o bug de assinatura em `sendQuoteEmail`/`handleSendEmail` (Ponto B — envio do PDF ao e-mail que o cliente digita) deve ser corrigido nesta mesma leva de mudanças ou tratado como item separado, já que ele usa a mesma Edge Function que estamos reescrevendo.
- [ ] Confirmar que `RESEND_API_KEY` está de fato configurado nas secrets deste projeto Supabase e que o domínio/remetente usado está verificado no Resend — sem isso, nenhum dos e-mails (existente ou novo) sai de verdade.
