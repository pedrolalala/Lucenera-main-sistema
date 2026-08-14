---
titulo: "SPEC-066 — Estrutura de Compras: Fornecedor×Marca, Observação de Caixa Fechada, Medida Fina (Produção Interna), Solicitações e Entrada de Nota Fiscal"
status: parcialmente aprovada — 4 frentes prontas para implementar, 1 frente ainda bloqueada por decisão de produto
data_ultima_modificacao: 2026-08-06
sistemas_envolvidos:
  - Compras (compras-lucenera-3o23t98ee)
  - Supabase (banco central)
dependencias:
  - SPEC-039 (Necessidade de Compra — colunas Pendente/Empresa que comprou/Status/Entrega)
  - SPEC-040 (abas Por Produto / Por Item de Orçamento)
  - SPEC-057 (correções Necessidade de Compra — campo Empresa no pedido, numeração legado)
---

# SPEC-066 — Estrutura de Compras: Fornecedor×Marca, Caixa Fechada, Medida Fina, Solicitações e Entrada de Nota Fiscal

> Origem: 5 arquivos de reunião de trabalho entre a Débora (compradora) e o Filippo, 06/08/2026, em `02-Reunioes/015. Lucenera (debora) -06.08.2026_ Esctrutura da Necessidade de compra/`: `Renião.01.txt`, `Reunião.02.txt`, `Reunião.03.txt` (**vazio, sem áudio capturado**), `Renião.04.txt`, `Reunião.05.txt`. A transcrição é automática, tem muito ruído de fala e trechos truncados/mal reconhecidos — esta SPEC é uma leitura interpretativa do conteúdo, cruzada com o código e o schema reais. **Onde a intenção da Débora não ficou 100% inequívoca no áudio, isso está marcado explicitamente como Pendência, não como decisão.**
>
> Reuniões 02/04/05 são a Débora demonstrando, em tela compartilhada, o sistema **atual/legado** que ela usa hoje (fora do Lucenera novo) — servem como especificação de referência de campos e fluxo, não como descrição do sistema novo já pronto.

## Checklist de Ação

### A. Rastreabilidade de cliente/venda por peça — já implementado, só confirmar

- [x] **Achado**: a Débora pediu poder ver, a partir de um produto, quais clientes/projetos precisam dele ("onde eu vou ver o cliente que precisa dela"). Isso **já existe**: `NecessidadeCompraDetalhe.tsx` (painel expansível da aba "Por Produto" em `NecessidadeCompra.tsx`) + `services/necessidade-compra-detalhe.ts` já trazem `cliente`/`cliente_id` por projeto com entrega futura para cada produto. A própria Débora reconheceu isso na reunião ("Isso aqui já está gravado").
- [ ] Nenhuma ação de código necessária. Homologar com a Débora que o painel expansível (clicar no ícone de "Projetos" na linha do produto) cobre exatamente o que ela pediu — se não cobrir 100%, abrir pendência específica depois de ver o gap real.

### B. Relação Fornecedor ↔ Marca (inverter a FK) — pronto para implementar

- [x] **Achado de schema crítico (verificado 2ª vez, depois de quase escrever a migration errada)**: "fornecedor" neste sistema **não é** a tabela `public.fornecedores` — ela existe mas tem **0 linhas**, não é usada em nenhum lugar real do código. O fornecedor de verdade é `public.contatos WHERE tipo = 'fornecedor'` (357 linhas) — é essa tabela que `marcas.fornecedor_id`, `pedidos_compra.fornecedor_id`, `produto_fornecedores.fornecedor_id` e `cotacoes_compra.fornecedor_id` referenciam de fato (confirmado via `pg_constraint` direto no Supabase real). `getFornecedores()` no frontend (`services/pedido-compra.ts`) também já busca em `contatos` via RPC `buscar_fornecedores_fuzzy`. A coluna nova desta Frente vai em **`contatos`**, não em `fornecedores`.
- [ ] Migration: adicionar `public.contatos.marca_id uuid REFERENCES public.marcas(id)`, nullable (só relevante para `tipo = 'fornecedor'`). Migrar os 66 vínculos existentes: para cada `marcas.fornecedor_id IS NOT NULL`, setar `contatos.marca_id` = o `id` daquela marca no contato-fornecedor correspondente.
- [ ] **Pendência de decisão**: manter `marcas.fornecedor_id` como está (obsoleta, mas sem quebrar nada que já leia dela) ou remover a coluna depois de confirmar que nada mais no código a usa? Não decidido na reunião — verificar todos os usos de `marcas.fornecedor_id` no frontend antes de decidir.
- [ ] UI: tela de cadastro/edição de Fornecedor ganha campo "Marca" (Select). A Débora pediu poder cadastrar fornecedor novo direto dali, sem sair da tela ("abrir um campo aí pra você adicionar") — like um botão "+ novo fornecedor" inline, mesmo padrão já usado em outros modais do sistema (ex. `ProductCreateModal.tsx` em Orçamentos).
- [ ] Regra de negócio explícita (decidida na reunião): **um fornecedor pertence a exatamente uma marca; uma marca pode ter zero ou vários fornecedores.** Não é N:N — é 1 (fornecedor) : N (marca). Exceções de marca que não entrega tudo por um fornecedor são tratadas manualmente, não como regra de sistema ("a gente tem que trabalhar com exceção... isso tem que estar" — ou seja, o cadastro tem que permitir a exceção existir, não bloquear).

