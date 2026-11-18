---
titulo: "SPEC-320 — Sistema para escoar (zerar) a Reserva sem venda (herança Connect) conforme o Matheus/Vitória baixam as listas de entrega na Connect — Reunião 62"
status: implementado em rascunho (migration 385 NÃO aplicada; sistema não publicado)
data_ultima_modificacao: 2026-11-18
sistemas_envolvidos:
  - Venda Parcial (`separacao-parcial`) — provável casa da tela (decisão em aberto)
  - Banco (Supabase SP) — função `limpar_reserva_sem_venda_connect` (migration 298, em rascunho) + tabela de lotes/log
  - Cadastro (linha "Reserva sem venda (herança Connect)") e Movimentação de Peças (kardex)
---

# SPEC-320 — Escoar a Reserva sem venda (herança Connect)

Fonte: `02-Reunioes/62. Lucenera (Vinicius) 16.11.2026_ reserva sem herança/Reunião.01` (termina em 19:21, quando o Pedro diz "aonde eu vou criar um sistema"). Continua a **SPEC-250** (migration 298 em rascunho, nunca aplicada) e muda o desenho: em vez de uma lista única, o saldo é **escoado aos poucos**, conforme as listas de entrega são baixadas na Connect.

## Situação medida em 16/11 (banco SP, só leitura)

- **160 peças** com reserva sem venda positiva, **2.884 un.** (mesmo total de 06/11); 3 peças negativas (−16 un.: 10427, 10922, 13653).
- Valor das 160 peças: **custo total R$ 406.213,78** (custo de tabela R$ 333.860,73); **preço de venda R$ 974.573,32**.
- Relatório por peça: `03-Projeto/Auditoria/reserva_sem_venda_heranca_connect_2026-11-16.csv`.
- A função `limpar_reserva_sem_venda_connect` **não existe no banco** (298 não aplicada); `pode_tratar_heranca_connect()` existe.

## O que a reunião decidiu / disse

1. **Regra de saída** (Vinicius, 00:45–00:55): tudo que sai de "Reserva sem venda (herança Connect)" **sai também do Estoque Geral**, na mesma quantidade (o Geral soma essa reserva; se não sair, deixa de bater com a Connect). Disponível e Separação não mudam. É a conta da SPEC-250/migration 298.
2. **Por que existe**: é material que está **em separação na Connect** (lista de entrega feita até 05/11, antes da virada), sem venda no sistema novo. Quando o Matheus der baixa da lista lá, a peça sai fisicamente e o Geral do sistema novo para de bater. Exemplo: peça 11887, Geral 4, reserva 3, **1 sem venda**; peça 8952, 323 sem venda.
3. **Não dá para zerar tudo de uma vez**: uma parte já foi entregue/baixada, outra ainda vai ser; a data da lista de entrega é de 05/11 para trás. "Tem que zerar, mas com muita cautela" / "tem que zerar logo".
4. **Desenho escolhido (Pedro, 14:19–15:17 e 18:32)**: um sistema onde o Matheus e a Vitória, **ao baixar uma lista de entrega na Connect, entram e informam as peças e quantidades dessa lista**, e o sistema escoa essa quantidade da reserva sem venda e do Estoque Geral. Escoa conforme entrega.
5. **Relatório de apoio**: o Vinicius pediu relatório das separações pedidas do dia 5 até agora (a Connect não tem esse relatório pronto; o Matheus vai tentar). Serve para eliminar o que já foi baixado antes.
6. Sem origem possível: parte do saldo (ex.: 1 un. da 11887) **não tem lista de entrega** de onde sair ("só pelo banco de dados"). Essa sobra fica para uma limpeza final, com aprovação.
7. Peças com venda no sistema novo (vínculo) e as sem venda na mesma peça: só a parte **sem venda** é tocada; a com vínculo continua escoando pelo fluxo normal.

## Checklist de Ação

