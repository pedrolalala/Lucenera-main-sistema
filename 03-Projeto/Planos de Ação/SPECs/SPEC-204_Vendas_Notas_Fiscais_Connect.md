---
titulo: "SPEC-204 — Vendas: Notas Fiscais Connect (importação dos XMLs)"
status: pendente
data_ultima_modificacao: 2026-10-16
sistemas_envolvidos:
  - Vendas
  - Banco (Supabase)
  - scripts (repo central)
---

# SPEC-204 — Vendas: Notas Fiscais Connect (importação dos XMLs)

## Checklist de Ação

- [x] Migration 219: tabelas `notas_fiscais_connect`, `_itens`, `_duplicatas`, `_eventos` com RLS (leitura = sistema Vendas)
- [x] Script `scripts/importar_nfe_connect.py` (idempotente, dry-run por padrão)
- [x] Tela "Notas Fiscais Connect" no Vendas (`/notas-fiscais-connect`), só consulta
- [x] Dry-run: migration + importação dos 22 XMLs de jan/2026 da Manoella, testes de permissão
- [x] Aplicar a migration 219 no Supabase
- [x] Importar os XMLs de jan/2026 (`--aplicar`)
- [x] Publicar o Vendas (push → Cloudflare, `8b0e933`)
- [ ] Conferir a tela logado com usuário real
- [x] CHANGELOG
- [ ] Atualizar `supabase/docs` / `AI_DB_CONTEXT.md` do Vendas

### Passos manuais do usuário

- [x] Colocar os XMLs em `01-Documento/04 - XML/XML NOTA FISCAL/` (jan/2026, Manoella)
- [ ] Próximos meses/empresas: colocar os XMLs na pasta e pedir a importação

## Objetivo

O Vendas é o único lugar onde nota fiscal e boleto são orquestrados a partir de uma venda aprovada (Focus NFe). As notas emitidas até hoje pela Connect ficam fora dele. Esta SPEC abre uma terceira aba, **Notas Fiscais Connect**, com todas as notas da Connect importadas dos XMLs. Começa pela empresa Manoella, janeiro/2026.

## Decisões aprovadas

- Aba nova no Vendas, ao lado de "Vendas" e "Pendências de Nota Fiscal" (pedido do usuário, 15/10/2026).
- Primeira carga: só Manoella, jan/2026 (19 notas nº 4579–4597, 2 cartas de correção, 1 cancelamento).
- Tabelas próprias, separadas de `notas_fiscais` (que é das notas emitidas pela Focus, com fluxo de tentativa/erro).
- Importação pelo script a partir da pasta do repo; a tela é só consulta (sem upload, sem edição).

## Definição da SPEC

### Banco (migration `20261015_219_spec204_notas_fiscais_connect`)

| Tabela | Conteúdo | Chave |
|---|---|---|
| `notas_fiscais_connect` | cabeçalho: chave, número/série, emissão, natureza, emitente (`empresa_id`), destinatário (nome, CPF/CNPJ, IE, cidade/UF, `cliente_id` → `contatos`), totais, pagamento, protocolo, `situacao` (autorizada/cancelada), XML original | `chave_nfe` única |
| `notas_fiscais_connect_itens` | cProd (`codigo_produto`, `produto_id` → `produtos`), descrição, NCM, CFOP, qtd, unitário, total, impostos | (`nota_id`, `numero_item`) |
| `notas_fiscais_connect_duplicatas` | parcelas da cobrança (nDup, vencimento, valor) | (`nota_id`, `numero`) |
| `notas_fiscais_connect_eventos` | carta de correção (110110), cancelamento (110111) | (`chave_nfe`, `tipo_evento`, `sequencia`) |

- `orcamento_id` (nullable) fica pronto para ligar a nota à venda depois; não é preenchido agora.
- RLS: SELECT para `authenticated` com `(SELECT pode_acessar_sistema('vendas'))`; sem política de escrita; `anon` sem grant. Gravação só pelo script (conexão direta).

### Script `scripts/importar_nfe_connect.py <pasta> [--aplicar]`

- Lê `*-nfe.xml` (nfeProc) e `*-procEventoNFe.xml`. Só aceita nota autorizada (cStat 100/150) emitida por empresa do grupo (`empresas.cnpj`).
- Reimportar a mesma chave atualiza a nota e refaz itens/duplicatas (idempotente).
- Cancelamento homologado (cStat 135/136/155) → `situacao = 'cancelada'`, `cancelada_em`.
- Vínculos: `cliente_id` quando o CPF/CNPJ bate com exatamente um contato (não duplicado); `produto_id` por `codigo_produto = cProd`.

### Tela Vendas `/notas-fiscais-connect`

- Cards: notas de venda, valor das vendas, remessas, canceladas (respeitam os filtros). Remessa e cancelada não somam no valor.
- Filtros: busca (número, destinatário, CPF/CNPJ, natureza), empresa, mês, situação.
- Tabela: número, emissão, empresa, destinatário + documento, natureza, nº de itens, valor (riscado se cancelada), situação + selo de carta de correção.
- Clique abre o detalhe: chave, protocolo, destinatário (e se está no cadastro), itens, valores, duplicatas, eventos (texto da correção), informações complementares.

