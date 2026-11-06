-- SPEC-249 chamado 1: devolve a equipe de antes (funcionária sem equipe; orçamentos e reserva em Administração) a partir do backup.
UPDATE public.connect_reserva_ambiente r SET equipe_id = b.equipe_id FROM backup.spec249_moara_reserva b WHERE r.id = b.id;
UPDATE public.orcamentos o SET equipe_id = b.equipe_id FROM backup.spec249_moara_orcamentos b WHERE o.id = b.id;
UPDATE public.funcionarios f SET equipe_id = b.equipe_id FROM backup.spec249_moara_funcionario b WHERE f.id = b.id;
