---
titulo: "SPEC-073 — Módulo de Duplicatas: telas Cadastrar Duplicatas e Baixar Duplicata"
status: implementado (3 botões da toolbar sinalizados como pendentes: Executar, Acordo, Info)
data_ultima_modificacao: 2026-08-11
sistemas_envolvidos:
  - Administração Bancária (retorno-bancario-bradesco-5392a) — 3 telas: Consultar Duplicatas (existente, corrigida), Cadastrar Duplicatas (nova), Baixar Duplicata (nova)
  - Supabase (banco central) — 10 colunas novas em `public.boletos`
dependencias:
  - SPEC-064 (perfil Ribeirão/São Paulo em boletos)
  - SPEC-066 (tipo_operacao/perfil em Notas Fiscais e Boletos)
---

# SPEC-073 — Módulo de Duplicatas: Cadastrar Duplicatas e Baixar Duplicata

> Origem: pedido do usuário com uma especificação detalhada (campo a campo, "verificado por screenshots") de três telas — Consultar Duplicatas, Baixar Duplicata, Cadastrar Duplicatas — pedindo que fossem só **ajustes de interface**, preservando regra de negócio e schema.

## Achado crítico (investigação obrigatória antes de qualquer alteração)

A especificação batia quase campo-a-campo com as colunas de
`staging_conta_pagar`/`staging_conta_receber` — as tabelas de staging da
importação do sistema legado **Connect**. Ou seja: a especificação descreve
as telas do sistema antigo, que a versão nova (Supabase) só reconstruiu
parcialmente:

- **Consultar Duplicatas** (`ConsultarDuplicatas.tsx`) já existia e batia
  quase exatamente com a spec — mas os botões "Editar", "Executar",
  "Acordo", "Exportar" e "Info" não tinham nenhum `onClick` (só "Localizar"
  funcionava).
- **Baixar Duplicata** não existia como tela.
- **Cadastrar Duplicatas** não existia como tela (só um Dialog simples
  "Novo Boleto" em `Boletos.tsx`, com campos bem mais simples).

Isso foi reportado ao usuário antes de codar (contradiz "só interface" —
são 2 telas novas). Usuário confirmou: construir as duas telas do zero.

Em seguida, comparando os campos pedidos com o schema real de
`public.boletos`, vários campos não tinham onde gravar (Juros, Desconto,
Forma de Pagamento, Bandeira, Linha Digitável, Responsável, Referência,
Observação, Apropriação). Isso contradiz a instrução "não alterar
estrutura de banco de dados" — reportado de novo, usuário autorizou
explicitamente adicionar as colunas.

## Migration aplicada (`20260811_095_spec073_duplicatas_cadastro_baixa`)

10 colunas novas em `public.boletos`, todas aditivas/nullable (zero risco
pras linhas existentes):

| Coluna | Tipo | Uso |
|---|---|---|
| `apropriacao_id` | uuid → `plano_de_contas(id)` | Apropriação (nível 3, folha) |
| `conta_bancaria_id` | uuid → `contas_bancarias(id)` | Campo "Conta" |
| `forma_pagamento` | text | Boleto/PIX/Dinheiro/Cartão/Transferência |
| `bandeira` | text | Só relevante se forma_pagamento = Cartão |
| `linha_digitavel` | text | Linha digitável do boleto |
| `juros_multa` | numeric default 0 | Baixa |
| `desconto` | numeric default 0 | Baixa |
| `responsavel_id` | uuid → `usuarios(id)` | Campo "Responsável" |
| `referencia` | text | Campo "Referência" |
| `conta_grupo_id` | uuid | Agrupa as parcelas geradas juntas em "Gerar Conta" |
| `observacao` | text | Campo "Observação"/"Observações" (faltava até em Boletos.tsx) |

**Achado sobre Apropriação/Grupo/Sub grupo**: `plano_de_contas` já é
hierárquico em exatamente 3 níveis (nível 1 = Grupo, nível 2 = Sub Grupo,
nível 3 = Apropriação/folha, confirmado via `SELECT ... GROUP BY nivel`) —
por isso só precisou de UMA FK (`apropriacao_id`, sempre um registro nível
3); Grupo/Sub Grupo na tela são 2 selects em cascata que filtram pelo
`parent_id`, sem coluna própria.

**Achado sobre Conta**: `contas_bancarias` já existia com os campos certos
(nome, banco, agência, conta) — só faltava a FK em `boletos`.

## Telas novas

### Cadastrar Duplicatas (`src/pages/CadastrarDuplicata.tsx`, rota `/cadastrar-duplicata`)

