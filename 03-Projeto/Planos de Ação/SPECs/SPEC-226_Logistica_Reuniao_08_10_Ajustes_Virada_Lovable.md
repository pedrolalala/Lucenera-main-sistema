---
titulo: "SPEC-226 — Logística: ajustes da reunião 08/10 (Mari, Matheus, Vini) antes de sair do Lovable"
status: pendente
data_ultima_modificacao: 2026-10-23
sistemas_envolvidos:
  - Sistema de Entregas / Logística (lucenera-logistics-b7cd1 → logistica-lucenera.pages.dev)
  - Banco (separacoes, entregas_finalizadas, separacao_arquivos, enum separacao_status)
  - Movimentação de Peças (SPEC-224) — só referência (tratativa de reserva pela venda)
---

# SPEC-226 — Logística: ajustes da reunião 08/10 antes de sair do Lovable

Fonte: `02-Reunioes/36. Lucenera (Mari Matheus Vini) - 08.10.2026_ Logistica/Reunião.01`.

## Checklist de Ação

**Tela de Separação (Solicitado / Em separação / Separado)**
- [x] A1. Botão **Atualizar** visível na tela (recarrega a lista). **Sem** atualização automática, para não atrapalhar quem está mexendo numa separação.
- [x] A2. Botão **Imprimir** em cada solicitação: imprime só aquele pedido (como o "imprimir" de um e-mail), com solicitante, data/hora do pedido, data/horário da entrega, contato e telefone, quem vai receber, endereço, quantidade de anexos, observação, detalhes da garantia, itens e tipo (entrega / garantia / devolução).
- [x] A3. Observação da garantia (`garantia_detalhes` / `garantia_motivo` / `garantia_peca`) **aparece no card**, sem precisar clicar em Editar.
- [x] A4. Pedido "Em separação" **para de aparecer em todos os dias** até a entrega. Cada pedido aparece **uma vez só, no dia da entrega** (fim do agrupamento `eachDayOfInterval` em `SeparacaoPage.tsx`).
- [x] A5. Busca: incluir **solicitante, número da venda e quem recebe** nos campos da busca que já existe (SPEC-116). Conferir se ela pega Solicitado, Em separação e Separado de uma vez.
- [x] A6. Complexidade escrita por extenso (**Fácil / Médio / Complexo**) junto da bolinha. Hoje ninguém lê a legenda.

**Pedido combinado (uma visita, várias coisas)**
- [x] B1. A mesma solicitação pode ter **até 3 coisas marcadas juntas**: Entrega normal, Entrega de garantia, Retirada de devolução/troca.
- [x] B2. Quando marcar devolução: campo de detalhes e anexo do **orçamento de devolução**, que serve de guia do que retirar na obra. Esse anexo fica em destaque, separado da lista de separação.
- [x] B3. Identificação visual por tipo: **garantia = amarelo**, **devolução = vermelho**, com o nome escrito (etiqueta), não só a cor.

**Recusar solicitação**
- [x] C1. Botão **Recusar** na solicitação, com **motivo obrigatório** (ex.: falta informação, não dá tempo, falta material).
- [x] C2. Ao recusar, abre um **e-mail novo no Outlook já preenchido** (para quem pediu e a gestora da equipe; assunto e corpo com o pedido e o motivo). O Matheus só confere e envia. Mesmo jeito do "Enviar ao fornecedor" do Compras (SPEC-214).
- [x] C3. Pedido recusado sai da fila do Matheus. Quem pediu corrige e **reenvia**, e o pedido volta para "Solicitado". Fica registrado quem recusou, quando e por quê.

**Calendário**
- [x] D1. O calendário mostra **só as entregas do dia** (data da entrega), não o que está em processo.
- [x] D2. Cada dia mostra a **quantidade** de entregas. Clicando no dia, abre a lista daquele dia com a complexidade de cada uma, para saber se ainda cabe mais alguma.

