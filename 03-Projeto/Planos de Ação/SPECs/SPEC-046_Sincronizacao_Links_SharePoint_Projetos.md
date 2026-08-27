---
titulo: "SPEC-046 — Sincronização de Links do SharePoint com projetos.link_sharepoint"
status: pendente
data_ultima_modificacao: 2026-07-24
sistemas_envolvidos:
  - CRM (lucenera-crm)
---

# SPEC-046 — Sincronização de Links do SharePoint com `projetos.link_sharepoint`

> Preencher o frontmatter acima antes de escrever o resto. `status` aceita apenas: `não iniciado`, `pendente`, `concluído`.
> Toda vez que a SPEC for editada, atualizar `data_ultima_modificacao`.

## Checklist de Ação

- [x] Item 1 — Script `scripts/sincronizar_links_sharepoint.py`: autentica no Microsoft Graph API (client credentials, app "Lucenera Conexão Sharepoint para Skip", permissão `Files.Read.All` já concedida para a organização), resolve o site do SharePoint pelo `responsavel_nome` do projeto (`PROJETOS<NOME_SEM_ACENTO_SEM_ESPACO>`), lista as pastas da biblioteca de documentos padrão desse site, extrai o código (`\d{2}\.\d{3}`) do início do nome de cada pasta e casa com `projetos.codigo`.
- [x] Item 2 — Regra de não sobrescrever: só grava `link_sharepoint` em projetos onde o campo está vazio; projetos com link já preenchido (manual ou de rodada anterior) são ignorados e listados no relatório.
- [x] Item 3 — Suporte a `--min`/`--max` (faixa de código, obrigatórios) e `--dry-run` (mostra o relatório sem gravar).
- [x] Item 4 — Rodado para todos os projetos com código `26.xxx` (`--min 26.000 --max 26.999`) em 2026-07-24: **140 projetos atualizados** com sucesso, 0 erros de site.
- [ ] Item 5 — Resolver os 15 casos que a rodada geral não conseguiu resolver sozinha (ver "Pendências").

### Passos manuais do usuário

- [x] Criar o app registration no Azure AD / obter Tenant ID, Client ID e Client Secret, e colocar em `.env` (`SHAREPOINT_TENANT_ID`, `SHAREPOINT_CLIENT_ID`, `SHAREPOINT_CLIENT_SECRET`) — feito em 2026-07-24, com 2 tentativas até pegar o **Valor** do segredo certo (a primeira vez copiou o "ID secreto" por engano, formato GUID, que não é o segredo de autenticação).
- [ ] Confirmar no CRM que os 8 links gravados no teste (26.171–26.180, exceto 26.173/26.178) abrem a pasta certa.
- [ ] Decidir o que fazer com 26.173 (link salvo aponta pra Home do site, não pra pasta do projeto — provavelmente colado errado manualmente) e 26.178 (sem `responsavel_nome`, o script não sabe em qual site procurar).
- [ ] Depois de validado, decidir se roda pra todos os projetos de uma vez ou em lotes por faixa de código.

## Objetivo

Os projetos têm uma pasta correspondente no SharePoint (um site por responsável, ex. "PROJETOS MARINA", "PROJETOS THAIRINE"), com nome no padrão `<código> <nome do cliente/projeto>`. Colar esse link manualmente em cada projeto (ver SPEC-045) é trabalho repetitivo. Esta SPEC automatiza o preenchimento inicial (e permite reexecuções pontuais) lendo a estrutura real do SharePoint via Microsoft Graph API e casando pelo código do projeto.

## Decisões aprovadas

- Rodar primeiro num intervalo pequeno de teste (`26.170`–`26.180`) para o usuário conferir manualmente antes de rodar pra todos os projetos.
- Nunca sobrescrever um `link_sharepoint` já preenchido — só completa o que está vazio.
- Site do SharePoint é resolvido pelo campo `projetos.responsavel_nome` (texto livre, já existente — não é FK), não por um cadastro de equipe separado.
- Autenticação via o app "Lucenera Conexão Sharepoint para Skip" já registrado no Azure AD da Lucenera, usando a permissão de aplicativo `Files.Read.All` (Microsoft Graph) já concedida para a organização — não foi necessário pedir nenhuma permissão nova.

## Definição da SPEC

### 1. Como o script decide onde procurar

```
site = "PROJETOS" + responsavel_nome (maiúsculo, sem acento, sem espaço)
```