### C. Observação / "Caixa Fechada" — pronto para implementar (schema já existe)

- [x] **Achado de schema**: `public.produto_fornecedores` já tem as colunas `observacao` (text) e `qtd_minima` (numeric) — exatamente o que a Débora pediu ("caixa fechada vem tanto... a observação eu acho que é uma coisa boa a gente começar a estruturar"). A tabela existe mas está **vazia (0 linhas)** — não precisa de coluna nova, só passar a popular e exibir o que já existe.
- [ ] Expor `observacao` (e opcionalmente `qtd_minima`) de `produto_fornecedores` na tela onde a Débora cadastra o vínculo produto×fornecedor.
- [ ] Expor essa mesma `observacao` **apenas** no momento de "Fechar Pedido em Lote" (`ModalPedidoLote.tsx`) — decisão explícita da Débora de **não** adicionar coluna nova na grid principal de Necessidade de Compra, para não virar informação redundante fora do contexto em que ela é usada ("só nessa hora que você vai fazer o pedido do lote... de resto vai ficar só redundante").
- [ ] Fora de escopo por decisão explícita: **não** construir regra automática de bloqueio/múltiplo de caixa fechada (validar que a quantidade pedida é múltiplo de `qtd_minima`, por exemplo) — é só informação textual por enquanto. A Débora deixou claro que essa regra só importa pra poucos itens específicos (ex. lâmpadas Stella) e pode ficar pra depois.

### D. Fluxo de "Medida Fina" (produção interna — linha/rotineira) — parcialmente desbloqueado

> Continua sendo a frente mais nova/imatura. A Reunião.02 resolveu a pendência mais crítica (P-D1: como identificar item de produção interna), mas P-D2/P-D3/P-D4 continuam abertas. **Ainda não implementar** — mas já dá pra desenhar a modelagem com mais confiança.

- [ ] **Contexto real (hoje 100% manual, fora do sistema)**: alguns itens de orçamento (linha/esteira, produzidos internamente pela "rotineira") entram no orçamento com quantidade estimada/arredondada, porque a medida exata da obra ("medida fina") só é tirada depois que o orçamento já foi aprovado e faturado. Quando a "medida fina" chega (via desenho técnico feito pela equipe de projetos), a Débora hoje: consulta uma tabela de componentes por código pra achar o preço certo, monta manualmente um pedido de produção, anexa o desenho, e manda por Teams/WhatsApp para o Cláudio (responsável pela produção interna).
- [x] **P-D1 resolvida (Reunião.02)**: a identificação de item de produção interna é **por marca**. Na demonstração do sistema legado, Débora entra direto na marca "Eclart" como exemplo de "marca de produção interna" (existem outras). Ou seja: **não precisa de flag novo em `orcamento_itens`** — o mesmo padrão da Frente B (`contatos.marca_id` / marca) já resolve isso. Ação: adicionar um campo `marcas.producao_interna boolean DEFAULT false` (ou reaproveitar alguma classificação existente, a confirmar) para marcar quais marcas são de produção interna (ex. "rotineira").
- [ ] **Proposta discutida (não fechada)**: quando alguém atualizar a quantidade do item de orçamento com a medida fina real, o sistema dispara automaticamente uma notificação/ordem de produção pro Cláudio dentro do sistema (não mais WhatsApp), com o desenho anexado. O Cláudio marca "pronto" quando finaliza, e isso fecha a necessidade daquele item.
- [ ] **Pendência bloqueante P-D2**: quem edita a "medida fina" no sistema — a própria Débora, ou a equipe de projetos ("as meninas") direto no orçamento? Isso muda onde a funcionalidade deve morar (Compras vs. Orçamentos).
- [ ] **Pendência bloqueante P-D3**: o Cláudio precisa de acesso próprio ao sistema (login, papel/permissão) para ver essas ordens e marcar como concluído. Não foi discutido se ele já tem usuário, nem que sistema ele acessaria.
- [ ] **Pendência P-D4**: modelagem de dados não decidida — uma tabela nova (`ordens_producao_interna`, por exemplo) ou reaproveitar `pedidos_compra` com um `fornecedor_id` especial/nulo representando "produção interna"? Precisa de mais uma conversa dedicada só a essa modelagem antes de qualquer migration.
- [ ] Upload/anexo do desenho técnico (imagem ou PDF) precisa de um local de armazenamento — provavelmente Supabase Storage, mesmo padrão já usado em outros anexos do sistema (a confirmar qual).

