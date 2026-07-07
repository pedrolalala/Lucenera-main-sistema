# Ata de reunião

- Reunião: 08. Lucenera (Filippo) - 06.07.2026: Gestão de Estoque e Transferência de Materiais
- Data: 2026-07-06
- Duração aproximada: 00:15:19
- Link tl;dv: não informado no arquivo original
- Fonte: transcrição local em `00_original/Reunião_Filippo_Vinicius_Pedro.md`

## Assunto principal

Alinhamento da regra de estoque reservado por cliente, entrega futura, necessidade de compra e transferência de reserva entre clientes.

## Participantes identificados

- Filippo
- Vinícius
- Pedro
- Vitória, Débora e equipe operacional foram citadas como usuárias/responsáveis do processo.

## Áreas envolvidas

- Estoque
- Compras
- Orçamentos
- CRM
- Cadastro
- Logística
- Supabase

## Contexto

- A equipe precisava diferenciar estoque total, estoque disponível, estoque de cliente/itens reservados e entrega futura.
- O processo atual usa consulta de reservas por cliente e solicitações por Teams para Vitória executar transferências.
- O sistema antigo registra que houve transferência, mas não oferece histórico operacional suficiente de movimentação, origem, destino, solicitante e aprovador.

## Fluxo operacional discutido

- Estoque total é a quantidade física.
- Estoque de cliente e itens reservados são o mesmo conceito: quantidade comprometida para clientes específicos.
- Estoque disponível é estoque total menos estoque reservado.
- Entrega futura representa compromisso aprovado sem cobertura física suficiente.
- Necessidade de compra deve ser calculada por produto, sem ficar amarrada ao cliente.
- Transferência de reserva entre clientes precisa registrar quem solicitou, quem aprovou, produto, quantidade, cliente/projeto de origem, cliente/projeto de destino e motivo.
- Quando uma reserva é transferida do cliente A para o cliente B, o cliente A volta a ter necessidade/entrega futura; quando novo material chegar, Débora decide a nova reserva.

## Decisões registradas

- "Estoque de cliente" e "itens reservados" devem ser tratados como sinônimos.
- A reserva precisa continuar vinculada logicamente a cliente/projeto/orçamento, mas a peça física é fungível: não existe uma peça fisicamente "do Filipe" ou "do Pedro".
- A operação de transferência deve ser registrada, não apenas o saldo final.
- A compra de reposição não deve ficar vinculada a um cliente específico.
- A visualização de estoque deve permitir abrir um produto e enxergar quais clientes compõem a reserva.
- A regra de devolução ficou para ser explicada depois da implementação da transferência.

## Problemas e riscos

- Se o sistema só guardar o saldo agregado (`quantidade_reservada`), não é possível auditar de quem saiu e para quem foi uma reserva.
- Se a compra ficar amarrada ao cliente original, o processo quebra quando uma transferência acontece no meio do prazo de compra.
- Há risco de duplicidade conceitual entre "reserva", "estoque de cliente" e "entrega futura" se os nomes não forem padronizados.
- A modelagem precisa diferenciar compromisso ativo de cobertura física; caso contrário, a transferência não consegue dizer quem ficou em entrega futura.

## Encaminhamentos

- Consolidar SPEC-010 como fonte canônica para saldos operacionais por `projeto_item_id`.
- Ajustar SPEC-011 para registrar transferência como operação auditável entre itens de projeto e refletir a mudança de cobertura física entre origem e destino.
- Ajustar SPEC-012 para deixar claro que necessidade de compra é agregada por produto e não por cliente.
- Atualizar escopos e Supabase docs para registrar que as tabelas de saldos/movimentos por `projeto_item_id` ainda não existem no banco real em 06/07/2026.
- Atualizar a SPEC de devolução usando a regra já documentada nos vídeos Connect, mantendo pendentes apenas validações de responsabilidade, financeiro e coleta física.
