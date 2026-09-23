---
titulo: "SPEC-158 — Correções e pendências da reunião de 22/09/2026 (revisão geral do sistema com Vinícius)"
status: CONCLUÍDA (exceto P1.3 e P4-P7 abaixo). P1 (exceto P1.3), P2, P3.1 implementados, revisados,
  migrations aplicadas em produção, commitados e PUBLICADOS no Skip: Orçamentos v0.0.373, Cadastro v0.0.85;
  P1.4 (desconto por item no Gerenciamento), P2.3 (digitador) e P2.5 (cor preta em Peças) achados/decididos
  depois dos itens originais da reunião, todos implementados, revisados e publicados; P1.3 bloqueado
  aguardando esclarecimento do usuário; P3.2-P3.4 já estavam resolvidos no Cadastro real (achado ao
  investigar); P4-P7 aguardando decisão/alinhamento (P7 já feita fora desta SPEC, confirmado pelo usuário)
data_ultima_modificacao: 2026-09-23
sistemas_envolvidos:
  - Orçamentos (gestao-financeira-clone-544cb) — P1, P2
  - Cadastro (cadastro-lucenera-b86fe) — P3
  - Vendas (vendas-lucenera) — P4
  - Separação Parcial / Logística — P5
  - Administração Bancária (retorno-bancario-bradesco-5392a) — P6
dependencias:
  - SPEC-019 / SPEC-135 (reset do ciclo de aprovação — origem do bug P1.1)
  - SPEC-083 / SPEC-106 (painel Gerenciamento, custo/lucro por peça — origem do bug P1.2)
  - SPEC-152 (filtro de engenheiro em Responsável Obra — P2.1 é só o rótulo que faltou)
  - SPEC-154 (integração Focus NFe — P4 depende dela)
---

# SPEC-158 — Correções da reunião de 22/09/2026

> Origem: `02-Reunioes/25. Lucenera (Vinicius) - 22.09.2026_reuniões gerais sobre o sistema/Reunião.01.txt`.
> Revisão geral do sistema com o Vinícius, tela a tela, conferindo o que já tinha sido pedido em reuniões
> anteriores (o que já estava OK ele foi "ticando") e levantando o que faltava. Esta SPEC cobre **tudo** que
> foi citado, separado por prioridade e por grau de definição.

## Itens JÁ CONFIRMADOS como resolvidos na própria reunião (não fazer nada)

Registrados só para não serem reabertos por engano numa próxima leitura da ata:

- Condição de pagamento / valor com desconto no orçamento — Vinícius: "já foi adicionado, pode dar OK".
- Recálculo automático de parcelas (primeira parcela preenchida → demais divididas pelo restante) — já
  implementado e publicado (SPEC-156 desta numeração local / commit `0bbf08a`). Vinícius conferiu ao vivo.
- Bloqueio de aprovação com peça sem cadastro — testado ao vivo na reunião: "Não é possível aprovar, não tem
  produto cadastrado, peça sem código interno. Beleza, ótimo."
- Vendedor limitado às 3 pessoas no orçamento (SPEC-140) — conferido.

---

## PRIORIDADE 1 — Bugs confirmados (corrigir primeiro)

### P1.1 — Editar orçamento em "Aprovação Financeira" devolve para o cliente

**Sintoma (reproduzido ao vivo na reunião, [02:18]-[03:58])**: com o orçamento em *Aprovação Financeira*,
o Pedro alterou uma data e o orçamento voltou para *Aprovação do Cliente*. Vinícius: *"toda vez que tiver em
revisão financeira não é para voltar"* — a responsabilidade das vendedoras já terminou nesse ponto; a partir
dali é do financeiro, e uma correção do financeiro não pode reiniciar o ciclo com o cliente.

**Causa raiz confirmada** (lida direto da função viva em produção via `pg_get_functiondef`): a trigger
`trg_orcamento_workflow` → `handle_orcamento_workflow()` reseta `status` para `'enviado_cliente'` quando um
orçamento em `'Aprovação Financeira'` **ou** `'Orçamento Aprovado'` sofre UPDATE que altere qualquer um de:
`valor_total`, `forma_pagamento`, `frete_tipo`, `frete_valor`, `condicoes_pagamento`,
`prazo_pagamento_dias`, `desconto_global`.