### E. "Entrada de Nota Fiscal" (substitui a aba "Recebimento") — desenho bem mais concreto, pronto para um v1

- [x] **Achado de código**: `/recebimento` hoje é placeholder (`<EmBreve titulo="Recebimento" />`, `App.tsx:54`). `/solicitacoes` também (`App.tsx:51`).
- [x] **Achado de schema**: existe uma tabela `public.notas_fiscais`, mas ela é do domínio de **vendas** (colunas `orcamento_id`, `arquiteto`, `boleto_id` — nota fiscal emitida para o cliente, só 3 linhas hoje). **Não serve** para o que a Débora pediu (nota fiscal de **compra**, recebida de fornecedor) — precisa de tabela nova, não reaproveitar essa.
- [ ] Renomear a aba/rota: "Recebimento" → "Entrada de Nota Fiscal" (mesma nomenclatura que a Débora já usa no dia a dia).
- [x] **Fluxo real detalhado (Reunião.05)**: hoje, no grupo do Teams "TIMS NFs", o Matheus ou a Vitória avisam que uma nota física chegou no armazém (número da nota, marca, empresa). Débora também já recebe a nota por e-mail. **Antes de ela poder dar entrada, a nota passa por um checador de impostos (o "VINI"), que confere os impostos e só depois libera para ela.** Só então ela faz a "entrada de nota fiscal" no sistema.
- [ ] **Novidade em relação ao desenho original desta SPEC**: incluir um gate/status de "aguardando checagem de impostos" antes da entrada poder ser confirmada — quem faz essa checagem (VINI) precisa, no mínimo, aparecer como responsável/step no fluxo, mesmo que a checagem em si continue manual/fora do sistema por enquanto. **Pendência P-E3**: o VINI vai interagir com o sistema (marcar "impostos conferidos") ou isso continua 100% por fora (Teams/e-mail) e só a Débora usa o sistema?
- [ ] Fluxo v1 de entrada (a Débora demonstrou o equivalente no sistema legado): buscar/vincular o `pedido_compra`, preencher número da nota fiscal, empresa, data/hora da entrada. O sistema legado também amarra número do orçamento/venda/cliente/L (ambiente) — ver ressalva abaixo.
- [x] **Achado importante (a própria Débora questionou, Reunião.05)**: no sistema legado, a entrada de nota fiscal registra vínculo até o nível de orçamento/venda/cliente/L (ambiente do projeto). Mas ela mesma disse que **isso pode ser exagero para o sistema novo**, já que hoje existe um **único estoque consolidado** (não hoje segregado por cliente/venda no momento do recebimento): *"como hoje se trata apenas de um único estoque, talvez isso possa ser repensado... seria melhor enxugar um pouco isso"*. **Decisão sugerida**: a entrada de nota fiscal v1 vincula só ao `pedido_compra` (fornecedor, itens, valor, empresa) — **não** replicar o nível de detalhe orçamento/venda/cliente/L do sistema legado, a menos que ela confirme que precisa disso. Isso simplifica a Frente E em relação ao desenho original desta SPEC.
- [ ] Depois de salva a entrada, hoje ela gera um documento e leva manualmente pro Teams (canal "Suprimentos"), nomeado tipo `ENF <número> <marca> <empresa> <data>`, e avisa o Matheus. Ele imprime e arquiva. **Quer isso dentro do sistema** — uma visualização/relatório acessível para o Matheus sem precisar exportar/reenviar arquivo manualmente.
- [ ] **Decisão explícita**: **não** criar uma etapa separada de "verificação física de peças" dentro do sistema — a conferência física (bater referência da caixa com a entrada feita) continua sendo feita pelo pessoal do armazém no chão de fábrica, fora do sistema, mesmo no fluxo legado.
- [ ] Migration: tabela nova `public.notas_fiscais_compra` (nome sugerido, a confirmar) com `pedido_compra_id` (FK), `numero_nf`, `data_emissao`, `valor`, `arquivo_url` (upload do PDF/XML), `criado_por`, `criado_em`. **Não usar o nome `notas_fiscais`** (já ocupado pelo domínio de vendas).
- [ ] **Fora de escopo desta rodada** (mencionado, não decidido, não bloqueia o v1 acima):
  - Integração automática via API/e-mail para puxar XML da nota fiscal sozinho (a Débora citou que o sistema legado "Connect" faz isso e quer paridade, mas não é urgente).
  - Validação automática de divergência nota×pedido (valor, parcelas, empresa) — decisão explícita da reunião foi **manter manual por enquanto**, porque referência/SKU nem sempre bate exatamente com o que vem na nota, e automatizar cedo demais arrisca gerar recusas falsas por divergência de centavos ou referência.
  - Integração com o portal da SEFAZ (cancelar nota fiscal, manifesto de destinatário) — hoje é 100% manual fora do sistema; registrado aqui só como necessidade futura real, sem desenho técnico ainda.
  - Checagem de impostos do VINI dentro do sistema (ver P-E3) — por ora, tratar como um passo humano antes da entrada, sem modelagem de status dedicada.