Ex.: `responsavel_nome = "Thairine"` → site `PROJETOSTHAIRINE` → `https://lucenera.sharepoint.com/sites/PROJETOSTHAIRINE`.

Projetos sem `responsavel_nome` preenchido não têm como ser resolvidos automaticamente (ficam no relatório como pendência manual).

### 2. Como o match é feito

Para cada pasta na raiz da biblioteca de documentos do site (`GET /sites/{siteId}/drive/root/children`), extrai o código do início do nome via regex `^(\d{2}\.\d{3})` e compara com `projetos.codigo` dos projetos daquele responsável, dentro da faixa `--min`/`--max` pedida.

### 3. Resultado do teste inicial (26.170–26.180, 2026-07-24)

- 8 links gravados com sucesso (26.171, 26.172, 26.174, 26.175, 26.176, 26.177, 26.179, 26.180).
- 2 ignorados por já terem link (26.170 — válido; 26.173 — parece link errado, aponta pra Home do site).
- 1 sem responsável cadastrado (26.178).

### Impacto no banco

Só `UPDATE projetos SET link_sharepoint = ... WHERE id = ...` para projetos com o campo vazio. Nenhuma mudança de schema (a coluna já existe desde a SPEC-045).

### Impacto em telas

Nenhuma tela nova — os links aparecem no card "Link do SharePoint" já criado em `ProjectDetail.tsx` (SPEC-045).

### Critérios de aceite

- Rodar o script com `--dry-run` mostra exatamente o que seria alterado, sem gravar nada.
- Rodar sem `--dry-run` grava só os projetos sem link prévio, dentro da faixa pedida.
- Projetos sem `responsavel_nome` ou cujo site não existe/não tem a pasta aparecem no relatório, não travam a execução dos demais.

### Testes/verificações obrigatórias

- Conferir manualmente, no CRM, que os links gravados no teste abrem a pasta certa no SharePoint.
- Antes de rodar pra todos os projetos, revisar quantos projetos não têm `responsavel_nome` (ficarão de fora automaticamente).

## Análise obrigatória de ecossistema

- **Depende de `projetos`, `orcamentos`, `contatos`, `produtos`, `boletos`, `projeto_itens`, `projeto_parcelas`, `usuarios` ou `user_system_access`?** Sim — `projetos` (`codigo`, `nome`, `responsavel_nome`, `link_sharepoint`).
- **A mudança afeta CRM, Orçamentos, Financeiro, Cadastro, Estoque/Compras, Logística ou Hub/TI?** Só o CRM lê `link_sharepoint`. Nenhum outro sistema é afetado.
- **Existe dado duplicado que deveria ser derivado por relacionamento?** Não.
- **Existe migration antiga que contradiz o snapshot central?** Não aplicável — não há migration nesta SPEC (a coluna já existia, SPEC-045).
- **Exige atualização de `AI_DB_CONTEXT.md`?** Sim, ver abaixo.

## Realizado

### 2026-07-24

- Criado `scripts/sincronizar_links_sharepoint.py` (Python, `psycopg2` + `requests`), lendo credenciais do `.env` local (`SHAREPOINT_TENANT_ID`/`SHAREPOINT_CLIENT_ID`/`SHAREPOINT_CLIENT_SECRET`/`SUPABASE_DB_URL`).
- Testado com `--dry-run` no intervalo `26.170`–`26.180`: autenticação falhou 2 vezes por confusão entre "ID secreto" e "Valor" do client secret no Azure (erro `AADSTS7000215`, depois confirmado por formato — o ID secreto é sempre um GUID de 36 caracteres, o Valor não); resolvido depois que o usuário gerou um novo segredo e copiou a coluna certa.
- Rodado sem `--dry-run` no mesmo intervalo: 8 projetos atualizados com sucesso, 2 ignorados (link já existente), 1 sem `responsavel_nome`.
- Usuário aprovou (`--min 26.000 --max 26.999`) rodar para **todos** os projetos com código `26.xxx`, ainda no mesmo dia. Resultado:
  - **140 projetos atualizados** com sucesso.
  - **10 já tinham link** (não sobrescritos): 26.170, 26.171, 26.172, 26.173, 26.174, 26.175, 26.176, 26.177, 26.179, 26.180 — os 8 do teste inicial + 26.170/26.173, que já tinham link manual de antes.
  - **10 com "pasta não encontrada nesse site"** (site resolvido certo, mas nenhuma pasta com aquele código dentro): 26.008 (Agência Blitztur), 26.014 (Sérgio e Andréa Passalacqua - Monte Verde), 26.031 (Camila Strang - Escritório Aluguel), 26.032 (Fazenda Paulo Titoto), 26.046 (João Pedro A.), 26.055 (Apto Sogra - Camila Strang), 26.065 (Manoela Balbo), 26.067 (Patrícia), 26.084 (Joalheria Dudarillo), 26.087 (Juliana e Pedro).
  - **5 sem `responsavel_nome`** (não deu pra saber em qual site procurar): 26.020 (Haras Aroeira - Arena de Laços), 26.030 (Bruno e Alessandra Andrade), 26.100 (Célia e Ferraro), 26.110 (Consultório Patricia Tiemi), 26.178 (Atila Abreu).
  - 0 erros de site — todos os sites "PROJETOS X" referenciados por esses 165 projetos existem e foram lidos sem problema de permissão.

