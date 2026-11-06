---
titulo: "SPEC-256 — Logística: agrupar no calendário as entregas do mesmo cliente, endereço e dia"
status: não iniciado
data_ultima_modificacao: 2026-11-06
sistemas_envolvidos:
  - Logística (04-Sistemas/lucenera-logistics-b7cd1)
  - Dashboard (contagem de entregas), se usar a mesma fonte
---

# SPEC-256 — Agrupar entregas do mesmo cliente no calendário

> Origem: reunião 06/11 (min. 101–104). Relacionadas: SPEC-226 (calendário só com as entregas do dia), SPEC-244 (pedido de separação pelas equipes).

## Checklist de Ação

- [ ] A. No calendário e nas contagens do dia, agrupar solicitações de entrega com **mesmo cliente (código), mesmo endereço e mesma data de entrega**.
- [ ] B. O cartão do dia mostra "1 entrega (3 listas)" e abre as listas por dentro.
- [ ] C. A contagem do dia e as métricas passam a contar a **entrega real**, não a lista.
- [ ] D. Lista com data diferente (peça especial para 2 semanas) **não entra** no grupo do dia.
- [ ] E. Agrupar só na visualização: as listas continuam separadas para a separação e a baixa.

### Passos manuais do usuário

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

Nada implementado.

## Pendências

- [ ] Confirmar com o Matheus se o grupo deve aparecer também na tela dele de separação.
- [ ] Verificar se o endereço de entrega é gravado de forma comparável (texto livre pode diferir).
