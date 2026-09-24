---
titulo: "SPEC-161 — Refinamentos do Controle de Produção e do Controle de Garantia, reunião de 22/09/2026"
status: "RASCUNHO — nenhum item implementado ainda. P1, P3, P4, P5 e P6 já têm decisão do usuário registrada
  abaixo; P2, P7, P8 e a seção de Garantia (P9-P15) só têm causa raiz confirmada, aguardando implementação."
data_ultima_modificacao: 2026-09-23
sistemas_envolvidos:
  - Controle de Produção (`controle-de-producao`, Skip projectId 60535) — P2-P8
  - Controle de Garantia (`controle-de-garantia`, Skip projectId 60545) — P9-P15 (Reunião.03, recebida depois)
fonte:
  - "02-Reunioes/25. Lucenera (Vinicius) - 22.09.2026_reuniões gerais sobre o sistema/Reunião.02.txt"
  - "02-Reunioes/25. Lucenera (Vinicius) - 22.09.2026_reuniões gerais sobre o sistema/Reunião.03.txt"
relacionado:
  - SPEC-156 (criou os dois sistemas, 22/09/2026 mais cedo — este SPEC é continuação/revisão do que já foi
    construído, não um sistema novo)
---

## Contexto

Esta é uma reunião de **revisão ao vivo** dos dois sistemas construídos horas antes na SPEC-156 (Controle de
Produção e Controle de Garantia). `Reunião.02.txt` (136 linhas) é inteira sobre **Produção** (P1-P8 abaixo).
`Reunião.03.txt` — vazia na primeira leitura desta SPEC (0 linhas), recebida depois com 90 linhas — é a
revisão do **Controle de Garantia** (P9-P15 abaixo).

Toda a investigação de causa raiz abaixo foi feita lendo o código **real publicado no Skip** (não o git
local, que pode estar desatualizado — ver [[feedback_skip_deploy_separate_tree]]) e confirmando o schema
real de `producao_pedidos`/`garantia_itens`/`garantia_protocolos` e a definição real da RPC
`garantia_buscar_produtos` no Supabase.

---

## PRIORIDADE 1 — Recuperação/alteração de senha — ❌ DESCARTADO

[00:05]-[00:35]. Antes de começar a revisão, surge um problema real: *"ela chegou a colocar a senha? [...]
ela me mandou assim, ó: criei a conta e não consigo acessar, diz que errei a senha, mas não tem onde ir para
recuperar."* Decisão inicial: *"Vou colocar aqui para ter a recuperação de senha, alterar na realidade,
né?"*

**Decisão final do usuário (2026-09-23)**: *"nenhum dos dois, desconsidere!"* — o caso relatado não era
sobre o Controle de Produção nem o Controle de Garantia. Este item sai do escopo desta SPEC. Não confundir
com SPEC-159/SPEC-160 (essas cobrem "esqueci minha senha"/"alterar senha" só para o Catálogo Ubiqua,
`/perfil` — sistema diferente, sem relação com este achado).

---

## PRIORIDADE 2 — Prioridade do pedido: remover "Alta", manter só Normal/Urgente

[02:44] *"Vou só simular aqui, tá? É, acho que a prioridade alta, acho que eu deixaria só normal e
urgente, tá? Tá, senão vai fazer confusão lá com os meninos."*

**Causa raiz confirmada**: `PrioridadeProducao = 'normal' | 'alta' | 'urgente'` em
`src/services/producao.ts`, usado no formulário de criação, no filtro da listagem (`Producao.tsx`) e no
badge colorido da tabela.

- [ ] Remover `'alta'` do type/enum e de todos os 3 pontos de uso (form, filtro, badge).
- [ ] Confirmar antes de remover: existe algum pedido real já cadastrado com `prioridade = 'alta'`? Se sim,
      decidir o de-para (provavelmente vira `'normal'`) antes de travar a opção — não é motivo pra migration
      complexa, só uma checagem rápida antes de tirar a opção do form.

