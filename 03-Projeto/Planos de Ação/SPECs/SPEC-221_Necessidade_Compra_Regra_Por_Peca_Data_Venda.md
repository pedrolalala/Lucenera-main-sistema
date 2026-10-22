---
titulo: "SPEC-221 — Necessidade de Compra: regra por peça (pedido em andamento cobre, inclusive o comprado a mais) e destino pela data da venda"
status: não iniciado
data_ultima_modificacao: 2026-10-22
sistemas_envolvidos:
  - Necessidade de Compra (compras-lucenera-3o23t98ee) — Necessidade de Compra e Entrada de Nota Fiscal
  - Banco — views de necessidade (vw_necessidade_compra_item_orcamento) e RPC entregas_futuras_para_entrada (SPEC-220)
---

# SPEC-221 — Regra da necessidade de compra por peça e destino pela data da venda

> Origem: `02-Reunioes/35. Lucenera (Vinicius) - 22.10.2026_ Reuniões gerais/Reunião.01` (Vinicius, 22/10/2026).
> O usuário avisou: "o Vinicius passou uma informação sobre o banco de dados que é bem delicada".

## O que o Vinicius explicou (regra do negócio)

1. **Necessidade só aparece se a peça estiver negativa E não houver pedido de compra em andamento que cubra.**
   Exemplo dele: estoque zero, vendi 5 para o Pedro; a caixa fechada é de 10, então compro 10 (5 para o Pedro e 5
   sobrando). Até chegar, alguém vende mais 3 → **não** abre necessidade (o pedido cobre). Vende mais 2 → não abre.
   Vende mais 1 → aí abre **1**. Acontece muito comprar a mais (caixa fechada, desconto do fornecedor para fechar um
   valor, fita LED que tem giro).
2. **Troca de reserva**: a Lana (venda de 3 meses atrás) tinha a peça reservada; o Vinicius vendeu agora e precisa com
   urgência → passa a reserva da Lana para o Vinicius (o sistema já faz). A Lana fica em entrega futura. A necessidade
   da Lana **só volta** se não houver pedido em andamento que cubra.
3. **Quando o material chega, vai para os clientes pela data da venda (a mais antiga primeiro)**, e não para quem
   "originou" o pedido. No exemplo, o pedido feito para o Vinicius vai para a Lana.

## Como está hoje (conferido no banco em 22/10)

- A tela da Necessidade de Compra lista **por L** (`vw_necessidade_compra_item_orcamento`):
  `pendente do L = entrega futura do L − o que está em pedido aberto LIGADO àquele L` (`pedido_compra_item_origem`).
  - Comprado a mais (sem L) **não cobre** venda nova → abre necessidade que não devia (caso 1).
  - Depois da troca de reserva, o pedido continua ligado ao L de quem ganhou a reserva; o L de quem perdeu aparece
    como necessidade **mesmo com pedido a caminho** → risco de comprar duas vezes (caso 2).
- A visão por peça (`vw_necessidade_compra`) já faz `necessidade − em pedidos abertos`, mas não é a que a Débora usa
  para montar o pedido.
- Na Entrada de Nota (SPEC-220, de ontem) o "Para quem" sugere **os L de origem do pedido**, e não a venda mais antiga
  (caso 3).
- Hoje os números ainda batem: 26 peças / 242 unidades nas duas contas, porque desde o sistema novo ninguém trocou
  reserva nem comprou a mais. Vai divergir no primeiro caso real.

## Checklist de Ação

**A. Necessidade por peça, com o pedido cobrindo pela data da venda**
- [ ] A1. Para cada peça: cobertura = soma do que falta chegar nos pedidos em andamento (aguardando aprovar, aprovado,
      concluído parcialmente), **inclusive o comprado a mais**, sem olhar a qual L o pedido foi ligado
- [ ] A2. A cobertura atende os L em entrega futura **da venda mais antiga para a mais nova**; aparece na tela só o
      que sobra sem cobertura (os L mais novos). No exemplo: 5 (Pedro) + 3 + 2 cobertos pelo pedido de 10; o 1 seguinte aparece
- [ ] A3. Mostrar na linha do L quando ele está coberto parcialmente ("2 de 5 cobertos pelo pedido 1783")
- [ ] A4. O total por peça na tela = entrega futura − cobertura (igual à `vw_necessidade_compra`)

**B. Chegada vai para a venda mais antiga**
- [ ] B1. `entregas_futuras_para_entrada` devolve a data da venda; a lista "Para quem" vem ordenada pela data
- [ ] B2. A sugestão do "Para quem" passa a ser: vendas mais antigas primeiro, até acabar o que chegou (não mais os L
      de origem do pedido). Continua dando para mudar à mão, com o mesmo limitador

**C. Troca de reserva** — coberta por A (não precisa mudar a troca em si)
- [ ] C1. Teste: trocar a reserva entre duas vendas com pedido a caminho e conferir que a necessidade não reaparece

**Entrega**
- [ ] Migration (views/RPC) com dry-run em ROLLBACK, telas, publicar, CHANGELOG

### Passos manuais do usuário
- [ ] Confirmar a "data da venda" (ver Pontos para confirmar)
- [ ] Teste com a Débora: pedido de 10 para uma venda de 5; vender mais 3 e mais 2 (não abre); mais 1 (abre 1)

## Pontos para confirmar

1. **Data da venda** para a ordem: a aprovação do orçamento (`orcamentos.aprovado_cliente_em`, quando vira venda). Recomendação: **sim**; se
   não houver, a data em que o item entrou no projeto.
2. **Pedido "aguardando aprovar" cobre?** (ainda não foi confirmado com o fornecedor). Recomendação: **sim**, para a
   Débora não montar outro pedido da mesma peça enquanto o primeiro espera retorno.

## Outros assuntos da mesma reunião (fora desta SPEC — registrar e tratar depois)

- **Setor showroom × estoque geral** (Reunião.03): a venda procura a peça só no estoque geral; se a peça está no
  showroom, abre necessidade para a Débora sem precisar. Precisa da **transferência de setor** (já citada na SPEC-220,
  E2) → SPEC própria. Também vale para o empréstimo.
- **Orçamento de empréstimo** (Reunião.03): o Vinicius descreveu empréstimo como um orçamento que move as peças para o
  setor "empréstimo" (continuam disponíveis, sem financeiro), com devolução total, parcial ou virar venda. A SPEC-219
  (outra sessão, 22/10) fez o empréstimo só como registro no Showroom, **sem mexer em estoque** — confirmar se segue
  assim ou se evolui para o que o Vinicius descreveu.
- **Peça com avaria** (Reunião.03): hoje marcam com "***" na descrição. Pedido: marcação de avaria (foto, aviso,
  preço de venda próprio), talvez cadastro separado → SPEC do Cadastro.
- **Promoção por quantidade na Ubiqua** (Reunião.02): ex. "comprando 4, leve 5 com 5%"; regra a definir na reunião de
  23/10 com a Josi e o Filippo → SPEC do Catálogo Ubiqua depois.

## Realizado

(vazio)