### F. Aba "Solicitações" — desenho concreto obtido (Reunião.02/04), pronto para implementar

- [x] **Desenho obtido direto da demonstração da Débora no sistema legado (Reunião.02)**: "Solicitações" = **"Aprovar Necessidade de Compra"**. É o passo entre "eu vi que preciso comprar isso" e "virou um pedido de compra de verdade". Fluxo:
  1. A partir da Necessidade de Compra (que **soma todas as empresas juntas**, ver Frente G abaixo), a Débora escolhe os itens, seleciona a **marca**, o **fornecedor** (resolvido pela marca, Frente B), a **empresa** de destino da compra (rotineira/slide/foco/etc.) e o **perfil** (Ribeirão/São Paulo), pode ajustar o **quantitativo**, e salva — isso gera um registro em "Solicitações", **sem** efetivar a compra ainda.
  2. Em "Solicitações", cada item tem um **status**: `Aguardando aprovar` → (opcional) `Confirmado` → `Aprovado` ou `Rejeitado`.
  3. **Decisão explícita da Débora sobre o status "Confirmado"**: ele existe para um fluxo de **duas pessoas** (quem monta a solicitação vs. quem revisa/confirma antes da aprovação final) — uma rechecagem de preço/quantidade/empresa por questão de organização financeira. **Se o time de compras for só ela (uma pessoa fazendo tudo), esse status não é necessário** — o fluxo vira só `Aguardando aprovar` → `Aprovado`/`Rejeitado`. **Pendência P-F1**: confirmar com o Filippo/Débora se o time de Compras hoje é só ela ou se existe mais alguém no papel de "confirmador", para decidir se o status "Confirmado" entra no v1 ou fica pronto no schema mas sem uso na UI por enquanto.
  4. Rejeitado → volta para "Necessidade de Compra" (não fica órfão, não é estado final).
  5. Aprovado → gera o `pedido_compra` (Frente já coberta por SPEC-021/038/057 — reaproveitar o fluxo de pedido já existente, só mudando a origem: em vez de nascer direto da tela de Necessidade de Compra, pode nascer de uma "Solicitação" aprovada).
  6. Campos adicionais no momento de aprovar/gerar pedido: **condição de pagamento** e **data prevista de entrega** (estimativa da Débora, editável).