- Seção **Gerar Conta**: todos os campos da spec (Data emissão, Tipo,
  Operação, Empresa, Perfil Empresa, Código [readonly, gerado ao salvar],
  Responsável, NF, Referência, Tipo pessoa, Código [do contato, readonly],
  Fornecedor/Cliente, Grupo/Sub grupo/Apropriação em cascata,
  Situação, Conta, Observação).
- Seção **Gerar Parcelas**: N° Parc (total planejado), Parcela (próxima a
  adicionar, readonly), Dia, Venc 1° Parc, botão (+) que adiciona uma linha
  por vez na grade (Parcela/Valor/Vencimento/Linha Digitável, todos
  editáveis), até atingir N° Parc. Vencimento sugerido automaticamente
  (1ª parcela = Venc 1° Parc; demais = mesmo Dia, +1 mês por parcela) mas
  editável linha a linha.
- **Nota de interpretação**: a spec não deixa 100% claro se "N° Parc" e
  "Parcela" são um total pré-definido ou um contador livre — sem as
  screenshots referenciadas, adotei a leitura mais literal do botão "de
  adicionar parcela (+)" (singular): adiciona uma parcela por clique,
  respeitando o total de N° Parc.
- Salvar grava N linhas em `boletos`, todas com o mesmo `conta_grupo_id`
  novo (ou reaproveitado, se estiver editando).
- Suporta edição: `?id=<conta_grupo_id>` carrega as parcelas existentes do
  grupo e permite adicionar/remover/alterar antes de salvar (salvar recria
  o grupo inteiro — mais simples e seguro que casar linha a linha).

### Baixar Duplicata (`src/pages/BaixarDuplicata.tsx`, rota `/baixar-duplicata`)

- Aberta via **Exportar** em Consultar Duplicatas, recebendo as duplicatas
  já marcadas na grade (`navigate('/baixar-duplicata', { state: { ids }})`)
  — se nenhuma estiver marcada, abre vazia com sua própria busca interna
  (Tipo, Empresa, Fatura, Boleto, Tipo situação) e grade de seleção.
  local.
- Seção "Dados da Baixa" com os campos da spec (Grupo/Sub grupo/
  Apropriação, Situação, Forma de pgto., Bandeira, Conta, Linha Digitável,
  Data Pagamento, Juros e multas, Descontos, Observações) — aplicados a
  **todas** as duplicatas marcadas de uma vez.
- Salvar calcula `valor_pago = valor + juros − desconto` **por duplicata**
  (não um valor único pro lote) e faz `UPDATE` em cada `boletos` marcada.
- Grade inferior "Duplicatas baixadas nesta sessão" mostra o resultado de
  cada baixa feita (session-local, não é histórico persistido separado —
  `boletos` já é o registro permanente).

### Consultar Duplicatas — botões ligados

- **Editar**: exige exatamente 1 duplicata marcada; navega pra Cadastrar
  Duplicatas em modo edição do grupo dela. Duplo-clique na linha faz o
  mesmo direto (mesmo padrão de duplo-clique adotado em todo o ecossistema
  nesta sessão).
- **Exportar**: navega pra Baixar Duplicata com as duplicatas marcadas.
- **Localizar**: já funcionava (recarrega os dados).
- **Executar, Acordo, Info**: **não implementados** — sinalizados com um
  toast "ainda não implementado". Nenhum lugar do sistema (nem a spec
  fornecida) deixa claro o que essas 3 ações devem fazer especificamente;
  inventar a regra de negócio contradiria a instrução explícita de não
  alterar/inventar lógica de negócio. Ver Pendências.

## Escopo do que NÃO foi alterado

- Nenhuma regra de cálculo existente (juros/desconto são novos campos, não
  alteram nada pré-existente).
- Nenhuma coluna/tabela removida ou renomeada.
- `ConsultarDuplicatas.tsx`: só os botões ganharam `onClick` e a linha
  ganhou seleção/duplo-clique — filtros, grade, rodapé e aba "Baixado"
  continuam exatamente como estavam (já batiam com a spec).
- `Boletos.tsx` (Controle de Boletos, tela separada de "Duplicatas") não
  foi tocado.

## Pendências

- [ ] **P-1**: definir o que os botões "Executar" e "Acordo" devem fazer
  (não há equivalente identificável no restante do sistema).
- [ ] **P-2**: definir o conteúdo do botão "Info" (info de quê — da
  duplicata selecionada? do sistema?).
- [ ] **P-3**: confirmar a interpretação de "N° Parc"/"Parcela" em Gerar
  Parcelas (ver nota de interpretação acima) — se o comportamento
  esperado for diferente (ex.: split automático de um valor total em N
  parcelas iguais), ajustar.
- [ ] **P-4**: aba "Baixado" em Consultar Duplicatas continua mostrando
  placeholder estático ("Selecione uma duplicata..." — não foi conectada a
  dado real, estava fora do escopo reportado desta rodada).
