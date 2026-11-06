---
titulo: "SPEC-249 — Reunião 06/11 (sistema em geral): regras da transição com a Connect, chamados técnicos e índice das SPECs 250–256"
status: pendente
data_ultima_modificacao: 2026-11-06
sistemas_envolvidos:
  - Todos (guarda-chuva)
  - CRM / Orçamentos / Venda Parcial / Compras / Logística (ver SPECs filhas)
---

# SPEC-249 — Reunião 06/11: transição, chamados e índice

> Fonte: `02-Reunioes/43. Lucenera (Vinicius TOdos) - 06.11.2026 sistema geral/Reunião. 01` (ata em `02_ata_decisoes.md`).
> Esta SPEC não muda código: registra as regras de operação confirmadas, os chamados a investigar e aponta as SPECs que mudam o sistema.

## Checklist de Ação

- [ ] Registrar a ata e as decisões (feito nesta data, ver `02_ata_decisoes.md`).
- [x] Investigar o chamado 1 (vendas da Moara não aparecem para a equipe) — CORRIGIDO em 06/11 (migration 297, ver Realizado).
- [x] Investigar o chamado 2 (XML da Connect parou no orçamento 8514) — fica fora do nosso banco (ver Realizado).
- [x] Investigar o chamado 3 (boleto Figueiredo Nunes: data/valor) — conferido; ajuste é na Connect (ver Realizado).
- [x] Chamado 4 (erro de quantidade depois de devolução na Connect): sem causa nova; fica a ideia de edição com observação (SPEC-254, item G).
- [x] Conferir se todos os usuários veem na Central de Solicitações o que já foi pedido — todos veem (RLS de leitura aberta a logados); acrescentada **busca por texto** no painel.
- [ ] Atualizar `02-Reunioes/00_INDICE_REUNIOES.md` (reunião 43) e `00_FLUXOS_CONSOLIDADOS.md` (fluxo de transição abaixo).

### Passos manuais do usuário

- [ ] Responder as perguntas abertas de cada SPEC filha (seções "Pendências").
- [ ] Treinar as equipes com as regras da seção "Rotina da transição".
- [ ] Combinar quem confere o estoque dos dois sistemas e com que frequência (ver SPEC-244, seção 5).

## Objetivo

Reunir num lugar só tudo o que foi combinado em 06/11 sobre a convivência Connect + sistema novo, separar o que é regra de processo (não precisa de código) do que vira mudança no sistema, e listar os chamados técnicos.

## Decisões aprovadas (reunião 06/11)

- Valem as regras da seção "Rotina da transição". A reunião é evidência: onde conflita com SPEC anterior, isso está dito na SPEC filha.
- Fora de linha com limite ao estoque, Enter não adiciona item e reimportar XML atualizando o mesmo orçamento **já funcionam** (testados na reunião); não precisam de trabalho.

## Rotina da transição (regras de operação)

| Situação | Regra |
|---|---|
| Cliente novo | Cliente da Connect só chega uma vez por semana (terça). Cliente criado depois, ou **inativo** na Connect, não vem: criar no CRM e atrelar ao orçamento. Projeto criado no CRM já cria as pastas e o grupo do Teams (ponte CRM ↔ SharePoint); preferir criar pelo CRM porque leva os dados do cliente. |
| Orçamento novo | Montar na Connect, mandar ao cliente, importar o XML no sistema novo. **Não digitar duas vezes.** |
| Orçamento alterado na Connect | Reimportar o XML pelo orçamento ("Editar → importar XML"): atualiza o mesmo número. Conferir desconto, frete, arquiteto/RT, datas (ver SPEC-254). Troca de 1 ou 2 peças pode ser na mão. |
| Pagamento | A Connect não tem datas de pagamento: preencher no sistema novo (parcelas, forma, sinal) antes de aprovar. |
| Aprovação | Seguir as etapas do sistema novo (equipe → financeiro). Nota fiscal e boleto continuam só na Connect até a virada fiscal (provável janeiro). |
| Separação | Na Connect: separar os itens. Depois repetir no sistema novo (Venda Parcial → Logística). |
| Devolução / troca / garantia | Se a venda já está no sistema novo, fazer nos **dois**. Se a venda antiga não está (fora da herança), fazer na Connect e avisar o Pedro (orçamento "sem gerar" para amarrar). |
| Estoque | Toda movimentação nos dois. Viu divergência, avisa na hora. |
| Pedido de compra Connect | Débora importa o PDF no sistema novo (SPEC-247). Item especial por medida: pedido manual (SPEC-253). |

## Chamados técnicos (investigar, sem SPEC própria)

