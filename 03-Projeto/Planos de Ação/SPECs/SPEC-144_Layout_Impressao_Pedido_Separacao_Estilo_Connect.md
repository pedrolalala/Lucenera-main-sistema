---
titulo: "SPEC-144 — Layout de impressão do Pedido em Separação no estilo do documento Connect"
status: concluído
data_ultima_modificacao: 2026-09-15
sistemas_envolvidos:
  - Separação (separacao-parcial) — `SeparacaoParcialPage.tsx` (`imprimirListaSeparacao`), `separacaoParcialService.ts`
---

# SPEC-144 — Layout de impressão do Pedido em Separação no estilo do documento Connect

> Origem: usuário anexou `01-Documento/01 - Planilhas/PD 5607.7462 ISLIGHT 1 (1).pdf` (documento real do sistema legado Connect, "PEDIDO EM SEPARACAO - VENDAS - VENDAS") e pediu pra usar como base pro layout da nossa impressão, acrescentando informações que hoje não aparecem no impresso atual (`imprimirListaSeparacao()`).

## Checklist de Ação

- [x] Estender `buscarVendaPorNumero()` (`separacaoParcialService.ts`) pra trazer `orcamentos.data_emissao`, `empresas.nome` (via embed `orcamentos.empresa_id`), `funcionarios.nome` (via embed `orcamentos.vendedor_id`), e os campos de endereço/documento do cliente em `contatos` (`cpf_cnpj`, `telefone`, `celular`, `endereco`, `numero`, `bairro`, `cidade`, `estado`) — antes só buscava `id/nome/razao_social`.
- [x] Adicionar esses campos na interface `VendaInfo`.
- [x] Reescrever `imprimirListaSeparacao()` (`SeparacaoParcialPage.tsx`) pro layout novo (ver "Definição" abaixo), mantendo a função de gerar+abrir impressão automaticamente ao confirmar "Separar" (comportamento da SPEC-091, não alterado).
- [x] Verificado com dado real (ORC-0032/VINICIUS BORTOLIN, via REST API direto — psql estava com falha de DNS transitória na hora): `empresa.nome = "FOCO ILUMINACAO"`, `vendedor.nome = "Thairine Cristina da Silva"`, cliente com `cpf_cnpj/telefone/numero` NULL — confirmado que os fallbacks (`-`) funcionam corretamente com dado incompleto real.
- [x] Preview renderizado localmente (fora do app, servidor HTTP temporário no scratchpad) com os dados reais acima + os 2 itens do PDF de referência — layout conferido visualmente (cabeçalho, dados do cliente, tabela, assinaturas). Não foi feito teste clicando "Separar" de verdade no app (mudaria estoque real de uma venda real) — se quiser conferir a impressão gerada pelo app em produção, o teste real é clicar "Separar" numa venda de teste.
- [x] `npx tsc --noEmit` + `npx oxlint src` (sem warnings novos) + `npm run build` locais, depois `skip_project_apply_changes` (QA 100% verde) + `skip_project_publish` — Skip 48801, v0.0.38 e v0.0.39 (fix de charset), `https://separacao-parcial-dff01.goskip.app`.

### Passos manuais do usuário

- [ ] Nenhum previsto — não altera schema (todos os campos usados já existem em `orcamentos`/`empresas`/`funcionarios`/`contatos`).

## Objetivo

A equipe de expedição/conferência já conhece o layout do pedido de separação do Connect (documento físico usado há anos). A tela de Separação Parcial já gera uma impressão (SPEC-091), mas com um layout próprio, mais simples, que não inclui vários dados que o documento antigo tinha (dados completos do cliente, empresa/marca da venda, vendedor, data do orçamento). Objetivo: aproximar o layout impresso do documento de referência do Connect, mantendo os dados que já existem no nosso banco.

## Decisões aprovadas

- **Número do "pedido" (topo esquerdo)**: no Connect era um único número (`05607/07462`). Na nossa versão, mostra dois números que já existem no sistema, sem criar nenhuma sequência nova: **`{orcamentoNumero}-P{n} / {vendaNumero}`** (ex.: `ORC-0032-P2 / VENDA-0001`) — o primeiro é o código da parcial (mesmo que já aparece em tela, em "Parciais desta venda"), o segundo é o número da venda (SPEC-136). Confirmado com o usuário via pergunta direta (2026-09-15).
- **Nome da empresa (linha abaixo do título, "ISLIGHT" no documento original)**: achado importante — "ISLIGHT" **não é um nome de sistema legado genérico pra trocar por "LUCENERA"**. É o nome de uma das empresas/marcas reais do grupo: `orcamentos.empresa_id` tem comentário no schema "ÂNCORA: Define se a venda é Foco, Manoella ou Islight. Todo o fluxo financeiro e de estoque herdará este ID." — ou seja, cada orçamento pertence a uma dessas empresas, e o documento deve mostrar a empresa **real** daquela venda (`empresas.nome`), não um nome fixo.
- Título do documento ("PEDIDO EM SEPARACAO - VENDAS - VENDAS") mantido como no original — é um título de formulário genérico, não específico do Connect, reconhecível pela equipe.
- Coluna de fabricante/fornecedor (lado direito da tabela de itens, ex. "INTERLIGHT SISTEMAS DE") **não será reproduzida nesta rodada** — `produtos` não tem fabricante/fornecedor por peça vinculado de forma direta e confiável (tem `fornecedor_principal_id`, mas não foi confirmado que reflete o fabricante real de cada peça); fica como possível melhoria futura, não bloqueia esta SPEC.