Mudar a data de pagamento no formulário altera `prazo_pagamento_dias` (o frontend converte cada vencimento
calendário em offset de dias), caindo exatamente nessa condição — por isso "mudar a data" devolvia ao cliente.

Existe um escape (`app.skip_approval_reset`) usado por RPCs específicas, mas o caminho de edição normal do
formulário não o usa.

**Correção**: restringir o reset a `'Orçamento Aprovado'` apenas. Orçamento em `'Aprovação Financeira'`
passa a seguir pelo ramo que só registra no histórico (`historico_status_orcamentos`) sem mexer no status —
ramo que já existe hoje para o caso `skip_approval_reset = true`.

- [x] Migration nova (`supabase/db/migrations/20260923_158_fix_reset_aprovacao_financeira/001_...sql`)
      recriando `handle_orcamento_workflow()` com a condição corrigida. Revisada pelo `revisor` — comparou
      byte a byte com a função viva de produção, sem achado crítico. Testada com um teste comportamental
      real (transação com `ROLLBACK`) contra o banco: orçamento em Aprovação Financeira manteve o status,
      orçamento Aprovado continuou resetando. **Ainda não aplicada** (aguardando confirmação do usuário).
- [x] Confirmado: `'Orçamento Aprovado'` continua resetando (teste acima).

### P1.2 — Margem do painel "Gerenciamento" ignora o desconto por item

**Sintoma ([20:46])**: Vinícius colocou desconto em um item específico e a margem no painel *Gerenciamento*
não mudou. *"É o desconto no item. Não tá sendo considerado aqui, tá, nessa margem, no gerenciamento de
orçamento."*

**Causa raiz confirmada** em `04-Sistemas/gestao-financeira-clone-544cb (1)/src/components/budgets/GerenciamentoDialog.tsx`:

```ts
const vendaUnitComDesconto = item.preco_unitario * (1 - descontoSimulado / 100)
```

Só aplica o desconto **global simulado** (`descontoSimulado`). O desconto **por item** (`item.desconto`,
percentual, que o resto do sistema aplica na fórmula
`quantidade * preco_unitario * (1 - desconto/100)`) nunca entra na conta — então venda, lucro e lucro% da
linha ficam todos inflados para qualquer item com desconto próprio.

**Correção**: aplicar os dois descontos (o do item e o global simulado) sobre o preço unitário, na mesma
ordem usada no restante do orçamento.

- [x] `GerenciamentoItem` ganhou `desconto?: number` (o dado já chegava do form via `form.watch('itens')`,
      só não era declarado/usado). Cálculo corrigido: `precoUnitComDescontoItem(item)` aplica o desconto do
      item, o global simulado é aplicado por cima — mesma ordem do formulário
      (`quantidade * preco_unitario * (1 - desconto/100)`). Revisado pelo `revisor`, sem achado crítico
      (uma divergência menor e pré-existente foi identificada no seed do % inicial do desconto global em
      R$ quando há sinal > 0 — baixo impacto, não bloqueia).

### P1.4 — Campo de desconto por item, sem opção de preencher dentro do Gerenciamento

**Sintoma ([24:31])**, achado ao testar o P1.2 na mesma reunião: *"É, tem ali, mas não tem como preencher,
né? Aqui aí não deixa, nem aqui não tem opção aqui de colocar o desconto, nem aqui embaixo, nada. Não tem
opção, tem ali, mas não tem opção, só tem o campo."*

**Causa raiz confirmada**: a tabela do `GerenciamentoDialog.tsx` não tinha (e nunca teve) nenhuma coluna
editável de desconto **por item** — só existia o campo "Desconto simulado (%)" GLOBAL no topo do painel
(esse sempre funcionou, tem `onChange` normal) e o campo de custo manual, editável só pra itens avulsos.
Não era um bug de `readOnly`/`disabled` num input existente — o campo simplesmente não existia nessa tela.

