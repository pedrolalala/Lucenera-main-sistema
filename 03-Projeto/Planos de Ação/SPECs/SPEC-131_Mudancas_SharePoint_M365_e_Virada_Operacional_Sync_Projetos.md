---
titulo: "SPEC-131 — Mudanças no SharePoint / M365 e Virada Operacional da Sincronização de Projetos"
status: pendente
data_ultima_modificacao: 2026-09-11
sistemas_envolvidos:
  - SharePoint / Microsoft 365 (site LUCENERAPROJETOS345, lista "Organização Projetos")
  - Azure AD / Entra ID (app registration usado pela integração)
  - Power Automate (fluxos de automação de pasta / Teams / Planner)
  - Processo operacional (equipe de projetos — "as meninas")
---

# SPEC-131 — Mudanças no SharePoint / M365 e Virada Operacional da Sincronização de Projetos

> Preencher o frontmatter acima antes de escrever o resto. `status` aceita apenas: `não iniciado`, `pendente`, `concluído`.
> Toda vez que a SPEC for editada, atualizar `data_ultima_modificacao`.

## Relação com a SPEC-130

- A **SPEC-130** descreve a integração técnica (Edge Functions, migration, trigger, cron) que faz o sistema e a lista "Organização Projetos" ficarem sincronizados nos dois sentidos.
- **Esta SPEC-131 registra e coordena tudo que a SPEC-130 depende e que acontece fora do nosso código**: mudança de permissão no Azure AD, remoção do controle de código da lista do SharePoint, ajuste/validação dos fluxos de automação, e a virada de processo com a equipe.
- As duas andam juntas. A SPEC-130 não pode ser ligada em produção antes dos itens desta aqui estarem concluídos.

## Checklist de Ação

Quase tudo aqui é executado por terceiros (Alan / Vinícius / equipe). Cada item deve terminar com evidência anexada nesta SPEC (print, export de configuração, e-mail de confirmação).

- [ ] Item 1 — **Documentar o mecanismo atual de geração do código do projeto na lista** "Organização Projetos": é coluna calculada? valor padrão? passo de Power Automate? preenchimento manual por alguém? Anexar print/descrição. (Alan)
- [ ] Item 2 — **Exportar os nomes internos das colunas** da lista: `GET https://graph.microsoft.com/v1.0/sites/{site-id}/lists/{list-id}/columns`. Anexar a saída completa nesta SPEC (vira o mapa oficial de campos da SPEC-130). (Alan)
- [x] Item 3 — **Elevar a permissão do app registration**: nova app **"Lucenera CRM"** registrada (locatário único), permissão **`Sites.Selected` (application)** com **admin consent** concedido, e acesso de **escrita concedido só ao site `LUCENERAPROJETOS345`**. Concluído por Alan em 2026-09-11. **Pendente**: confirmar que os secrets `SHAREPOINT_TENANT_ID`/`SHAREPOINT_CLIENT_ID`/`SHAREPOINT_CLIENT_SECRET` da Edge Function foram atualizados com os valores da app nova (a antiga só tinha leitura).
- [ ] Item 4 — **Validar que a automação (pasta / Teams / Planner) dispara em item criado por app-only** (service principal via Graph). Testar criando 1 item de teste pela API. Se não disparar, ajustar o gatilho do fluxo (condição de disparo / conta de serviço) e registrar o que mudou. (Alan)
- [ ] Item 5 — **Desligar a geração de código na lista** no momento da virada (remover a coluna calculada / o valor padrão / o passo do fluxo identificado no Item 1). A partir daqui o código nasce só no sistema. (Alan)
- [ ] Item 6 — **Definir a lista de campos que a equipe ainda pode editar direto na lista** depois da virada, e quais passam a ser somente leitura / "não editar". (Vinícius)
- [ ] Item 7 — **Levantar os itens órfãos da lista** (projetos que existem só no SharePoint e não no sistema) para o Vinícius decidir caso a caso antes da virada. (gerado pelo script de backfill da SPEC-130)
- [ ] Item 8 — **Definir data/hora da virada, janela de freeze e responsável.** (Vinícius + Alan)
- [ ] Item 9 — **Comunicar e instruir a equipe**: criação de projeto passa a ser 100% pelo sistema; a lista vira consulta + edição só dos campos do Item 6. Material curto de 1 tela. (Vinícius)
- [ ] Item 10 — **Confirmar o valor do secret `SHAREPOINT_CLIENT_SECRET`** no Supabase (Valor do segredo, não o ID — mesma pegadinha das SPEC-046/047). (usuário)

### Passos manuais do usuário

- [ ] Acompanhar com o Alan os itens 1–5 (M365 / Azure AD) e anexar as evidências nesta SPEC.
- [ ] Acompanhar com o Vinícius os itens 6, 8, 9.
- [ ] Executar o item 10 no painel do Supabase.
- [ ] Dar o "ok" da virada só quando itens 1–10 estiverem verdes e a SPEC-130 homologada em projeto de teste.

## Objetivo