1. **Vendas da Moara não aparecem para a equipe.** A venda 5921 aparece com Reserva e Entrega Futura, mas a busca da Thaís não a encontra; no print do Pedro ela estava em "Administração" e não na equipe. Hipótese: equipe do orçamento Connect vem da regra de digitador (SPEC-243/`funcionarios.nm_connect`) e a Moara cai no padrão. Pedro disse que corrige. Critério de aceite: a venda aparece para a equipe certa; conferir as outras vendas da Moara que têm reserva ou entrega futura.
2. **XML da Connect parou no 8514 (30/10, ~11h).** Mesmo problema no computador da Adriana e da Gi (orçamentos novos não aparecem na tela de baixar XML); para o Pedro aparece. Será levado ao Sérgio (Connect). Critério: orçamentos posteriores ao 8514 aparecem para todas. Enquanto isso, ver se é permissão/filtro por usuário.
3. **Boleto Figueiredo Nunes:** planilha de contas a pagar com vencimento em 05/11 e o sistema sem nada em aberto naquele dia. Hipótese: data alterada na Connect entre a carga e ontem (novo boleto com vencimento 9 e valor um pouco maior). Conferir pela SPEC-245 (carga diária do financeiro).
4. **Erro de quantidade depois de devolução na Connect** (caso do orçamento da véspera): o Sérgio corrigiu na Connect, mas a carga antiga ficou errada no sistema novo. Ajuste pontual já foi feito (05/11, venda 2299). Ideia para o futuro: permitir editar o item com observação obrigatória do motivo; decidir depois.
5. **Central de Solicitações:** para evitar bug pedido em duplicidade, cada pessoa deve poder ver o que já foi aberto. Conferir se a lista da Central mostra todas as solicitações (e não só as próprias) com busca; se não, abrir SPEC curta. Existe grupo separado de IA no Teams para dúvidas.

## SPECs geradas pela reunião

| SPEC | Tema |
|---|---|
| 250 | Limpar a "reserva sem venda (herança Connect)" que ficou em trânsito |
| 251 | Venda Parcial: Transferir (pegar emprestado) para todas as equipes, vendas da Connect incluídas, com log |
| 252 | Venda Parcial: visual das finalizadas, remessa em aba separada, "Separar tudo", histórico, entregas antigas |
| 253 | Previsão de chegada nas vendas, pedido de compra ligado à venda e itens especiais por medida |
| 254 | Orçamento: comprovante na aprovação, reimportar XML, arquiteto e sinal |
| 255 | Garantia e demais saídas sem cobrança: sem revisão financeira, número G, rótulo |
| 256 | Logística: agrupar no calendário as entregas do mesmo cliente |

## Realizado

### 2026-11-06 (investigação dos chamados)

- **Chamado 1 — Moara (CORRIGIDO):** a venda 5921 é o orçamento `CNX-8428` (número de venda `CNX-5921`, cliente CK2), hoje na equipe **Thais**. Quem aparecia em "Administração" são as vendas da **vendedora Moara** (funcionária "Moara Bonato de Araujo Valente", Assistente Projetista, `nm_connect = MOARA`): ela está **sem equipe** no cadastro (`funcionarios.equipe_id` vazio) e a carga da Connect joga quem não tem equipe em "Administração". São **26 orçamentos da Connect** nessa situação, e nenhuma equipe de projetistas os enxerga (o RLS por equipe da SPEC-200 esconde). Outros funcionários sem equipe que digitaram na Connect: Teresinha (4 vendas), Matheus (3), Mariane (2), Vitória (1), Débora (1) e Filippo (1) — são pessoas fora das equipes de vendas e continuam em Administração. **Correção aplicada (confirmada pelo usuário: Moara era da equipe Thairine e saiu da empresa, mas as vendas dela precisam aparecer para a equipe):** migration 297 (`20261106_297_spec249_equipe_moara`, ajuste de dado, APLICADA 06/11 após dry-run com ROLLBACK) definiu a equipe da Moara = Thairine e moveu os **26 orçamentos** e as **474 linhas** de Reserva × Ambiente dela de Administração para Thairine. Backup do antes em `backup.spec249_moara_*` e `rollback.sql` restaura. Conferido: Administração caiu de 43 para 17 vendas da Connect; a Thairine passou a enxergar as 26 (teste como usuária Thairine); orçamentos, estoque, financeiro e saldos iguais antes e depois.
- **Chamado 2 — XML parado no 8514:** é a tela de baixar XML da própria Connect (fora do nosso banco). Não há o que corrigir aqui; fica com o Sérgio. Como contorno, a equipe pode usar a exportação do orçamento direto pela Connect do Pedro.
- **Chamado 3 — Figueiredo Nunes:** no banco, a duplicata 7912, **parcela 2, vence 05/11/2026, R$ 12.669,33, em aberto** (`status_pago = 0`), já está carregada (a SPEC-245 carrega o financeiro todo dia; na hora da reunião ainda não tinha aparecido). O boleto que chegou vence **09/11** e é um pouco maior: a correção de data e valor é feita **na Connect** (Carol/Lana) e entra na próxima carga diária; não alterei dado financeiro.
- **Chamado 5 — Central de Solicitações:** todos os logados já enxergam todas as solicitações (kanban com filtros de classificação e tipo). Acrescentei **busca por texto** (título, descrição, sistema, autor) no painel para conferir se já existe pedido igual antes de abrir outro. Código no commit c0396fe de `central-de-solicitacoes` (build ok só com São Paulo; pushado e **NO AR** em solicitacoes-lucenera.pages.dev, deploy fbcfa460).

### 2026-11-06

- Transcrição lida por inteiro; ata e decisões em `02_ata_decisoes.md`; SPECs 249–256 criadas (nenhuma implementada).
- A pendência registrada no CHANGELOG de 05/11 ("Separar tudo" e Transferir nas vendas da Connect conflitam com a SPEC-244) passa a ter decisão do Vinicius: **liberar** (SPECs 251 e 252). A SPEC-244 precisa ser ajustada junto.

## Pendências

- [ ] Chamado 2: acionar o Sérgio (Connect).
- [ ] Chamado 3: Carol/Lana corrigirem data/valor do boleto na Connect.
- [ ] Atualizar o índice e os fluxos consolidados de reuniões.
- [ ] Definir a conferência periódica de estoque entre Connect e sistema novo: quem faz e quando.
