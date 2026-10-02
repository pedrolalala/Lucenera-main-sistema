---
titulo: "SPEC-174 — Conferência das entregas de 22/09 a 01/10 e novos pedidos da reunião de revisão de 01/10/2026"
status: concluído
data_ultima_modificacao: 2026-10-02
sistemas_envolvidos:
  - Central / Hub (cards de sistema da Central; o SystemSwitcher não muda) — N1
  - Orçamentos (gestao-financeira-clone-544cb) — N2, N3
  - Compras / Necessidade de Compra (compras-lucenera-3o23t98ee) — N2, N4
  - Cadastro / Consulta de Produto (cadastro-lucenera-b86fe) — N5, N6, N7
  - Estoque (banco: produtos, estoque_itens, movimentações) — N8, N9
  - Controle de Produção / Controle de Garantia — N10, N11
  - Catálogo Ubiqua (catalogo-pecas-ubiqua-e6fa0) — N12 (já coberto pela SPEC-172)
dependencias:
  - SPEC-158 (correções da reunião de 22/09 — base da conferência)
  - SPEC-161 / SPEC-162 / SPEC-163 (Produção e Garantia)
  - SPEC-166 (busca na Necessidade de Compra)
  - SPEC-167 (Previsão de Entrega no orçamento)
  - SPEC-120 (menu lateral SystemSwitcher)
  - SPEC-095 (validade padrão de 10 dias)
  - SPEC-171 / SPEC-172 (Catálogo Ubiqua)
---

# SPEC-174 — Conferência das entregas de 22/09 a 01/10 + novos pedidos da reunião de 01/10/2026

> Origem: `02-Reunioes/26. Lucenera (Vinicius) - 01.10.2026_Reunião revisão do sistema/Reunião.01.txt`.
> Reunião de revisão com o Vinícius, em que ele conferiu tela a tela o que tinha sido pedido em 22/09
> (SPEC-158 e seguintes) e levantou pedidos novos. Esta SPEC tem duas partes:
> **Parte A**: o que mudou no sistema entre 22/09 e 01/10 e o que foi conferido na reunião.
> **Parte B**: o que precisa ser feito a partir da reunião.

## Checklist de Ação

### Parte B — implementação (marcar conforme for feito)

- [x] N1 — Central (Hub): card de sistema abre em **nova aba**; o menu lateral continua na mesma aba (publicado 01/10)
- [x] N2a — Orçamentos: pop-up obrigatório de **Previsão de Entrega** na aprovação da equipe (publicado 02/10)
- [x] N2b — Compras: mostrar a previsão de entrega do cliente na Necessidade de Compra / rastreio do produto (publicado 01/10)
- [x] N3 — Orçamentos: aviso de orçamento vencido (validade de 10 dias) oferecendo atualizar os preços (publicado 02/10)
- [x] N4 — Necessidade de Compra: busca igual à do orçamento (código interno → referência → nome, vários termos) (publicado 01/10)
- [x] N5 — Consulta de Produto: destaque mais forte da linha/card selecionado (publicado 02/10)
- [x] N6a — Editar produto: botão **Salvar cortado** (bug) (publicado 02/10)
- [x] N6b — Estoque integrado: setores na **vertical**, com todos os setores do produto (publicado 02/10)
- [x] N7 — Permissões por ação na Consulta de Produto (todos consultam, só alguns editam) — via Hub (publicado 02/10; matriz final com o Vinícius)
- [x] N8 — Estoque **Casa Cor**/Garantia como setor separado, fora do estoque geral (publicado 02/10; carga da planilha pendente)
- [x] N9 — Estoque **por empresa** nos bastidores — levantamento feito na SPEC-175 (implementação depende de decisão)
- [x] N10 — Aba Log só admin no Controle de Produção e no Controle de Garantia (publicado 02/10)
- [x] N11 — Status do Controle de Produção selecionável (Select real) (publicado 02/10)

### Passos manuais do usuário

- [ ] Pedir ao Mateus o e-mail de todo mundo para criar os logins do Controle de Produção e da Garantia.
- [ ] Pedir ao Sérgio 3 planilhas de estoque, uma por empresa (Manoela, Foco, ISLIGHT), para o balanço inicial do N9.
- [ ] Levantar a planilha de controle de Casa Cor (hoje no Excel do Matheus) para carregar no N8.
- [ ] Ligação com o Vinícius (02/10 à tarde) para mostrar a matriz de permissões do Hub (N7) e conferir o Controle de Garantia, que não foi visto na reunião.
- [ ] Limpar as vendas de teste usadas na reunião (o Vinícius perguntou; ainda não foram limpas).

## Objetivo

