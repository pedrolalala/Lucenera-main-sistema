---
titulo: "SPEC-251 — Venda Parcial: botão Transferir (pegar emprestado) para todas as equipes, vendas da Connect incluídas, com log por venda e geral"
status: pendente
data_ultima_modificacao: 2026-11-06
sistemas_envolvidos:
  - Venda Parcial (04-Sistemas/separacao-parcial)
  - Banco (Supabase SP) — movimentação reserva ↔ entrega futura entre vendas, log de trocas
  - Movimentação de Peças (botão "Trocar", SPEC-098/149)
---

# SPEC-251 — Transferir entre vendas

> Origem: reunião 06/11 (min. 61–75, 126–135). Relacionadas: SPEC-235 (B: ajuste dentro da venda; "Trocar" liberado às vendedoras), SPEC-243 (Tratar só Matheus), SPEC-244.
> A pendência de 05/11 ("Transferir nas vendas da Connect conflita com a SPEC-244") foi decidida: **liberar**.

## Checklist de Ação

- [x] A. Mostrar o botão **Transferir** na Venda Parcial (vendas do sistema **e** vendas da Connect) para todas as equipes, em cada item que esteja em Entrega Futura.
- [x] B. Janela de transferência: lista **todas as vendas (de todas as equipes)** e todos os Ls que têm o item em Reserva; escolher a venda, a quantidade e concluir. Transferir também entre Ls do mesmo cliente.
- [x] C. Efeito: na venda que recebe, Entrega Futura → Reserva; na venda de origem, Reserva → Entrega Futura (o item "abre" entrega futura de novo). Estoque Geral não muda.
- [ ] D. Coluna na janela com **previsão de chegada** do item (pedido de compra em andamento e data prevista). Depende da SPEC-253.
- [x] E. Motivo obrigatório (texto curto) e registro de quem pediu, quem cedeu e a equipe de cada lado.
- [x] F. **Log por venda**: aparece nas **duas** vendas envolvidas (origem e destino) e em nenhuma outra. Mostrar nº das vendas, peça, quantidade, quem, quando, motivo.
- [x] G. **Log geral** (botão Log fora de uma venda) com busca/filtro (cliente, peça, pessoa, venda) e rolagem.
- [x] H. Manter a regra: a Venda Parcial lista por equipe; só a janela de transferir mostra todas.
- [ ] I. (Depois) aviso para a equipe da venda de origem: "a venda X cedeu a peça Y para a venda Z, feito por W".

### Passos manuais do usuário

- [x] Publicar o Venda Parcial — NO AR em separacao-lucenera.pages.dev (deploy 99151414 por wrangler, 06/11; bundle em São Paulo e texto novo conferidos em produção); commit f792cdf pushado.
- [ ] Testar uma transferência real de 2 + 2 unidades (a reunião testou só 4 de uma vez).
- [ ] Enquanto o aviso automático (I) não existe: continuar mandando o print do log no grupo de transferências.

## Objetivo

Hoje o botão Transferir/Trocar fica escondido nas vendas da Connect e só o Tratar (Matheus e Pedro) aparece. As equipes precisam pegar peça de outra venda (mesmo de outra equipe) para atender uma entrega, com rastro de quem pegou de quem.

## Decisões aprovadas (reunião)

- Todas as equipes veem **todas** as vendas na janela de transferir; as demais telas continuam por equipe. As meninas já priorizam os clientes da própria equipe e pedem autorização quando precisam de outra.
- Itens de grande estoque (ex.: lâmpada 9801 com 2000 em estoque) são pegos direto; o registro é o log (print para o grupo por enquanto).
- Se a transferência feita for parcial (2 + 2), não tem problema fazer em duas operações.
- Garantia sem estoque disponível entra em Entrega Futura e depois pega emprestado de uma venda importada da Connect (testado: 4 unidades da venda da Luciana funcionaram; log gerado).

## Definição da SPEC

### Como está (conferido na reunião)

- Venda do sistema: Trocar/Ajustar existem; na venda da Connect aparece só **Tratar**, restrito a Matheus/administração (SPEC-243 fase 2).
- A transferência feita na reunião (garantia → venda da Luciana) moveu a peça e gravou log na tela de logs.
- O log mostrava **tudo** ao abrir dentro de uma venda e não mostrava o **número da venda** envolvida (só nome do cliente); o cliente da Luciana tem duas vendas.

### Mudanças

| Parte | Mudança |
|---|---|
| Venda Parcial (tela) | Botão Transferir em item com Entrega Futura (também venda Connect); janela com colunas: cliente, venda, L, disponível em reserva, previsão de chegada. |
| Banco | A função de troca entre vendas aceitar origem/destino de orçamento `origem = 'connect'`, respeitando a conta da SPEC-232 (reservado total não muda). Log com `orcamento_origem`, `orcamento_destino`, `motivo`, `equipe_origem`, `equipe_destino`. |
| Log | Filtrar por venda envolvida (origem **ou** destino). Log geral com busca. Mostrar sempre o nº da venda de cada lado. |
| Regra SPEC-244 | Ajustar: "Trocar fica só nas vendas do sistema" deixa de valer. |

