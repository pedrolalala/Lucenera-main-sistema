---
titulo: "SPEC-047 — Sincronização Diária Automática: Lista SharePoint → Projetos do CRM + Link do SharePoint"
status: não iniciado
data_ultima_modificacao: 2026-07-24
sistemas_envolvidos:
  - CRM (lucenera-crm)
---

# SPEC-047 — Sincronização Diária Automática: Lista SharePoint → Projetos do CRM + Link do SharePoint

> Preencher o frontmatter acima antes de escrever o resto. `status` aceita apenas: `não iniciado`, `pendente`, `concluído`.
> Toda vez que a SPEC for editada, atualizar `data_ultima_modificacao`.

## Nota sobre origem do código

O sistema **CRM** está registrado como submodule em `04-Sistemas/lucenera-crm-3bd29 (1)/`, mas desatualizado em relação à produção (mesma situação das SPECs anteriores). Implementação (quando aprovada) deve seguir o mesmo caminho: direto no projeto Skip "Lucenera CRM" (`projectId 24580`) para o código da Edge Function, e via Supabase (SQL/migration) para o agendamento do Cron.

## Checklist de Ação

- [ ] Item 1 — Reescrever (ou substituir) a Edge Function `supabase/functions/sync-sharepoint/index.ts`: hoje ela tenta gravar campos (`responsavel`, `arquiteto_responsavel`, `responsavel_obra`, `prazo`, `valor`, `observacoes`) que **não existem** em `projetos` — nunca deve ter rodado com sucesso. Trocar por um mapeamento validado contra o schema real (ver "Definição da SPEC").
- [ ] Item 2 — Trocar a lógica de match de `nome` (frágil, duplica com variação de texto) para `codigo` (chave confiável, já usada nos scripts da SPEC-046).
- [ ] Item 3 — Escopo v1 do import: sincronizar só os campos "seguros" (ver tabela abaixo) — **não** tentar resolver status, arquiteto ou engenheiro automaticamente nesta rodada (ver "Decisões aprovadas" e "Pendências").
- [ ] Item 4 — Incorporar na mesma function a lógica de busca do link do SharePoint (portar de `scripts/sincronizar_links_sharepoint.py`, já testado na SPEC-046: resolve site por `responsavel_nome`, lista pastas, casa por código, preenche só se `link_sharepoint` estiver vazio).
- [ ] Item 5 — Agendar a function para rodar 1x por dia via Cron nativo do Supabase (`pg_cron` + `pg_net` chamando a Edge Function via HTTP, ou o agendador de Edge Functions do Supabase se disponível no plano).
- [ ] Item 6 — Rodar manualmente pelo menos uma vez em ambiente controlado antes de deixar o Cron ativo, comparando o resultado com o que já sabemos ser correto (os 620 links já gravados manualmente pela SPEC-046).

### Passos manuais do usuário

- [ ] Confirmar se as credenciais `SHAREPOINT_TENANT_ID`/`SHAREPOINT_CLIENT_ID`/`SHAREPOINT_CLIENT_SECRET` já configuradas como *secrets* da Edge Function no Supabase estão com o valor certo (mesma pegadinha "ID secreto vs Valor" da SPEC-046 — o `.env` local foi corrigido, mas o secret do lado do Supabase pode não ter sido atualizado do mesmo jeito).
- [ ] Aprovar o escopo v1 (só campos seguros) antes da implementação, ou pedir para eu já resolver status/arquiteto/engenheiro nesta rodada (ver "Pendências").
- [ ] Homologar em ambiente de teste / rodar manualmente antes de ativar o Cron definitivo.

## Objetivo

O CRM tem os dados de projeto que estão no Supabase; a criação real de projetos novos, hoje, acontece na lista "Organização Projetos" do SharePoint (`site LUCENERAPROJETOS345`), de onde nascem as automações existentes (pasta, Planner). Hoje isso não chega ao CRM automaticamente. Esta SPEC cria uma sincronização diária que: (1) importa projetos novos/atualizados dessa lista pro CRM, casando por código; (2) para cada projeto (novo ou existente) sem `link_sharepoint`, busca e preenche o link da pasta correspondente — os dois processos rodando juntos, uma vez por dia, sem intervenção manual.

## Decisões aprovadas

