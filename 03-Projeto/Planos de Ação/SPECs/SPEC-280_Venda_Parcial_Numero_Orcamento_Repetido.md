# SPEC-280 — Venda Parcial: número do orçamento repetido misturava vendas de clientes diferentes

**Data:** 11/11/2026 · **Origem:** Reunião 49, parte 2 (Carol) — a bonificação ORC-0005 (Thairine) apareceu junto da garantia ORC-0005 (Marina); itens da VENDA-8508 apareceram dentro da VENDA-8506.

## Causa
Cada equipe tem a sua sequência de orçamentos, então o número se repete: há 3 × `ORC-0005` (garantia Marina, bonificação Thairine, venda Thais) e 2 × cada de `ORC-0001` a `ORC-0009`. A Venda Parcial identificava a venda pelo **texto** do número (`buscarVendaPorNumero`, `listarParciaisPorVenda`, chave e clique da lista), então juntava itens e parciais de todas as vendas com o mesmo número.

## Estrago nos dados
Nenhum. Das 1.008 separações, as 3 ligadas a números repetidos têm itens de um único orçamento cada, e nenhuma separação mistura orçamentos. O erro era só de busca/exibição.

## Entregue (código local, não publicado; sem mudança de banco)
- **Separação Parcial:** a venda aberta pela lista passa a ser identificada por `orcamentoId` (busca de itens, lista de parciais, previsão e chave da linha). `listarParciaisPorVenda` só traz parciais cujos itens (`separacao_itens → projeto_itens.orcamento_id`) são daquela venda. A numeração da próxima parcial (`-P<n>`) passa a contar só as da venda certa.
- **Logística (`pedido-separacao.ts`):** a busca do orçamento por número (`maybeSingle`, que falhava com 2+ linhas e deixava o pedido sem empresa/vendedor/data) e a das parciais irmãs agora também filtram pelo cliente da separação.
- Teste em SP (ORC-0005): busca antiga devolvia 2 itens misturados na garantia e na bonificação; a nova devolve 1 e 1, e a parcial `ORC-0005-P1` só aparece na garantia.

## Regra mantida: transferir entre equipes (11/11)
- Na Venda Parcial cada equipe vê só as vendas da própria equipe (lista para separar) e **pode transferir peça de qualquer outra equipe** (Transferir). Conferido em SP, em transação desfeita: a lista mostra Thairine 115 / Marina 96 / Thais 103 só da própria equipe; a Adriana (Thairine) transferiu 1 unidade de venda da Marina para venda da Thairine sem erro (`trocar_reserva_projetista` é SECURITY DEFINER).
- Falha achada: na lista de onde puxar, reservas de outra equipe vinham sem equipe e sem nº da venda para quem é de equipe (a tela lia `orcamentos`, escondido pela regra de equipe; a Adriana via 8 de 19). Correção: função `reserva_dados_vendas(uuid[])` (migration 331, só adiciona; devolve só nº da venda, origem e equipe; exige acesso ao sistema separacao-parcial; `anon` barrado) e `getReservasOutrosProjetos` passa a usá-la, com fallback para a leitura antiga se a função não existir. Ensaio em ROLLBACK ok (Adriana: 8 → 19). **Migration 331 APLICADA em SP em 11/11** (autorizada pelo usuário; uma transação com conferência antes do COMMIT; `anon` sem execução, `authenticated` com). Conferido depois: a Adriana identifica 19 de 19 vendas e a regra de equipe segue intacta (leitura direta de orçamentos continua mostrando só os da equipe).

## Pendente
- Publicar a Separação Parcial (já usa a função `reserva_dados_vendas`) e a Logística; Carol conferir as 17 vendas parciais (ela disse que ia verificar todas).
- Digitar/buscar um número repetido sem passar pela lista ainda pega a primeira correspondência; hoje a tela só abre vendas pela lista.
- Cosmético: o `numero_entrega` (`ORC-0005-P1`) repete entre vendas de mesmo número. Solução definitiva: gravar `orcamento_id` em `separacoes` (migration + preenchimento pelos itens) — decidir.
- Conferir outros sistemas que usem `orcamentos.numero` como chave (o resto não encontrado por busca de código).

## Rollback
Reverter os commits da Separação Parcial e da Logística e republicar.