### Riscos

- Na Connect a mesma troca precisa ser feita à mão (operação paralela): o saldo da Connect não é atualizado pelo sistema novo. Reforçar no texto da janela: "lance também na Connect".
- Peça cedida por venda da Connect cuja entrega depende da herança sem data: confirmar que não vira inconsistência com o Tratar (a venda que cedeu passa a ter Entrega Futura, como numa venda normal).

## Critérios de aceite

- Vendedora de outra equipe consegue transferir de uma venda de qualquer equipe; Estoque Geral e reservado total iguais antes e depois.
- Nas duas vendas aparecem log com o nº da outra venda; numa terceira venda o log não aparece.
- Log geral encontra a transferência pelo nome do cliente.
- Venda da Connect mostra o botão; Tratar continua só para Matheus/administração.

## Realizado

### 2026-11-06 (A, B, C, E, F, G, H — só front, sem migration; NO AR)

- **Nenhuma migration:** a função `trocar_reserva_projetista` já trabalha por item de projeto e não olha a origem (sistema ou Connect). A lista de origem (`vw_cadastro_produto_reserva_detalhe`) e as tabelas de saldo já são lidas por todos os logados; o filtro por equipe existe só na lista de vendas. A permissão (`pode_trocar_reserva`) é por cargo, não por equipe: admin, gerente e Projetista.
- **Teste no banco como projetista (Marina), em ROLLBACK:** transferência de 1 un. de uma venda do sistema para uma venda da Connect com Entrega Futura: destino Reserva 2→3 e Entrega Futura 3→2; origem Reserva 4→3 e Entrega Futura 0→1; Estoque Geral do produto 56→56; a transferência apareceu no log da venda de destino. Nada ficou gravado.
- **Venda Parcial (`04-Sistemas/separacao-parcial`):** botão **Transferir** (antes "Trocar") também nas vendas da Connect; janela com coluna **Venda** (selo "Connect"), equipe, aviso "vendas de todas as equipes / faça também na Connect"; **motivo obrigatório**; bloco **"Transferências desta venda"** (cedeu/recebeu, quantidade, de/para qual venda, cliente, equipe, quem, motivo) que aparece nas duas vendas envolvidas e em nenhuma outra; **Log de Transferências** geral com **busca** (cliente, venda, peça, equipe, pessoa, motivo), nº da venda e equipe de cada lado, e o botão agora visível para todos. `tsc`: 7 erros antes e depois (antigos); `vite build` ok e só com São Paulo.

## Pendências

- [ ] **Matheus e Vitória:** migration 299 (`20261106_299_spec251_matheus_vitoria_transferir`) em RASCUNHO, dry-run OK, **NÃO aplicada** (aguarda o OK explícito, porque mexe em permissão). Ver Realizado.
- [ ] Item D (coluna de previsão de chegada) depende da SPEC-253.
- [ ] Item I (aviso/pop-up para a equipe da venda de origem) fica para depois.
- [ ] Destino Connect cuja peça tem data de entrega na Connect: a reserva recebida não poderá ser separada (SPEC-244, item "não liberado"). Decidir se a transferência para esse item deve ser recusada ou avisar.
- [ ] Confirmar se a janela deve ocultar vendas com data de entrega marcada (para não pegar o que está de saída).
- [ ] Definir o texto do aviso (item I) e para quem vai (equipe da venda de origem, grupo de transferências).
- [ ] Decidir se a quantidade padrão sugere o que falta na venda de destino.

### 2026-11-06 (migration 299 — permissão de Matheus e Vitória; rascunho, dry-run OK, NÃO aplicada)

- **Como:** em vez de fixar cargo no código, usa o mecanismo de exceção individual do Acesso a Sistemas (o mesmo do ajuste de reserva da SPEC-235 e do Tratar da SPEC-243): módulo novo `transferir_reserva` do sistema `separacao-parcial` e exceção "conceder" para o **Matheus** e a **Vitória**; a administração concede ou tira depois pela Central, sem migration. `pode_trocar_reserva()` passa a aceitar admin, gerente, Projetista (como antes) **ou** a exceção; `aprovar_transferencia_estoque` deixa de repetir a regra à mão e chama `pode_trocar_reserva()`. De quebra, `pode_trocar_reserva()` perde o acesso do `anon` (ele podia executar; devolvia falso).
- **Dry-run com ROLLBACK:** antes — Matheus e Vitória: não; Marina (projetista): sim; Débora (assistente administrativa) e Antônio (auxiliar de estoque): não. Depois — Matheus e Vitória: **sim**; Marina: sim; Débora e Antônio continuam **não**. A Vitória fez uma transferência real (venda do sistema → venda da Connect): aprovada, a reserva do destino subiu 1 e o Estoque Geral ficou igual. O Antônio, na mesma transferência, foi barrado com a mensagem nova; `anon` barrado.
- **Para a tela não precisa publicar nada:** o botão Transferir já usa `pode_trocar_reserva()`; assim que a 299 for aplicada, Matheus e Vitória passam a vê-lo.