Registrar o resultado da conferência que o Vinícius fez em 01/10 sobre tudo que foi entregue desde a reunião
de 22/09, para que os itens OK não sejam reabertos, e transformar os pedidos novos da reunião em uma lista
de trabalho com prioridade e grau de definição.

## Decisões aprovadas (na reunião de 01/10)

- **Nova aba por sistema**: o Vinícius pediu, o Pedro aceitou. Clicar em um sistema na Central abre outra aba;
  dentro da mesma aba, o menu lateral continua navegando na própria aba.
- **Previsão de Entrega obrigatória na aprovação da equipe**: toda vez que o orçamento for salvo/aprovado
  na etapa de aprovação da equipe, abre um pop-up pedindo a data prevista de entrega, obrigatória, no mesmo
  estilo do "digite APROVAR" da Aprovação Financeira. Motivo: hoje a data é preenchida quando o orçamento
  é criado e não é atualizada quando o cliente fecha meses depois (exemplo da reunião: venda 5750, fechada
  em 25/09 com previsão de 29/09).
- **Financeiro aprova no mesmo dia**, no máximo no dia seguinte. Por isso basta pedir a data na aprovação da
  equipe; não é preciso pedir de novo na aprovação financeira.
- **Busca da Necessidade de Compra = busca do orçamento**: prioridade código interno, depois referência,
  depois nome/descrição, aceitando vários termos ("arandela stella", "aros 4427").
- **Casa Cor e Garantia não somam no estoque geral**: ficam visíveis, mas fora do disponível. Para vender
  peça de Casa Cor: transferir para o estoque geral (ou reservar direto do Casa Cor) e dar o abatimento pelo
  **desconto** do orçamento, sem campo novo de preço.
- **Estoque geral = reserva + separação + disponível**; disponível pode ficar negativo (vendido sem ter a peça)
  e o sistema **não pode bloquear** a venda por isso.
- **Estoque por empresa só nos bastidores**: a tela continua mostrando a soma; o banco registra entrada e
  saída pela empresa da nota. Venda acima do estoque da empresa **não é bloqueada**.
- **Cores**: código e referência em preto (SPEC-158 P2.5) aprovados; manter, só deixar mais forte o destaque
  do item selecionado.

### Decisões do usuário em 01/10 (depois da reunião)

- **N3:** aviso ao abrir/editar ou aprovar orçamento vencido: "deseja atualizar os preços?". Sim = preço de
  venda atual do cadastro, mantendo descontos; Não = segue com os preços antigos.
- **N8:** setor separado. 'Estoque Casa Cor' e 'Estoque Garantia' aparecem na consulta, mas não entram no
  estoque geral nem no disponível. Venda = transferir para o geral + desconto no orçamento.
- **N10:** aba Log só para administrador, no Controle de Produção e no Controle de Garantia.
- **N11:** o problema é que os status não aparecem para selecionar, só na descrição (legenda) dos status.
- **N2a:** segue como implementado (gravação da data + RPC de aprovação em dois passos); deixar a versão
  atômica (RPC única) como melhoria futura.
- **N9:** vira SPEC própria (SPEC-175).

## Definição da SPEC

### Parte A — Conferência do que mudou de 22/09 a 01/10

Legenda: ✅ conferido OK na reunião · ⚠️ conferido, com ajuste pedido (vira item da Parte B) ·
⬜ entregue mas **não conferido** na reunião.