- [x] Nova coluna "Desc. item (%)" na tabela do Gerenciamento, editável (min 0, max 100, mesmo padrão de
      `BudgetItemCard.tsx`). Grava DE VERDADE no campo real do orçamento (`itens.{index}.desconto`, via
      `form.setValue` — não é uma simulação local como o desconto global ou o custo manual). `index` é a
      posição no array (mesmo contrato já usado por `BudgetItemCard`/`EditableItemCard` via
      `useFieldArray`), confirmado pelo revisor que não há reordenação entre `fields` e
      `form.watch('itens')` que pudesse desalinhar o índice. Edição propaga em tempo real pra linha do item
      fora do painel (mesma árvore de estado do react-hook-form), sem sincronização manual necessária.
      Revisado pelo `revisor`, sem achado crítico. Publicado no Skip (v0.0.372).

### P1.3 — "Margem padronizada em 50%" — ⚠️ PRECISA DE ESCLARECIMENTO, NÃO CORRIGIR ÀS CEGAS

**Relato ([23:20])**: *"ele tá puxando uma margem já padronizada. Ele não tá fazendo o cálculo da margem...
Ele tá já colocando como padrão tudo por 50%"*, comparando o aro `6654` com a lâmpada `9801`. Vinícius:
*"se a gente solta o sistema assim, seria um mega problema, tipo, estaria mega mascarado a margem"*. O Pedro
chegou a falar em *"fazer um backup geral e modificar tudo que tiver percentagem de lucro"*.

**O que a verificação nos dados reais mostrou (2026-09-23)** — e por que NÃO se deve fazer o UPDATE em massa
antes de alinhar:

- As margens no banco **não** estão padronizadas: de 3.831 produtos com custo e venda preenchidos, apenas
  **62** ficam em 50% (±1p.p.). Média 60,5%, variando de -190,5% a 92,0%.
- Os dois produtos citados têm margens **diferentes** entre si: aro `6654` = 62,7% e lâmpada `9801` = 52,0%
  (usando `preco_custo` × `valor_venda`) — batendo com o "61 e 52" que o próprio Vinícius leu na tela.
