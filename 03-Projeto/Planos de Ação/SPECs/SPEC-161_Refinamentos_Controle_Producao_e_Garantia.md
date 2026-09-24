---
titulo: "SPEC-161 — Refinamentos do Controle de Produção e do Controle de Garantia, reunião de 22/09/2026"
status: "CONCLUÍDA e PUBLICADA (24/09/2026) — 7 migrations aplicadas; Controle de Produção (P2-P8) no Skip
  60535 v0.0.9 (submodule d64bcba); Controle de Garantia (P9-P13/P15/P16) no Skip 60545 v0.0.9 (submodule
  1335a36). Pendente: logins da produção (handoff). P1 descartado, P14 não implementado."
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

- [x] Remover `'alta'` do type/enum e de todos os 3 pontos de uso (form, filtro, badge).
- [x] Confirmado antes de remover (23/09/2026, `SELECT prioridade, count(*) FROM producao_pedidos GROUP BY
      prioridade` no Supabase real): nenhum pedido real usa `prioridade = 'alta'` (só `normal`/`urgente`) —
      sem de-para necessário. O `CHECK` do banco continua aceitando `'alta'` por segurança (não removido),
      só a UI não oferece mais a opção.

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
- [x] Nova tabela `producao_pedido_anexos` (producao_pedido_id, url, nome_arquivo, criado_em, criado_por) —
      migration `20260923_160_spec161_producao_garantia_refinamentos/001_producao_pedido_anexos.sql`.
      `pdf_desenho_url` não foi removida (mantida por compatibilidade com desenhos já salvos antes desta
      SPEC, exibida na listagem como "Desenho (antigo)") — anexos novos vão todos pra tabela nova.
- [x] Permitir anexar/remover arquivos a qualquer momento: em modo de edição (`ModalNovoPedidoProducao.tsx`),
      adicionar/remover anexo é imediato (não espera o "Salvar" do resto do formulário).
- [x] Decisão de escopo tomada (não estava resolvida pela SPEC): mantive `pdf_pedido_url` como está — 1
      arquivo único, sem mudança — porque a reunião só pediu múltiplos para "desenhos", nunca mencionou o
      pedido em si. Se o usuário quiser múltiplo também pra `pdf_pedido_url`, é um ajuste futuro pequeno
      (mesmo padrão da tabela de anexos).

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

- [x] Nova ação "Editar" (reaproveitado o formulário de `ModalNovoPedidoProducao` em modo edição, prop
      `pedido`) cobrindo todos os campos + os anexos da Prioridade 3.
- [x] Confirmado: sem restrição de quem pode editar.
- [x] Nova tabela de auditoria `producao_pedido_edicoes` (`editado_por` + `editado_em`), histórico completo —
      migration `002_producao_pedido_edicoes.sql`. Decisão de escopo: mantida **separada** de
      `producao_pedido_prazo_alteracoes` (P8), não unificadas — a de prazo tem uma regra própria (motivo
      obrigatório, prazo_anterior/prazo_novo estruturados) que um mecanismo genérico só complicaria sem
      necessidade real hoje.
- [x] Exibida na UI: novo painel `PedidoDetalhesExpandido.tsx`, que substitui o `HistoricoHandoffsPanel`
      isolado na linha expansível — agora reúne Observação (P7) + Histórico de prazo (P8) + Histórico de
      edições (P4) + Histórico de handoffs (já existia).

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

- [x] Restringir "Entregue por" a uma lista fixa de 3 pessoas (Manuel, João, Cláudio), via FK `usuarios`
      (`ModalHandoffProducao.tsx`, `<Select>` filtrado por nome).
- [x] Restringir "Recebido por" a uma lista fixa de 6 pessoas (Mateus, Vitória, Alexandre, Leandro, Antônio,
      Vinícius), via FK `usuarios`.
