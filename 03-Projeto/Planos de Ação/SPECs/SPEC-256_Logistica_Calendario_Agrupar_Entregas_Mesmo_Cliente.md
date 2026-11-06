---
titulo: "SPEC-256 — Logística: agrupar no calendário as entregas do mesmo cliente, endereço e dia"
status: pendente
data_ultima_modificacao: 2026-11-06
sistemas_envolvidos:
  - Logística (04-Sistemas/lucenera-logistics-b7cd1)
  - Dashboard (contagem de entregas), se usar a mesma fonte
---

# SPEC-256 — Agrupar entregas do mesmo cliente no calendário

> Origem: reunião 06/11 (min. 101–104). Relacionadas: SPEC-226 (calendário só com as entregas do dia), SPEC-244 (pedido de separação pelas equipes).

## Checklist de Ação

- [x] A. No calendário e nas contagens do dia, agrupar solicitações de entrega com **mesmo cliente (código), mesmo endereço e mesma data de entrega**.
- [x] B. O cartão do dia mostra "1 entrega (3 listas)" e abre as listas por dentro.
- [x] C. A contagem do dia e as métricas passam a contar a **entrega real**, não a lista.
- [x] D. Lista com data diferente (peça especial para 2 semanas) **não entra** no grupo do dia.
- [x] E. Agrupar só na visualização: as listas continuam separadas para a separação e a baixa.

### Passos manuais do usuário

- [ ] Publicar o Logística (aguarda o OK; sem migration).
- [ ] Matheus: confirmar que o agrupamento ajuda (ou não muda nada) na rotina dele.

## Objetivo

No sistema novo cada pedido de separação cria uma lista própria. Quando o mesmo cliente tem várias vendas, o calendário mostra "9 entregas" quando são 6, o que confunde a decisão de aceitar mais uma entrega no dia e distorce os dados ("o dia fez 10 entregas" quando foi 1 entrega com 10 listas).

## Decisões aprovadas (reunião)

- Agrupar **automaticamente**, não manualmente, preferencialmente pelo código do cliente.
- Cuidado: não agrupar só pelo nome; agrupar apenas o que é destinado àquele dia e endereço.

## Definição da SPEC

- Chave do grupo: `cliente_id` (código do cliente) + endereço de entrega normalizado + `data_entrega`.
- Sem endereço preenchido: não agrupa (mostra separado).
- Aplicar no calendário, na lista do dia e no contador; não alterar status, baixa nem PDFs de cada lista.
- Conferir se o dashboard usa a mesma fonte de contagem para não divergir.

## Critérios de aceite

- Cliente com 3 listas no mesmo dia e endereço aparece como 1 entrega com 3 listas.
- Lista do mesmo cliente com outra data ou outro endereço aparece à parte.
- Contagem do dia confere com o número de grupos.

## Realizado

### 2026-11-06 (A–E — só front, sem migration; commit be366a6, NÃO publicado)

- **Regra de agrupamento (`lib/agrupar-entregas.ts`):** mesma data (a do dia do calendário) + mesmo **cliente** + mesmo **endereço**. Cliente = código (`cliente_id`) quando existe, senão o nome normalizado; endereço = `endereco` (ou `endereco_entrega`) sem acento, caixa nem pontuação. **Sem endereço, a lista fica sozinha**; nunca agrupa só pelo nome; lista com outra data fica em outro dia. Complexidade do grupo = a mais alta das listas.
- **Teste da regra** (8 listas de exemplo): "Ana Souza / Rua A, 10 - Centro" e "ANA SOUZA / rua a 10 centro" juntaram; mesmo nome com outro endereço ficou separado; duas listas sem endereço não se juntaram; mesmo código de cliente e endereço juntou; outro código no mesmo endereço ficou separado.
- **Calendário:** a contagem do dia e do mês passa a ser de **entregas** (grupos); quando há mais listas que entregas, o dia mostra "N listas". A cor/letra de complexidade conta por entrega.
- **Detalhes do dia:** cabeçalho "N entregas programadas (M listas)"; grupo com mais de uma lista aparece num quadro "1 entrega · N listas do mesmo cliente e endereço" com os cartões de cada lista dentro. As listas continuam separadas para editar, separar, dar baixa e imprimir.
- Dados reais hoje: 24 separações abertas; só 4 têm `cliente_id` e 23 têm endereço; 1 par já seria agrupado (mesmo dia e endereço).
- Erros de tipo: 53 antes e depois (dívida antiga; o `tsconfig.app.json` tem um padrão `*/*` inválido, então a checagem foi feita numa cópia temporária sem essa linha); `vite build` ok só com São Paulo.

## Pendências

- [ ] Publicar o Logística (aguarda o OK).
- [ ] **Criar Rota** continua usando as listas (uma parada por lista); confirmar com o Matheus se o grupo deve virar uma parada só.
- [ ] Dashboard: se algum painel conta entregas pelas listas (`separacoes`), ele ainda mostra o número antigo; conferir e alinhar.
- [ ] Confirmar com o Matheus se o grupo deve aparecer também na tela dele de separação.
- [ ] Verificar se o endereço de entrega é gravado de forma comparável (texto livre pode diferir).