- Agendamento roda **no Supabase** (Edge Function + Cron nativo), não em ferramenta externa — decisão explícita do usuário: "a melhor opção é um agendamento que rode uma vez por dia... isso é algo de vocês de verdade", preferindo a opção mais robusta/self-hosted em vez de depender de uma sessão do Claude Code.
- Match de projeto por **`codigo`**, não por `nome` (a function antiga usava nome; código é mais confiável, mesmo critério já usado nos scripts da SPEC-046).
- **Escopo v1 restrito a campos seguros** — ver tabela na "Definição da SPEC". Status, arquiteto e engenheiro ficam de fora da sincronização automática nesta primeira versão, porque:
  - Os valores de status na lista do SharePoint (`field_10`: "Contrato de Projeto", "Proposta Sinal"...) não batem 1:1 com o enum controlado `projeto_status` do CRM — gravar errado quebraria badge/filtro.
  - Arquiteto/engenheiro no CRM são vínculos por ID (`arquiteto_id`, `responsavel_obra_id` → `contatos`), não texto — resolver isso automaticamente exigiria casar nome por fuzzy-match, com risco real de vincular ao contato errado.
- A busca do link do SharePoint reaproveita a mesma lógica já testada e validada na SPEC-046 (site por responsável, match por código na raiz da biblioteca de documentos).

## Definição da SPEC

### 1. Campos reais da lista "Organização Projetos" (confirmado por leitura direta via Graph API em 2026-07-24)

| Campo na lista (Graph) | Exemplo real | Mapeia pra `projetos` | Incluir no v1? |
|---|---|---|---|
| `field_0` | `26.211` | `codigo` | ✅ sim (chave de match) |
| `Title` | `IVAN SPADONI` | `nome` | ✅ sim |
| `field_9` | `Thairine` | `responsavel_nome` | ✅ sim |
| `field_4` | `RIBEIRÃO PRETO` | `cidade` | ✅ sim |
| `N_x00ed_velEstrat_x00e9_gico` | `"Nível 4"` | `nivel_estrategico` (extrair só o número) | ✅ sim |
| `Arquivado` | `false` | `arquivado` | ✅ sim |
| `field_6` | `2026-07-24T07:00:00Z` | `data_entrada` (a confirmar semântica exata) | ✅ sim, com confirmação |
| `EstadoLookupId` | `1` (ID, não texto) | `estado` | ❌ não no v1 — precisa resolver contra a lista "Estados" à parte |
| `field_10` | `"Contrato de Projeto"` | `status` | ❌ não no v1 — não bate com o enum `projeto_status` do CRM |
| `field_2` | `RAFAEL GRANERO` (texto) | `arquiteto_id` | ❌ não no v1 — precisa casar por nome com `contatos`, risco de erro |
| `Respons_x00e1_veldaObra` | `CAMILA STRANG` / `.` | `responsavel_obra_id` | ❌ não no v1 — mesmo risco acima |

### 2. Por que a `sync-sharepoint` atual não serve como base

O código hoje monta um payload com `responsavel`, `arquiteto_responsavel`, `responsavel_obra`, `prazo`, `valor`, `observacoes` — nenhum desses é coluna real de `projetos`. Um `upsert` com esses campos falharia com erro do PostgREST (coluna desconhecida). Não há evidência de que essa function tenha sido executada com sucesso alguma vez. Será substituída, não só ajustada.

### 3. Fluxo da nova function (proposto)

1. Autentica no Graph (mesmas credenciais já usadas e validadas na SPEC-046).
2. Lê todos os itens da lista "Organização Projetos" (paginado).
3. Para cada item, monta o payload só com os campos do v1 (tabela acima).
4. `UPSERT` em `projetos` casando por `codigo` — cria se não existir, atualiza os campos seguros se já existir (sem sobrescrever status/arquiteto/engenheiro, que não fazem parte do payload).
5. Para cada projeto tocado (novo ou existente) sem `link_sharepoint`, roda a mesma lógica da SPEC-046 (resolve site por `responsavel_nome`, lista pastas, casa por código, preenche).
6. Loga um resumo (quantos criados, atualizados, links preenchidos, erros) — mesmo formato de relatório dos scripts da SPEC-046.

### Impacto no banco