- [x] **Achado crítico (verificado antes de escrever a migration)**: `public.solicitacoes_compra` **já existe** no Supabase real — mas com outro propósito: é um log interno criado automaticamente pela RPC `criar_pedido_compra_de_necessidade()`/`criar_pedido_compra_lote()` **junto** com o pedido (status sempre `'pedido_gerado'`, 14 linhas hoje), não uma fila de aprovação **prévia**. Não é o mesmo conceito que a Débora descreveu. Por isso a tabela nova desta Frente tem nome diferente: `public.solicitacoes_aprovacao_compra`.
- [ ] Migration: nova tabela `public.solicitacoes_aprovacao_compra` — `produto_id`, `marca_id`, `fornecedor_id` (FK `contatos`, não `fornecedores` — ver achado da Frente B), `empresa_id`, `perfil`, `quantidade`, `custo_unitario`, `cliente_id` (opcional, se quiser manter o vínculo de origem), `status` (`aguardando_aprovar`/`confirmado`/`aprovado`/`rejeitado`), `condicao_pagamento`, `data_prevista_entrega`, `criado_por`, `criado_em`, `pedido_compra_id` (preenchido quando aprovado e o pedido é gerado).
- [x] Aprovar chama uma RPC nova `aprovar_solicitacao_compra()` (`SECURITY DEFINER`), que por sua vez chama a RPC já existente `criar_pedido_compra_de_necessidade()` — reaproveita toda a lógica de criação de pedido já validada em produção, não duplica.
- [ ] UI: nova página `Solicitacoes.tsx` (substitui o placeholder `EmBreve` em `/solicitacoes`), listando por status, com ação de aprovar/rejeitar/confirmar (se aplicável) e edição de empresa/perfil/quantidade antes de aprovar.
- [ ] **Pendência P-F2**: como uma Solicitação é criada — a partir de uma ação explícita na grid de Necessidade de Compra ("gerar solicitação" em vez do fluxo atual de ir direto pro Pedido em Lote), ou os dois caminhos (solicitação e pedido direto) continuam coexistindo? A reunião não deixou isso 100% claro — a Débora mostrou o legado gerando a solicitação a partir de uma tela equivalente à Necessidade de Compra, mas o sistema novo já tem o fluxo direto "Fechar Pedido em Lote" (SPEC-030/057) que pula esse passo. Decidir se "Solicitações" é **obrigatório** no caminho (todo pedido passa por lá) ou **opcional** (um atalho a mais para quando ela quer separar "escolher o que comprar" de "efetivar o pedido").

### G. Necessidade de Compra deve somar todas as empresas — já é o comportamento atual, confirmar

- [x] **Achado (Reunião.02)**: a Débora foi explícita que a Necessidade de Compra **não pode ser filtrada por empresa antes da compra** — ela precisa ver o total consolidado de todas as empresas (rotineira/slide/foco/etc.) juntas, porque otimiza a compra: comprar no CNPJ onde o volume é maior economiza frete e melhora negociação (ex. "uma lâmpada na Foco tem 20 e na Slide tem 60 — eu vou comprar na Slide"). A empresa só é escolhida **depois**, no momento de aprovar/fechar o pedido (Frentes F e "Fechar Pedido em Lote" já existente).
- [x] **Achado de código**: `vw_necessidade_compra` (view usada por `NecessidadeCompra.tsx`) **já não tem filtro nem coluna de empresa** — o cálculo de necessidade já é agregado por produto, independente de empresa (consistente com "hoje se trata apenas de um único estoque", frase da própria Débora na Reunião.05). **Nenhuma ação de código necessária aqui** — só confirmar com ela que o comportamento atual já é isso, sem regressão.

### H. Encargos (IPI/ICMS/ST) no valor total do pedido — gap real, fora de escopo desta rodada

- [x] **Achado (Reunião.02/03)**: hoje `pedidos_compra.valor_total` só soma o valor dos produtos, **sem os encargos** (IPI, ICMS, ST — que variam por marca, algumas marcas têm, outras não). Isso afeta os relatórios de **previsão/provisão financeira de caixa** que a Débora preenche manualmente hoje (campo "previsão de pagamento") para saber quanto está previsto de gastar em cada mês.
- [ ] **Fora de escopo desta SPEC** — é um cálculo mais complexo (a própria Débora citou que "o Sérgio ia dar uma atualizada nisso pra puxar os encargos da marca"), possivelmente envolvendo cadastro de alíquota por marca. Registrado aqui como necessidade real e futura, não como item a implementar agora.

## Objetivo

Débora (compradora) está numa sessão de onboarding/estruturação do sistema de Compras com o Filippo, testando o fluxo real de compra contra o que o sistema oferece hoje e demonstrando, em telas do sistema legado que ela usa, o desenho de referência para as partes que ainda faltam. Da conversa, saem **4 frentes técnicas com decisão suficiente para implementar** (B, C, E-v1, F), **2 frentes já resolvidas sem precisar de código novo** (A, G — confirmar comportamento existente), **1 gap real registrado como fora de escopo** (H — encargos no valor total), e **1 frente que segue precisando de mais decisão** antes de qualquer linha de código (D — medida fina/produção interna, agora parcialmente desbloqueada).

## Decisões aprovadas