- [x] Confirmado: FK para `usuarios` (não texto livre) — login de cada pessoa será criado antes de usar.
- [x] Confirmado: cabeçalho "Andamento interno", campos "Entregue por" / "Recebido por".
- [x] Pendência técnica verificada (23/09/2026, `SELECT id, nome FROM usuarios WHERE nome ILIKE ANY (...)`
      no Supabase real): **só "Vinícius" tem login em `usuarios` hoje** — as outras 8 pessoas (Manuel, João,
      Cláudio, Mateus, Vitória, Alexandre, Leandro, Antônio) ainda não. **AVISO — ação de negócio pendente do
      usuário**: como pedido, implementei os selects restritos por FK sem fallback de texto livre (decisão
      final do usuário), mas isso significa que **"Entregue por" vai aparecer vazio (0 opções) até que os
      logins de Manuel, João e Cláudio sejam criados** — o handoff fica inutilizável até lá. Adicionei um
      aviso em vermelho no próprio modal quando a lista de opções está vazia, mas o Hub precisa criar esses
      logins antes do golden path de handoff funcionar de verdade.

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
- [x] Atualizado `STATUS_SUGESTOES`/`STATUS_LABEL` para bater com a lista acima. Continua texto livre (sem
      `CHECK` no banco). Pedido novo agora nasce com `status = 'pedido_de_producao'` (antes era
      `'em_andamento'` via default da coluna) — setado explicitamente em `criarProducaoPedido()`, sem
      precisar alterar o `DEFAULT` da coluna no banco.
- [x] Ordenação especial implementada: pedidos com status "Aguardando Material" aparecem sempre primeiro na
      listagem (`ordenarComAguardandoMaterialPrimeiro()` em `Producao.tsx`), preservando a ordem relativa
      (`data_pedido desc`) do resto.
- [x] Status legados (`entrada_parcial`, `cancelado`, `excluido`, `aguardando_pintura`, `em_andamento`)
      continuam válidos e com label, só não entram mais em `STATUS_SUGESTOES`.

---

## PRIORIDADE 7 — Observação visível na listagem

[13:59]-[14:21]. *"Sabe aquela observação que eu coloquei lá? É fixado na laje, tem que aparecer aqui em
algum lugar também. Sim, senão eles não vão conseguir visualizar a observação."*

**Causa raiz confirmada**: `producao_pedidos.observacao` existe no banco e é preenchível no formulário de
criação (`ModalNovoPedidoProducao`), mas `Producao.tsx` não exibe nenhum indicador dele na tabela — depois
de criado, a observação fica invisível na listagem principal.

- [x] Ícone (`MessageSquare`, com tooltip mostrando o texto completo ao passar o mouse) na linha da tabela
      quando `observacao` não é vazio, ao lado da seta de expandir; o texto completo também aparece no topo
      do painel expansível (`PedidoDetalhesExpandido.tsx`).

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

- [x] Nova tabela de histórico `producao_pedido_prazo_alteracoes` (producao_pedido_id, prazo_anterior,
      prazo_novo, motivo, alterado_por, alterado_em) — migration `003_producao_pedido_prazo_alteracoes.sql`.
      Histórico completo (mais de uma alteração por pedido).
- [x] Ao editar `data_prazo` pra um valor diferente do carregado, o formulário exige motivo antes de salvar
      (`ModalNovoPedidoProducao.tsx`, campo condicional + validação também em `atualizarProducaoPedido()`
      no service, defesa em profundidade).
- [x] Ícone de alerta (`AlertTriangle`, amber) na coluna Prazo quando existir histórico de alteração, com
      tooltip mostrando quantas vezes mudou; clicar no ícone expande a linha com o motivo de cada alteração.
- [x] Procurei um componente equivalente pronto em Separação/Logística/Garantia (grep por
      `AlertTriangle`/`Tooltip`/`Popover`/"reagendar"/"motivo" nos 3 sistemas) e não achei um componente de
      "histórico de alteração com justificativa" já implementado — o mais próximo é o padrão visual
      já usado no próprio ecossistema (ícone `AlertTriangle` em amber + texto explicativo, visto em
      `PainelAdiantamentosPendentes.tsx` do Garantia). Reaproveitei esse padrão visual (cor/ícone) em vez de
      inventar um novo, mas o componente em si (ícone + tooltip + expandir linha) é novo — não achei nada
      pronto que desse pra importar/reusar diretamente.

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

