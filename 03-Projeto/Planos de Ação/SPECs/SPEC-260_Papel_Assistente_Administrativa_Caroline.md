---
titulo: "SPEC-260 — Papel próprio da assistente administrativa (Caroline), sem ser Admin"
status: aplicada
---

# SPEC-260 — Papel `assistente_administrativa`

> Pedido (08/11/2026, solicitação "ACESSO CONTAS A PAGAR E RECEBER - CAROLINE"): dar acesso ao financeiro sem ser Admin geral, com um papel só dela, como a Débora tem o dela, baseado no que ela já acessa.

## Situação encontrada
- Acesso a Sistemas (cards): já tinha `contas-pagar` e `contas-receber` desde 06/11 18:51, mais 8 outros (cadastro, garantia, produção, financeiro, necessidade de compra, orçamentos, solicitações, vendas).
- Papéis: **`admin`** (o mesmo de Pedro/Filippo/Vinicius) + `administracao_comercial`. `usuarios.role` = funcionario.
- Dados do financeiro no banco são protegidos por `pode_acessar_sistema('financeiro')` (Acesso a Sistemas), não pelo papel admin.

## O que foi feito (migration 311, aplicada 08/11/2026)
- [x] Papel novo `assistente_administrativa`: todas as ações em financeiro, contas-pagar, contas-receber, vendas, orçamentos, necessidade-de-compra, cadastro; só `visualizar` em controle-garantia e controle-producao; `criar`+`visualizar` em solicitações (**sem aprovar**).
- [x] Caroline: ganha `assistente_administrativa`, **perde `admin`**, **mantém `administracao_comercial`** (`pode_editar_caixa_fechada` depende dele).
- [x] Acesso a Sistemas não mudou.
- Verificado com `hub_pode_executar`: financeiro/contas/vendas/orçamentos/cadastro = sim; editar garantia, aprovar solicitação, RH, dashboard financeiro = não.

## Não muda / observação
- Salário e comissão (títulos `especie` salario/comissao) só aparecem com acesso a `rh`; ela não tem.
- Telas que checam `usuarios.role = admin` já não davam privilégio a ela (role = funcionario).

## Rollback
`supabase/db/migrations/20261108_311_spec260_papel_assistente_administrativa/rollback.sql` (devolve o papel admin e apaga o papel novo).
