---
titulo: "SPEC-244 — Operação em paralelo com a Connect: a herança sem data de entrega passa a ser separada no sistema novo"
status: "RASCUNHO PRONTO (migration 279 e telas NÃO aplicadas/publicadas) — aguardando OK para aplicar e publicar"
data: 2026-11-05
relacionadas: SPEC-243 (herança Connect), SPEC-232 (conta de estoque), SPEC-224 (movimentação de peças), SPEC-220 (entrada de NF)
---

# SPEC-244 — Operação em paralelo com a Connect

## 1. Decisão (usuário, 05/11/2026 — "decisão final")

A Connect e o sistema novo passam a operar **lado a lado**. O que foi importado até agora é **histórico**. A partir daqui, qualquer pedido de separação, movimentação e entrada é feito no sistema novo, em paralelo com a Connect.

- A herança da Connect **"sem data de entrega"** (o aviso que a Venda Parcial já mostra) é **liberada para separar**: **mesmo fluxo, mesma função, mesmas telas** da venda do sistema. Separar passa a **mexer no estoque**.
- **Entrega Futura da Connect** segue o fluxo normal em paralelo: quando a peça chega na entrada de NF, a Débora vincula à venda (SPEC-243 item I / migration 275) e aí vira Reserva e pode ser separada.
- **Quem pede a separação são as equipes** (mesmos usuários que já pedem nas vendas do sistema). Matheus e Vinicius têm outra relação: **movimentação de peças** (SPEC-224) e o **Tratar** da SPEC-243 fase 2.
- **Estoque:** regra da **SPEC-232**: separar tira da Reserva (vai para Ag. separar/Separado) e **não** baixa o Estoque Geral; a **baixa do Estoque Geral e a liberação do reservado acontecem ao finalizar a entrega**. Nenhuma função nova de estoque: a conta já é genérica (`sync_entregue_ao_finalizar_separacao`).
- **TUDO em paralelo (decisão do usuário, 05/11): as importações da Connect PARAM** — estoque, herança (Reserva/Entrega Futura) e **pedidos de compra**. (**Contas a Pagar/Receber**: parou no começo, mas o financeiro voltou a ser carregado todo dia pela SPEC-245.) Daqui para a frente a **equipe faz cada movimentação NOS DOIS sistemas** (separação, entrada de NF, pedido de compra, lançamento financeiro): o que se faz na Connect também se faz no sistema novo, e vice-versa. Não existe sincronização automática depois do marco.

## 2. O que muda

| Parte | Mudança |
|---|---|
| Banco (migration **279**) | Marco `connect_operacao_paralela` (linha única, gravada ao aplicar). `connect_item_liberado(item)` / `connect_itens_liberados(itens[])`: item da Connect liberado = Reserva **sem data de entrega** (`aviso_data`) **ou** que já recebeu da NF (`recebimento_para_reserva`). `registrar_separacao_setor` **recusa** item da Connect não liberado (vale também fora da tela). `remover_connect_lote` e `carregar_connect_reserva_ambiente` **recusam** depois do marco. `vw_cadastro_produto_setores`: o setor Separação passa a somar também a Connect (Reserva e Entrega Futura continuam separadas por origem). |
| Venda Parcial | Na venda da Connect, os itens liberados têm o campo de quantidade e o botão **Separar** (mesmo fluxo; parciais, estorno e finalização iguais). Os demais itens ficam só para consulta ("—"). **Trocar** e **Ajustar** continuam só nas vendas do sistema. Botões **Tratar** e **Ligar a um projeto** seguem só para Matheus/administração. Selo "Connect — herança em paralelo". |
| Cadastro | A aba **Separação** da peça mostra as duas origens; Reserva e Entrega Futura continuam por origem. |
| Scripts | `importar_produtos_estoque.py --incluir-estoque`, `importar_reserva_entrega_futura_connect.py --aplicar`, e `importar_pedido_compra.py` **recusam** depois do marco (**exceção, 05/11:** `importar_contas_pagar_receber.py` voltou a gravar por decisão da SPEC-245, porque o financeiro da Connect é carregado todo dia) (guarda em `sync_connect_common.exigir_sem_operacao_paralela`). O dry-run continua funcionando. Seguem liberados, por não mexerem em estoque/saldo/financeiro: clientes novos, XML dos orçamentos, produtos novos/preço. |

## 3. Regras e números

- Herança com Reserva **sem data** na Connect: 2.168 linhas, 13.171,7 un. Reserva **com data**: 708 linhas, 4.425 un (seguem na Connect). Entrega Futura: 921 linhas, 5.115 un (só viram Reserva pela NF).
- Itens da Connect liberados no ensaio: **2.164** (de 3.720 itens da Connect).
- Item = (L, peça, ambiente): se o item tem **alguma** linha de Reserva sem data, **toda** a Reserva dele fica liberada (aproximação aceita; o espelho não separa a quantidade por linha).
- O reservado total **não muda** ao separar; muda ao finalizar (−q junto do Estoque Geral −q), como nas vendas do sistema.
- A venda 100% entregue some da Venda Parcial como as do sistema (já é a regra atual).

## 4. Testes feitos (dry-run com ROLLBACK, banco real)

- Marina (projetista) pediu 1 peça de um item liberado: Reserva 2→1, Ag. separar 0→1, **Estoque Geral e reservado iguais** (563/581), setor Separação do Cadastro = 1.
- Item com data de entrega na Connect: **recusado** com a mensagem "tem data de entrega definida na Connect".
- Recarga da herança (`remover_connect_lote`) depois do marco: **recusada**.
- Estoque total antes × depois do ensaio: 32.521,70/25.594,70 (iguais).
- **Não testado:** a finalização da entrega de um item da Connect até o Estoque Geral (a função é a mesma da venda do sistema e já estava em produção; falta um teste real com uma entrega pequena).

## 5. Pontos em aberto / riscos

- **Dois sistemas, uma só operação:** a **equipe faz a movimentação nos dois** (decisão do usuário). Se alguém esquece de lançar num dos lados, os dois divergem e **não há correção automática**; vale uma conferência periódica de estoque (a combinar quem e quando). Isso vale para separação, entrada de NF, pedido de compra e financeiro.
- **Peças com herança negativa** (13653 −1; 10922 −7) e itens com data na Connect que a equipe queira separar: precisam do Matheus/Vinicius (movimentação) ou de liberar a regra.
- **Item sem projeto:** a separação funciona; o pedido na Logística/PDF pode mostrar projeto vazio até o Matheus ligar o projeto (migration 278).
- A mesma separação é **lançada nos dois sistemas** pela equipe (cada lado baixa o seu estoque); a divergência só aparece se algum lançamento ficar de fora.

## 6. Realizado

- 05/11: SPEC criada; migration 279 (up/rollback/dry_run) **em rascunho, ensaio OK**; telas Venda Parcial e Cadastro alteradas (não commitadas); guardas nos importadores de estoque, Reserva/Entrega Futura, pedido de compra e Contas a Pagar/Receber (testado só o caminho de dry-run).
- Falta: aplicar a 279, commit/push (Venda Parcial → Cadastro → central), teste real com uma entrega pequena, avisar as equipes.