- [x] Adicionado `'avaria'` ao type `MotivoGarantia` + `MOTIVO_LABEL` + lista `MOTIVOS` em
      `ModalNovoItemGarantia.tsx`. Migration `004_garantia_motivo_avaria.sql` (`DROP`/`ADD CONSTRAINT`
      `garantia_itens_motivo_check`).

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
- [x] Adicionado `'credito_gerado_despacho'` ao type/label/lista de desfecho. Migration
      `005_garantia_desfecho_credito_despacho.sql` (`DROP`/`ADD CONSTRAINT` `garantia_protocolos_desfecho_check`).
- [x] Nova coluna `garantia_protocolos.desfecho_em` — decisão de escopo: usei tipo **`date`** (não
      `timestamptz`), pra ficar consistente com as outras colunas de "data de evento" do mesmo domínio
      (`data_pedido`, `data_prazo`, `data_ficou_pronto`, `peca_antiga_devolvida_em`, todas `date`).
      Preenchida via input de data no `ModalAtualizarProtocolo.tsx` (mesmo padrão de
      `marcarProducaoPedidoPronto`, default hoje mas editável) junto com `desfecho` em `finalizarProtocolo()`
      — permite calcular duração (`desfecho_em - created_at`) pra relatório futuro. Exibida também na
      listagem de protocolos, abaixo do desfecho.

### PRIORIDADE 11 — Mostrar os itens dentro de um protocolo

[15:35]-[15:41]. *"Seria importante ver o que tá dentro desse protocolo, as peças [...] o que que foi
criado, né? O que que tava dentro desse protocolo? Não aparece, não aparece, não tem nada aqui."*

**Causa raiz confirmada**: `listarProtocolos()` só retorna `itens_count` (contagem via
`garantia_itens(count)`), nunca a lista real dos itens agrupados. `ModalAtualizarProtocolo.tsx` também só
mostra a contagem, sem nenhum jeito de expandir/ver os itens.

- [x] Nova função `listarItensDoProtocolo(protocoloId)` (reaproveita `listarItens` com o filtro novo
      `garantiaProtocoloId` em `ListarItensFiltro`).
- [x] Lista de itens exibida dentro do `ModalAtualizarProtocolo` (escolhida a opção "dentro do modal",
      alternativa explicitamente aceita pela SPEC — modal já é aberto ao clicar "Atualizar"/no badge de
      status).

### PRIORIDADE 12 — Bug confirmado: nome do produto cadastrado nunca resolve

**Achado técnico (não citado literalmente na reunião, mas é a causa raiz concreta por trás da reclamação
de "a informação da peça" não vir completa, [15:35]-[15:41]).**

**Causa raiz confirmada**: em `listarItens()` (`services/garantia.ts`), o mapeamento faz
`produto_nome_resolvido: d.produto_descricao_livre` — ou seja, **sempre** copia o mesmo valor de
`produto_descricao_livre`, nunca resolve o nome real via `produto_id` (join com `produtos`). Para um item
de garantia vinculado a um produto cadastrado de verdade (`produto_id` preenchido, `produto_descricao_livre`
null porque não é peça avulsa), `produto_nome_resolvido` fica `null` também — a peça aparece em branco ou
como "Peça" genérico em qualquer lugar que dependa desse campo (ex.: `PainelAdiantamentosPendentes.tsx`).

- [x] Corrigido `listarItens()`. **Decisão técnica tomada na implementação, diferente da sugestão literal da
      SPEC**: em vez de um `.select('*, produtos(nome)')` direto, criei a função `SECURITY DEFINER`
      `garantia_resolver_nomes_produtos(uuid[])` (migration `007_garantia_resolver_nomes_produtos.sql`) e
      resolvo os nomes em lote no service. Motivo: a RLS real de `produtos` (`spec069_produtos_select`)
      exige um papel do Hub que o Garantia não tem — um embed direto (`produtos(nome)`) ficaria em branco
      pra qualquer usuário sem esse papel, reproduzindo o mesmo bug de forma disfarçada (mesma classe de
      problema que a própria migration do `garantia_buscar_produtos` já documentou). `produto_nome_resolvido`
      agora usa o nome real quando `produto_id` existe (com fallback pra `produto_descricao_livre` se o RPC
      não achar nada), e só cai pra `produto_descricao_livre` quando é peça avulsa sem cadastro.

