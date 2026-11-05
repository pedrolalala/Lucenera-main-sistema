-- Ajuste de dado 05/11/2026 (APLICADO): quantidades da venda Connect 2299 (orçamento CNX-2464), linhas L04. Connect já corrigida pelo Sergio.
BEGIN;
SET LOCAL session_replication_role = DEFAULT;
CREATE TEMP TABLE alvo(pi uuid, oi uuid, cod int, nova numeric) ON COMMIT DROP;
INSERT INTO alvo VALUES
 ('04c3cfe5-9b8c-4c07-ac90-2a0f2482b046','7dca60e7-b160-49ef-ac7e-15c91dde387f',10106,10),
 ('4f9b493f-3b0f-4124-92b6-2dd029b6b25c','ffaa2f8a-786b-4fce-97c2-9af26cc18b0d',11150,4),
 ('8e60435f-6945-4800-8a86-7808b9f8c5d3','916c0686-dbf6-45c8-b831-68cd7a0d0126',12395,4);
SELECT 'ANTES' k, (SELECT valor_total FROM orcamentos WHERE id='d6f605aa-037c-4ef2-a8ea-15316a3d731a') orc_total,
  (SELECT valor_total FROM projetos WHERE id=(SELECT projeto_id FROM orcamentos WHERE id='d6f605aa-037c-4ef2-a8ea-15316a3d731a')) proj_total,
  (SELECT sum(quantidade) FROM estoque_itens) e_qtd, (SELECT sum(quantidade_reservada) FROM estoque_itens) e_res;
UPDATE connect_reserva_ambiente r SET quantidade=a.nova FROM alvo a WHERE r.projeto_item_id=a.pi AND r.tipo='reserva';
UPDATE projeto_itens p SET quantidade=a.nova FROM alvo a WHERE p.id=a.pi;
UPDATE estoque_saldos_projeto_item s SET q_reserva=a.nova FROM alvo a WHERE s.projeto_item_id=a.pi;
UPDATE orcamento_itens o SET quantidade=a.nova FROM alvo a WHERE o.id=a.oi;
SELECT 'DEPOIS' k, (SELECT valor_total FROM orcamentos WHERE id='d6f605aa-037c-4ef2-a8ea-15316a3d731a') orc_total,
  (SELECT valor_total FROM projetos WHERE id=(SELECT projeto_id FROM orcamentos WHERE id='d6f605aa-037c-4ef2-a8ea-15316a3d731a')) proj_total,
  (SELECT sum(quantidade) FROM estoque_itens) e_qtd, (SELECT sum(quantidade_reservada) FROM estoque_itens) e_res;
SELECT a.cod, p.quantidade q_item, s.q_reserva, oi.quantidade q_orc, r.quantidade q_planilha
 FROM alvo a JOIN projeto_itens p ON p.id=a.pi JOIN estoque_saldos_projeto_item s ON s.projeto_item_id=a.pi
 JOIN orcamento_itens oi ON oi.id=a.oi JOIN connect_reserva_ambiente r ON r.projeto_item_id=a.pi AND r.tipo='reserva';
COMMIT;
