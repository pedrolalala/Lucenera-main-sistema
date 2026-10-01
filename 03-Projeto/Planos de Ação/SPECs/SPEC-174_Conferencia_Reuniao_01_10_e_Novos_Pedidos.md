---
titulo: "SPEC-174 — Conferência das entregas de 22/09 a 01/10 e novos pedidos da reunião de revisão de 01/10/2026"
status: pendente
data_ultima_modificacao: 2026-10-01
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

- [ ] N1 — Central (Hub): card de sistema abre em **nova aba**; o menu lateral continua na mesma aba
- [ ] N2a — Orçamentos: pop-up obrigatório de **Previsão de Entrega** na aprovação da equipe
- [ ] N2b — Compras: mostrar a previsão de entrega do cliente na Necessidade de Compra / rastreio do produto
- [ ] N3 — Orçamentos: aviso de atualização de preço depois que a validade (10 dias) vence — **definir antes**
- [ ] N4 — Necessidade de Compra: busca igual à do orçamento (código interno → referência → nome, vários termos)
- [ ] N5 — Consulta de Produto: destaque mais forte da linha/card selecionado
- [ ] N6a — Editar produto: botão **Salvar cortado** (bug)
- [ ] N6b — Estoque integrado: setores na **vertical**, com todos os setores do produto
- [ ] N7 — Permissões por ação na Consulta de Produto (todos consultam, só alguns editam) — via Hub
- [ ] N8 — Estoque **Casa Cor** como setor separado, que não soma no estoque geral — **definir antes**
- [ ] N9 — Estoque **por empresa** nos bastidores — **levantamento antes, SPEC própria**
- [ ] N10 — Log de alterações visível para administrador (Produção) — **proposta, confirmar**
- [ ] N11 — Status "Pedido de produção" visível na lista do Controle de Produção — **confirmar o que faltou**

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

## Pendências

- [ ] N1 — Cards da Central (Hub) abrem o sistema em nova aba; o menu lateral (SystemSwitcher) continua na mesma aba.
- [ ] N2a — Pop-up obrigatório de Previsão de Entrega na aprovação da equipe do orçamento.
- [ ] N2b — Mostrar a previsão de entrega das vendas no detalhe do produto da Necessidade de Compra.
- [ ] N3 — Definir com o Vinícius quando e como oferecer a atualização de preços de orçamento vencido (10 dias).
- [ ] N4 — Busca da Necessidade de Compra com a mesma regra do orçamento (código → referência → nome, vários termos).
- [ ] N5 — Destaque mais forte da linha selecionada na Consulta de Produto do Cadastro.
- [ ] N6a — Corrigir o botão Salvar cortado na edição de produto do Cadastro.
- [ ] N6b — Estoque integrado na vertical, com todos os setores, na edição de produto do Cadastro.
- [ ] N7 — Permissão de editar/copiar/excluir produto pela matriz do Hub; montar a matriz com o Vinícius.
- [ ] N8 — Definir e implementar o setor de estoque Casa Cor (fora do estoque geral); carregar a planilha do Matheus.
- [ ] N9 — Levantamento e SPEC própria para estoque por empresa; receber do Sérgio as 3 planilhas de balanço.
- [ ] N10 — Confirmar se cria a aba Log (só admin) no Controle de Produção e na Garantia.
- [ ] N11 — Confirmar o que falta no status "Pedido de produção" do Controle de Produção.
- [ ] Conferir com o Vinícius os itens ⬜ da Parte A, principalmente o Controle de Garantia.
- [ ] Criar os logins do Controle de Produção e da Garantia (depende dos e-mails do Mateus).
- [ ] Limpar as vendas de teste usadas na reunião.