### Critérios de aceite

- Usuário com o Vendas vê as notas; usuário sem o Vendas não vê nada; `anon` recebe permission denied; ninguém altera pela API.
- Jan/2026 Manoella: 19 notas, 141 itens, 18 duplicatas, 3 eventos, 1 cancelada (4590).
- **Só soma no valor a nota de venda autorizada.** Remessa (natureza "REMESSA", envio para transporte/industrialização, sem valor de venda) e cancelada não somam (decisão do usuário 15/10). Jan/2026: 17 notas de venda = R$ 775.116,33 (fica fora a remessa 4591, R$ 8.018,95).

## Realizado

### 2026-10-15

- Migration 219, script e tela escritos. Dry-run completo (migration + importação no mesmo ROLLBACK): 19 notas, 141 itens (todos com peça cadastrada), 18 duplicatas, 3 eventos ligados, 4590 cancelada, R$ 783.135,28 autorizados. anon: permission denied; usuário sem Vendas: 0 linhas; com Vendas: 19/141; UPDATE negado para os dois.
- Só 1 dos 17 destinatários está em `contatos` (2 notas ligadas); os demais ficam com nome/documento da própria nota.
- Aplicado: migration 219 + importação `--aplicar` (mesmos números do dry-run); reimportação = 0 novas, 19 atualizadas.
  Vendas `8b0e933` publicado. No navegador de teste o Vendas não abria porque `https://goskip.dev/skip.js` (script
  síncrono no `index.html` de todos os sistemas) não respondia e travava a página; contornado, o app carrega normal.

## Pendências

- [ ] Conferir a aba Notas Fiscais Connect logado com um usuário do Vendas.
- [x] Devolução de cliente abate do valor das vendas (decisão do usuário 16/10).
- [ ] Islight março/2026 (notas 784–812): a pasta `Islight/Março` é cópia da de fevereiro — pedir os XMLs certos.
- [ ] Definir se/como ligar cada nota da Connect a uma venda (`orcamento_id`) e se destinatários fora do cadastro devem virar clientes.

### 2026-10-15 (ajustes)

- Migration 220 aplicada: leitura também para quem entra no Vendas pelo Hub (`hub_pode_executar`), não só por Acesso a Sistemas — o usuário via a aba vazia.
- Remessa deixa de somar no valor (só venda autorizada soma); selo "Remessa · não soma" na linha.

### 2026-10-16

- Importados fev–set/2026 da Manoella (pastas por mês em `01-Documento/04 - XML/XML NOTA FISCAL/`; script agora lê subpastas). Total: 236 notas (nº 4579–4814, sem buraco), 6 canceladas (4590, 4673, 4722, 4734, 4740, 4777), 18 eventos.
- Ignorados: rascunho sem protocolo do nº 4755 (julho, emitente zerado, R$ 0 — a 4755 real foi importada) e evento "Operação não Realizada" de nota de outro emitente (manifestação de nota recebida). O script agora pula evento de nota de terceiro.
- **Nada do financeiro foi tocado** (pedido do usuário): contadores do banco antes/depois mostram escrita só nas 4 tabelas `notas_fiscais_connect*`; essas tabelas não têm trigger, view nem função ligada.
- Regra de soma: só nota de VENDA autorizada (CFOP 5101–5123/5401–5405 e 6xxx) soma. Remessa, devolução, devolução de compra, retorno de amostra, saída para industrialização e bonificação ficam na lista com o selo "Não é venda · não soma". Vendas `bea828a`. Total de vendas jan–set: 199 notas, R$ 2.894.799,93.
- **Devolução de cliente abate** (decisão do usuário 16/10): nota autorizada de entrada CFOP 1201–1204/1410–1411 (e 2xxx) é descontada do valor das vendas; card "Devoluções de cliente", valor em vermelho com "−" e selo "Devolução · abate". Devolução de compra, remessa, retorno, industrialização, bonificação e compra continuam sem entrar na conta. Script mostra o resumo pela mesma regra (por empresa/mês).
- Correção: a tabela por mês da Manoella informada antes ao usuário usava a regra antiga (só tirava REMESSA); o total R$ 2.894.799,93 estava certo. Manoella jan–set: vendas R$ 2.894.799,93 − devoluções R$ 18.171,73 = R$ 2.876.628,20. Islight (sem março): R$ 3.287.523,39 − R$ 164.945,34 = R$ 3.122.578,05.
- **Islight importada** (pastas por mês em `XML NOTA FISCAL/Islight/`): 191 notas nº 738–958, 9 canceladas (751, 778, 840, 863, 871, 889, 891, 913, 955), 26 eventos. Inutilizações 780–782 e 4141 (procInutNFe) ignoradas. **Março faltando**: a pasta `Março` é cópia idêntica de `fevereiro` (758–783); faltam as notas 784–812. Antes/depois do banco: escrita só nas 4 tabelas `notas_fiscais_connect*` (fora a `sharepoint_sync_state`, sincronização automática não relacionada).