- Fornecedor pertence a exatamente uma marca (`contatos.marca_id`); marca pode ter vários fornecedores. Direção oposta à FK atual (`marcas.fornecedor_id`), que será migrada.
- Observação de "caixa fechada" usa a coluna `produto_fornecedores.observacao` já existente (não criar coluna nova), exibida só no cadastro produto×fornecedor e no modal de Fechar Pedido em Lote — não na grid principal.
- Não construir regra automática de múltiplo de caixa fechada agora — só exibição de texto informativo.
- Item de produção interna ("rotineira") é identificado **por marca** (`marcas.producao_interna`), não por flag em item de orçamento nem por categoria.
- Aba "Recebimento" renomeada para "Entrada de Nota Fiscal"; sem etapa separada de verificação física de peças; v1 vincula só ao `pedido_compra` (fornecedor/itens/valor/empresa), sem replicar o nível de detalhe orçamento/venda/cliente/L do sistema legado.
- Validação automática de divergência nota fiscal × pedido fica manual por enquanto (risco de falso-positivo por causa de referência/SKU divergente). Checagem de impostos (hoje feita pelo "VINI") também continua manual/fora do sistema por ora.
- Integração com SEFAZ (recusa/manifesto de nota fiscal) fica de fora desta rodada — necessidade futura registrada, sem desenho técnico.
- Aba "Solicitações" = "Aprovar Necessidade de Compra": fluxo `Aguardando aprovar` → (`Confirmado`, opcional) → `Aprovado`/`Rejeitado`; rejeitado volta pra Necessidade de Compra; aprovado gera o `pedido_compra`.
- Necessidade de Compra continua somando todas as empresas juntas (sem filtro por empresa) — a escolha de empresa acontece só no momento de aprovar/fechar o pedido. Comportamento já é esse hoje, sem mudança de código necessária.
- Encargos (IPI/ICMS/ST) no valor total do pedido/necessidade ficam de fora desta rodada — gap real, mas não é o escopo desta SPEC.
- Fluxo de "medida fina"/produção interna (item D) segue sem avançar para implementação — P-D1 resolvida, mas P-D2/P-D3/P-D4 continuam abertas.

## Análise de ecossistema

- **Depende de**: `marcas`, `fornecedores`, `produto_fornecedores`, `pedidos_compra`, `vw_necessidade_compra`. Não depende de `orcamentos`/`projetos` para as frentes B/C/E/F/G — a frente D (medida fina), se avançar no futuro, vai depender de `orcamento_itens` (para o flag/edição de medida fina) e possivelmente de um novo domínio de "produção interna".
- **Afeta**: só o sistema Compras (`compras-lucenera-3o23t98ee`). A tabela `notas_fiscais` existente (domínio vendas, usada em outro sistema) não é tocada — a nova tabela de nota fiscal de compra tem nome diferente para não colidir. A nova tabela `solicitacoes_aprovacao_compra` (Frente F) referencia `pedidos_compra` (preenchido só quando aprovada), sem alterar o fluxo de pedido já existente (SPEC-021/038/057).
- **Existe migration antiga que contradiz o snapshot central?** Não verificado exaustivamente para este ponto — mas `marcas.fornecedor_id` está confirmado real e populado (66/110) via consulta direta ao Supabase, então a migration de inversão precisa migrar dado, não só schema.
- **Exige atualizar `AI_DB_CONTEXT.md`?** Sim, do sistema Compras — documentar a inversão fornecedor↔marca, a nova tabela `notas_fiscais_compra` e a nova tabela `solicitacoes_aprovacao_compra` quando implementadas.

## Critérios de aceite

**Frente B (Fornecedor×Marca)**:
- Cadastro/edição de fornecedor permite selecionar uma marca (obrigatório ou opcional — a confirmar com a Débora antes de implementar).
- Os 66 vínculos existentes de `marcas.fornecedor_id` aparecem corretamente como `contatos.marca_id` depois da migration, sem perda de dado.
- Uma marca com múltiplos fornecedores exibe todos eles corretamente onde for consultada (ex. resolução de fornecedor por marca na Necessidade de Compra).

**Frente C (Observação/Caixa Fechada)**:
- Cadastrar/editar `produto_fornecedores.observacao` reflete no modal de Fechar Pedido em Lote para aquele produto.
- Grid principal de Necessidade de Compra **não** ganha coluna nova.

**Frente E (Entrada de Nota Fiscal v1)**:
- Buscar um pedido de compra pelo número preenche automaticamente fornecedor/itens/valor/empresa.
- Confirmar a entrada grava um registro em `notas_fiscais_compra` vinculado ao pedido.
- Existe uma visualização (ainda que simples) acessível para conferência posterior, sem precisar exportar/reenviar PDF manualmente.

