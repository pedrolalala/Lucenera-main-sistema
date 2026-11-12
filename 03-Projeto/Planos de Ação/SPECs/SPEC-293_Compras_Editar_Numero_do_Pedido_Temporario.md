---
titulo: "SPEC-293 — Compras: editar o número do pedido de compra (temporário), com auditoria e financeiro em dia"
status: pendente (SPEC aprovada nas recomendações; implementação não iniciada)
data_ultima_modificacao: 2026-11-12
sistemas_envolvidos:
  - Compras / Necessidade de Compra (04-Sistemas/compras-lucenera-3o23t98ee) — aba Pedidos
  - Banco (pedidos_compra.numero, set_pedido_compra_numero, financeiro_ponte_pedido, financeiro_titulos, auditoria)
---

# SPEC-293 — Editar o número do pedido (temporário)

**Origem:** solicitação da Débora na Central em 12/11/2026 19:11 ("PERMISSÃO PARA EDIÇÃO DA NUMERAÇÃO DO PEDIDO - TEMPORARIO": "ainda não consigo editar a numeração dos pedidos, no novo sistema, para acertar todos"). O usuário disse que ela já tinha pedido "ontem", mas **não existe registro**: nenhuma solicitação em 11/11 sobre isso, nenhuma SPEC e nenhuma menção nas reuniões 44 a 52 (verificado em 12/11/2026). Tratar como pedido novo.
Nota de numeração: o número 292 foi usado por outra sessão (SPEC-292 da Carol, CRM e Cadastro; migration 346). Esta SPEC é a 293; a migration usará o próximo número livre.

## Checklist de Ação

- [ ] A. RPC `renomear_numero_pedido_compra(p_pedido, p_novo_numero, p_motivo)` (SECURITY DEFINER, `search_path` fixo, `REVOKE ALL FROM PUBLIC, anon`): recusa número vazio ou só espaços, número já existente (comparação sem diferenciar maiúsculas e sem espaços nas pontas) e pedido inexistente; permissão por lista + papel (item B)
- [ ] B. Permissão **restrita**: só a Débora e administradores (lista em `compras_config`, chave `numero_pedido_editavel_por`), com chave liga/desliga `numero_pedido_edicao_ativa` para encerrar o "temporário" sem nova migration; trava de papel com `IS DISTINCT FROM`
- [ ] C. **Qualquer status** do pedido pode ser renomeado (inclusive com NF e financeiro já lançados); pedido `cancelado` também
- [ ] D. Auditoria: número antigo, número novo, quem, quando e motivo (obrigatório); de/para guardado em `backup.spec293_renumeracao_pedidos_compra` para poder desfazer
- [ ] E. Atualizar o que guarda o número como **texto**: `financeiro_titulos.documento` e `descricao` do título do pedido (origem `pedido_compra`) e a observação das parcelas previstas ("Previsão do pedido <nº>"); rótulos gravados em `pagamento_existente_vinculos` (SPEC-290, `pedido_numero`) e em `pagamentos_antecipados.observacao` só se citarem o número do pedido; nada que seja ligado por `id` precisa mudar
- [ ] F. Tela: botão "Editar número" na linha do pedido (só para quem pode) com janela de confirmação mostrando "de → para" e motivo; mensagem clara de erro para número duplicado
- [ ] G. Os 44 pedidos importados da Connect (`NNNN CONNECT`) também podem ser renomeados; o sufixo " CONNECT" deixa de ser obrigatório no número (a origem continua identificável pela observação do pedido)
- [ ] H. A sequência automática (`pedidos_compra_numero_seq`) passa a continuar do **maior número numérico existente**, para o próximo pedido novo não repetir um número da Connect; ajuste de uma vez só e como parte do mesmo ensaio
- [ ] I. Migration + `rollback.sql` + dry-run em ROLLBACK (como Débora, como administrador e como usuário sem permissão e `anon`); aplicar **só com autorização**
- [ ] J. `vite build`, revisor antes do commit, publicar Compras (wrangler), CHANGELOG, `AI_DB_CONTEXT.md`, snapshot

### Passos manuais do usuário
- [ ] Confirmar com a Débora **quais números** quer trocar e para quê (renumerar os pedidos nativos 1790–1803 para os números que a Connect deu? tirar o sufixo CONNECT?). Se ela tiver a lista de-para, uma carga única fica mais segura que 40 edições manuais
- [ ] Débora testar a edição em um pedido de teste e conferir o número no Contas a Pagar
- [ ] Definir quando desligar a chave "temporário"

## Estado verificado (12/11/2026, somente leitura)

- `pedidos_compra.numero` é texto com `UNIQUE (numero)` (`pedidos_compra_numero_uniq`). O trigger `set_pedido_compra_numero` só preenche quando o número vem vazio; o banco **não** impede alterar o número depois. A tela não oferece edição.
- Numeração atual: nativos do sistema 1790 a 1803 (sequência automática); 44 pedidos `NNNN CONNECT` (1733 a 199x, vindos da planilha da Connect) e 51 `PC-LEGADO-…`. Como a Connect continua numerando, os números nativos se sobrepõem aos dela.
- 35 títulos do Contas a Pagar de origem `pedido_compra` guardam o número do pedido como texto.
- Lição da SPEC-268 (orçamentos renumerados em 11/11): o número aparece em PDF, XML, boletos e títulos; sempre ligar por `id` e guardar de/para em `backup`.

## Decisões (recomendações do usuário, 12/11/2026)

1. Só a Débora e administradores editam.
2. Vale para qualquer status do pedido, com os textos do financeiro atualizados e auditoria.
3. Os pedidos `CONNECT` também podem ser renomeados; o sufixo vira só marca de origem.
4. "Temporário" = uma chave de configuração que o usuário desliga; sem data fixa.
5. A sequência automática continua do maior número existente.
6. **Em aberto:** quais números a Débora quer trocar (de/para).

## Riscos / atenção

- Renomear pedido com NF/financeiro lançado muda o texto no Contas a Pagar e nos PDFs/e-mails **já enviados** ao fornecedor continuam com o número antigo; avisar na janela de confirmação.
- Dois pedidos trocando de número entre si (1802 ↔ 1803) esbarram na regra de número único: a RPC aceita um por vez; para trocas cruzadas usar um número temporário ou a carga única.
- A sequência automática não pode retroceder nem repetir número já usado, inclusive os que a Connect ainda vai emitir.

## Rollback

Telas: reverter o commit de Compras. Banco: `rollback.sql` remove a RPC e restaura a sequência; os números já alterados voltam pelo de/para em `backup.spec293_renumeracao_pedidos_compra`.