Registrar, num lugar rastreável, todas as mudanças de ambiente e de processo necessárias para a sincronização de projetos (SPEC-130) entrar no ar sem quebrar o que já funciona hoje no SharePoint (numeração de projetos, automação de pasta/Teams) e sem pegar a equipe de surpresa.

## Decisões aprovadas

Herdadas da conversa de 2026-09-10:

- **A sincronização é de duas vias** (detalhe técnico na SPEC-130).
- **O código do projeto passa a ser gerado só pelo sistema.** O SharePoint deixa de gerar.
- **A lista "Organização Projetos" continua existindo e visível**, mas deixa de ser ponto de cadastro de projeto novo.
- **O `POST` de criar item via Graph tem que continuar sendo o gatilho** das automações de pasta/Teams/Planner — nada de gravar na lista por outro caminho.
- **Acesso mínimo (reforçado pelo usuário):** vai ser criada uma permissão **só para essa integração/CRM**, com acesso de escrita **exclusivamente à lista "Organização Projetos"** do site `LUCENERAPROJETOS345`. **Nada mais no SharePoint/M365 pode ser alterado.** `Sites.ReadWrite.All` está descartado. Obs. técnica: o Graph concede acesso no nível de **site**, não de lista — então a garantia "só essa planilha" é: (a) a app só enxerga esse 1 site, e (b) a Edge Function só chama o `list-id` dessa lista.

## Definição da SPEC

### 1. Permissão do app — antes e depois

| | Hoje | Depois |
|---|---|---|
| Permissão Graph | `Sites.Read.All` (application) | `Sites.Selected` (application) |
| Alcance de escrita | nenhum | só o site `LUCENERAPROJETOS345`, role `write` |
| Alvo efetivo da integração | — | só a lista "Organização Projetos" (imposto pelo código) |
| Admin consent | concedido p/ leitura | reconceder após a mudança |

`Sites.Selected` exige um passo a mais: além de conceder a permissão no app, o Alan precisa conceder à app o acesso ao site (`POST /sites/{site-id}/permissions`, role `write`). Sem esse segundo passo a app fica sem acesso a nenhum site.

**Limite de granularidade do Graph:** a permissão de aplicação vai até o nível de **site**, não dá para restringir a uma única lista pela permissão. A garantia de "só a planilha 'Organização Projetos'" vem de: (a) a app só ter acesso a esse 1 site, e (b) a Edge Function ter o `list-id` fixo e recusar qualquer outro. Se no futuro esse site passar a hospedar outras listas sensíveis, reavaliar (mover a lista para um site dedicado à integração).

### 2. Controle de código na lista

- **Hoje:** o número do projeto (ex. `26.211`) é controlado dentro da lista "Organização Projetos" (mecanismo a confirmar no Item 1).
- **Depois:** o sistema gera o código (RPC `gerar_codigo_projeto()` da SPEC-130) e envia no `POST`/`PATCH`. A lista não gera mais nada. Projeto criado direto na lista (caso ainda aconteça) chega ao sistema sem código, o sistema gera e devolve por `PATCH`.
- **Risco de janela:** durante a virada, os dois lados não podem gerar código ao mesmo tempo (colisão). Por isso o freeze do Item 8.

### 3. Fluxo de automação (pasta / Teams / Planner)

- Precisa disparar quando o item é criado pela **conta de serviço** (app-only), não só por usuário.
- Se o gatilho atual ("Quando um item é criado") não dispara para app-only, opções: (a) confirmar que dispara e seguir; (b) ajustar a condição de disparo do fluxo; (c) a Edge Function, além de criar o item, aciona o fluxo por outro caminho. **Preferência: (a).**

### 4. Virada operacional

1. Freeze curto: ninguém cria/edita projeto nos dois lados durante a janela.
2. Rodar o backfill da SPEC-130 (casar por código, preencher `sharepoint_item_id`).
3. Tratar os órfãos do Item 7 com o Vinícius.
4. Alan desliga a geração de código na lista (Item 5) e confirma a permissão de escrita (Item 3).
5. Ligar o push e o cron do pull (SPEC-130).
6. Homologar com 1 projeto de teste ponta a ponta.
7. Liberar para a equipe + enviar a instrução do Item 9.

### 5. Critérios de aceite

- A app escreve na lista (`POST` de item retorna **201**) e **não** escreve em nenhum outro site (se `Sites.Selected` bem configurado).
- Item criado via Graph dispara a criação de pasta/Teams como hoje.
- Nenhuma coluna/fluxo da lista gera código automaticamente após a virada.
- Todo mundo da equipe sabe que projeto novo se cria no sistema, com instrução escrita.
- Existe uma data de virada registrada, com responsável.

### 6. Rollback

- Reverter a permissão do app para `Sites.Read.All`.
- Religar a geração de código na lista (restaurar a coluna/fluxo removido no Item 5).
- Desligar push e cron (rollback da SPEC-130).
- Equipe volta ao cadastro manual nos dois lados. Nenhum dado é perdido — só volta o trabalho duplicado.

## Análise obrigatória de ecossistema