### PRIORIDADE 13 — Busca de produto: mostrar "código interno"

[01:35]-[02:39]. *"Pega um produto, eu vou colocar o código interno para a gente, para ficar mais fácil
[...] de repente colocar o código interno aqui, ó, na frente."*

**Causa raiz confirmada**: a RPC `garantia_buscar_produtos` (`SECURITY DEFINER`, lida direto do Supabase)
retorna só `id, nome, sku, referencia` — **sem `codigo_produto`**. `ModalNovoItemGarantia.tsx` também só
exibe `nome` + `sku` no resultado da busca, nunca `referencia` nem um código interno.

- [x] RPC `garantia_buscar_produtos` alterada pra também retornar `codigo_produto` (migration
      `006_garantia_buscar_produtos_codigo_produto.sql`, com `DROP FUNCTION` explícito antes do
      `CREATE OR REPLACE` — não dá pra mudar `RETURNS TABLE(...)` sem isso). Também passou a buscar por
      `codigo_produto` no filtro de texto (`p_search`), além de nome/sku/referência.
- [x] `ProdutoBusca`/`buscarProdutos()` em `garantia.ts` e a exibição em `ModalNovoItemGarantia.tsx`
      (resultado da busca + card do produto selecionado) mostram `#codigo_produto` antes do nome.

### PRIORIDADE 14 — Busca de produto: UX mais rica (dois cliques, modal de busca)

[02:30]-[02:35]. *"Não sei se tem como dar dois cliques e abrir [...] fazer a mesma, a mesma forma de busca
do orçamento."*

**Causa raiz confirmada**: hoje a busca de produto em `ModalNovoItemGarantia.tsx` é um `<Input>` simples com
uma lista de resultados em texto (nome + sku), bem mais simples que o `ProductSearchModal.tsx` do sistema de
Orçamentos (tabela completa, filtros por marca/categoria, colunas de estoque, ordenação).

- [ ] **Não implementado nesta rodada** (explicitamente marcado como não bloqueante pelo usuário ao pedir a
      implementação da SPEC-161). A busca de produto ganhou uma melhoria pequena de qualquer forma (código
      interno em destaque, Prioridade 13), mas o modal de busca completo estilo `ProductSearchModal.tsx`
      (Orçamentos) não foi portado — fica como melhoria de UX futura, a avaliar se vale o investimento.

### PRIORIDADE 15 — Bug confirmado: coluna "Criado em" sempre em branco

**Achado ao vivo pelo próprio Vinícius durante o teste** [09:52]-[10:39]: *"Vou pôr aqui um teste [...] A
data não pegou também, criado em, tem que pegar aqui, Pedro."*

**Causa raiz confirmada**: em `pages/Garantia.tsx`, a função `fmtDate()` foi escrita para colunas do tipo
`date` puro (formato `"2026-09-22"`) e faz `new Date(\`${v}T00:00:00\`)`. A coluna `created_at`, porém, é
`timestamptz` (formato completo `"2026-09-22T14:23:11.123456+00:00"`) — concatenar `T00:00:00` nesse valor
já completo gera uma string de data inválida, e `fmtDate` sempre retorna "—" pra essa coluna. Confirmado
comparando o tipo real da coluna (`information_schema.columns`) com o código de `fmtDate`.

- [x] Corrigida a exibição de `created_at` na aba "Aguardando protocolo": nova função `fmtDateTime()` em
      `Garantia.tsx` usa `new Date(v)` diretamente (sem concatenar `T00:00:00`), usada só na coluna "Criado
      em". `fmtDate()` (com a concatenação) foi mantida e agora também é usada em `desfecho_em` (coluna
      `date` puro nova da Prioridade 10, exibida na tabela de protocolos) — deixou de ficar sem uso.

### PRIORIDADE 16 — Data da venda: padrão "hoje" quando não dá pra auto-resolver

[08:32]-[08:44]. *"Agora é que não veio, né? Não veio a peça [...] O cliente, beleza, eu não coloquei [...]
E aqui a data, que acho que teria que vir a data de hoje, né?"* — decisão a partir do contexto: no teste ao
vivo, ele não informou cliente (a busca automática de data de venda exige cliente + produto, então não roda
sem isso) e, sem outra fonte pra data, sugeriu que o campo já viesse com a data de hoje como ponto de
partida, em vez de vazio — o único campo de data do formulário de "Novo item de garantia" é "Data da venda".