**Frente F (Solicitações)**:
- Uma solicitação criada a partir da Necessidade de Compra guarda marca, fornecedor, empresa, perfil e quantidade editáveis.
- Mudar o status para "Aprovado" gera o `pedido_compra` correspondente; "Rejeitado" volta o item para a Necessidade de Compra.
- Se o status "Confirmado" ficar fora do v1 (por decisão da P-F1), o fluxo funciona corretamente só com `aguardando_aprovar`/`aprovado`/`rejeitado`.

**Frente G (Necessidade de Compra agregada)**:
- Nenhuma regressão: a grid de Necessidade de Compra continua mostrando o total de todas as empresas juntas, sem filtro por empresa antes da compra.

## Testes/verificações obrigatórias

- Antes de aplicar a migration da Frente B, rodar um `SELECT` de conferência nos 66 vínculos `marcas.fornecedor_id` atuais e comparar com o resultado pós-migration em `contatos.marca_id` — nenhum vínculo pode se perder.
- QA completo do Skip (`skip_project_apply_changes`) antes de publicar qualquer uma das frentes.
- Não há suíte de testes automatizada no sistema Compras — critério de aceite é verificação manual + build/lint do Skip, mesmo padrão das SPECs anteriores deste sistema.
- Homologar com a Débora especificamente a Frente A (rastreabilidade cliente por peça) e a Frente G (agregação por empresa), já que o código existe mas não foi confirmado formalmente que cobre 100% o que ela pediu.

## Realizado

**2026-08-06 — Frentes B, C, E e F implementadas e publicadas em produção:**

- Migration `supabase/db/migrations/20260806_080_spec066_fornecedor_marca_nf_compra_solicitacoes/` aplicada no Supabase real: `contatos.marca_id` (65 dos 66 vínculos migrados — 1 fornecedor estava vinculado a 2 marcas simultaneamente sob o schema antigo, "BELLALUCE" e "METALSPOT" via o mesmo contato; sob a regra nova, 1 fornecedor = 1 marca, só BELLALUCE manteve o vínculo automático — METALSPOT precisa de um fornecedor próprio cadastrado manualmente, ver Pendências), RLS de escrita em `produto_fornecedores`, tabela `notas_fiscais_compra` + bucket de storage, tabela `solicitacoes_aprovacao_compra` + RPCs `aprovar_solicitacao_compra`/`rejeitar_solicitacao_compra`.
- Frontend (`compras-lucenera-3o23t98ee`, Skip `projectId 40326`, v0.0.54/`30185b6`, QA completo passou): painel de fornecedores múltiplos em `Marcas.tsx` (Frente B); observação/qtd mínima editável no Fechar Pedido em Lote (Frente C); páginas novas `EntradaNotaFiscal.tsx` (Frente E, com upload de PDF/foto) e `Solicitacoes.tsx` (Frente F) substituindo os placeholders "Em breve"; botão "Solicitar Compra" adicionado à Necessidade de Compra.
- **Achado durante a publicação**: o QA do Skip acusou build quebrado na primeira tentativa — `pedido-compra.ts` local estava desatualizado (não tinha `getEmpresas`/`cancelarPedidoCompra`/`STATUS_PEDIDO_COMPRA_CANCELAVEL` das SPEC-057/060, que nunca foram sincronizadas para o git local) e o campo "Empresa" também estava faltando em `ModalPedidoLote.tsx`. Reconstruído a partir do uso real em `PedidosCompra.tsx`/`ModalRegistrarCompra.tsx` (lidos direto do Skip) antes de publicar — nada quebrou em produção, o erro foi pego no QA antes do publish.
- Build/lint (`npm run build`, `oxlint`) passaram sem erro novo em todos os arquivos alterados.
- **Não testado no navegador com dados reais** — homologação com a Débora/Matheus ainda pendente, especialmente a Frente E (upload de anexo) e a resolução de fornecedor por marca na Frente B/F.

## Pendências

- [ ] **Novo, achado na migration**: marca "METALSPOT" ficou sem fornecedor vinculado (perdeu o vínculo automático que compartilhava com "BELLALUCE" sob o schema antigo). Precisa que alguém cadastre o fornecedor/CNPJ correto de METALSPOT em `Marcas.tsx` (painel de fornecedores da marca).

## Pendências