- O único 50% fixo que existe no código é **proposital e pedido pelo próprio Vinícius** na mesma reunião
  ([09:56]): item **sem cadastro** assume custo = 50% do preço de venda (*"colocou 100 aqui no preço de
  venda, meio que considerar que custo é 50, colocou 1000, considera que o custo é 500"*) — implementado em
  `GerenciamentoDialog.tsx` (`vendaUnitComDesconto * 0.5`, SPEC-106).

**Hipótese mais provável**: o que o Vinícius viu como "tudo 50%" era o comportamento dos itens **sem
cadastro** (que ele estava testando naquele momento) — que é o comportamento correto e desejado. Mas o
trecho da ata é ambíguo e a correção proposta na hora (UPDATE em massa em `percentual_lucro`) é
irreversível e de alto impacto.

- [ ] **Alinhar com o Vinícius antes de qualquer alteração**: mostrar as margens reais dos dois produtos
      citados e confirmar se o que incomodou foi (a) o desconto por item não entrar na conta (P1.2, já
      corrigido), (b) o 50% dos itens sem cadastro, ou (c) outra coisa. **Nenhum UPDATE em massa em
      `produtos.percentual_lucro` deve ser feito sem essa confirmação.**

---

## PRIORIDADE 2 — Orçamento (ajustes definidos)

### P2.1 — Rótulo "Responsável Obra" → "Engenheiro"

[00:15]-[02:04]. A SPEC-152 já fez o campo listar **só** engenheiros (`contato_tipos.tipo = 'engenheiro'`) e
o placeholder já diz "Buscar engenheiro...", mas o rótulo visível continua "Responsável Obra". Vinícius:
*"trocar responsável de obra por engenheiro"*, igual ao campo Arquiteto ao lado.

- [x] `ProjectCreateModal.tsx` (modal "Criar Projeto" dentro do Novo Orçamento): `<FormLabel>Responsável
      Obra</FormLabel>` → `Engenheiro`. Confirmado (revisor) que o CRM já usava "Engenheiro" pro mesmo
      campo — este ajuste só alinha o Orçamentos com o resto do ecossistema.

### P2.2 — Modal de item sem cadastro: simplificar e renomear

[13:33]-[17:57]. Hoje o botão dentro do orçamento abre o formulário **completo** de cadastro de produto
(3 colunas: Dados básicos / Custo e preço / Fiscal e comercial). Decisão do Vinícius: as vendedoras não
preenchem nada disso — quem cadastra direito é a Débora, no Cadastro. Então dentro do **orçamento** o modal
deve ficar mínimo:

- [x] Campos reduzidos a: **referência**, **nome**, **marca** e **preço de venda**. Todo o resto (categoria,
      fornecedor, unidade, descrição técnica, custo/BDI/frete/ST/IPI/margem, fiscal, status comercial, SKU)
      removido do formulário — continua existindo em `produtos`, só não é mais coletado aqui.
      `categoria_id` passou a ser opcional na RPC `criar_produto_orcamento` (migration
      `20260923_158b_item_sem_cadastro_simplificado/001_...sql` — testado com teste comportamental real:
      produto criado sem categoria, categoria_id ficou null).
- [x] Renomeado para "Adicionar item sem cadastro" — no título do modal E nos 4 botões/tooltips que abrem
      esse modal (`BudgetItemCard.tsx`, `EditableItemCard.tsx`, `ProductSearchModal.tsx` ×2 — achado do
      revisor na 1ª rodada, corrigido).
- [x] Referência e marca agora aparecem na linha do item: como o item criado sempre recebe um `produto_id`
      real, a linha renderiza via `ProductSelectButton.tsx`, que já buscava nome/sku/referência direto do
      banco — só faltava marca, adicionada via embed `marca:marcas(nome)` (confirmado sem risco de embed
      ambíguo do PostgREST — só 1 FK entre as tabelas — e testado com uma chamada REST real).
- [x] Preço de venda passou a ser o único campo de preço, editável diretamente (não mais calculado/travado
      a partir de custo+margem).

### P2.3 — Digitador do orçamento (além do vendedor)

[28:28]-[30:35]. Hoje o orçamento registra só o **vendedor** (as 3 pessoas fixas da SPEC-140). Falta
registrar **quem digitou** o orçamento — que pode ser outra pessoa da equipe (ex.: vendedora Thairine como
vendedor, mas quem digitou foi a Adriana).

- [x] Capturar automaticamente **do login** (decisão explícita: *"é direto do login, que é o seu melhor,
      porque senão aqui qualquer um pode pôr qualquer um"*) — não é campo editável.
- [x] Exibir no layout do orçamento enviado ao cliente para aprovação.
- [x] Impacto de banco: coluna nova `orcamentos.digitado_por uuid REFERENCES usuarios(id) ON DELETE SET NULL`
      (migration `20260923_158c_digitador_orcamento`, aplicada em produção). Referencia `usuarios(id)`, não
      `auth.users(id)` direto (diferente de `enviado_cliente_por`) — permite embed direto do PostgREST pra
      resolver o nome, mesmo padrão de `vendedor:funcionarios!orcamentos_vendedor_id_fkey(nome)`.
- [x] Capturado sempre em `addBudget()` (`useBudgetStore.ts`), incondicional (não depende do status
      inicial) — nunca faz parte do form nem do payload de `updateBudget`, fisicamente impossível editar
      pela UI. Exibido na Edge Function `generate-report` (PDF do orçamento), terceira coluna na mesma
      linha de Vendedor/Arquiteto Externo, só quando preenchido (orçamentos antigos ficam sem, sem
      backfill). Aguardando revisão do `revisor` antes de commitar/publicar.

### P2.4 — Botão "Salvar" também no rodapé

[25:00] *"traz esse salvar aqui para baixo também"* — hoje só existe no topo do formulário de orçamento.

- [x] Botão "Salvar" duplicado no rodapé do formulário, mesma ação (`form.handleSubmit`) do botão do topo.

### P2.5 — Cor preta padrão em "Peças e produtos / referência"

[28:05]-[28:12] *"Peças e produtos, referência, ter a cor preta, deixar tudo preto mesmo. Como se fosse um
padrão sistema"*. Hoje esse texto aparece esmaecido (`text-muted-foreground`).

- [x] **Concluído (2026-09-23).** Usuário confirmou a tela exata: "sistema de consultar produtos" — a
      listagem de Peças do Cadastro (`04-Sistemas/cadastro-lucenera-b86fe/src/pages/Pecas.tsx`), não
      Orçamentos nem Vendas como eu tinha suposto pela transcrição. Causa raiz real, diferente da hipótese
      original ("`text-muted-foreground`"): "Código" usava `text-slate-500` (cinza) e a badge de
      "Referência" usava `text-primary` (laranja Lucenera, `--primary: 37 90% 51%` neste sistema —
      confirmado em `main.css`), batendo exatamente com a descrição do usuário ("referência tá numa cor
      laranja e o código tá com uma cor meio cinza"). Trocados os dois para `text-slate-900` (mesmo padrão
      já usado pelo nome da peça no mesmo arquivo), mantendo o resto do visual (fundo da badge, fonte
      pequena — usuário disse explicitamente que pode ficar "descartado" visualmente, só o texto precisa
      ser preto/legível). Revisado pelo `revisor`, sem achado. Publicado no Skip (Cadastro v0.0.85).


---

## PRIORIDADE 3 — Cadastro de Produto

### P3.1 — Copiar produto (herança de cadastro) — pedido como URGENTE

[11:06]-[15:55]. Vinícius classificou como *"um negócio aqui urgente que... tem que ser feito"*. Hoje, criar
um produto novo exige preencher tudo do zero. Na prática **quase nunca** se cria um produto do zero: cria-se
a partir de outro parecido.

Fluxo pedido: abrir um produto existente no Cadastro → botão **Copiar** → abre um produto novo, com **código
interno novo** (sequência), herdando todo o resto (marca, fornecedor, categoria, NCM/CEST, impostos,
estrutura fiscal) → o usuário altera só o que muda.

Exemplo dado: um embutido de solo já cadastrado só com ângulo fechado; surge a versão de ângulo aberto —
copia, muda a sigla do ano e o ângulo, o preço é o mesmo.

- [x] Implementado **só dentro do Cadastro** (`cadastro-lucenera-b86fe`), não no orçamento — como
      combinado explicitamente. Botão "Copiar" no rodapé de `PecaForm.tsx`, visível só quando editando um
      produto existente (`pecaId` preenchido). Implementação minimalista: não busca dados de novo — o
      formulário já está carregado com a peça de origem; "Copiar" só troca `editingId → null` (via
      `useDataStore`), o que faz o React re-renderizar `PecaForm` com `pecaId=null` SEM remontar (sem
      `key` no componente) e SEM limpar os valores já preenchidos (o `useEffect` que reagiria a essa
      mudança só reseta `codigoProdutoAtual`, nunca chama `form.reset()` nesse ramo).
- [x] `codigo_produto` do novo vem da sequência (`nextval` via `createProduto`, ramo `pecaId=null`), nunca
      copiado — confirmado, `codigoProdutoAtual` vira `null` e a UI mostra "gerado automaticamente".
- [x] Todos os campos ficam editáveis. SKU duplicado (se o usuário esquecer de mudar) é barrado pela
      checagem de unicidade já existente (`checkSkuExists`), com mensagem clara — não sobrescreve nem
      duplica silenciosamente.
- [x] Revisado pelo `revisor`, que confirmou passo a passo a hipótese de "não remonta, não limpa" contra o
      código real antes de aprovar (era o ponto mais arriscado da implementação). Achado real do revisor —
      **corrigido**: `estoqueItens` (state local, fora do react-hook-form) não era limpo ao copiar, então o
      painel "Estoque Integrado" continuava mostrando o estoque real do produto de origem como se já
      pertencesse ao produto novo. Fix: `setEstoqueItens([])` adicionado no ramo `else` do `useEffect`
      (`PecaForm.tsx`).
- Achado do revisor, não-bloqueante, **não corrigido nesta SPEC** (quirk pré-existente, só exposta por um
  caminho novo): se o produto de origem tiver `margem_lucro` legitimamente igual a `0` (ex.: item vendido ao
  custo), o cálculo automático de `preco_venda`/`valor_venda` aplica 150% de margem implícita mesmo assim
  (a proteção `pecaId === null` que existia só pra "peça nova do zero" agora também vale pra "copiado"), sem
  aviso visível — pode gerar preço bem diferente do pretendido. Registrado como follow-up para o
  Pedro/Vinícius decidirem se vale tratar.

### P3.2 — Cards/bordas separando os 3 blocos do formulário

[06:03]-[06:34] *"tem 3 blocos de dados para preencher... colocar uma borda em volta... dados básicos com um
cardzinho em volta, custo e preço com cardzinho em volta, fiscal e comercial com card"*.

- [x] **Moot/resolvido por tabela.** Investigado: o Cadastro real (`PecaForm.tsx`) já tem os 3-4 blocos com
      bordas coloridas visíveis (`border-2 border-amber-200`, `border-sky-200`, `border-violet-200`,
      `border-emerald-200`), nada a fazer lá. A fala era sobre o modal do ORÇAMENTO (confirmado pelo
      próprio Pedro na hora: *"vou fazer isso dentro de buscar produtos dentro de orçamento"*) — que a
      SPEC-158 P2.2 colapsou pra 1 seção só (4 campos), então não há mais "3 blocos" pra separar ali.

### P3.3 — Marca obrigatória

[07:05] *"A marca vai ser obrigatório, você vai ter que colocar."* No schema do modal do orçamento já está
`marca_id: z.string().min(1, 'Obrigatório')` — confirmar se vale também no Cadastro.

- [x] **Já implementado.** `PecaForm.tsx` (Cadastro real) já tem `marca_id: z.string().min(1, 'Obrigatório')`
      — confirmado no código, nenhuma mudança necessária.

### P3.4 — Margem padrão de 150%

[07:27] *"a gente tinha conversado para deixar isso como um padrão. 150%, mas para tipo visualização... o
preço de custo a gente já sabe que é 300, e aí ele vai estipular mais ou menos um preço de venda."*

- [x] **Já implementado.** `PecaForm.tsx` já tem `margem_lucro: z.coerce.number().min(0).optional().default(150)`
      no schema E `margem_lucro: 150` nos `defaultValues` do form, com proteção extra pra sempre aplicar
      150% em peça nova mesmo que o campo seja zerado — confirmado no código, nenhuma mudança necessária.
      Bate com a regra do trigger `fn_atualizar_preco_venda` (`custo_total * 2.5`, ou seja, +150%).

---

## PRIORIDADE 4 — Vendas / Emissão de NF-e (depende da conta Focus NFe)

Levantado em [31:02]-[41:00]. A estrutura da SPEC-154 já está no ar (banco + Edge Functions + espelho), mas a
conta Focus NFe ainda não existe. Vinícius avaliou que **boa parte desses campos vem pronta da própria API**
depois de configurada (*"eu acho que depois que fizer API isso vai ser, vai ter isso já"*). Registrado aqui
para conferência **depois** da conta criada, não para implementar às cegas agora:

- [ ] Poder **imprimir** a partir da tela de Vendas.
- [ ] Razão social do destinatário e poder ajustar a quantidade de peças da nota.
- [ ] **Transportadora** e modalidade de frete (remetente/destinatário), quando houver frete.
- [ ] **Quantidade de volumes**.
- [ ] Estrutura fiscal: base de cálculo de ICMS, valor de ICMS, ICMS-ST — *"só vai aparecer quando for venda
      do lucro presumido"* e nas vendas de revenda (material Ubiqua importado).
- [ ] Aba **Faturamento** (dados financeiros/boletos).
- [ ] **Dados adicionais** — texto livre que sai na nota (ex.: *"referente ao pedido de compra XXX"*).
- [ ] **Notas de referência** (ex.: nota de devolução referenciando a nota original).
- [ ] Natureza da operação: manter opção de **venda com entrega futura** (muda CFOP), embora o uso rotineiro
      seja só "venda" — *"tem que ter esse campo"*, mas não é o fluxo padrão.
- [ ] Indicador de presença: sempre **"não se aplica"** no uso atual.
- [ ] Endereço de entrega: **manter como está** — decisão explícita de que hoje não se usa
      (*"Pode colocar lá, que a gente não faz, a gente não usa"*).

---

## PRIORIDADE 5 — Nota fiscal de Simples Remessa a partir da Separação

[42:00]-[45:40]. Hoje, para emitir uma nota de **simples remessa** (só transporte), o Matheus precisa
**digitar um orçamento fake** — retrabalho puro, já que a separação já tem todos os dados.

Contexto de negócio dado pelo Vinícius:
- Cliente em Ribeirão Preto: emite só a nota fiscal de venda, entrega controlada pelas listas de entrega.
- Cliente fora (ex.: São Paulo, Inhotim): se a nota de venda ainda estiver válida para transporte, vai com
  ela (+ carta de correção de volumes). Se venceu, ou se a entrega é picada em várias remessas, precisa de
  **nota de simples remessa** por entrega.
- Entrega futura é evitada de propósito (*"dá mó bucha"* — obriga a emitir duas notas e fechar a operação
  depois).

Pedido: **de uma ou mais separações, emitir a nota fiscal de simples remessa** direto, sem redigitar.
Vinícius: *"não tem problema emitir 3 notas"* se a entrega foi separada em 3 — paga-se por nota, mas é raro.

- [ ] Feature grande, depende da integração Focus NFe estar funcionando (P4). Planejar em SPEC própria
      quando a conta existir.

---

## PRIORIDADE 6 — Administração Bancária / Contas em Aberto (investigar)

[48:38]-[56:18]. Vinícius e Pedro acharam a tela confusa e com números que não batem. Pedro assumiu estudar
a parte: *"Deixa eu estudar essa parte melhor. Nós vamos ter que mexer legalzinho aqui"*.

Pontos concretos levantados:
- [ ] Filtro de vencimento não parece filtrar (*"Coloca para hoje, não muda"*); só o bloco "a vencer" reagiu.
- [ ] Total "vencido" na casa de **R$ 1 milhão** — suspeita de resíduo do problema já conhecido de duplicatas
      antigas (ver `reference_import_contas_atualiza_vl_parcela`).
- [ ] Registros com **vencimento em 2030** — claramente errado.
- [ ] Confirmar o que o vermelho representa (entendimento: dias de atraso).
- [ ] Nomenclatura confusa em "Nota fiscal / Boleto vinculado" — Vinícius: *"eu não sei se precisa disso
      também, às vezes esse campo nem precisa"*.
- [ ] Conferir a correção que a Carol fez (remanejamento de pendências de ano) antes de concluir qualquer
      coisa.

---

## PRIORIDADE 7 — Limpeza de dados / recarga a partir da planilha do Sérgio

[58:17]-[61:16]. Apareceu no sistema o nome **"Felipe Tancini"** que **não existe** como cliente, fornecedor
nem funcionário (filtrado ao vivo, em todas as situações, sem nenhum registro). Pedro: *"foi em algum momento
eu fiz a atualização para dentro do sistema e ele não tá apagando histórico"*. Vinícius: *"aí esse é um
problema"*.

Decisão tomada na reunião:
- [x] Recarregar a partir da planilha do Sérgio tratando-a como **fonte de verdade**. **Feita fora desta
      SPEC**, em paralelo — ver SPEC-157 (reconciliação/espelho formal nos 4 scripts de import Connect,
      `CHANGELOG.md` 2026-09-22) e confirmação direta do usuário (2026-09-23): "a limpeza já foi feita".
- [x] Limpeza dos dados de teste — coberta pelo mesmo trabalho da SPEC-157/sync Connect.

---

## Prioridade acordada no fim da reunião

[61:16]-[62:55]. Vinícius definiu a ordem:

1. **Primeiro**: a limpeza/recarga dos dados (P7) — é o que destrava ele para voltar a testar sem ficar
   perdido com dado inconsistente.
2. **Depois**: Estoque + Produção + Garantia — *"se a gente botar para rodar semana que vem, tá bom"*
   (Produção e Garantia já entregues pela SPEC-156).

## Análise de ecossistema

- **Depende de tabelas centrais?** Sim: `orcamentos` (P1.1, P2.3), `produtos` (P1.3, P3), `contatos` (P2.1),
  `transacoes`/`negociacoes` (P6, P7).
- **Sistemas afetados**: Orçamentos, Cadastro, Vendas, Separação/Logística, Administração Bancária.
- **Dado duplicado a derivar?** Não — P2.3 (digitador) é dado novo, não derivável do vendedor.
- **Migration antiga contradiz o snapshot?** P1.1 corrige uma regra da SPEC-019 que a SPEC-135 já havia
  ajustado parcialmente; a migration nova precisa citar as duas.
- **Exige atualizar `AI_DB_CONTEXT.md`?** Sim, no Orçamentos (P1.1 muda regra de transição de status; P2.3
  adiciona coluna) — [x] feito.

## Critérios de aceite

- P1.1: editar qualquer campo de pagamento de um orçamento em *Aprovação Financeira* mantém o status e
  registra a alteração no histórico; orçamento em *Orçamento Aprovado* continua resetando.
- P1.2: item com desconto próprio reflete a margem correta no painel Gerenciamento, isolada e combinada com
  o desconto global simulado.
- P2/P3: conferência visual com o Vinícius.

## Pendências conhecidas

- P1.3 (margem "padronizada") — bloqueado aguardando esclarecimento; **não** executar UPDATE em massa.
- P2.3 (digitador) — **concluído** (2026-09-23): coluna `orcamentos.digitado_por` aplicada em produção,
  captura automática no login, exibida no PDF do orçamento. Revisado (achado corrigido: truncagem do nome
  do(s) arquiteto(s) no PDF pra não colidir visualmente com a nova coluna). Publicado no Skip (Orçamentos
  v0.0.373) — inclui a Edge Function `generate-report`, confirmada via Management API (body deployado
  contém `orcamentos_digitado_por_fkey` e o label "Digitador"; `updated_at` bate exato com o horário do
  publish). Não basta o "QA ok" do Skip pra confirmar Edge Function no ar — ver
  [[project_spec154_backend_focus_nfe_2026_09_21]].
- P2.5 (cor preta referência) — **concluído** (2026-09-23): usuário confirmou a tela ("sistema de consultar
  produtos" = listagem de Peças do Cadastro), causa raiz real diferente da hipótese original (`text-slate-500`
  no código, `text-primary` laranja na referência, não `text-muted-foreground`). Corrigido pra
  `text-slate-900` nos dois, revisado sem achado, publicado no Skip (Cadastro v0.0.85).
- P4/P5 — dependem da conta Focus NFe, que ainda não existe.
- P6 — investigação, sem causa raiz confirmada ainda.
- **Concluído (2026-09-23)**: migrations `20260923_158_fix_reset_aprovacao_financeira` e
  `20260923_158b_item_sem_cadastro_simplificado` aplicadas e confirmadas em produção. Frontend (P1.2, P2.1,
  P2.2, P2.4, P3.1) commitado nos 3 repositórios (git) e publicado no Skip — Orçamentos
  (gestao-financeira-clone-544cb.goskip.app, v0.0.371) e Cadastro (cadastro-lucenera-b86fe.goskip.app,
  v0.0.84).
- **Achado durante o merge (Cadastro)**: o git local do submódulo `cadastro-lucenera-b86fe` estava ~30
  commits atrás do que já estava publicado no Skip (SPEC-120 SystemSwitcher, SPEC-116 busca fuzzy,
  SPEC-115, SPEC-101, vários fixes de layout — nunca puxados pro git local). Mesclado sem perda: conflito em
  `PecaForm.tsx` resolvido preservando o fix mais novo (setTimeout no setValue de marca/categoria) junto com
  o botão Copiar. Havia também, na working tree local (não commitados), arquivos soltos do rollout
  SystemSwitcher (`Layout.tsx`, `cross-system-auth.ts`, `Login.tsx`, `SystemSwitcher.tsx`,
  `useSistemasPermitidos.ts`, `Pecas.tsx`, `PecaDetailsPanel.tsx`, `produtos.ts` — este último com um fix da
  SPEC-151 de estoque de showroom) — per orientação já registrada de não commitar esse rollout sem perguntar
  ao usuário, foram colocados em `git stash` (`SPEC-158: rollout SystemSwitcher pendente...`) em vez de
  descartados ou commitados. Precisa decisão do usuário: commitar, descartar ou revisar antes.
- **Achado na publicação (Orçamentos)**: `skip_project_apply_changes` reportou `ok: false` na etapa
  "integrations" — mas os 3 erros são de migrations antigas (jun/jul/2026, sem relação com SPEC-158)
  falhando ao serem replayadas do zero pelo QA do Skip contra um schema que já mudou desde então (coluna
  `projeto_id`/função `recusar_orcamento_cliente_publico`/constraint `orcamentos_data_inicio_pagamento_check`
  — desalinhamento pré-existente entre o histórico de migrations rastreado pelo Skip e o schema real, que é
  gerenciado direto via Management API, fora do Skip). Build e testes passaram normalmente; publicado mesmo
  assim. Vale investigar/alinhar esse histórico do Skip em algum momento, mas não bloqueia nem foi causado
  por esta SPEC.
