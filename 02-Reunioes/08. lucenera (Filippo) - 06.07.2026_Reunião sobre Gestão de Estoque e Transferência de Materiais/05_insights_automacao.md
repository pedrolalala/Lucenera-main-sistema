# Insights de automação

- Reunião: 08. Lucenera (Filippo) - 06.07.2026: Gestão de Estoque e Transferência de Materiais
- Data: 2026-07-06
- Duração aproximada: 00:15:19
- Fonte: transcrição local em `00_original/Reunião_Filippo_Vinicius_Pedro.md`

## Oportunidades extraídas

- Tela de produto com abas de disponível, reservado por cliente, entrega futura, transferência e necessidade de compra.
- Solicitação de transferência no sistema substituindo pedido solto no Teams.
- Fila de aprovação de transferência para Vitória.
- Alerta para Débora quando uma transferência cria reposição pendente.
- Histórico auditável de transferências por produto/cliente/projeto/equipe.
- View agregada de necessidade de compra por produto, sem travar compra a cliente.
- Badges no CRM mostrando item aprovado como reservado, entrega futura, entregue ou cancelado.

## Observação de uso

Antes de transformar esses insights em código, validar a modelagem em SPEC. O ponto mais sensível é separar compromisso ativo de cobertura física: sem isso o sistema não sabe dizer quem ficou em entrega futura depois de uma transferência.