- [ ] Confirmar com o usuário as decisões em aberto (seção abaixo), principalmente **onde fica a tela** (sistema novo ou módulo — não decidir sozinho).
- [ ] **Banco (migration nova, rascunho + dry-run com ROLLBACK, não aplicar sem OK):** reaproveitar a função da 298 (reserva sem venda −q, Geral −q, reservado −q; tudo ou nada; motivo obrigatório; trava de quantidade pela conta do Cadastro) e acrescentar o **lote de baixa**: tabela com número da lista de entrega da Connect, cliente/projeto (texto livre), data da baixa na Connect, quem lançou e quando, e os itens (peça, quantidade, saldo antes/depois). Cada lote vira movimento no kardex (origem "Reserva sem venda (herança Connect)", destino "Baixa (entregue na Connect)").
- [ ] **Tela "Escoar reserva sem venda"**: (1) lista as peças com saldo sem venda (código, descrição, Geral, reserva sem venda, Disponível) com busca; (2) o usuário monta o lote: número da lista da Connect, cliente, data, e adiciona peça + quantidade (a tela já mostra o máximo permitido); (3) **pré-visualização** antes/depois por peça (usa o modo teste da função) e botão Confirmar; (4) histórico dos lotes já lançados, com estorno só pela Administração (devolve Geral e reserva).
- [ ] **Entrada em massa opcional**: colar/importar planilha "código; quantidade" de uma lista inteira da Connect (para listas grandes), validando linha a linha antes de confirmar.
- [ ] **Relatório de conferência** (para Vitória/Matheus e Vinicius): por peça, saldo atual, quanto já foi escoado por lote, saldo que ainda não tem lista; exporta CSV/PDF; totais de peças, unidades e valor (custo só para Administração — AGENTS.md/SPEC-193).
- [ ] **Painel de progresso**: total inicial (2.884 un. / 160 peças em 16/11), escoado, restante, por data — para saber quando "zerou".
- [ ] **Sobra final**: lista das peças que ficaram com saldo sem venda e sem lista; limpeza em lote única só com aprovação explícita do Vinicius (mesmo motivo registrado, kardex normal) e as 3 negativas tratadas à parte.
- [ ] Permissão: só Matheus, Vitória e Administração (`pode_tratar_heranca_connect()` + incluir a Vitória); `anon` sem execução; RLS verificada como `authenticated`.
- [ ] Atualizar SPEC-250 (apontar para esta), SPEC-243/244 (regra "herança sem cliente nunca muda" ganha esta exceção), CHANGELOG e Sumário de Sistemas.
- [ ] Depois de pronto: revisor e auditor; teste com **uma peça** (11887, 1 un.) e depois uma grande (8952) antes de liberar para a equipe.

## Decisões em aberto (precisam do usuário)

1. **Onde fica a tela?** (a) dentro da Venda Parcial, junto do "Tratar" da herança; (b) no Cadastro, na linha da peça; (c) sistema novo à parte. A reunião diz "vou criar um sistema só para isso" (c), mas a regra do projeto é não decidir sozinho entre sistema novo e módulo. Recomendação: (a), por já ter o público (Matheus/Vitória) e a permissão.
2. **Vitória** entra no `pode_tratar_heranca_connect()`? Hoje é só Matheus e administração.
3. **Sobra sem lista** (ex.: 1 un. da 11887): zerar tudo no final, ou deixar visível até alguém conferir fisicamente?
4. As **3 peças negativas** (−16 un.) entram nesta SPEC ou ficam fora?
5. Ajustar a regra "herança sem cliente nunca muda" (SPEC-243/244): confirmar que esta SPEC é a exceção (já pedido na SPEC-250).

## Fora do escopo

- Alterar vendas, separações com venda ou reservas por cliente da Connect.
- Devolução/XML (a conversa de 08:13–09:11 sobre devolução foi um comentário lateral; segue o fluxo normal de devolução).
- Importar o estoque da Connect (SPEC-244 proíbe).

## Realizado

- 16/11/2026: relatório atualizado e totais de valor medidos (acima); SPEC criada. Nada implementado, nenhuma migration aplicada.
- 18/11/2026: decisões do usuário: **sistema novo à parte** (`04-Sistemas/escoar-reserva`), **Vitória entra** (tabela `escoar_reserva_operadores` + Matheus + admin), **3 negativas ficam fora**. Migration `20261118_385_spec320_escoar_reserva_sem_venda` escrita e testada em dry-run com ROLLBACK (160 peças / 2.884 un. batem; preview, lançamento, lista repetida bloqueada, estorno só admin, usuário sem acesso e anon bloqueados). Tela com 3 abas (Lançar lista com colar planilha, Peças com saldo + CSV, Histórico com estorno) compila. **Pendente:** aplicar 385 (aguarda OK), publicar no Cloudflare, registrar no Hub/Acesso a Sistemas, teste com 11887 e depois 8952. Obs.: Vinicius saiu em 17/11 — a aprovação da "sobra final" precisa de outro responsável.
