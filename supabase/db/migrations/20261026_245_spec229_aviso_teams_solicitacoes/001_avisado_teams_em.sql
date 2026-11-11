-- SPEC-229: aviso no Teams quando entra solicitação nova.
-- A Edge Function classificar_solicitacao manda o aviso só quando
-- avisado_teams_em está vazio e o pedido foi criado há menos de 1 hora, e grava
-- a data. Assim editar o pedido (que chama a mesma função) não manda de novo,
-- e pedido antigo nunca vai para o Teams (sem precisar preencher as linhas velhas).

alter table public.solicitacoes
  add column if not exists avisado_teams_em timestamptz;

comment on column public.solicitacoes.avisado_teams_em is
  'SPEC-229: quando o aviso de pedido novo foi enviado ao Teams. Preenchido só pela Edge Function classificar_solicitacao.';