**Dar baixa (Registrar entrega)**
- [x] E1. **"Quem recebeu" começa vazio e é obrigatório.** Não salva sem preencher.
- [x] E2. Ficam os dois registros: **com quem foi combinado** (`responsavel_recebimento`, da solicitação) e **quem recebeu de fato** (`recebido_por`, na baixa). Os dois aparecem nas Finalizadas.
- [x] E3. Conferir se a **data real da entrega** pode ser retroativa (baixa feita no dia seguinte).

**Finalizadas**
- [x] F1. **Zoom** no visualizador dos documentos assinados e fotos (`PhotoGallery.tsx`): aproximar e arrastar para ler a assinatura.
- [x] F2. Botão **Imprimir / Salvar PDF da lista** de finalizadas (com os filtros aplicados).

**Métrica de tempo por etapa**
- [x] G1. Gravar data e hora de cada troca de status: solicitado → em separação → separado → finalizado (e recusado). `data_inicio_separacao` já existe. Faltam "separado em" e "recusado em". O "finalizado em" é a data real da entrega.
- [x] G2. Tela de métricas no Admin: tempo médio de cada etapa por complexidade e por tamanho do pedido (nº de itens), e **antecedência** (tempo entre o pedido e a data de entrega pedida), para mostrar quando a equipe pede em cima da hora.

**Registro de log no Admin (pedido do Pedro em 23/10)**
- [x] I1. A tela **Admin → Logs** (`AdminLogsPage.tsx`) passa a mostrar o registro real. Hoje ela só lista as últimas separações. Colunas: **data/hora, conta (nome + login/e-mail), ação, o quê** (ex.: "Separação 7536 Paula"). Ao clicar numa linha aparece o antes → depois de cada campo alterado.
- [x] I2. Filtros: período, pessoa, tipo de ação (entrou, criou, alterou, mudou status, recusou, deu baixa, apagou, imprimiu) e busca por cliente / venda / nº da entrega. Botão para exportar (imprimir/PDF ou planilha).
- [x] I3. Fonte = auditoria central da SPEC-206 (`auditoria.eventos`), filtrada pelo sistema Logística. **Nada de tabela de log nova**: assim o mesmo registro aparece também na Movimentação da Central.
- [x] I4. Cobrir todas as tabelas do sistema. `separacoes` já é registrada. Faltam triggers em `entregas_finalizadas`, `entregas_pendentes`, `separacao_arquivos` e `separacao_itens`. Em itens, **1 evento por separação** (como em `orcamento_itens`), não 1 por linha. Cada uma ganha um caso em `auditoria.referencia()`.
- [x] I5. **Sem campo de motivo** (decisão do Pedro em 23/10): o registro guarda só **o que foi feito, por quem e a que horas**. Nenhuma tela passa a pedir justificativa por causa do log. O motivo da recusa (C1) continua, porque veio da reunião.
- [x] I6. Ações que não mexem no banco também entram no registro, gravadas por `logistica_registrar_evento` (função nova, para não mexer na assinatura de `auditoria_registrar_acao`): imprimir solicitação, abrir e-mail de recusa, baixar documento assinado. Logins e telas abertas já são registrados (`registro-tela.ts` está no sistema).
- [x] I7. Permissão: **só os Admins do Logística**, na área do Painel Administrativo (decisão do Pedro em 23/10). Gestoras e equipe não veem. Hoje `auditoria_listar` exige admin geral (`is_admin()`), então foi criada uma RPC própria, `logistica_listar_log` (+ `logistica_log_usuarios` e `logistica_eh_admin`), que confere o papel admin em `user_roles_separacao`. O registro é **só leitura**: ninguém edita nem apaga, nem o admin. A retenção de 12 meses é a mesma da SPEC-206.

**Banco**
- [x] H1. Migration (próximo número livre): colunas para B1/B2 (`inclui_devolucao`, `devolucao_detalhes`), C (`recusado_em`, `recusado_por`, `motivo_recusa`), G1 (`separado_em`), valor `recusado` no enum `separacao_status` e rollback.

### Passos manuais do usuário