| SPEC / item | O que mudou | Sistema | Conferência 01/10 |
|---|---|---|---|
| SPEC-158 P1.1 | Editar orçamento em Aprovação Financeira não volta mais para o cliente | Orçamentos | ✅ "isso de não voltar resolveu" |
| SPEC-158 P1.2/P1.3/P1.4 | Margem do Gerenciamento com desconto por item; coluna de desconto editável | Orçamentos | ⬜ |
| SPEC-158 P2.1 | Rótulo "Responsável Obra" → "Engenheiro" | Orçamentos | ✅ |
| SPEC-158 P2.2 | Modal "Adicionar item sem cadastro" reduzido (referência, nome, marca, preço) | Orçamentos | ✅ "bem melhor" |
| SPEC-158 P2.3 | Digitador do orçamento gravado pelo login | Orçamentos | ⬜ |
| SPEC-158 P2.4 | Botão Salvar também no rodapé | Orçamentos | ⬜ |
| SPEC-158 P2.5 | Código e referência em preto na consulta de peças | Cadastro | ⚠️ aprovado; pediu destaque mais forte do selecionado (N5) |
| SPEC-158 P3.1 | Copiar produto (Excluir / Copiar / Salvar) | Cadastro | ⚠️ funciona; botão Salvar aparece cortado (N6a) |
| "+" do código de projeto | Botão de criar projeto ao lado do código, no orçamento | Orçamentos | ✅ |
| SPEC-159 / SPEC-160 | Alterar senha e "esqueci minha senha" no Catálogo Ubiqua | Catálogo Ubiqua | ⬜ |
| SPEC-161 / SPEC-162 | Refinamentos de Produção + ocorrências (fotos, tipo livre, resolvida com data, autor e hora) | Controle de Produção | ✅ "ficou da hora"; ⚠️ status "pedido de produção" (N11) |
| SPEC-161 | Refinamentos do Controle de Garantia | Controle de Garantia | ⬜ "depois eu olho o da garantia" |
| SPEC-163 | Produção e Garantia acessíveis pela Central | Hub | ✅ |
| SPEC-164 (PDF) / SPEC-136 | PDF aprovado e venda com número próprio, separado do orçamento | Orçamentos / Vendas | ✅ gerou a venda; "depois vamos testar de novo" |
| SPEC-164 / SPEC-165 (Memória) | Memória Lucenera como base corporativa + importação de reuniões | Memória Lucenera | ⬜ |
| SPEC-165 (Adm. Bancária) | CNAB 400 remessa/retorno, duplicatas, JSON da NF-e | Adm. Bancária / Vendas | ⬜ |
| SPEC-165 (Showroom) | /admin acha toda peça da vitrine | Showroom | ⬜ |
| SPEC-166 | Coluna e busca por referência na Necessidade de Compra | Compras | ⚠️ busca pelo código 7947 funcionou; pediu a mesma busca do orçamento (N4) |
| SPEC-167 | Campo Previsão de Entrega no orçamento | Orçamentos | ⚠️ existe; pediu pop-up obrigatório e levar a data até Compras (N2) |
| SPEC-168 a SPEC-172 | Catálogo Ubiqua: fotos de variantes, cadastro sem confirmação, Sair/Excluir conta, estoque atual dividido entre empresas, desconto %, PDF, cliente completo | Catálogo Ubiqua | ✅ "o resto tá tudo como você pediu"; falta e-mail com PDF anexo (N12) |
| SPEC-173 | Contatos com tipo "construtora" e origem PROSPECCAO_SAO_PAULO | CRM / Cadastro | ⬜ |
| Sync Connect 29/09 | Recarga a partir da planilha do Sérgio (SPEC-157), conferência R$ 0,00 | Banco | ⬜ |

**Itens ⬜**: continuam entregues e publicados conforme as respectivas SPECs. Ficam para conferir com o
Vinícius na próxima conversa; esta SPEC não os reabre.

### Parte B — Novos pedidos

#### N1 — Cards da Central abrem o sistema em nova aba — DEFINIDO

[04:01]-[07:33]. Hoje, ao clicar no card de um sistema dentro da Central (Hub), a própria aba aberta se
transforma no sistema clicado. O Vinícius trabalha com 3 ou 4 abas abertas (ex.: Logística aberta o dia
todo) e hoje precisa duplicar a aba do navegador na mão para não perder a Central. Este é o "dupliquei" de
[07:33] (confirmado pelo usuário em 01/10): era sobre duplicar a aba do navegador, não sobre duplicar orçamento.

Regra (esclarecida pelo usuário em 01/10):

| Onde clica | Comportamento |
|---|---|
| Card de sistema **dentro da Central** | Abre em **nova aba** do navegador (`target="_blank"` + `rel="noopener"`); a Central continua aberta na aba de origem |
| **Menu lateral** (SystemSwitcher, SPEC-120) para ir a outro sistema | **Continua na mesma aba**, como hoje; não muda |

- Só muda o Hub (cards da Central). O SystemSwitcher replicado nos ~10 sistemas **não é alterado**.
- Sugestão do Vinícius, **não decidida**: renomear "Central" para "Painel principal". Confirmar antes de mudar.
- Aceite: na Central, clicar em "Orçamentos" abre uma aba nova e a Central continua na aba de origem; dentro
  do Orçamentos, escolher "Compras" no menu lateral troca a própria aba, sem abrir outra.

#### N2 — Previsão de Entrega obrigatória e visível em Compras — DEFINIDO

[07:13]-[26:31].

