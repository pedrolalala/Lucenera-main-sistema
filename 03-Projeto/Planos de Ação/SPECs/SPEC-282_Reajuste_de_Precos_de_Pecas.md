# SPEC-282 — Preço das peças: reajuste, regra do orçamento (10 dias) e correção dos valores

**Data:** 11/11/2026 · **Status:** RASCUNHO — Partes A, B e C aguardam respostas (seção 9). A Parte D já foi feita (local).
**Origem:** peça 11412 (Connect/Cadastro R$ 184,49; orçamento ORC-0012 R$ 182,47) e conversa de 11/11 com o usuário.
**Sistemas:** Cadastro, Orçamentos, banco (Supabase São Paulo). Compras não muda.

## 1. Problema, em fatos (banco de 11/11)
1. O orçamento grava `preco_unitario` na hora em que a peça entra e **não acompanha** o cadastro. Quando a peça é reajustada (ST, custo, lucro), o orçamento fica velho.
2. A regra do usuário "orçamento com mais de 10 dias abre pop-up perguntando se quer reajustar" **existe** (SPEC-174 N3, `budget-expiration.ts`, `BudgetPriceUpdateDialog.tsx`) e funciona, mas:
   - olha só o **tempo**, não a mudança de preço (o ORC-0012 tinha 2 dias, não abriu);
   - o número **10 está escrito dentro do código em 5 lugares** (`budget-expiration.ts`; `BudgetFormPage.tsx` na validade padrão, no botão "usar padrão" e na renovação; e no texto do diálogo). Ninguém muda sem programar;
   - 345 de 390 orçamentos não têm `validade` preenchida; para eles vale emissão + 10 dias.
3. Não existe como reajustar várias peças de uma vez, nem histórico de **quem mudou o preço, quando e quanto**. Em 11/11 há itens com preço diferente do cadastro: rascunho 17 (10 peças), Aprovação Financeira 6, enviado ao cliente 24 (19 peças), aprovado 2.331 (esperado: venda fechada).
4. 348 peças foram alteradas em 04/11 (carga Connect), 80 em 05/11 e 57 em 09/11.

## 2. PARTE A — Regra do orçamento explícita e configurável
**Decisão do usuário:** a regra tem de ficar à vista e alterável.
- Nova tabela `orcamento_regras` (chave/valor, RLS, sem `anon`):

| chave | padrão | efeito |
|---|---|---|
| `validade_dias` | 10 | validade padrão = emissão + N dias (hoje fixo no código) |
| `aviso_preco_dias` | 10 | ao editar orçamento com mais de N dias, abre o pop-up "atualizar preços" |
| `aviso_preco_quando_mudou` | ligado | abre o pop-up também quando alguma peça tem preço diferente do cadastro (Parte D) |
| `status_que_avisam` | rascunho, Aprovação da Equipe | em que status o pop-up abre (aprovado e devolução nunca) |

- Tela "Regras do orçamento" no Orçamentos (ação `editar_regras_orcamento`; padrão: admin e quem o usuário indicar), mostrando cada regra com valor atual, quem alterou e quando.
- O código lê os valores uma vez ao abrir, em um único módulo (`budget-regras.ts`); acabam os "10" soltos. Se a leitura falhar, usa 10 (comportamento de hoje).
- Mudar `validade_dias` vale para orçamentos **novos**; o vencimento dos existentes só muda se o usuário pedir (seção 9).

## 3. PARTE B — Sistema de reajuste de preços (Cadastro)
**Escopo (combináveis):** uma peça · marca inteira · marca + categoria (ex.: só LUMINARIA) · fornecedor · lista de peças colada/planilha.
**O que reajusta:** % ST, % IPI, % frete, % desconto do fornecedor, preço de custo (% ou valor novo), % de lucro, preço de venda direto (% sobre o atual).
**Fluxo:** 1) escolhe escopo e regra → **pré-visualização** (peça, antes → depois, quantidade, impacto) sem gravar; 2) confirma → grava numa transação como **lote** (número, autor, data, motivo); 3) **histórico** por peça e por lote; 4) **desfazer lote**.
Conta igual à do Cadastro hoje: líquido = custo − desconto; BDI = líquido × (frete+ST+IPI+despesas); custo total = líquido + BDI; venda = custo total × (1 + lucro); 2 casas.
**Permissão:** ação nova `reajustar_precos` — Vinicius (tudo: em massa e por peça) e quem o usuário indicar. Funções `SECURITY DEFINER`, `REVOKE FROM PUBLIC, anon`; custo continua restrito (SPEC-193).
**Banco:** `produto_reajuste_lote` (id, autor, motivo, escopo jsonb, regra jsonb, criado_em, desfeito_em) e `produto_reajuste_item` (lote, produto, campos antes/depois); funções `reajuste_previa`, `reajuste_aplicar`, `reajuste_desfazer`; trigger de histórico também para edição manual de peça. A carga da Connect não pode desfazer um reajuste do sistema (SPEC-244).