- [x] Aplicar a migration 241 no Supabase SP (001 sozinho, depois 002).
- [x] Publicar o Logística na Cloudflare (`logistica-lucenera.pages.dev`).
- [ ] Fazer a reunião rápida de validação com Mari/Matheus/equipe **antes** da virada.
- [ ] Definir a data de corte (a partir dela tudo é lançado só no sistema novo) e avisar as equipes.

## Objetivo

Deixar o Sistema de Entregas novo (Cloudflare) com os ajustes pedidos na reunião de 08/10, para a equipe parar de usar a versão do Lovable. Os principais problemas eram: tela poluída (pedido em separação aparecendo todo dia), calendário difícil de entender, observação da garantia escondida, falta de jeito de recusar pedido e falta de medir o tempo da separação.

## Decisões aprovadas (na reunião)

- **Sem atualização automática.** Fica um botão Atualizar (Mari e Matheus preferiram assim; o automático pode atrapalhar uma separação em andamento).
- Pedido aparece **só no dia da entrega**. Quem quiser acompanhar o andamento olha as abas Solicitado / Em separação / Separado. O pedido antigo das meninas/Filipe de "aparecer todo dia" fica revogado.
- Calendário = **só entregas do dia**, com contador e complexidade ao clicar no dia.
- 3 tipos que podem ir juntos na mesma visita: **entrega normal, garantia (amarelo), retirada de devolução (vermelho)**.
- Recusa com motivo e **aviso por e-mail do Outlook aberto já preenchido** (Teams foi citado, mas o combinado foi e-mail).
- Na baixa, **quem recebeu é obrigatório e começa em branco**. Guarda também com quem foi combinado.
- Métrica pelos **cliques de status** (o sistema grava a hora). O Matheus precisa trocar o status assim que a etapa acontece de verdade. Separado e finalizado são métricas diferentes.
- **Não migrar o histórico do Lovable.** O sistema antigo continua no ar só para consulta (finalizadas, PDFs e fotos assinados).
- Virada: **primeiro arrumar, depois reunião rápida de validação com a equipe, depois definir a data**. O "dia 20" citado não foi confirmado.

## Definição da SPEC

### Estado atual (código em `04-Sistemas/lucenera-logistics-b7cd1`)

| Pedido da reunião | Como está hoje no sistema novo |
|---|---|
| Atualizar | Não tem botão; `useSeparacoes` busca uma vez. |
| Imprimir solicitação | Não tem impressão por card. |
| Observação garantia | Campos existem em `separacoes`; card só mostra a borda laranja. `RegistrarEntregaPage` já mostra. |
| Arrasto por dias | `SeparacaoPage.tsx` ~L195 repete o pedido do início da separação até a entrega. **Atenção:** compara `status === 'em_separacao'`, mas o enum é `'Em separação'`, então hoje o arrasto talvez nem rode. Conferir no ar. Mesmo assim a regra sai. |
| Busca | Já existe (SPEC-116): cliente, obra, endereço, responsável, telefone, gestora. Faltam solicitante e nº da venda. |
| Tipos | `tipo_pedido` (normal/garantia) + `inclui_garantia`. Não existe devolução. |
| Recusa | Não existe. O enum `separacao_status` não tem `recusado`. |
| Baixa | `recebido_por` vem preenchido com `responsavel_recebimento` (`RegistrarEntregaPage.tsx` L114). |
| Zoom | `PhotoGallery.tsx` mostra `<img>` sem zoom. |
| Métrica | Só `data_inicio_separacao`. A auditoria (SPEC-206) já registra alterações em `separacoes`, então dá para usar como apoio, mas coluna própria é mais simples para a tela de métricas. |
| Código duplicado | Existem as pastas `components/separacao/` (em uso) e `components/separação/` (velha, sem import). Mexer só na primeira. |

### Fora desta SPEC

- **Tratativa de reserva pela venda** (mover reserva → entrega futura etc., buscando pela venda e não pelo orçamento): já está coberto pelo sistema **Movimentação de Peças (SPEC-224)**.
- Ver o PDF da venda pelo card: vem com o vínculo da venda (`numero_venda`). Se ainda não abrir, entra como item novo.

### Banco (rascunho, para o implementador)