---

## PRIORIDADE 3 — Anexar múltiplos desenhos por pedido, editável depois de criado

[02:51]-[10:53], o bloco mais longo da reunião. Hoje um pedido pode ter no máximo 1 arquivo de "pedido" e 1
de "desenho". Na prática, um pedido de produção frequentemente representa **vários desenhos** (ex.: *"nessa
solicitação aqui, ó, tem 5 desenhos"*). Testando ao vivo, o Vinícius confirmou o bug: *"coloquei um, aperta,
ele não deixa [adicionar outro] [...] ele tá substituindo"* [08:29-09:33].

**Causa raiz confirmada**: `producao_pedidos.pdf_desenho_url` é uma coluna `text` única — cada upload novo
sobrescreve o anterior, não acumula. Confirmado via `information_schema.columns` no Supabase real (sem
tabela de anexos separada).

**Decisão final do usuário (2026-09-23)**: *"anexar os 6 arquivos!"* — confirma a leitura de [10:28-10:53]
(anexos separados), não um PDF único fundido.

- [x] Confirmado: **anexos separados** (não fundir num PDF único).
- [ ] Nova tabela `producao_pedido_anexos` (produção_pedido_id, url, nome_arquivo, criado_em, criado_por) —
      substitui a coluna única `pdf_desenho_url` por N arquivos por pedido.
- [ ] Permitir anexar/remover arquivos a qualquer momento, não só na criação (ver Prioridade 4 — "editar").
- [ ] Decisão pendente: `pdf_pedido_url` (o pedido em si, distinto dos desenhos) continua sendo 1 arquivo
      único, ou também deveria virar múltiplo? A reunião não deixou isso explícito — só falou de
      "desenhos".

---

## PRIORIDADE 4 — Editar pedido depois de criado

[08:29]-[10:56]. Pedido explícito e repetido: *"Tem que ver. [...] tem que deixar editar [...] às vezes pode
ter uma atualização de desenho e aí ter que tirar um desenho e colocar outro"* [08:29]; *"E deixar editar,
né, tem que poder editar aqui"* [10:56].

**Causa raiz confirmada**: `Producao.tsx` só tem 2 ações por linha — "Status" (`ModalAtualizarStatusProducao`)
e "Handoff" (`ModalHandoffProducao`). Não existe nenhuma ação "Editar" para corrigir cliente, arquiteto,
empresa, prazo, observação ou trocar/adicionar desenhos depois que o pedido já foi criado.

**Decisão final do usuário (2026-09-23)** sobre quem pode editar: *"deve ter uma visualização de que foi
alterado por quem via registro de login com a data"* — ou seja, **sem restrição de quem pode editar**
(qualquer usuário logado pode), mas toda edição precisa ficar registrada (quem editou + quando, via
usuário logado), visível em algum lugar da tela — não é controle de permissão, é trilha de auditoria.

- [ ] Nova ação "Editar" (reaproveitar o formulário de `ModalNovoPedidoProducao` em modo edição) cobrindo
      todos os campos + os anexos da Prioridade 3.
- [x] Confirmado: sem restrição de quem pode editar.
- [ ] Nova coluna/tabela de auditoria: registrar `editado_por` (do login/`auth.uid()`) + `editado_em` a cada
      edição — histórico, não só "última edição" (mesmo espírito do histórico de prazo da Prioridade 8, pode
      valer a pena unificar as duas trilhas num só mecanismo de auditoria genérico do pedido, a avaliar na
      implementação).
- [ ] Exibir essa trilha de forma visível na UI (ex.: junto do histórico de handoffs já expansível na linha).

---

## PRIORIDADE 5 — Handoff: quem pode entregar vs. quem pode receber

[10:56]-[12:50]. Hoje qualquer nome serve nos dois campos do handoff. A regra de negócio real é mais
restrita: *"a gente vai ter 3 pessoas que podem entregar, que é o Manuel, o João e o Cláudio [...] são os 3
que estão na produção. E aí eles podem entregar para mais 5 pessoas, pode até colocar 6 [...] que é o
Mateus e a Vitória, o Alexandre, Leandro Antônio e eu"* [12:07-12:50]. Confirmado também que "recebido por"
é **só interno** — nunca uma pessoa externa [11:44-12:06].

**Causa raiz confirmada**: `ModalHandoffProducao.tsx` usa o **mesmo** `<datalist>` (todos os usuários ativos
de `usuarios`) para os campos "Entregue por" e "Recebido por" — nenhuma distinção entre os dois papéis.

**Decisão final do usuário (2026-09-23)**:
- Sobre FK vs. texto livre: *"não importa por que vou criar o login de cada um quando for usar!"* — o
  usuário vai criar login de verdade para as ~9 pessoas envolvidas antes de usar o sistema. **Usar FK para
  `usuarios`** nos dois campos (não precisa mais do fallback de texto livre pensado na SPEC-156).
- Sobre o nome da seção: *"Andamento interno entregue por / recebido por"* — cabeçalho "**Andamento
  interno**", com os dois campos mantendo os rótulos atuais "Entregue por" / "Recebido por".

- [ ] Restringir "Entregue por" a uma lista fixa de 3 pessoas (Manuel, João, Cláudio), via FK `usuarios`.
- [ ] Restringir "Recebido por" a uma lista fixa de ~6 pessoas (Mateus, Vitória, Alexandre, Leandro, Antônio,
      Vinícius), via FK `usuarios`.
- [x] Confirmado: FK para `usuarios` (não texto livre) — login de cada pessoa será criado antes de usar.
- [x] Confirmado: cabeçalho "Andamento interno", campos "Entregue por" / "Recebido por".
- [ ] Pendência técnica (não de negócio): confirmar que as ~9 pessoas têm de fato login em `usuarios` antes
      de trocar o campo de texto livre pra FK — se algum login ainda não existir no momento de implementar,
      avisar antes de travar a mudança.

---

## PRIORIDADE 6 — Refinar o fluxo de status

[04:51]-[20:15]. Bloco longo de raciocínio ao vivo sobre o fluxo real do chão de fábrica.

**Decisão final do usuário (2026-09-23)**, depois de uma rodada de esclarecimento (a lista inicial dada
tinha ficado confusa sem a etapa inicial e sem indicar que existem ramos alternativos):

1. **Pedido de Produção** — status inicial, grava a data do pedido.
2. A partir daí, o pedido percorre um subconjunto dos status abaixo **com ramos alternativos** (nem todo
   pedido passa por todos — ex.: um pedido de produção interna pode nunca passar por "Produção com
   Terceiro"; um pedido sem pintura pula "Pintura"):
   - **Aguardando Material**
   - **Produção com Terceiro**
   - **Pintura**
   - **Em Montagem**
   - **Embalagem**
3. **Pronto** — status final.

O usuário não detalhou a regra exata de quais ramos se aplicam a qual tipo de peça — fica como
implementação em aberto manter isso como **texto livre com sugestões** (mesmo padrão já usado desde a
SPEC-156, por causa de dado sujo real na planilha original), permitindo que a pessoa escolha o status certo
pro caso concreto em vez de travar transições rígidas.

**Causa raiz confirmada**: `STATUS_SUGESTOES` atual em `producao.ts` é
`em_andamento, aguardando_pintura, com_terceiro, pronto, entrada_parcial, cancelado, excluido` — não bate
com a lista final acima (faltam `pedido_de_producao`, `em_montagem`, `embalagem`; `pintura` e `pronto` já
existem em formato próximo).

- [x] Confirmado: lista final de status com "Pedido de Produção" como inicial, "Pronto" como final, e um
      meio com ramos alternativos (Aguardando Material / Produção com Terceiro / Pintura / Em Montagem /
      Embalagem).
- [ ] Atualizar `STATUS_SUGESTOES`/`STATUS_LABEL` para bater com a lista acima. Manter como texto livre (sem
      `CHECK` no banco).
- [ ] Considerar ordenação especial: pedidos com status "Aguardando Material" aparecem primeiro na
      listagem, independente do filtro atual (ordenado por `data_pedido desc`) — pedido explícito da
      reunião ("é a situação mais crítica", [18:22]-[18:27]), ainda válido.
- [ ] Manter os status legados (`entrada_parcial`, `cancelado`, `excluido`, `aguardando_pintura`) como
      valores válidos (dado histórico real já pode existir com eles), só não oferecê-los mais como sugestão
      padrão pra pedidos novos.

---

## PRIORIDADE 7 — Observação visível na listagem

[13:59]-[14:21]. *"Sabe aquela observação que eu coloquei lá? É fixado na laje, tem que aparecer aqui em
algum lugar também. Sim, senão eles não vão conseguir visualizar a observação."*

**Causa raiz confirmada**: `producao_pedidos.observacao` existe no banco e é preenchível no formulário de
criação (`ModalNovoPedidoProducao`), mas `Producao.tsx` não exibe nenhum indicador dele na tabela — depois
de criado, a observação fica invisível na listagem principal.

- [ ] Ícone/indicador na linha da tabela quando `observacao` não é vazio, expansível (ex.: a mesma seta
      usada hoje pra expandir o histórico de handoffs) mostrando o texto completo.

---

## PRIORIDADE 8 — Rastrear alteração de prazo, com justificativa obrigatória

[22:16]-[22:26], fala longa e detalhada do Vinícius. Cenário: o prazo de entrega foi definido, mas algo
impede o cumprimento (*"deu algum B.O."*) e o prazo precisa ser adiado. Pedido: sempre que `data_prazo`
mudar depois de já ter sido definida, **exigir uma justificativa** (texto livre, ex.: "faltando material"),
e sinalizar visualmente que aquele prazo já foi alterado (*"ter tipo uma exclamaçãozinha aqui dentro de um
triangulozinho [...] vai passar o mouse ou clicar aqui o porquê que foi alterado"*). O próprio Vinícius
identificou que esse padrão **já existe em outro sistema**: *"É a mesma, o mesmo sentido do sistema de
entrega, de separação, garantia, esse tipo de coisa que a gente fez a visualização diferente"* [22:16] —
vale localizar esse componente/padrão já implementado em Logística/Separação antes de desenhar do zero.

**Causa raiz confirmada**: `producao_pedidos` não tem nenhuma coluna nem tabela para histórico de alteração
de `data_prazo` ou motivo — só o valor atual.

- [ ] Nova tabela de histórico (ex.: `producao_pedido_prazo_alteracoes`: producao_pedido_id, prazo_anterior,
      prazo_novo, motivo, alterado_por, alterado_em) — precisa ser histórico (mais de uma alteração possível
      no mesmo pedido), não só "motivo mais recente" numa coluna.
- [ ] Ao editar `data_prazo` (ver Prioridade 4) para um valor diferente do atual, exigir motivo antes de
      salvar.
- [ ] Ícone de alerta na linha da tabela quando existir histórico de alteração, com tooltip/popover
      mostrando o(s) motivo(s).
- [ ] Antes de desenhar do zero: localizar o componente equivalente já usado em Separação/Logística ou
      Garantia (citado pelo próprio Vinícius) e reaproveitar o padrão visual, não reinventar.

---

## Controle de Garantia (Reunião.03.txt, recebida depois — revisão ao vivo do sistema)

Mesmo padrão de layout do Controle de Produção (*"eu usei o mesmo princípio [...] só tem que ver a questão
de fornecedor, produto"*, [00:26]). Toda causa raiz confirmada lendo `controle-de-garantia` (Skip projectId
60545) real + schema de `garantia_itens`/`garantia_protocolos` + definição real da RPC
`garantia_buscar_produtos` no Supabase.

### PRIORIDADE 9 — Motivo: adicionar "Avaria"

[02:39]. *"Pode colocar Avaria também aqui, tá? Avaria, avaria, que é quando teve um problema na entrega,
né? É, ou chegou quebrado, essas coisas."*

**Causa raiz confirmada**: `MotivoGarantia` em `services/garantia.ts` é
`'queimou' | 'sobrecarga_mau_uso' | 'envio_errado' | 'producao_errada' | 'outro'` — sem opção específica
pra dano de transporte/entrega.

- [ ] Adicionar `'avaria'` ao type `MotivoGarantia` + `MOTIVO_LABEL` + lista `MOTIVOS` em
      `ModalNovoItemGarantia.tsx`.

### PRIORIDADE 10 — Desfecho: adicionar "Crédito gerado em despacho" + data do desfecho

[13:35]-[15:35]. Revisando o modal de atualizar protocolo, confirmado que os 6 status do protocolo
**não precisam mudar** (*"aqui não precisa mudar nada, aqui é isso aqui mesmo"*, [13:35]). Mas faltou uma
opção de desfecho: *"Pode botar um aqui, é Crédito gerado em despacho, mais uma nova, mais um novo
status."* [14:45]. E o desfecho precisa de data própria: *"Desfecho é uma data, né? [...] A data aqui, a
data do que aconteceu, de quando aconteceu [...] até de quando criou o protocolo e quando finalizou [...]
para ter um controle de tudo [...] de quanto tempo demora e tal"* [14:55]-[15:29] — ou seja, medir a
duração entre abertura e finalização do protocolo.

**Causa raiz confirmada**:
- `DESFECHO_LABEL`/`DESFECHOS` (em `garantia.ts` e `ModalAtualizarProtocolo.tsx`) só tem
  `peca_nova | conserto | nao_acatado` — falta `credito_gerado_despacho`.
- `finalizarProtocolo()` só grava `status: 'finalizado', desfecho` — nenhuma coluna de data específica do
  desfecho (só existe `updated_at`, genérico, não semântico).

- [x] Confirmado: os 6 status do protocolo (`em_contato_fornecedor` → ... → `material_recebido`) ficam como
      estão, sem mudança.
- [ ] Adicionar `'credito_gerado_despacho'` ao type/label/lista de desfecho.
- [ ] Nova coluna `garantia_protocolos.desfecho_em` (date/timestamptz), preenchida junto com `desfecho` em
      `finalizarProtocolo()` — permite calcular duração (`desfecho_em - created_at`) para relatório futuro.

### PRIORIDADE 11 — Mostrar os itens dentro de um protocolo

[15:35]-[15:41]. *"Seria importante ver o que tá dentro desse protocolo, as peças [...] o que que foi
criado, né? O que que tava dentro desse protocolo? Não aparece, não aparece, não tem nada aqui."*

**Causa raiz confirmada**: `listarProtocolos()` só retorna `itens_count` (contagem via
`garantia_itens(count)`), nunca a lista real dos itens agrupados. `ModalAtualizarProtocolo.tsx` também só
mostra a contagem, sem nenhum jeito de expandir/ver os itens.

- [ ] Nova função `listarItensDoProtocolo(protocoloId)` (reaproveitar `listarItens` com um filtro por
      `garantia_protocolo_id`, hoje inexistente em `ListarItensFiltro`).
- [ ] Exibir a lista de itens dentro do `ModalAtualizarProtocolo` (ou numa linha expansível na tabela de
      protocolos, mesmo padrão do histórico de handoffs em Produção).

### PRIORIDADE 12 — Bug confirmado: nome do produto cadastrado nunca resolve

**Achado técnico (não citado literalmente na reunião, mas é a causa raiz concreta por trás da reclamação
de "a informação da peça" não vir completa, [15:35]-[15:41]).**

**Causa raiz confirmada**: em `listarItens()` (`services/garantia.ts`), o mapeamento faz
`produto_nome_resolvido: d.produto_descricao_livre` — ou seja, **sempre** copia o mesmo valor de
`produto_descricao_livre`, nunca resolve o nome real via `produto_id` (join com `produtos`). Para um item
de garantia vinculado a um produto cadastrado de verdade (`produto_id` preenchido, `produto_descricao_livre`
null porque não é peça avulsa), `produto_nome_resolvido` fica `null` também — a peça aparece em branco ou
como "Peça" genérico em qualquer lugar que dependa desse campo (ex.: `PainelAdiantamentosPendentes.tsx`).

- [ ] Corrigir `listarItens()`: buscar o nome do produto cadastrado via join (`produtos(nome)` no
      `.select()`, já que a query já faz `.from('garantia_itens').select('*, contatos_fornecedor:...')`) e
      usar esse nome real em `produto_nome_resolvido` quando `produto_id` existir; só cair pra
      `produto_descricao_livre` quando for peça avulsa sem cadastro.

### PRIORIDADE 13 — Busca de produto: mostrar "código interno"

[01:35]-[02:39]. *"Pega um produto, eu vou colocar o código interno para a gente, para ficar mais fácil
[...] de repente colocar o código interno aqui, ó, na frente."*

**Causa raiz confirmada**: a RPC `garantia_buscar_produtos` (`SECURITY DEFINER`, lida direto do Supabase)
retorna só `id, nome, sku, referencia` — **sem `codigo_produto`**. `ModalNovoItemGarantia.tsx` também só
exibe `nome` + `sku` no resultado da busca, nunca `referencia` nem um código interno.

- [ ] Alterar a RPC `garantia_buscar_produtos` pra também retornar `codigo_produto`.
- [ ] Atualizar `ProdutoBusca`/`buscarProdutos()` em `garantia.ts` e a exibição em
      `ModalNovoItemGarantia.tsx` pra mostrar o código interno em destaque (o pedido foi "na frente", ou
      seja, antes do nome).

### PRIORIDADE 14 — Busca de produto: UX mais rica (dois cliques, modal de busca)

[02:30]-[02:35]. *"Não sei se tem como dar dois cliques e abrir [...] fazer a mesma, a mesma forma de busca
do orçamento."*

**Causa raiz confirmada**: hoje a busca de produto em `ModalNovoItemGarantia.tsx` é um `<Input>` simples com
uma lista de resultados em texto (nome + sku), bem mais simples que o `ProductSearchModal.tsx` do sistema de
Orçamentos (tabela completa, filtros por marca/categoria, colunas de estoque, ordenação).

- [ ] Avaliar se vale portar o padrão de `ProductSearchModal.tsx` (Orçamentos) pra cá, ou se um ajuste mais
      simples (ex.: melhorar a lista atual com mais colunas) já resolve — não ficou claro na reunião o nível
      de investimento esperado aqui; tratar como melhoria de UX, não bloqueante.

### PRIORIDADE 15 — Bug confirmado: coluna "Criado em" sempre em branco

**Achado ao vivo pelo próprio Vinícius durante o teste** [09:52]-[10:39]: *"Vou pôr aqui um teste [...] A
data não pegou também, criado em, tem que pegar aqui, Pedro."*

**Causa raiz confirmada**: em `pages/Garantia.tsx`, a função `fmtDate()` foi escrita para colunas do tipo
`date` puro (formato `"2026-09-22"`) e faz `new Date(\`${v}T00:00:00\`)`. A coluna `created_at`, porém, é
`timestamptz` (formato completo `"2026-09-22T14:23:11.123456+00:00"`) — concatenar `T00:00:00` nesse valor
já completo gera uma string de data inválida, e `fmtDate` sempre retorna "—" pra essa coluna. Confirmado
comparando o tipo real da coluna (`information_schema.columns`) com o código de `fmtDate`.

- [ ] Corrigir a exibição de `created_at` na aba "Aguardando protocolo" — usar `new Date(v)` diretamente
      (sem concatenar `T00:00:00`) para colunas `timestamptz`, mantendo `fmtDate` (com a concatenação) só
      pra colunas `date` puro como `data_venda_referencia`.

### Pendência de esclarecimento — data "de hoje" num campo não identificado

[08:32]-[08:44]. *"Agora é que não veio, né? Não veio a peça [...] E aqui a data, que acho que teria que vir
a data de hoje, né?"* — dito durante uma demonstração ao vivo, sem eu conseguir ver a tela. Não deu pra
identificar com segurança qual campo é esse (pode ser uma data de abertura do item diferente de "data da
venda", que já existe e já tem fallback manual funcionando). **Não implementar às cegas** — perguntar ao
usuário qual campo específico da tela de "Novo item de garantia" precisava vir com a data de hoje por
padrão.

---

## Pendências de decisão do usuário (não implementar às cegas)

- P1: **resolvido** — descartado, não se aplica a nenhum dos dois sistemas.
- P2 (prioridade "Alta"): confirmar se já existe algum pedido real com `prioridade = 'alta'` antes de
  remover a opção do formulário.
- P3: **resolvido** — anexos separados (6 arquivos), não um PDF único.
- P4 (editar): **resolvido** — sem restrição de quem edita, mas precisa de trilha de auditoria
  (quem + quando).
- P5 (handoff): **resolvido** — FK para `usuarios` (login será criado pra cada pessoa antes de usar);
  cabeçalho "Andamento interno". Só falta confirmar, no momento de implementar, que os logins já existem de
  fato.
- P6 (status): **resolvido** — lista final com "Pedido de Produção" inicial, "Pronto" final, e ramos
  alternativos no meio (Aguardando Material / Produção com Terceiro / Pintura / Em Montagem / Embalagem).
  Regra exata de quais ramos valem pra qual tipo de peça fica como texto livre (implementação, não decisão
  de negócio).
- P8 (alteração de prazo): antes de desenhar do zero, localizar o componente equivalente já usado em
  Separação/Logística (citado pelo próprio Vinícius) e reaproveitar.
- P10 (Garantia — desfecho): nenhuma pendência, decisão registrada acima.
- Garantia — pendência de esclarecimento (ver nota ao final da seção): qual campo exato da tela de "Novo
  item de garantia" deveria vir com a data de hoje por padrão ([08:32]-[08:44]) — não identificado com
  segurança pela transcrição sozinha.

## Critérios de aceite (quando implementado)

**Controle de Produção**
- P2: formulário de novo pedido só oferece Normal/Urgente; pedidos antigos com "Alta" continuam visíveis
  sem quebrar (se existirem).
- P3+P4: um pedido criado com 1 desenho pode receber mais desenhos depois (anexos separados, não um PDF
  fundido), sem duplicar o pedido nem perder os anexos já existentes; toda edição fica registrada (quem +
  quando).
- P5: só as pessoas certas (via login real) aparecem como opção em cada lado do "Andamento interno".
- P6: um pedido novo nasce com o status "Pedido de Produção" e consegue percorrer o fluxo até "Pronto",
  passando só pelos status intermediários que fizerem sentido pro caso (sem forçar todos).
- P7: dá pra saber que um pedido tem observação sem precisar abrir/editar ele.
- P8: mudar o prazo de um pedido já com prazo definido exige motivo, e fica visualmente marcado na listagem.

**Controle de Garantia**
- P9: "Avaria" aparece como opção de motivo ao criar um item.
- P10: "Crédito gerado em despacho" aparece como opção de desfecho; finalizar um protocolo grava a data do
  desfecho, permitindo calcular a duração total do protocolo.
- P11: abrir um protocolo mostra quais itens/peças estão agrupados nele.
- P12: um item de garantia vinculado a um produto cadastrado mostra o nome real do produto em qualquer
  lista (não fica em branco/"Peça").
- P13: a busca de produto no item de garantia mostra o código interno.
- P15: a coluna "Criado em" na aba "Aguardando protocolo" mostra a data real, não mais "—".