## 4. PARTE C — Corrigir os valores dos orçamentos já existentes
Redefinir `preco_unitario` dos itens para o preço atual do cadastro (`produtos.preco_venda`, mantendo o desconto de cada item) e recalcular total/parcelas só onde for permitido.
- **Proposta:** rascunho e Aprovação da Equipe: corrigir direto, com cópia dos valores antigos (schema `backup`) e prévia antes de gravar.
- **Enviado ao cliente:** não alterar sozinho; o vendedor atualiza pelo pop-up ao reabrir (lista dos orçamentos afetados para o comercial).
- **Aprovação Financeira e Aprovado:** **não alterar** (venda fechada com parcelas/boletos); exceção só por pedido explícito, orçamento a orçamento.
- Entrega: script com prévia (orçamento, peça, antes, depois, diferença no total) → aprovação do usuário → aplicação em transação → conferência (0 itens divergentes no escopo).

## 5. PARTE D — Já feito (Orçamentos, commit `f5ec0b3`, local)
Ao abrir para editar um orçamento não aprovado, o pop-up abre também quando algum item tem preço diferente do cadastro (título "Preço de peças mudou"); não salva sozinho; não repete na sessão. Falta publicar (wrangler) e ligar às chaves da Parte A.

## 6. Já resolvido nesta conversa (referência)
- **SPEC-276:** mensagem "Em uso" do Cadastro diz qual peça já tem a referência (no ar, `fa7fe97`).
- **Migration 327** (rotulada SPEC-277 no CHANGELOG; o número 277 também existe na SPEC do PDF de venda, de outra sessão): código interno da peça = maior código da Connect + 1 (próximo 13800); 4349 → 13798, P883 → 13799. Aplicada.

## 7. Critérios de aceite
A: alterar `validade_dias`/`aviso_preco_dias` na tela muda o comportamento sem deploy; nenhum "10" fixo no código; padrão 10 se a leitura falhar. B: prévia = aplicação; marca+categoria só mexe nas peças da categoria; histórico com autor/data/antes/depois; desfazer devolve; sem permissão não executa (testado em ROLLBACK como `authenticated`). C: no escopo, 0 itens divergentes; aprovado/enviado/financeira intactos; backup dos valores antigos existe. D: orçamento com peça reajustada abre o pop-up.

## 8. Ordem e rollback
Ordem: publicar D → A (banco + tela + leitura) → C com prévia → B (Cadastro). Rollback: A) drop da tabela e volta aos 10 fixos (commit anterior); B) desfazer por lote + drop das tabelas/funções; C) restaurar do backup; D) reverter `f5ec0b3`.

## 9. Perguntas ao usuário
1. Parte C: confirma o escopo (só rascunho e Aprovação da Equipe)? Enviado ao cliente entra?
2. Quem manda no preço: o sistema novo ou a Connect? Quem replica um reajuste na Connect?
3. Rascunho: atualizar sozinho ao abrir ou só avisar (hoje: só avisa e o vendedor confirma)?
4. Quem altera as regras do orçamento (Parte A) e quem reajusta (Parte B) além do Vinicius?
5. Reajuste de custo mantém o % de lucro (venda muda) ou mantém a venda?
6. Mudar os dias de validade vale só para orçamentos novos ou também para os abertos?
7. Desfazer lote: só até a próxima edição manual da peça?

## 10. Documentos a atualizar
CHANGELOG, `AI_DB_CONTEXT.md` do Orçamentos e do Cadastro, `supabase/db/current/` (tabelas novas), Hub (ações novas).