- `separacoes`: `inclui_devolucao boolean default false`, `devolucao_detalhes text`, `separado_em timestamptz`, `recusado_em timestamptz`, `recusado_por uuid`, `motivo_recusa text`.
- `ALTER TYPE separacao_status ADD VALUE 'recusado'` (fora de transação; rollback não remove o valor do enum, só para de usar).
- `separacao_arquivos`: categoria/tipo para "orçamento de devolução", se a tabela já tiver campo de tipo; senão, uma coluna nova.
- Gravação de `separado_em` / `recusado_em`: no update de status do front ou num trigger (o trigger é mais garantido).
- Log (bloco I): sem mudar a estrutura de `auditoria.eventos`. Só triggers novos (I4), casos novos em `auditoria.referencia()` e a RPC `auditoria_listar_logistica`, que = SECURITY DEFINER, `search_path = ''`, confere o admin do Logística e devolve só `sistema = logística`.
- RLS: mesmas políticas atuais de `separacoes`. Conferir como `authenticated` (feedback RLS).

### Permissões

- Recusar: só quem hoje move status (equipe do estoque/Matheus). Confirmar o papel no `user_roles_separacao`.
- Métricas: Admin do sistema.

### Critérios de aceite

1. Pedido em separação com entrega daqui a 5 dias aparece **só** no dia da entrega, nas abas e no calendário.
2. Pedido com garantia mostra o texto da garantia no card e na impressão.
3. Pedido com entrega + garantia + devolução mostra as 3 etiquetas (cores certas) e o anexo do orçamento de devolução.
4. Recusar sem motivo não deixa. Com motivo, abre o Outlook preenchido e o pedido some da fila. O reenvio volta para Solicitado.
5. Baixa sem "quem recebeu" não salva. Finalizadas mostram combinado e recebido.
6. Zoom funciona no celular e no computador.
7. A tela de métricas mostra o tempo de cada etapa de um pedido de teste que passou por todas.
8. Pedido de teste criado → impresso → mudou data → recusado → reenviado → separado → baixa: **cada passo** aparece em Admin → Logs com a conta certa, a hora e o antes/depois.
9. Usuário que não é admin do Logística não vê o registro (testar como `authenticated`, não como dono do banco).

## Realizado

### 2026-10-23

- Código pronto em `04-Sistemas/lucenera-logistics-b7cd1` (build ok, **não commitado, não publicado**). Migration `supabase/db/migrations/20261023_241_spec226_logistica/` (001 enum, 002 resto, rollback). O 002 passou em dry-run com ROLLBACK no banco SP. **Ainda não aplicada.**
- Padrões usados no lugar das perguntas abertas (dá para trocar):
  - e-mail da recusa = procura pelo primeiro nome do solicitante/gestora em `usuarios`; se não achar exatamente 1, o Outlook abre sem destinatário;
  - o recusado é corrigido no **mesmo** pedido (aba Recusados → Corrigir e reenviar → volta para Solicitado);
  - garantia = amarelo e devolução = vermelho, sempre com o nome escrito; complexidade Médio passou a laranja (como já era no calendário);
  - Imprimir/PDF da lista de finalizadas fica no sistema novo.
