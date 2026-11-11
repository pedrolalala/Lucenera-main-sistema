---
titulo: "SPEC-267 — Liberação manual de item da Connect para separar (vendas 4907 e 4908)"
status: pendente
data_ultima_modificacao: 2026-11-09
sistemas_envolvidos:
  - Venda Parcial (separacao-parcial)
  - Banco (Supabase São Paulo)
---

# SPEC-267 — Liberação manual de item da Connect para separar (vendas 4907 e 4908)

## Checklist de Ação

- [x] Migration **320** redigida: tabela `connect_item_liberacao_manual`, 3ª via em `connect_item_liberado()`, função `liberar_vendas_connect(vendas, motivo, aplicar)`.
- [x] Ensaio com ROLLBACK (`dry_run.sql`): 4 itens passam a liberados; estoque, reservado, financeiro, Reserva e Ag. separar iguais antes×depois; projetista e anon barrados; sem motivo recusa.
- [x] Aplicar a migration 320 no banco de São Paulo (autorizada e aplicada em 09/11).
- [x] Executar `liberar_vendas_connect(ARRAY[4907,4908], motivo, true)` como Matheus (feito 09/11: 4 itens liberados).
- [ ] Conferir na Venda Parcial que os 4 itens mostram campo de quantidade e botão Separar.
- [x] Atualizar CHANGELOG.

### Passos manuais do usuário

- [x] Autorizar a aplicação da migration 320.
- [ ] Avisar o Matheus de que as vendas 4907 e 4908 serão entregues e a Equipe de projetos fará o pedido de separação.

## Objetivo

As vendas **4907** (1 item, 8 un) e **4908** (3 itens, 65 un) da Connect (LUNA E CARLOS - DELFINÓPOLIS) serão entregues. Os itens têm data de entrega 21/06/2026 na Connect e, pela regra da SPEC-244, não estão liberados para a Equipe de projetos pedir a separação. A SPEC cria uma liberação manual, registrada e reversível, sem mexer em estoque.

## Decisões aprovadas

- O **Tratar não serve**: a peça ainda não foi entregue; Tratar marca como entregue/baixa estoque. A Reserva fica como está e segue o fluxo normal (Reserva → Ag. separar → entrega).
- Solução: **caminho 2** (exceção manual por item), pedida pelo usuário em 09/11/2026.

## Definição da SPEC

| Item | Peça | Qtd |
|---|---|---|
| 4907 | 10009 EKPF12 - PERFIL DE ALUMINIO - MOVEIS - SOBREPOR - 2 M | 8 |
| 4908 | 10450 ARANDELA BELA FACHO DUPLO 2XE27 - TABACO | 21 |
| 4908 | 11488 ICE ARANDELA DE LUZ GERAL RETANGULAR - 5W - 3000K - BRANCO | 2 |
| 4908 | 11562 LAMPADA LED BULBO 9W - 2700K - BIVOLT | 42 |

- **Tabela** `connect_item_liberacao_manual(projeto_item_id PK, cod_venda_connect, produto_codigo, motivo obrigatório, liberado_por, liberado_em)`. RLS ligada, `anon` sem acesso, leitura só para quem acessa `separacao-parcial`; gravação só pela função.
- **`connect_item_liberado()`**: ganha a 3ª via (existir linha na tabela). As duas vias antigas ficam idênticas à migration 300. Como `registrar_separacao_setor` e a tela já usam essa função, a separação passa a funcionar sem mudança de código.
- **`liberar_vendas_connect(p_vendas integer[], p_motivo text, p_aplicar boolean default false)`**: só Matheus/administração (`pode_tratar_heranca_connect`); `p_aplicar=false` só lista o que faria; motivo obrigatório ao aplicar; idempotente.
- **Não muda**: estoque geral, reservado, saldos por item, financeiro, herança sem cliente. Quem separar depois movimenta Reserva → Ag. separar como em qualquer venda liberada.
- **Rollback**: `rollback.sql` devolve a função à regra da migration 300 e apaga função e tabela.
- Aproximação igual à SPEC-244: item liberado = toda a Reserva dele liberada.
- Atenção operacional: a função usa `auth.uid()`, então rodar direto no banco exige simular o JWT do Matheus/administração (como no `dry_run.sql`).

## Realizado

### 2026-11-09

- SPEC criada; migration 320 ensaiada com ROLLBACK e depois APLICADA (autorizada). Liberação das vendas 4907 e 4908 executada como Matheus: 4 itens liberados; estoque geral, reservado, Reserva e Ag. separar iguais antes×depois. Falta só a conferência visual na Venda Parcial.

## Pendências

- [x] (feito) Migration 320 aplicada e vendas 4907/4908 liberadas.
- [x] Botão "Liberar para separar" na Venda Parcial (Matheus/administração): commit c1b62cb, no ar 09/11 (deploy e80cb0b1).
- [ ] Testar o botão em tela com uma venda Connect bloqueada.