- [x] `ModalNovoItemGarantia.tsx`: `dataVenda` inicializa com a data de hoje (em vez de string vazia), tanto
      no estado inicial quanto no reset ao fechar/reabrir o modal. "Buscar automaticamente" e a edição manual
      continuam funcionando normalmente por cima desse valor inicial.

---

## Pendências de decisão do usuário (não implementar às cegas)

- P1: **resolvido** — descartado, não se aplica a nenhum dos dois sistemas.
- P2 (prioridade "Alta"): **verificado (23/09/2026)** — nenhum pedido real usa `prioridade = 'alta'`, opção
  removida do form sem de-para necessário.
- P3: **resolvido** — anexos separados (6 arquivos), não um PDF único.
- P4 (editar): **resolvido** — sem restrição de quem edita, mas precisa de trilha de auditoria
  (quem + quando).
- P5 (handoff): **resolvido, com ressalva** — FK para `usuarios` implementada. Verificado (23/09/2026) que
  **só "Vinícius" tem login hoje** — as outras 8 pessoas (Manuel, João, Cláudio, Mateus, Vitória, Alexandre,
  Leandro, Antônio) ainda não. "Entregue por" fica com 0 opções até o Hub criar os logins de Manuel/João/
  Cláudio — ver seção "Realizado" abaixo.
- P6 (status): **resolvido** — lista final com "Pedido de Produção" inicial, "Pronto" final, e ramos
  alternativos no meio (Aguardando Material / Produção com Terceiro / Pintura / Em Montagem / Embalagem).
  Regra exata de quais ramos valem pra qual tipo de peça fica como texto livre (implementação, não decisão
  de negócio).
- P8 (alteração de prazo): componente equivalente pronto não foi encontrado em Separação/Logística/Garantia
  (busca feita na implementação) — reaproveitado só o padrão visual (ícone `AlertTriangle` amber), componente
  em si é novo. Ver seção "Realizado" abaixo.
- P10 (Garantia — desfecho): nenhuma pendência, decisão registrada acima.
- P16 (Garantia — data de hoje): **resolvido** — "Data da venda" inicializa com hoje, segue editável/com
  busca automática por cima.

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

---

## Realizado (2026-09-23, implementador)

Todo o escopo desta SPEC (P2-P13, P15, P16) foi implementado no git local dos dois submódulos. P1
(descartado) e P14 (melhoria de UX opcional) não foram tocados, conforme instrução do usuário.

**Migrations criadas** (redigidas, **NÃO aplicadas no Supabase real** — aplicação é passo manual do
usuário):
`supabase/db/migrations/20260923_160_spec161_producao_garantia_refinamentos/`
1. `001_producao_pedido_anexos.sql` — tabela `producao_pedido_anexos` (P3).
2. `002_producao_pedido_edicoes.sql` — tabela `producao_pedido_edicoes` (P4).
3. `003_producao_pedido_prazo_alteracoes.sql` — tabela `producao_pedido_prazo_alteracoes` (P8).
4. `004_garantia_motivo_avaria.sql` — `'avaria'` no CHECK de `garantia_itens.motivo` (P9).
5. `005_garantia_desfecho_credito_despacho.sql` — `'credito_gerado_despacho'` no CHECK de
   `garantia_protocolos.desfecho` + coluna `desfecho_em date` (P10).
6. `006_garantia_buscar_produtos_codigo_produto.sql` — `DROP FUNCTION` + `CREATE OR REPLACE` de
   `garantia_buscar_produtos` retornando `codigo_produto` (P13).
7. `007_garantia_resolver_nomes_produtos.sql` — nova função `SECURITY DEFINER`
   `garantia_resolver_nomes_produtos(uuid[])` (P12).