- Arquivos novos: `src/lib/logistica.ts` (log, arquivos, impressão, e-mail), `RecusarModal.tsx`, `TiposPedidoBadges.tsx`, `pages/admin/AdminMetricasPage.tsx`. `AdminLogsPage.tsx` reescrita.
- **Achados no caminho (corrigidos nesta SPEC):**
  - Botões "Iniciar Separação" e "Voltar" gravavam `em_separacao`, valor que não existe no enum (o certo é `Em separação`). No sistema novo, mudar status para Em separação dava erro.
  - `user_roles_separacao`: os 22 `user_id` eram do banco antigo (nenhum existe em `auth.users`). Só o fallback do Pedro era admin. A migration religa pelo e-mail (19 de 22; ficam fora teste@, teste.entregador@ e Terezinha@, que não têm conta). Backup em `backup._bkp_spec226_user_roles_separacao`.
  - Os buckets `materiais-separacao` e `entregas-fotos` não existiam no Supabase SP (não vieram na virada de 14/10). Anexos e fotos davam erro. Criados na migration (privados, só conta logada).
  - Dar baixa exigia foto mas **nunca enviava nem salvava** as fotos, e "Quem realizou a entrega" também não era gravado. Agora sobe para `entregas-fotos` e grava `fotos_urls` e `entregue_por`.
  - Os detalhes da entrega finalizada não mostravam as fotos. Agora mostram, com zoom.
  - `useSignedUrls` importava `@/integrations/supabase/client`, que não existe (corrigido para `@/lib/supabase/client`).
  - O formulário "Nova Separação" (reescrito pelo Skip em mar/2026) gravava `numero_venda` como lista e `codigo_obra` como número (as colunas são texto), não conferia erro do Supabase e não tinha campo para os detalhes da garantia. Os botões "Digitar itens / Extrair PDF / Colar lista" não faziam nada e foram trocados por anexar arquivos.
  - Anexos guardavam link assinado de 7 dias (vencia). Agora guardam o caminho e o link é gerado ao abrir (os links antigos continuam funcionando).
- `src/lib/supabase/types.ts` atualizado à mão com as colunas novas e o `recusado`.
- **Mesmo dia, mais tarde:** migration 241 **aplicada** no SP (enum, 7 colunas, 2 buckets, 19 permissões religadas, backup com 22 linhas, 6 funções, triggers). Logística commitado (`f282875`) e publicado (push → Cloudflare; bundle novo conferido em `logistica-lucenera.pages.dev`).
- Teste de ponta a ponta no banco real com a conta do Matheus (`authenticated`, transação desfeita no final, nada sobrou). Passou:
  - recusar sem motivo é barrado;
  - a recusa grava quem recusou e o reenvio limpa;
  - as horas de início e de separado são gravadas;
  - a baixa grava combinado, recebido, entregue e fotos;
  - o Registro de log mostra os 10 passos com nome e e-mail;
  - as Métricas calculam;
  - uma conta comum (Adriana) recebe "Apenas administradores";
  - fotos e anexos sobem para os buckets.
- Telas **não** foram abertas no navegador (a extensão do Chrome estava desconectada).

## Pendências

- [ ] Teste visual das telas no navegador (Pedro/Matheus): criar uma solicitação de teste com anexo, imprimir, recusar (abre o Outlook), corrigir e reenviar, separar, dar baixa com foto pelo celular, abrir a foto com zoom, ver Admin → Registro de log e Métricas. Depois apagar a solicitação de teste. O banco já foi testado.
- [ ] Moara (moara@lucenera.com.br) está sem acesso ao Logística na Central: não vê nem cria solicitações. Liberar se ela precisa.
- [ ] `separacao_itens` só aceita gravação de quem tem papel específico em `usuarios.role` (o Matheus não tem). Hoje só a Separação Parcial grava peças, então nada quebra; rever se a digitação de itens voltar.
- [ ] Digitar itens / colar lista / extrair itens do PDF na Nova Separação: o formulário original do Lovable (`components/separação/`, sem uso) tinha essas funções, que se perderam na reescrita do Skip em mar/2026. Hoje a lista só vai como anexo, ou vem pela Separação Parcial (venda). Decidir se volta.
- [ ] Fotos das entregas finalizadas importadas do Lovable apontam para o storage antigo (`lxdaqoqxhyzwqzjpinrj`) e não abrem no sistema novo. Pela decisão da reunião, consultar no Lovable.
- [ ] `systems.link` do slug `logistica` ainda aponta para `https://lucenera.lovable.app/separacao`. Na virada, trocar para `https://logistica-lucenera.pages.dev` (o card da Central abre o que estiver ali).
- [ ] Contas sem login no banco novo: teste@, teste.entregador@ e Terezinha@ continuam em `user_roles_separacao` sem conta. Criar a conta da Terezinha se ela ainda usa.
- [ ] Confirmar se o sistema em uso hoje pela equipe é mesmo o do Lovable e se `logistica-lucenera.pages.dev` ainda não foi liberado para eles.
