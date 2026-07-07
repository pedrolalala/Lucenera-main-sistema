# Decisões e pendências

- Reunião: 08. Lucenera (Filippo) - 06.07.2026: Gestão de Estoque e Transferência de Materiais
- Data: 2026-07-06
- Duração aproximada: 00:15:19
- Fonte: transcrição local em `00_original/Reunião_Filippo_Vinicius_Pedro.md`

## Decisões registradas

- Estoque de cliente e itens reservados são o mesmo conceito.
- Estoque disponível deve ser calculado como estoque físico menos estoque reservado.
- Estoque reservado precisa ser rastreável por cliente/projeto/orçamento.
- A peça física é fungível; o que precisa ser rastreado é o compromisso e a operação.
- Transferência de reserva precisa ser uma operação registrada e auditável.
- A compra de reposição/necessidade de compra não deve ficar vinculada a um cliente específico.
- Débora precisa visualizar pendências de reposição/re-reserva quando material chegar.

## Pendências / próximos passos

- Consolidar a modelagem de saldos operacionais por `projeto_item_id`, evitando duplicar produto/projeto/orçamento/cliente na tabela de saldo vivo.
- Representar "cobertura física" versus "entrega futura" por campos de saldo (`q_reserva`, `q_entrega_futura`) do item de projeto.
- Definir permissões: quem solicita transferência e quem aprova.
- Definir visualização para Vitória e Débora.
- Definir retenção/consulta do histórico de transferências; a reunião cita necessidade operacional de consulta e exemplo de 3 meses.
- Usar os vídeos Connect como regra base da devolução (`E. Futura → Reserva → Entregue`) e validar apenas responsáveis, efeitos financeiros e coleta física.
- Validar se a nomenclatura no frontend será "Reservado", "Estoque de Cliente" ou ambas com alias.

## Impacto nas SPECs

- SPEC-010 deve ser a fonte canônica dos saldos operacionais por `projeto_item_id`.
- SPEC-011 deve registrar transferência como operação entre `projeto_item_id` de origem e destino, não apenas como ajuste de saldo.
- SPEC-012 deve reforçar que necessidade de compra é agregada por produto e sem vínculo fixo com cliente/projeto.
- SPEC-013 deve ser tratada como absorvida pela SPEC-010, sem migration própria.
- SPEC-014 depende da view de saldos por item para exibir badges corretos no CRM.
- SPEC-015 usa a regra dos vídeos Connect para devolução e mantém pendentes apenas aprovação, financeiro e coleta física.