- **N2a — Pop-up na aprovação da equipe (Orçamentos).** Na ação que leva o orçamento da aprovação da equipe
  para a próxima etapa (confirmar o nome exato do status no `handle_orcamento_workflow`), abrir um modal
  obrigatório com o campo **Previsão de Entrega**, já preenchido com o valor atual (SPEC-167) mas exigindo
  confirmação/alteração. Sem data, não avança. Vale também para **toda nova gravação** nessa etapa ("alterou,
  pede a data").
  - Validação: a data não pode ser anterior à data da aprovação.
  - Banco: sem coluna nova (usa o campo da SPEC-167). Avaliar se vale registrar a data confirmada em
    `historico_status_orcamentos` para auditoria.
- **N2b — Levar a data até Compras.** Na Necessidade de Compra, ao abrir o produto (detalhe/rastreio das
  vendas que geram a necessidade), mostrar a **previsão de entrega de cada venda**. Uso: o Vinícius segura a
  compra para negociar volume (exemplo: Interlight, embutido de solo, 195 negativo, 7% de desconto a mais) e
  precisa saber até quando pode esperar.
  - Verificar as views `vw_necessidade_compra*` e acrescentar a previsão da venda de origem (via
    `orcamentos`), sem mudar a granularidade de 1 linha por produto (decisão de 08/06 reafirmada na SPEC-039).

#### N3 — Validade de 10 dias e atualização de preço — PRECISA DE DEFINIÇÃO

[21:36]-[24:57]. Já existe: validade padrão = emissão + 10 dias (SPEC-095), e o PDF já imprime
"Este orçamento tem validade até DD/MM/AAAA" (`generate-report`, observação 1).

Pedido novo: quando o orçamento passar da validade (10 dias), o sistema deve oferecer **atualizar os
preços** (custo, margem e impostos podem ter mudado). O aviso "deseja atualizar o orçamento?" que apareceu na
reunião é do sistema do Sérgio; no Orçamentos não existe nada parecido (busca no código feita em 01/10).

Perguntas abertas (responder antes de implementar):
1. Quando o aviso aparece: ao abrir o orçamento vencido para editar? Ao tentar aprovar?
2. "Atualizar" = substituir `preco_unitario` dos itens pelo `valor_venda` atual de `produtos`, mantendo os
   descontos?
3. Pode recusar e manter os preços antigos? Quem pode?
4. Conferir com o Vinícius se a observação da validade no PDF está visível o suficiente ("tem que deixar
   explícito").

#### N4 — Busca da Necessidade de Compra igual à do orçamento — DEFINIDO

[09:08]-[13:21]. Hoje (SPEC-166) a busca casa código exato (se o termo for número), nome e referência, mas
o Vinícius não conseguiu achar alguns itens. Na própria reunião, o código 7947 funcionou; os testes que
falharam podem ter sido de produtos sem necessidade em aberto. Mesmo assim, ele pediu explicitamente:

- Reaproveitar a regra de busca do orçamento (SPEC-100/SPEC-116: vários termos, todos precisam casar em
  código, referência, nome ou marca).
- Ordenação por relevância: **código interno exato primeiro**, depois referência, depois nome/descrição.
- Aceite: "arandela stella", "aros 4427", "7947" e uma referência (ex.: `LUC55-BR`) trazem o resultado
  esperado, comparado com a mesma busca no orçamento.

#### N5 — Destaque do item selecionado na Consulta de Produto — DEFINIDO

[27:57]-[29:18]. Ao clicar num produto da lista, a linha fica amarelada para indicar de qual item são os
dados à direita. No monitor do Vinícius só a referência aparece destacada; no do Pedro, a linha inteira.
Deixar o destaque **mais forte**, na linha inteira (fundo + borda), sem depender da calibração do monitor.

#### N6 — Editar produto: Salvar cortado e estoque integrado na vertical — DEFINIDO

[31:12]-[33:04].

- **N6a (bug)**: no modo editar do Cadastro, o botão **Salvar** fica cortado (Excluir e Copiar aparecem).
  Corrigir o layout para os 3 botões caberem.
- **N6b**: o bloco "estoque integrado" mostra hoje 3 valores na horizontal (setor atual, reserva e mais um).
  Passar para a **vertical** e listar **todos os setores** do produto: estoque geral, showroom, reserva,
  separação, garantia, Casa Cor (quando N8 existir). O bloco pode ficar mais estreito.
- Observação da reunião: o histórico de vendas do produto não veio na migração ("não veio o histórico").
  Fica registrado; não faz parte desta SPEC.

#### N7 — Permissão por ação na Consulta de Produto — DEFINIDO, via Hub

[33:04]-[35:16]. Todo mundo consulta produto; só algumas pessoas editam (ex.: a Mari edita peça, mas não
acessa o Dashboard nem a Aprovação Financeira). Usar a matriz de ações já existente
(`papel_permissoes` + `hub_pode_executar`), **sem regra fixa no código** (AGENTS.md). Lembrar que
`hub_pode_executar` não tem atalho para admin: cada papel precisa da permissão explícita.

- Cadastro: botões Editar / Copiar / Excluir só aparecem com permissão `editar` (ou ação equivalente) no
  sistema Cadastro.
- Montar a matriz papel × ação com o Vinícius na ligação de 02/10.

#### N8 — Estoque Casa Cor — PRECISA DE DEFINIÇÃO

[36:04]-[40:32]. Peças de Casa Cor (usadas em evento, vendidas com desconto) hoje ficam numa planilha do
Matheus. Regras ditas na reunião:

- Setor próprio, **visível**, mas **fora** do estoque geral e do disponível, para ninguém reservar peça de
  Casa Cor numa venda normal de preço cheio. A mesma regra vale para o estoque de Garantia.
- Para vender: transferir do Casa Cor para o geral e reservar, ou (sugestão do Pedro) reservar direto do Casa
  Cor. O preço menor entra como **desconto** no orçamento.
- Já existem tipos de operação `CASA COR SAÍDA` / `CASA COR ENTRADA` (SPEC-071/074): verificar como se
  relacionam com o setor novo.

Perguntas abertas: a peça de Casa Cor é a mesma `produto_id` com outro setor, ou um item separado? Quem pode
transferir entre setores?

#### N9 — Estoque por empresa nos bastidores — LEVANTAMENTO, SPEC PRÓPRIA

[40:32]-[54:41]. Requisito fiscal (fiscalização da Secretaria da Fazenda, mudança de regime tributário):
o estoque precisa ser rastreável **por empresa do grupo**: **Manoela, Foco e ISLIGHT** (confirmado pelo
usuário em 01/10; na ata, "Slide" é erro de transcrição de ISLIGHT e "estoque Lutineira" é erro de
transcrição de "estoque Lucenera"). Vendeu pela Manoela, sai da Manoela; comprou pela ISLIGHT, entra na
ISLIGHT. A tela mostra a soma (estoque Lucenera). Exemplo: importação Ubiqua é sempre pela ISLIGHT.

- Estado atual: `produtos` tem um estoque único (`estoque_total`, `estoque_disponivel`, `estoque_showroom`).
  `pedidos_compra.empresa_id` já existe (SPEC-057). No Catálogo Ubiqua a divisão por empresa já aparece porque
  cada empresa tem uma referência diferente (SPEC-171).
- Não bloquear: vender 15 pela Manoela com 10 na Manoela e 5 na Foco é permitido.
- Carga inicial: balanço com as 3 planilhas do Sérgio, uma por empresa (passo manual).
- **Futuro, fora de escopo**: marca presa a uma empresa (ex.: Interlight sempre pela ISLIGHT, por causa do
  crédito de ICMS) e venda com 2 ou 3 notas de empresas diferentes. Registrado só para a modelagem não
  impedir isso depois.
- Feature grande, que mexe no núcleo do estoque: abrir **SPEC própria** depois do levantamento (como o
  Sérgio exporta por empresa; onde movimentar: entrada de nota, reserva, baixa).

#### N10 — Log de alterações para administrador (Controle de Produção) — PROPOSTA, CONFIRMAR

[56:06]-[56:56]. As ocorrências já gravam autor e hora ("Vinícius, 1/10, 3:41"). O Pedro propôs uma aba
**Log**, visível só para administrador, com todas as movimentações ("preciso saber quem fez isso, tá lá").
Confirmar com o usuário se entra agora e se vale também para a Garantia.

#### N11 — Status "Pedido de produção" no Controle de Produção — CONFIRMAR

[57:56]-[58:20]. O Vinícius sentiu falta do status "pedido de produção" que tinha mandado; o Pedro mostrou que
os status estão no rodapé, mas disse "eu vou colocar". Confirmar se o pedido é (a) um status novo, ou
(b) mostrar o status na lista/filtro de forma mais visível.

#### N12 — Catálogo Ubiqua: e-mail com PDF anexo — COBERTO PELA SPEC-172

[03:01]. Único ponto que falta na Ubiqua. Já está nas pendências da SPEC-172 (o `mailto:` não anexa
arquivo). Não duplicar aqui.

### Ordem sugerida

1. N6a (bug) e N1 (pedido direto, baixo risco).
2. N2a + N2b (impacto direto em compras).
3. N4, N5, N6b.
4. N7 (depois da ligação de 02/10).
5. N3, N8, N10, N11 (depois de responder as perguntas abertas).
6. N9 em SPEC própria.

### Impacto no banco

- N1, N4, N5, N6a: nenhum.
- N2a: nenhum (talvez registro em `historico_status_orcamentos`).
- N2b: alterar view(s) `vw_necessidade_compra*`. Fazer `CREATE OR REPLACE VIEW` mantendo a ordem das colunas
  (lição da SPEC-136) e testar antes com dry-run e ROLLBACK.
- N7: linhas novas em `papel_permissoes`.
- N8, N9: estrutura nova de estoque (a definir).

## Realizado

### 2026-10-01

- SPEC criada a partir da reunião de 01/10 e do histórico de commits de 22/09 a 01/10.
- **N1 CONCLUÍDO — Central (Skip 37750) v0.0.46 (`7c2bcf9`) publicada em produção em 01/10 (20:06 UTC).**
  Depois do publish: nenhuma Edge Function redeployada, `schema_migrations` = 239, bundle de produção
  (`Dashboard-*.js`) contém `newTab`.
  - `src/pages/Dashboard.tsx`: card chama `redirectWithCode(..., { newTab: true })`.
  - `src/lib/cross-system-auth.ts`: a opção `newTab` já existia mas nunca funcionava —
    `window.open(..., 'noopener')` devolve `null`, então a navegação caía na própria aba. Agora abre sem
    `noopener` (ainda no clique, antes de qualquer `await`, para não ser barrado como pop-up) e zera
    `opener` em seguida. Se o SSO falhar, a aba nova vai para o sistema sem código (login normal), em vez de fechar.
  - `SystemSwitcher` não mudou (não passa `newTab`).
  - Antes do apply: as 13 migrations legadas da Central já estavam em `schema_migrations` (sem risco de
    reexecução). Depois do apply: nenhuma Edge Function redeployada (comparado com a foto anterior), `schema_migrations` = 239.
  - Teste no preview (Chrome, logado): card "Orçamentos" na Central → abriu **nova aba** já logada
    (`/budgets`, `window.opener === null`), Central intacta na aba original; menu lateral do Orçamentos →
    CRM na **mesma aba**; menu lateral da própria Central → Cadastro na **mesma aba**.
  - Submodule local `central-lucenera-dashboard-1c9ba` não alterado (atrasado em relação ao Skip, rollout SPEC-120 pendente).
- **N4 + N2b (Compras) CONCLUÍDOS — Skip 40326 v0.0.79 (`664ba6d`) publicado.** Implementados pelo agente
  `implementador`, revisados pelo `revisor` (sem achado crítico), gravados no Skip por patch de trechos.
  - N4: `services/necessidade-compra.ts` ordena por relevância quando há busca (código exato > referência >
    marca > nome, média por termo, mesma regra de `buscar_produtos_fuzzy`); filtro de inclusão não mudou.
  - N2b: coluna "Previsão Entrega" no detalhe "Ver projetos". Migration
    `20261001_174_necessidade_compra_previsao_entrega` **aplicada** (dry-run + COMMIT): view
    `vw_necessidade_compra_detalhe` ganhou `previsao_entrega` no fim, 19 colunas e 5 linhas preservadas.
    Hoje nenhum orçamento tem `previsao_entrega` preenchida, então a coluna mostra "—" até o N2a gravar datas.
- **N5 + N6a + N6b (Cadastro) — Skip 36668 v0.0.89 aplicado, publicação PENDENTE (bloqueada pelo classificador).**
  - `Pecas.tsx` do Skip tinha a ordenação SPEC-122 que o git local não tem: aplicado só o trecho do destaque.
  - N6a: Cancelar/Salvar com `flex-wrap` + `min-w` (achado do revisor: risco de corte em ~1366px).
  - Incidente no apply: 14 arquivos de Edge Functions estavam apagados/vazios na working tree (origem
    desconhecida); regravados com o conteúdo do ar. Regravar o `deno.json` raiz redeployou as 13 funções do
    Cadastro; 12 ficaram idênticas ao ar (conferido por download), mas `salvar-projeto` voltou para cópia velha
    (sem SPEC-077) por ~5 min — restaurado com a cópia do CRM (v0.0.89, no ar v87, conferido por download).
- **N2a (Orçamentos)** implementado no local (`TeamApprovalDeliveryDialog.tsx` novo, `TeamApprovalTab.tsx`,
  `BudgetFormPage.tsx`) e revisado (sem crítico; 1 médio: UPDATE da data + RPC de aprovação não são atômicos).
  Ainda não gravado no Skip 32554.

### 2026-10-01 (continuação) — N10 e N11 (Controle de Produção / Controle de Garantia)

Implementado pelo agente `implementador` **no local** (não aplicado no Supabase real, não publicado no
Skip, não commitado) — falta o `revisor` e os passos manuais abaixo.

- **N11 (Controle de Produção) — causa confirmada e corrigida.** `ModalAtualizarStatusProducao.tsx` era um
  `<Input list="...">` com `<datalist>` nativo; dentro do `Dialog` do Radix (overlay/focus-trap próprios) o
  `<datalist>` não abre de forma confiável — só o texto "Sugestões: ..." do rodapé aparecia, exatamente o
  relato do usuário ("só na descrição de quais status tem"). Os outros 3 campos do mesmo sistema (Tipo de
  peça, Empresa, Prioridade em `ModalNovoPedidoProducao.tsx`) já usavam `<Select>` do Radix dentro do mesmo
  tipo de `Dialog` e funcionam normalmente — confirma que o problema era o `<datalist>`, não o Dialog.
  Trocado por `<Select>` real com opção "Outro (escrever)" revelando um campo livre (mesmo padrão de
  `OCORRENCIA_OUTRO`/`ModalOcorrenciaProducao.tsx`), preservando a entrada de valor livre (status continua
  sem `CHECK` no banco — dado sujo real da planilha). Status legado que não está em `STATUS_SUGESTOES` cai
  automaticamente em "Outro" já preenchido com o valor atual, sem perder o pedido de vista.
  Verificado o Controle de Garantia: `ModalAtualizarProtocolo.tsx` já usa `<Select>` para `ProtocoloStatus`
  (enum fixo) — **a falha de N11 não existe na Garantia**, nada a corrigir lá.
  - `04-Sistemas/controle-de-producao/src/components/producao/ModalAtualizarStatusProducao.tsx`
  - `04-Sistemas/controle-de-producao/src/services/producao.ts` (export `STATUS_OUTRO`)
- **N10 (Controle de Produção + Controle de Garantia) — aba "Log", só administrador.** Levantamento do que já
  existia: Produção tinha `producao_pedido_ocorrencias` (quem registrou/resolveu), `producao_pedido_handoffs`
  (quem entregou/recebeu) e `producao_pedido_edicoes`/`producao_pedido_prazo_alteracoes` (quem editou e
  quando, sem diff de campos); Garantia não tinha **nenhuma** tabela de histórico. Em nenhum dos dois havia
  registro de **quem** mudou o status (a troca pelo modal rápido é um `UPDATE` direto, sem autor) nem diff de
  campos. Faltava dado — redigida migration (não aplicada):
  - `supabase/db/migrations/20261001_174b_log_producao_garantia/001_producao_pedidos_log.sql`: tabela
    `producao_pedidos_log` + trigger `AFTER INSERT OR UPDATE ON producao_pedidos` (função
    `registrar_log_producao_pedidos`, `SECURITY DEFINER`) gravando `auth.uid()`, ação
    (`criado`/`atualizado`/`status_alterado`) e `dados_antigos`/`dados_novos` em `jsonb`. RLS: só
    `usuarios.role = 'admin'` lê (mesmo critério usado em `cadastro-lucenera-b86fe` e nas policies do
    snapshot `07_rls_policies.sql`); sem policy de INSERT para `authenticated` (só a função grava).
    Conferido antes: único trigger existente em `producao_pedidos` é `producao_pedidos_updated_at`
    (`BEFORE UPDATE`) — sem conflito (fase diferente).
  - `.../002_garantia_log.sql`: mesma estrutura para `garantia_protocolos_log` (trigger em
    `garantia_protocolos`) e `garantia_itens_log` (trigger em `garantia_itens`). Conferido antes:
    `garantia_protocolos_updated_at` e `garantia_itens_updated_at` (`BEFORE UPDATE`) — sem conflito.
  - Frontend agrega a trilha nova com o que já existia (ocorrências/handoffs na Produção) numa aba "Log"
    visível só para quem tem `usuarios.role === 'admin'` (hook `useIsAdmin`, mesmo critério, sem e-mail
    hardcoded): botão "Log" ao lado dos filtros de tipo (Produção) e 4ª aba (Garantia), lista mais recente
    primeiro com busca simples por usuário/ação/pedido/detalhe.
    - `04-Sistemas/controle-de-producao/src/hooks/use-is-admin.ts` (novo)
    - `04-Sistemas/controle-de-producao/src/components/producao/LogPanelProducao.tsx` (novo)
    - `04-Sistemas/controle-de-producao/src/services/producao.ts` (`listarLogProducao`, `LOG_ACAO_LABEL`,
      `LogProducaoEntry`)
    - `04-Sistemas/controle-de-producao/src/pages/Producao.tsx` (toggle "Log", só admin)
    - `04-Sistemas/controle-de-garantia/src/hooks/use-is-admin.ts` (novo)
    - `04-Sistemas/controle-de-garantia/src/components/garantia/LogPanelGarantia.tsx` (novo)
    - `04-Sistemas/controle-de-garantia/src/services/garantia.ts` (`listarLogGarantia`, `LOG_ACAO_LABEL`,
      `LogGarantiaEntry`)
    - `04-Sistemas/controle-de-garantia/src/pages/Garantia.tsx` (4ª aba "log", só admin)
- **Verificação:** `oxlint` e `tsc --noEmit` sem erros e `vite build` ok nos dois sistemas. `oxfmt --check`
  reporta "format issues" em quase todo `src/` dos dois sistemas (inclusive arquivos nunca tocados, ex.
  `components/ui/button.tsx`) — drift pré-existente do ambiente (não introduzido por esta mudança;
  confirmado via `git status`, os arquivos reportados fora dos meus `git status --short` já estavam
  "desformatados" antes). Não roda `oxfmt` sem `--check` (reformataria o repo inteiro, fora de escopo).
- **Teste manual pendente (navegador):** abrir Controle de Produção logado como administrador, confirmar que
  o botão "Log" aparece e que o `Select` de status em "Atualizar status" abre a lista normalmente (e que
  "Outro" revela o campo livre); confirmar que o botão/aba "Log" **não** aparece para um usuário não-admin;
  repetir a checagem de visibilidade do "Log" no Controle de Garantia. Sem a migration aplicada, as duas
  abas "Log" carregam vazias (RLS não erra, só não tem linha ainda).

### 2026-10-02 — Publicação de N2a, N3, N5–N8, N10, N11

- **Migrations:** 174b (log Produção/Garantia) ficou aplicada (aplicada sem querer por um `revisor` em 01/10 durante
  dry-run — o arquivo tem `COMMIT;` próprio; mantida por decisão do usuário, 3 linhas de log de teste apagadas; 3
  `updated_at` de registros de teste foram alterados). 174c (permissão "editar" no Cadastro para `compras_e_entregas`
  e `estoque`, agora idempotente com `WHERE NOT EXISTS`) e 174d (`vw_produtos_estoque_detalhado` sem Casa
  Cor/Garantia + 2 colunas novas no fim) aplicadas com dry-run (sem BEGIN/COMMIT do texto) + COMMIT. Débora passou a
  ter "editar"; totais da view inalterados (31599 / 7512,70).
- **Publicados:** Controle de Produção 60535 v0.0.14 (`8b2ee8b`), Controle de Garantia 60545 v0.0.10 (`1fc8c52`),
  Orçamentos 32554 v0.0.377 (`237542e`), Cadastro 36668 v0.0.90 (`c037527`). Todos os arquivos levados ao Skip por
  patch de trechos (Cadastro: só os trechos N7/N8 por cima da versão do Skip, preservando a ordenação SPEC-122).
  Antes de cada apply: migrations legadas conferidas como registradas; depois: nenhuma Edge Function redeployada,
  `schema_migrations` = 239.
- Revisões (`revisor`) sem achado crítico nos 3 pacotes; ajustes feitos: 174c idempotente, `has_estoque` sem
  Casa Cor/Garantia, botão "Sim, revisar preços" fecha o diálogo antes de navegar.

## Pendências

- [ ] N7 — Fechar com o Vinícius a matriz papel × ação do Cadastro (hoje: `compras_e_entregas` e `estoque` ganharam "editar" pela migration 174c; `viewer` tem "editar" de brinde por `acao IS NULL`; botão "Nova Peça" não é escondido para quem só consulta).
- [ ] N8 — Carregar a planilha de Casa Cor do Matheus; não existe tela de transferência entre setores (Casa Cor → geral).
- [ ] N9 — Decidir a modelagem do estoque por empresa (SPEC-175) e receber do Sérgio as 3 planilhas de balanço.
- [ ] N2a — Melhoria futura: gravar a previsão de entrega e aprovar numa RPC única (hoje são 2 passos, não atômicos).
- [ ] N10 — Cuidado com UPDATE em massa em `producao_pedidos`/`garantia_protocolos`/`garantia_itens`: cada linha gera um log.
- [ ] Testar ao vivo com o Vinícius/equipe: N2a, N3, N5–N8, N10, N11 (publicados 02/10).
- [ ] Conferir com o Vinícius os itens ⬜ da Parte A, principalmente o Controle de Garantia.
- [ ] Criar os logins do Controle de Produção e da Garantia (depende dos e-mails do Mateus).
- [ ] Limpar as vendas de teste usadas na reunião.
- [ ] Commitar o código local dos submodules (Compras, Cadastro, Orçamentos, Produção, Garantia) — o Skip está à frente; o git local do Cadastro não tem a SPEC-122.
