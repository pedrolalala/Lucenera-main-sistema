# SPEC-276 — Cadastro: mensagem de referência em uso

**Data:** 11/11/2026 · **Origem:** Central de Solicitações / Débora (peça P883).

## Problema
Peça nova entra no orçamento com a referência só como identificação. Ao cadastrar, a tela mostrava "Em uso" sem dizer qual peça.

## Achado
Não há trava única em `produtos.referencia` (só índice comum). A checagem é da tela (`PecaForm.tsx`). Caso P883: peça 1547276 já existia.

## Entregue
- `findPecaPorReferencia` em `services/produtos.ts`; mensagem cita código e nome da peça. Sem mudança de banco.
- Cadastro publicado (`cadastro-lucenera`), commit `fa7fe97`.

## Pendente
- Confirmar a causa com a Débora.
- Vínculo automático referência do orçamento → peça cadastrada (não existe hoje); precisa de SPEC própria.

## Rollback
Reverter o commit `fa7fe97` e republicar.