- **Depende de `projetos`, `orcamentos`, `contatos`…?** Indiretamente — via SPEC-130. Esta SPEC em si não toca o banco.
- **A mudança afeta CRM, Orçamentos, Financeiro…?** O efeito prático é no **CRM** (passa a ser a única porta de cadastro de projeto). Demais sistemas seguem lendo `projetos` normalmente.
- **Existe migration antiga que contradiz o snapshot?** Não aplicável (sem banco aqui).
- **Exige atualização de doc?** Sim — quando concluída, registrar em `supabase/db/domains/crm.md` / `AI_DB_CONTEXT.md` do CRM que a lista do SharePoint deixou de ser fonte de cadastro e de numeração, e anexar aqui o export de colunas do Item 2.

## Realizado

### 2026-09-11

- Item 3 concluído: app "Lucenera CRM" registrada, `Sites.Selected` com admin consent, escrita concedida só ao site `LUCENERAPROJETOS345` (confirmado por Alan).
- Criada function temporária `supabase/functions/sharepoint-teste-conexao/index.ts` (fora do escopo definitivo da SPEC-130) e secrets `SHAREPOINT_TENANT_ID`/`SHAREPOINT_CLIENT_ID`/`SHAREPOINT_CLIENT_SECRET` atualizados no Supabase (projeto `vcvcwzmbiftcawncibke`) com os valores da app nova.
- **Teste de conectividade real executado com sucesso**: `POST` criou o item `7151` na lista "Organização Projetos" (**201 Created**), `Title` = "TESTE CONEXÃO SPEC-130/131 — NÃO CONSIDERAR", `field_9` = "Mariane" (confirma que `field_9` é o campo de responsável/vendedor). `lastModifiedBy.application.displayName` retornou **"Lucenera CRM"**, confirmando que a escrita foi feita pela app nova com a permissão `Sites.Selected`. Prova que o Item 3 desta SPEC funciona de ponta a ponta.
- **Achado que corrige a SPEC-047/SPEC-130**: `field_6` (que a SPEC-047 supunha ser "Data de Entrada", campo do usuário) veio **preenchido sozinho** pelo SharePoint com a data/hora exata da criação do item, sem ter sido enviado no payload. Indício forte de que é um campo automático de sistema, não um dado editável — a SPEC-130 não deve mapear `data_entrada` pra ele sem confirmar com o Alan.
- **Incidente de segurança**: durante o diagnóstico de um `.env` com chaves duplicadas, um comando de depuração imprimiu por engano o valor completo do client secret desta sessão. Secret tratado como comprometido; **rotação combinada com o usuário, ainda pendente** (ver Pendências).

## Pendências

- [ ] **Rotacionar o client secret da app "Lucenera CRM"** no Azure — o atual foi exposto por engano num comando de diagnóstico nesta sessão (2026-09-11) e deve ser considerado comprometido, mesmo tendo sido usado com sucesso no teste. Depois de gerar o novo, atualizar a linha do `.env` (bloco do CRM) e os secrets no Supabase.
- [ ] Confirmar se a automação de pasta/Teams disparou para o item de teste `7151` (link: `https://lucenera.sharepoint.com/sites/LUCENERAPROJETOS345/Lists/Organizao%20Projetos/7151_.000`). Depende do Alan/usuário.
- [ ] Apagar o item de teste `7151` da lista depois de conferir a automação.
- [ ] Apagar a function temporária `sharepoint-teste-conexao` do Supabase (não faz parte do código definitivo da SPEC-130).
- [x] **`.env` do repo central limpo (2026-09-11)**: renomeado o bloco da Ficha Técnica para `SHAREPOINT_FICHATECNICA_*` (só o nome da chave, valor intacto); `SHAREPOINT_TENANT_ID/CLIENT_ID/CLIENT_SECRET` agora se referem só à app "Lucenera CRM", sem ambiguidade pra scripts novos (ex. `backfill_sharepoint_projetos.py`).
- [ ] Item 1 — mecanismo atual de geração de código na lista "Organização Projetos" não está documentado. Depende do Alan.
- [x] Item 2 (parcial) — nomes de exibição de todas as colunas de negócio obtidos por amostra real em 2026-09-11 (Codigo, Nível Estratégico, Projeto, Responsável, Data Entrada, Status, Arquiteto Responsável, Responsável da Obra, Cidade, Estado, Arquivado — "Tipo de Item" é Content Type de sistema, "Caminho" é path da lista, não é link de pasta por projeto). Falta só a confirmação formal via `GET /lists/{id}/columns` do Alan — não bloqueia mais a SPEC-130.
- [ ] **Nova**: onde mora o link da pasta por projeto (usado pela SPEC-046) — não é a coluna "Caminho". Depende do Alan.
- [ ] Item 6 — lista de campos que a equipe ainda pode editar direto na lista após a virada não está definida. Depende do Vinícius.
- [ ] Item 8 — data/hora da virada, janela de freeze e responsável não definidos. Depende do Vinícius + Alan.
- [ ] Item 9 — material de comunicação/treinamento da equipe não feito. Depende do Vinícius.
- [ ] Item 10 — valor do secret `SHAREPOINT_CLIENT_SECRET` no Supabase não verificado.
- [ ] Confirmar o `displayName` exato da lista — código atual usa "Organização Projetos", a mensagem do Alan citou "Organização de Projetos".