Nenhuma mudança de schema. Apenas `INSERT`/`UPDATE` em `projetos`, escritos por uma Edge Function em vez de manualmente.

### Impacto em telas

Nenhuma tela nova. Projetos criados automaticamente aparecem nas listagens/páginas já existentes do CRM, com status/arquiteto/engenheiro em branco até alguém completar manualmente.

### Regras de permissão

A Edge Function roda com Service Role (mesmo padrão de outras functions administrativas) — não depende de usuário logado. O disparo é via Cron, não via UI, então não há botão exposto a usuários comuns nesta v1 (diferente da `sync-sharepoint` atual, que checava `role === 'admin'` de um usuário chamador).

### Critérios de aceite

- Rodar a function manualmente cria/atualiza projetos corretamente casando por código, sem duplicar.
- Projetos já existentes não têm status/arquiteto/engenheiro apagados ou sobrescritos.
- `link_sharepoint` só é preenchido quando vazio (mesma regra da SPEC-046).
- Cron dispara 1x por dia sem intervenção manual.

### Testes/verificações obrigatórias

- Rodar manualmente uma vez, comparar contra o que já sabemos ser correto (os 620 projetos já linkados na SPEC-046 não devem ser alterados incorretamente).
- Confirmar que um projeto novo criado na lista do SharePoint aparece no CRM no dia seguinte (ou na próxima execução do Cron) com os campos certos.
- Confirmar que os secrets do Supabase (`SHAREPOINT_*`) estão corretos antes de ativar o Cron (ver "Passos manuais do usuário").

## Análise obrigatória de ecossistema

- **Depende de `projetos`, `orcamentos`, `contatos`, `produtos`, `boletos`, `projeto_itens`, `projeto_parcelas`, `usuarios` ou `user_system_access`?** Sim — `projetos` (`codigo`, `nome`, `responsavel_nome`, `cidade`, `nivel_estrategico`, `arquivado`, `data_entrada`, `link_sharepoint`).
- **A mudança afeta CRM, Orçamentos, Financeiro, Cadastro, Estoque/Compras, Logística ou Hub/TI?** Só o CRM. Projetos criados automaticamente ficam visíveis pra outros sistemas que leem `projetos` (ex. Orçamentos), mas isso já é o comportamento normal de qualquer projeto novo — sem mudança de contrato.
- **Existe dado duplicado que deveria ser derivado por relacionamento?** Não — o objetivo é justamente parar de duplicar manualmente (SharePoint → CRM à mão).
- **Existe migration antiga que contradiz o snapshot central?** Não aplicável — sem migration de schema nesta SPEC.
- **Exige atualização de `AI_DB_CONTEXT.md`?** Sim, quando implementada — registrar a nova function/cron e a lista de campos v1 sincronizados.

## Realizado

Nenhuma implementação ainda — esta SPEC registra a decisão e o desenho aprovado (2026-07-24), a partir de uma inspeção real (só leitura) dos campos da lista "Organização Projetos" via Microsoft Graph API.

## Pendências

- [ ] Implementar a Edge Function nova (substituindo `sync-sharepoint`) com o escopo v1.
- [ ] Configurar o Cron no Supabase (`pg_cron`/`pg_net` ou agendador nativo de Edge Functions).
- [ ] Confirmar a semântica exata de `field_6` (Data de Entrada? Prazo?) antes de mapear.
- [ ] Resolver `EstadoLookupId` → texto do estado (consultar a lista "Estados" separadamente) — fora do escopo v1, avaliar numa v2.
- [ ] Decidir se/como resolver `status` (`field_10`) e arquiteto/engenheiro (`field_2`/`Respons_x00e1_veldaObra`) numa v2 — precisa de uma tabela de mapeamento de status aprovada pelo usuário, e uma estratégia seura de casar nome → `contatos.id` (ou aceitar deixar sempre manual).
- [ ] Confirmar se o secret `SHAREPOINT_CLIENT_SECRET` do lado do Supabase (Edge Function) está com o valor certo (não o "ID secreto") — mesma pegadinha corrigida no `.env` local durante a SPEC-046, mas não verificada do lado do Supabase.
- [ ] Atualizar `supabase/AI_DB_CONTEXT.md` do CRM e `supabase/db/domains/crm.md` depois de implementada.