**Arquivos alterados/criados** — `04-Sistemas/controle-de-producao/src/`:
`services/producao.ts`, `pages/Producao.tsx`, `components/producao/ModalNovoPedidoProducao.tsx`,
`components/producao/ModalHandoffProducao.tsx`, `components/producao/ModalAtualizarStatusProducao.tsx`,
`components/producao/PedidoDetalhesExpandido.tsx` (novo, substitui o uso direto de
`HistoricoHandoffsPanel.tsx` na linha expansível, que continua existindo e é reaproveitado por dentro).

**Arquivos alterados** — `04-Sistemas/controle-de-garantia/src/`:
`services/garantia.ts`, `pages/Garantia.tsx`, `components/garantia/ModalNovoItemGarantia.tsx`,
`components/garantia/ModalAtualizarProtocolo.tsx`.

**Decisões de escopo tomadas durante a implementação** (dentro do que já estava definido na SPEC, sem
inventar regra de negócio nova — detalhadas também nos itens correspondentes do checklist acima):
- `pdf_pedido_url` mantida como 1 arquivo único (P3 deixou isso como decisão pendente da reunião, não
  resolvida) — só os "desenhos" viraram múltiplos, como a reunião pediu explicitamente.
- `producao_pedido_edicoes` (P4) mantida como tabela separada de `producao_pedido_prazo_alteracoes` (P8),
  não unificadas num mecanismo genérico (a SPEC deixou isso "a avaliar na implementação").
- `garantia_protocolos.desfecho_em` (P10) implementada como `date` (não `timestamptz`), por consistência
  com as outras colunas de data de evento do mesmo domínio.
- P12 corrigido via nova função `SECURITY DEFINER` (`garantia_resolver_nomes_produtos`) em vez do
  `.select('*, produtos(nome))` sugerido literalmente pela SPEC — um embed direto seria bloqueado pela RLS
  real de `produtos` pra usuários sem papel do Hub, reproduzindo o mesmo bug de forma disfarçada.
- P11 implementado dentro do `ModalAtualizarProtocolo` (uma das duas alternativas que a própria SPEC aceitava
  explicitamente), não como linha expansível separada na tabela de protocolos.

**Achado que precisa de ação do usuário antes do golden path funcionar (não é um bug meu, é dado real do
Supabase)**: confirmado em 23/09/2026 via `SELECT id, nome FROM usuarios WHERE nome ILIKE ANY (...)` que só
"Vinícius" tem login em `usuarios` hoje — Manuel, João, Cláudio, Mateus, Vitória, Alexandre, Leandro e
Antônio ainda não têm. Como a Prioridade 5 restringiu os campos de handoff a `<Select>` alimentados por
`usuarios` (sem fallback de texto livre, por decisão explícita do usuário), **"Entregue por" vai aparecer com
0 opções até que os logins de Manuel, João e Cláudio sejam criados** — o registro de handoff fica
inutilizável até lá. Isso é o comportamento esperado pela decisão registrada na SPEC ("vou criar o login de
cada um quando for usar"), só reforçando aqui pra não ser surpresa no teste ao vivo.

**Verificação feita**: `npx oxlint src` e `npx tsc --noEmit -p .` sem erros/warnings novos, e `npx vite build`
concluído com sucesso nos dois sistemas (`controle-de-producao` e `controle-de-garantia`).

**Passos manuais do usuário (pendentes)**:
1. Aplicar as 7 migrations acima no Supabase real (dry-run primeiro, depois commit) — nenhuma foi aplicada
   por mim.
2. Criar os logins de Manuel, João, Cláudio, Mateus, Vitória, Alexandre, Leandro e Antônio em `usuarios`
   antes de usar o handoff do Controle de Produção (ver achado acima).
3. Testar ao vivo no navegador (golden path) os dois sistemas: criar/editar um pedido de produção com
   múltiplos anexos, mudar o prazo com justificativa, registrar handoff (depois dos logins existirem),
   avançar o status de um pedido; criar um item de garantia com motivo "Avaria", montar um protocolo,
   finalizar com "Crédito gerado em despacho" + data, conferir que o nome do produto cadastrado aparece
   certo em toda lista.
4. Publicar no Skip (projectId 60535 / 60545) depois da comparação com a working tree real do Skip, como já
   é o padrão desta sessão.
5. **Rodar o agente `revisor` antes de qualquer commit.**