### 2026-07-24 (continuação — lote histórico `11.xxx`–`25.439`)

- Usuário pediu para rodar também todo o histórico abaixo de `26.000` — bem maior do que parecia à primeira vista: **3.431 projetos**, indo até o código `11.002` (não só uma cauda pequena depois do `25.439`).
- `--dry-run` (`--min 11.000 --max 25.439`) revelou:
  - **472 matches** (prontos pra gravar).
  - **1** já tinha link.
  - **295** sem `responsavel_nome`.
  - **2.002** "pasta não encontrada" — normal pra histórico antigo, muitos projetos não têm pasta nesse padrão no SharePoint.
  - **661** erro de site (404) — **sistemático por pessoa**, não aleatório: os sites "PROJETOS\<NOME\>" simplesmente não existem para 11 responsáveis: Bender (122 projetos), Angélica (121, incluindo variação de capitalização "ANGÉLICA"), Ligia (114), Rianne (90), Amanda (67), Filippo (61), Vilber (59), Mary (14), Eduardo (9), Lais (2), Maria (1), João (1). Provavelmente times antigos com site renomeado/arquivado/inexistente, ou nome de site fora do padrão `PROJETOS<NOME>` assumido pelo script.
- Rodado sem `--dry-run`: **472 projetos atualizados** com sucesso, resultado idêntico ao dry-run (nenhuma mudança de estado entre as duas rodadas).
- Total acumulado do dia (todas as rodadas desta SPEC): **620 projetos** com `link_sharepoint` preenchido automaticamente (140 + 8 + 472, descontando sobreposição do lote de teste).

## Pendências

- [ ] Corrigir manualmente o link de 26.173 (aponta pra Home do site, não pra pasta do projeto).
- [ ] Investigar os projetos com "pasta não encontrada" (10 no lote `26.xxx` + 2.002 no lote histórico) — a pasta pode não existir ainda no SharePoint, ter nome fora do padrão, ou estar em subpasta (o script só olha a raiz da biblioteca de documentos, não desce em subpastas). Pra 2.002 projetos, provavelmente não vale a pena investigar um por um — aceitar como limite do histórico.
- [ ] Definir `responsavel_nome` dos projetos sem esse campo (5 no lote `26.xxx` + 295 no histórico) — ou aceitar que fiquem fora da sincronização automática.
- [ ] **Descobrir o nome correto (ou confirmar que não existe mais) dos sites do SharePoint para os 11 responsáveis com erro 404**: Bender, Angélica, Ligia, Rianne, Amanda, Filippo, Vilber, Mary, Eduardo, Lais, Maria, João — juntos, são 661 projetos que ficaram de fora só por causa disso. Se algum desses sites existir com nome diferente do padrão `PROJETOS<NOME>`, dá pra reprocessar só esses depois de mapear o nome certo.
- [ ] Rodar o mesmo script para códigos fora do padrão `XX.XXX` que hoje não são cobertos pela busca por `codigo >= / <=` (ex. `AVULSOS`, `COM-1`...`COM-25+`, `23M236`) — precisaria de lógica de matching diferente, já que esses não tem como casar com pasta nenhuma pelo padrão atual.
- [ ] Avaliar, depois desta rodada, se compensa automatizar a execução periódica (hoje é manual, sob demanda) — ver conversa anterior sobre "sob demanda vs. automático".
- [ ] Atualizar `supabase/AI_DB_CONTEXT.md` do CRM e `supabase/db/domains/crm.md` mencionando esse script e a convenção de nome de site (`PROJETOS<RESPONSAVEL>`).
