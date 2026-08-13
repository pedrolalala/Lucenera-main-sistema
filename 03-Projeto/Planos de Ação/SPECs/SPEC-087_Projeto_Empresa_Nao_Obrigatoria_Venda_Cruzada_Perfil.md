---
titulo: "SPEC-087 — Projeto sem empresa vinculada não pode travar criação; venda cruzada entre perfis"
status: concluído
data_ultima_modificacao: 2026-08-13
sistemas_envolvidos:
  - Orçamentos
  - CRM
dependencias:
  - 03-Projeto/Planos de Ação/SPECs/SPEC-086_Analise_Reunioes_Vinicius_11_08_2026.md (item 2.12)
---

# SPEC-087 — Projeto sem empresa vinculada não pode travar criação; venda cruzada entre perfis

> Origem: reunião com Vinícius, 11/08/2026 (`02-Reunioes/17. Lucenera
> (vinicius) - 11.08.2026_ estruturas falhas do sistema/Reunião.03`,
> [25:24]-[28:34]). Catalogado como item 2.12 na SPEC-086.

## Checklist de Ação

- [x] Localizar a origem real da mensagem "Projeto sem empresa vinculada"
      (Skip reconectado em 2026-08-13, investigação concluída)
- [x] Confirmar que a trava não bloqueia criação de projeto no CRM (não
      existe)
- [x] Confirmar que a seleção de empresa em Orçamentos não é restrita por
      perfil (venda cruzada já é livre)
- [ ] Nenhuma ação de código — ver "Conclusão" abaixo

## Objetivo original

Durante o teste ao vivo, o Vinícius reagiu a uma mensagem "Projeto sem
empresa vinculada" como se fosse uma trava indevida, e pediu que a venda de
uma peça vinculada a um perfil pudesse ser faturada por qualquer uma das
empresas do grupo, sem restrição.

## Investigação (2026-08-13, com o Skip reconectado)

A mensagem **não existe no CRM** — `ProjectNew.tsx`, `ProjectDetail.tsx` e
as Edge Functions `salvar-projeto`/`update-project` não têm nenhuma
validação de empresa; criar um projeto no CRM nunca exigiu isso.

A mensagem real vem de **Orçamentos** (`BudgetFormPage.tsx`,
confirmada na transcrição da reunião de forma imprecisa — o texto exato no
código é "Projeto sem empresa vinculada na origem — selecione manualmente").
Contexto completo:

- `orcamentos.empresa_id` é obrigatório pra **aprovar financeiramente** um
  orçamento (`aprovar_orcamento_financeiro`: `RAISE EXCEPTION 'Orçamento %
  não possui empresa vinculada.'`) porque alimenta `boletos.empresa_id` —
  a nota/boleto emitido precisa saber qual das 3 razões sociais do grupo
  (`empresas`: ISLIGHT, FOCO ILUMINAÇÃO, MANOELLA) está faturando a venda.
  Não é uma trava arbitrária — é um dado necessário pra emissão financeira
  real.
- Quando o orçamento nasce vinculado a um projeto que já tem `empresa_id`,
  o campo é **preenchido automaticamente**.
- Quando o projeto de origem não tem `empresa_id` (995 de 3.703 projetos
  têm hoje), a tela **não trava silenciosamente** — mostra a mensagem
  "Projeto sem empresa vinculada na origem — selecione manualmente" como
  orientação, e libera a seleção manual no dropdown.
- O dropdown de empresa lista as 3 empresas **sem nenhuma restrição por
  perfil** (Ribeirão/São Paulo) — selecionar Manoella pra uma venda "de São
  Paulo" já funciona hoje, não existe trava de venda cruzada.
- Achado de contexto: esse comportamento (auto-preencher + mensagem de
  orientação + card visível do perfil da empresa escolhida) foi adicionado
  pela **SPEC-078**, publicada em 12/08/2026 — um dia depois desta reunião.
  É bem provável que o pedido do Vinícius já tenha motivado essa correção,
  só que sem o vínculo ter sido documentado até agora.

## Conclusão

Os dois pontos pedidos na reunião já estão resolvidos:

1. Empresa nunca travou criação de projeto no CRM (nunca existiu essa
   trava).
2. Venda cruzada entre perfis (peça de um perfil faturada por empresa de
   outro) já é livre em Orçamentos — sem restrição no código.

O único ponto que **continua sendo uma trava de verdade** é a exigência de
`empresa_id` pra aprovar financeiramente um orçamento — mas essa exigência
é proposital (alimenta o boleto/nota real) e não foi o que o Vinícius
reclamou como bug. Fica só como nota: se no futuro isso incomodar de novo,
não é um bug de UI, é uma regra de negócio de faturamento.

## Pendências

Nenhuma. Item encerrado por já estar resolvido — não precisa de
implementação nova.