- [x] P-B1 — **Decidido**: manter `marcas.fornecedor_id` como está por ora (não remover na mesma migration) — só adicionar `contatos.marca_id` e migrar os 66 dados. Remoção da coluna antiga fica para depois de confirmar todos os usos no frontend.
- [x] P-B2 — **Decidido (2026-08-06)**: campo "Marca" no cadastro de fornecedor é **opcional**, não obrigatório.
- [ ] P-D2 a P-D4 — ver seção D acima (P-D1 já resolvida: identificação é por marca). Bloqueiam qualquer implementação do fluxo de medida fina/produção interna.
- [x] P-E1 — **Decidido**: tabela nova `notas_fiscais_compra`.
- [ ] **P-F1 — achado testando "Necessidade de Compra" ao vivo (14/08)**: `contato_tipos.tipo = 'fornecedor'` está com dado sujo em produção — 357 contatos ativos têm esse tipo, mas boa parte claramente não é fornecedor de material de compra (achados de amostra: "1 OFICIAL DE REGISTRO CIVIL", "2 TABELIAO DE PROTESTO DE LETRAS E TITULOS", padaria, posto de gasolina, companhia aérea, assinatura de software, associação de clube). Parece um import em massa de "qualquer contato que a empresa paga", não especificamente fornecedores de compra de material. Efeito prático: o campo "Marca/Fornecedor" do modal "Registrar Pedido de Compra" (`ModalRegistrarCompra.tsx`) sugere esses contatos junto com fornecedores reais — o código em si está correto (`buscar_fornecedores_fuzzy` já filtra por `contato_tipos.tipo = 'fornecedor'` certinho). Usuário decidiu (14/08) só registrar como achado por enquanto, sem reclassificar em massa — decisão de negócio de quais dos 357 remover do tipo `fornecedor` fica pendente.
- [x] P-E2 — **Decidido (2026-08-06)**: o Matheus **vai ter acesso próprio** ao sistema Compras (usuário criado pelo Filippo/Pedro fora desta SPEC, via o cadastro de usuário já existente — SPEC-059). Tanto o Matheus quanto a Débora podem fazer a "Entrada de Nota Fiscal": o Matheus faz a entrada assim que recebe fisicamente, anexando **PDF ou foto/imagem da nota**; a Débora, se for ela quem faz, pega o anexo do e-mail. **Não é um papel/permissão nova no código** — é a mesma tela e o mesmo formulário para os dois, só quem usa que muda. Consequência de código: a Frente E precisa de **upload de arquivo** (PDF ou imagem) anexado ao registro de `notas_fiscais_compra` (campo `arquivo_url`, Supabase Storage).
- [ ] P-E3 — A checagem de impostos do VINI antes da entrada de nota fiscal vai ter algum reflexo no sistema (ex. um status "aguardando checagem de impostos"), ou continua 100% fora do sistema (Teams/e-mail)? Mantido fora de escopo por ora (ver Decisões aprovadas).
- [x] P-F1 — **Decidido (2026-08-06)**: status "Confirmado" **não entra no v1**. Fluxo: `aguardando_aprovar` → `aprovado`/`rejeitado`. O valor `confirmado` pode ficar previsto no `CHECK` do banco para não exigir nova migration se for ativado depois, mas a UI não usa.
- [x] P-F2 — **Decidido (2026-08-06)**: "Solicitações" é **opcional**, coexiste com o "Fechar Pedido em Lote" direto que já existe (SPEC-030/057). Não remove nem esconde o atalho atual.
- [ ] P-H — Cálculo de encargos (IPI/ICMS/ST) por marca no valor total — gap real, mas sem desenho técnico ainda; precisa de uma SPEC própria quando for priorizado.
- [ ] P-geral — As transcrições têm trechos difíceis de interpretar (fala sobreposta, transcrição automática com erros, e a Reunião.03 veio completamente vazia — pode haver conteúdo relevante perdido nela). Se alguma decisão registrada aqui não bater com a intenção real da Débora/Filippo, corrigir esta SPEC antes de implementar essa parte especificamente.

## Decisões da rodada de confirmação (2026-08-06, respondidas pelo usuário)

- Marca no cadastro de fornecedor: **opcional**.
- Status "Confirmado" em Solicitações: **fora do v1**.
- "Solicitações": **opcional**, coexiste com o fluxo direto de pedido em lote.
- Acesso do Matheus: **vai ser criado** (fora desta SPEC); ele e a Débora usam a mesma tela de Entrada de Nota Fiscal, que precisa suportar **upload de PDF/imagem** da nota anexado ao registro.