## Definição da SPEC

### Layout alvo (baseado no PDF, adaptado aos nossos dados)

```
{orcamentoNumero}-P{n} / {vendaNumero}         PEDIDO EM SEPARACAO - VENDAS - VENDAS      Impressão: {data/hora atual}
{empresa.nome}                                                                             Data orçamento: {orcamentos.data_emissao}
                                                                                             Previsão de Entrega: {dataEntrega informada, ou "A combinar"}

Nome.....: {cliente.cpf_cnpj} {projetoCodigo} {clienteNome}          Telefone: {cliente.telefone || cliente.celular}
Endereco.: {cliente.endereco}, {cliente.numero}                      Bairro: {cliente.bairro}
Cidade...: {cliente.cidade}-{cliente.estado}                         Vendedor: {funcionarios.nome}

Código | Referência | Descrição                          | Qtd.
{item.codigo} | {item.referencia} | {item.descricao}      | {item.quantidade}
  (mantém a coluna "Local (L)" que já existe hoje — equivalente à coluna "Codigo"=L85 do Connect)

Total de itens: N          Total de peças: M

Observações: ____________________
             ____________________

_____________________          _____________________
Conferido: Ass. Conferente      Data/Hora

"ASSUMO TOTAL RESPONSABILIDADE PELAS MERCADORIAS CORRESPONDENTES A ESTA ENTREGA,
BEM COMO DECLARO CORRETO O CONTEÚDO E QUANTIDADES MENCIONADAS ACIMA."

_____________________          _____________________          _____________________
Conferido: Ass. Conferente      RG/CPF                          Data/Hora
```

Diferenças conscientes em relação ao Connect:
- Mantém a coluna "Local (L)" (já existente, equivalente à antiga "Codigo"=L85) e o checkbox de conferência física por linha (já existente na versão atual, útil operacionalmente, o Connect não tinha).
- Campos vazios (ex. cliente sem CPF cadastrado, sem endereço) mostram "-" em vez de ficar em branco cru ou aparecer "null"/"undefined".
- Quando `empresa.nome` não existir (orçamento sem `empresa_id`, casos antigos), cai para um texto neutro tipo "LUCENERA" como fallback — não deixar em branco.

### Dados novos a buscar em `buscarVendaPorNumero()`

| Campo | Origem | Uso |
|---|---|---|
| `empresaNome` | `orcamentos.empresa_id` → `empresas.nome` | Linha abaixo do título |
| `dataEmissao` | `orcamentos.data_emissao` | "Data orçamento" |
| `vendedorNome` | `orcamentos.vendedor_id` → `funcionarios.nome` | "Vendedor" |
| `clienteCpfCnpj` | `contatos.cpf_cnpj` | "Nome....." |
| `clienteTelefone` | `contatos.telefone` (fallback `celular`) | "Telefone" |
| `clienteEndereco/Numero/Bairro/Cep/Cidade/Estado` | `contatos.*` | "Endereco"/"Bairro"/"Cidade" |

Todos opcionais (`string \| null`) — nenhum é obrigatório pra imprimir (venda pode ter cliente com cadastro incompleto).

## Realizado

### 2026-09-15

- SPEC criada, decisões de mapeamento de número/empresa confirmadas com o usuário.
- Implementado, testado com dado real via REST API, e publicado (Skip 48801, `https://separacao-parcial-dff01.goskip.app`, v0.0.39).
- Commitado no submodule `separacao-parcial` (`b994339`).

## Pendências

- [ ] Teste clicando "Separar" de verdade numa venda real (ou de teste), pra conferir a impressão exatamente como o app gera no navegador do usuário — não feito nesta rodada porque alteraria estoque real; a verificação até aqui foi via preview local com os mesmos dados/template.
- [ ] Coluna de fabricante/fornecedor por peça (presente no PDF do Connect) — decisão consciente de não incluir nesta rodada (ver "Decisões aprovadas"), pode virar SPEC futura se o usuário quiser.
