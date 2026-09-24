---
titulo: "SPEC-161 — Refinamentos do Controle de Produção (e pendência do Controle de Garantia), reunião de 22/09/2026"
status: "RASCUNHO — nenhum item implementado ainda. Baseada em Reunião.02.txt (só Produção); Reunião.03.txt
  (deveria cobrir Garantia) está vazia — ver nota na seção 'Controle de Garantia' abaixo."
data_ultima_modificacao: 2026-09-23
sistemas_envolvidos:
  - Controle de Produção (`controle-de-producao`, Skip projectId 60535) — todas as prioridades
  - Controle de Garantia (`controle-de-garantia`, Skip projectId 60545) — só P1 (senha), resto sem conteúdo novo
fonte:
  - "02-Reunioes/25. Lucenera (Vinicius) - 22.09.2026_reuniões gerais sobre o sistema/Reunião.02.txt"
  - "02-Reunioes/25. Lucenera (Vinicius) - 22.09.2026_reuniões gerais sobre o sistema/Reunião.03.txt" (vazia)
relacionado:
  - SPEC-156 (criou os dois sistemas, 22/09/2026 mais cedo — este SPEC é continuação/revisão do que já foi
    construído, não um sistema novo)
---

## Contexto

Esta é uma reunião de **revisão ao vivo** dos dois sistemas construídos horas antes na SPEC-156 (Controle de
Produção e Controle de Garantia). O Vinícius compartilhou a tela do Controle de Produção e testou o fluxo de
criação/edição de pedidos junto com o Pedro, apontando ajustes. A intenção declarada era revisar **os dois**
sistemas (*"a gente pode ver tanto da produção quanto eu te mandei dois, né? Os dois que você pediu, de
produção e o de garantia"*, [00:47]), e o Vinícius chegou a dizer que precisava fechar a nomenclatura da
Garantia antes de mais nada (*"de garantia, eu preciso que a gente defina a nomenclatura, como que vai ser
usado"*, [00:47]) — mas a transcrição inteira de `Reunião.02.txt` (136 linhas, até [22:51]) é sobre
**Produção**; a Garantia nunca chega a ser discutida em detalhe nesse arquivo. `Reunião.03.txt`, que pelo
contexto deveria conter essa parte, **está vazio** (0 linhas) — provável falha de gravação/salvamento, não
falta de conteúdo. Ver seção "Controle de Garantia" no fim.

Toda a investigação de causa raiz abaixo foi feita lendo o código **real publicado no Skip** (não o git
local, que pode estar desatualizado — ver [[feedback_skip_deploy_separate_tree]]) e confirmando o schema
real de `producao_pedidos` no Supabase.

---

## PRIORIDADE 1 — Recuperação/alteração de senha

[00:05]-[00:35]. Antes de começar a revisão, surge um problema real: *"ela chegou a colocar a senha? [...]
ela me mandou assim, ó: criei a conta e não consigo acessar, diz que errei a senha, mas não tem onde ir para
recuperar."* Decisão: *"Vou colocar aqui para ter a recuperação de senha, alterar na realidade, né?"*

**Causa raiz confirmada**: `controle-de-producao/src/hooks/use-auth.tsx` só expõe `signIn`/`signOut`
(`supabase.auth.signInWithPassword`) — nenhum `resetPasswordForEmail`, nenhuma tela de "esqueci minha
senha", nenhuma tela de trocar senha logado. `Login.tsx` correspondente também não tem link nenhum para
recuperação. Não verifiquei ainda o `controle-de-garantia` linha a linha, mas os dois sistemas nasceram do
mesmo bootstrap (`use-auth.tsx` idêntico, mesma SPEC-156, mesmo dia) — a lacuna deve ser igual nos dois.

**Atenção — não confundir com SPEC-159/SPEC-160**: essas duas SPECs (já existentes, criadas por outra
sessão) cobrem "esqueci minha senha"/"alterar senha" só para o **Catálogo Ubiqua** (`/perfil`), um sistema
totalmente diferente. A memória do projeto já registra que o ecossistema tem **3 padrões diferentes** de
fluxo de senha espalhados — confirmar sempre qual sistema antes de reaproveitar código entre eles.

- [ ] Adicionar "Esqueci minha senha" na tela de Login (`supabase.auth.resetPasswordForEmail`, com
      `redirectTo` apontando pra uma rota nova de "definir nova senha").
- [ ] Tela de definir nova senha (chega pelo link do e-mail de recovery).
- [ ] Aplicar nos dois sistemas (`controle-de-producao` e `controle-de-garantia`) — confirmar antes se o
      caso relatado ("ela") era de um sistema específico ou se afeta os dois igual.

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

**Decisão tomada na reunião** (não fundir os desenhos num PDF único por enquanto): *"vamos fazer assim, por
enquanto a gente faz os 6 arquivos, os 6 desenhos em um arquivo [ambíguo — ver nota]. Eu vou estudar e eu
volto com a resposta amanhã"* [10:15], seguido logo depois por *"não, nem vou usar agora, deixa, vamos
afinar [...] acho que seria mais viável [...] poder anexar separadamente mesmo, tá? Editar, editar e
anexar. Mandou 6 desenhos, 6 anexos."* [10:28-10:53] — a fala final e mais clara do Vinícius foi **anexos
separados**, não um PDF fundido. Mantenho essa como a diretriz, mas o áudio tem uma contradição de poucos
segundos entre as duas falas — vale confirmar antes de implementar.

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

- [ ] Nova ação "Editar" (reaproveitar o formulário de `ModalNovoPedidoProducao` em modo edição) cobrindo
      todos os campos + os anexos da Prioridade 3.
- [ ] Decisão pendente: editar deve ser restrito a certos usuários/papéis? A reunião não fechou isso — só
      disse "não vai ser para todos assim" sobre o campo de status (ver Prioridade 6), não sobre edição
      geral. Confirmar antes de implementar sem controle nenhum.

---

## PRIORIDADE 5 — Handoff: quem pode entregar vs. quem pode receber

[10:56]-[12:50]. Hoje qualquer nome serve nos dois campos do handoff. A regra de negócio real é mais
restrita: *"a gente vai ter 3 pessoas que podem entregar, que é o Manuel, o João e o Cláudio [...] são os 3
que estão na produção. E aí eles podem entregar para mais 5 pessoas, pode até colocar 6 [...] que é o
Mateus e a Vitória, o Alexandre, Leandro Antônio e eu"* [12:07-12:50]. Confirmado também que "recebido por"
é **só interno** — nunca uma pessoa externa [11:44-12:06].

**Causa raiz confirmada**: `ModalHandoffProducao.tsx` usa o **mesmo** `<datalist>` (todos os usuários ativos
de `usuarios`) para os campos "Entregue por" e "Recebido por" — nenhuma distinção entre os dois papéis.

- [ ] Restringir "Entregue por" a uma lista fixa de 3 pessoas (Manuel, João, Cláudio).
- [ ] Restringir "Recebido por" a uma lista fixa de ~6 pessoas (Mateus, Vitória, Alexandre, Leandro, Antônio,
      Vinícius).
- [ ] Mesma pendência já registrada na SPEC-156 e ainda não resolvida: essas listas viram FK pra `usuarios`
      (exige login confirmado para cada pessoa) ou continuam texto livre com uma lista fixa de sugestões?
      Confirmar quais dessas pessoas já têm login antes de decidir.
- [ ] Renomear o cabeçalho dessa seção — hoje não tem nome claro; o próprio Vinícius não decidiu (*"Andamento
      interno, não sei, tá?"* [12:56]) — precisa de confirmação final do nome.

---

## PRIORIDADE 6 — Refinar o fluxo de status

[04:51]-[20:15]. Bloco longo de raciocínio ao vivo sobre o fluxo real do chão de fábrica. Fluxo que emergiu
da conversa, na ordem operacional real (não necessariamente a ordem de exibição — *"a ordem não importa,
né?"* [16:25], mas logo depois *"ou aguardando o material vai estar sempre em primeiro, né? [...] é a
situação mais crítica"* [18:22-18:27], ou seja, **aguardando material deve aparecer primeiro** na
prática):

1. **Pedido de produção** — status inicial, grava a data do pedido.
2. **Aguardando material** — crítico, deveria ordenar em primeiro lugar quando presente.
3. **Em produção** (chamado de "em andamento" em alguns momentos da fala, mas o Vinícius fecha em *"eu
   colocaria então no status, status em produção"* [16:25]).
4. Ramo alternativo para peças sem estoque próprio (ex.: arandela clássica): **produção com terceiro** →
   depois **montagem** (interno, com o Cláudio — ex.: terceiro faz a estrutura, "monta"/coloca o vidro
   internamente) [18:42-19:35].
5. **Finalizado/Pronto** — grava a data que ficou pronto (`data_ficou_pronto`, já existe na tabela).

**Causa raiz confirmada**: `STATUS_SUGESTOES` atual em `producao.ts` é
`em_andamento, aguardando_pintura, com_terceiro, pronto, entrada_parcial, cancelado, excluido` — veio do
dado real da planilha original (SPEC-156), não bate com o fluxo detalhado acima (`aguardando_pintura` é
específico demais; falta `pedido_de_producao` como estado inicial explícito; falta `montagem` como estado
distinto de `com_terceiro`).

- [ ] Atualizar `STATUS_SUGESTOES`/`STATUS_LABEL` para bater com o fluxo acima. Manter como texto livre (sem
      `CHECK` no banco) — mesma decisão já tomada na SPEC-156 por causa de dado sujo real na planilha
      original; a reunião não pediu pra mudar isso, só pediu status melhores.
- [ ] Considerar ordenação especial: pedidos com status "aguardando material" aparecem primeiro na
      listagem, independente do filtro atual (ordenado por `data_pedido desc`).
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

## Controle de Garantia

**Sem conteúdo novo para registrar.** A reunião pretendia cobrir os dois sistemas (Produção e Garantia), e
o Vinícius chegou a dizer que precisava fechar a nomenclatura da Garantia antes de mais nada — mas
`Reunião.03.txt`, que pelo contexto deveria conter essa parte da conversa, está **vazio** (0 linhas,
confirmado via leitura direta do arquivo). Não há evidência de que a conversa sobre Garantia tenha
acontecido de fato nesta sessão gravada, nem de que o conteúdo exista em algum outro lugar.

- [ ] Recomendação: agendar/gravar uma nova sessão de revisão específica do Controle de Garantia antes de
      abrir uma SPEC de refinamento pra ele — não há base real para propor mudanças agora.
- A única exceção é a Prioridade 1 (senha) acima, que provavelmente se aplica aos dois sistemas por
  compartilharem o mesmo bootstrap de autenticação (a ser confirmado lendo `controle-de-garantia` linha a
  linha antes de implementar).

---

## Pendências de decisão do usuário (não implementar às cegas)

- P1 (senha): confirmar se o relato ("ela criou a conta e não conseguiu acessar") era especificamente sobre
  Produção, Garantia, ou indiferente — e se a solução deve sair já nos dois sistemas juntos.
- P3 (anexos múltiplos): resolver a pequena contradição entre "um arquivo com os 6 desenhos" [10:15] e
  "anexar separadamente, 6 anexos" [10:53] antes de implementar — a leitura mais provável é a segunda
  (anexos separados), mas vale uma confirmação de 1 frase antes de desenhar o schema.
- P4 (editar): definir se há alguma restrição de quem pode editar um pedido já criado.
- P5 (handoff): FK pra `usuarios` vs. lista fixa em texto livre — depende de quais dessas ~9 pessoas
  (Manuel, João, Cláudio, Mateus, Vitória, Alexandre, Leandro, Antônio) já têm login confirmado no sistema
  (mesma pendência aberta desde a SPEC-156, nunca resolvida).
- P5: nome final do cabeçalho da seção de handoff (Vinícius não decidiu, só sugeriu "Andamento interno").
- P6 (status): confirmar a lista final de status e se "aguardando material" deve mesmo furar a ordenação
  padrão por data.
- Garantia: aguardando nova sessão de revisão — nada a decidir aqui ainda.

## Critérios de aceite (quando implementado)

- P1: usuário consegue recuperar/trocar senha sem precisar pedir pra alguém redefinir manualmente.
- P2: formulário de novo pedido só oferece Normal/Urgente; pedidos antigos com "Alta" continuam visíveis
  sem quebrar (se existirem).
- P3+P4: um pedido criado com 1 desenho pode receber mais desenhos depois, sem duplicar o pedido nem perder
  os anexos já existentes.
- P5: só as pessoas certas aparecem como opção em cada lado do handoff.
- P6: um pedido novo nasce com o status "Pedido de produção" e consegue percorrer o fluxo completo até
  "Finalizado" (incluindo o ramo de terceiro/montagem quando aplicável).
- P7: dá pra saber que um pedido tem observação sem precisar abrir/editar ele.
- P8: mudar o prazo de um pedido já com prazo definido exige motivo, e fica visualmente marcado na listagem.
