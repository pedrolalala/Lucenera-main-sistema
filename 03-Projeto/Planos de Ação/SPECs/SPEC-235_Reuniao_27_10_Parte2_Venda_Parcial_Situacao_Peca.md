---
titulo: "SPEC-235 — Reunião 27/10 (parte 2): Venda Parcial, ajuste reserva ↔ entrega futura só do Matheus, situação da peça no orçamento, busca de pessoa e NF postergada"
status: não iniciado
data_ultima_modificacao: 2026-10-27
sistemas_envolvidos:
  - Separação Parcial (separacao-parcial) — vira "Venda Parcial"; ajuste reserva ↔ entrega futura da mesma venda
  - Orçamentos (gestao-financeira-clone-544cb) — situação da peça (ativo / fora de linha / lançamento), busca de pessoa por duplo clique
  - Cadastro (cadastro-lucenera-b86fe) — selo "Fora de linha" / "Lançamento", fornecedor da peça, grupo "conversão"
  - Movimentação de Peças (movimentacao-pecas) — tela atualizar após mover de setor
  - Vendas / Contas a Receber — NF emitida depois da venda, parcelas com data a partir da NF, boleto
  - Banco (Supabase SP) — movimentar_peca_venda (permissão), produtos.ativo / status_comercial
---

# SPEC-235 — Reunião 27/10 (parte 2): Venda Parcial, situação da peça e ajustes

> Origem: reunião "39. Lucenera (Vinicius) - 27.10.2026_ andamento do sistema / Reunião.02" (continuação da
> Reunião.01, que virou a SPEC-234).
> Relacionadas: SPEC-224/227 (Movimentação de Peças, `movimentar_peca_venda`), SPEC-098/149 (troca de reserva entre
> projetos), SPEC-231 E1 (busca de pessoa por duplo clique), SPEC-231 F1/F4 (NF no Vendas, sinal no boleto),
> SPEC-234 (C: NF de venda parcial; E: acesso do Matheus; F: Showroom no disponível).

## Checklist de Ação

- [ ] A — Renomear o sistema "Separação Parcial" para **"Venda Parcial"** (é a consulta da venda; a separação parcial é gerada lá dentro).
- [ ] B — Na Venda Parcial, ajuste **reserva → entrega futura** e **entrega futura → reserva** dentro da **mesma venda** (escolher o item/L e a quantidade), só para o **Matheus e administrador**.
- [ ] C — Situação da peça no orçamento: desativada bloqueia; fora de linha só com saldo e até o disponível.
- [ ] D — Selos "Fora de linha" e "Lançamento" na peça (iguais ao de "Desativado").
- [ ] E — Fornecedor da peça aparecer no cadastro/consulta (hoje só a marca aparece).
- [ ] F — Duplo clique na busca de pessoa (igual ao Contas a Pagar/Receber) no Novo Orçamento: cliente, projeto, arquiteto e engenheiro; mostrar CPF/CNPJ e card maior.
- [ ] G — Movimentação de Peças: depois de mover de setor, a tela atualizar os saldos sozinha.
- [ ] H — Excluir o grupo "conversão" (veio da Connect, sem peças).
- [ ] I — NF emitida depois da venda: parcelas com prazo contado da emissão da NF (não urgente; ver seção I).

### Passos manuais do usuário

- [ ] Responder as pendências (principalmente se a troca de reserva **entre** vendas continua liberada para as meninas).
- [ ] Testar a peça 8840 (fora de linha) e uma desativada no Novo Orçamento depois do C.
- [ ] Testar o ajuste B com o Matheus numa venda de teste.

## Objetivo

Dar ao Matheus o ajuste de reserva/entrega futura dentro da venda, na tela onde ele consulta a venda, sem abrir isso para
as vendedoras. Impedir que peça desativada ou fora de linha sem saldo entre em orçamento. Acertar detalhes de cadastro
e de busca que apareceram no teste.

## Decisões aprovadas (reunião 27/10/2026, Vinicius)

### A. "Separação Parcial" vira "Venda Parcial"

- É a consulta da venda do cliente; dentro dela se gera a separação parcial. Muda só o nome do sistema/tela.

### B. Ajuste reserva ↔ entrega futura dentro da mesma venda

- Matheus pega uma quantidade de um item da venda e passa de **reserva para entrega futura** ou de **entrega futura
  para reserva**. É sempre **dentro da mesma venda** (confirmado por telefone com o Matheus na reunião).
- Transferir peça **entre vendas diferentes** continua na outra tela (troca de reserva / Movimentação de Peças).
- Quem pode: **só o Matheus e administrador**. Nem as vendedoras, nem a Vitória.
- Fica na Venda Parcial, porque é a única coisa da movimentação ligada à venda. Desenho livre (ex.: selecionar o item,
  escolher o L, seta Reserva ⇄ Entrega Futura).

### C. Situação da peça no orçamento

- **Desativada:** não entra no orçamento. Bloqueia na hora e avisa que a peça está desativada.
- **Fora de linha com saldo:** pode entrar, limitada à quantidade disponível.
- **Fora de linha sem saldo:** não entra no orçamento.
- Regra interna: peça com saldo não é desativada; ela fica "fora de linha" até acabar o saldo.

### D. Selos na peça

- Fora de linha mostra um selo igual ao de "Desativado" (cartão ao lado). "Lançamento" também ganha selo.
- No teste com a 8840, o "Desativado" apareceu e o "Fora de linha" não.

### E. Fornecedor

- A marca aparece, mas o fornecedor da peça não. Precisa aparecer.

### F. Busca de pessoa no orçamento

- Replicar no Novo Orçamento o duplo clique que abre a busca do cadastro (SPEC-231 E1): **cliente, projeto, arquiteto e
  engenheiro**. Vendedor não precisa.
- No teste (André Pessoa, Enoque) CPF e CNPJ não vieram, e o card precisa ser maior para caber tudo.

### G. Movimentação de setor

- Testado mover 1 da 13442 do Showroom para o Estoque geral: funcionou, mas a tela não atualizou o saldo sozinha.
  (O disponível somar o Showroom é tratado na SPEC-234 F.)

### H. Grupo "conversão"

- Veio da Connect e não tem nenhuma peça. Pode excluir.

### I. NF emitida depois da venda (não urgente)

- Exemplo: venda com 30% de sinal e o resto em 28/56 dias **da emissão da NF**. A NF só é emitida quando o material for
  enviado (ex.: prazo até 23/11), e não no dia da venda.
- A venda já entra com a parcela do sinal e as de 28/56 dias programadas (para aparecer no fluxo de caixa), mesmo sem
  data certa.
- Na emissão da NF (envio total), se as datas das parcelas não baterem com 28/56 dias da NF, ajusta-se no financeiro.
  O Vendas precisa reconhecer as parcelas em aberto para emitir os boletos.
- Ter também a opção de emitir boleto pelo Contas a Receber (como "Financeiro → Boleto → imprimir boleto" da Connect:
  localizar o que o cliente tem em aberto e gerar).
- Não é urgência: boleto só em ambiente de teste até o banco liberar a integração. Envio parcial com NF de venda
  parcial está na SPEC-234 C.

### Sem mudança

- Filtro "só com estoque" na consulta mostra peça com disponível 0: é peça com estoque físico toda reservada. Está certo.
- Nome "luminária de mesa" x "abajur" vem da tabela de preço do fornecedor. O Vinicius não quer mudar.

## Definição da SPEC

### Estado atual (conferido em 27/10)

- `movimentar_peca_venda(p_projeto_item_id, p_acao, p_quantidade, p_motivo, p_baixar_estoque)` já faz
  `reserva_para_entrega_futura`, `entrega_futura_para_reserva` e `separacao_para_reserva` num item (L) da venda. A
  permissão é `_mov_pode()` = admin ou acesso ao sistema `movimentacao-pecas`. **B pode reaproveitar essa função**,
  chamada da Venda Parcial.
- A permissão de B precisa ser **diferente** de `_mov_pode` (só Matheus + admin). Opções: papel/flag próprio ou lista
  de usuários. Decidir na implementação, sem abrir para quem tem só a Movimentação de Peças.
- A troca de reserva **entre projetos** (SPEC-098/149, `pode_trocar_reserva`) está na Separação Parcial para
  projetista/gerente/admin. Não muda por esta SPEC (ver pendência).
- `produtos.ativo` (boolean) e `produtos.status_comercial` (texto: Normal / Fora de Linha / Lançamento; quase todos
  nulos: 4.913 nulos, 3 Normal, 1 Lançamento, 1 Fora de Linha). Nulo = Normal.
- `produtos.fornecedor_principal_id`: preenchido em só **2 de 4.918** peças. A planilha da Connect tem `CodFornecedor` /
  `nmFornecedor`. Depende de importar isso (casar com `contatos` fornecedor), não só da tela.

### Análise de ecossistema

- C/D tocam a busca de peças do Orçamentos (`productCatalogService.ts`) e o Cadastro (`PecaForm.tsx`, `produtos.ts`). A
  trava de C deve estar também no banco (inserção de item de orçamento), não só na tela.
- B mexe em reserva/entrega futura. Precisa manter `estoque_itens.quantidade_reservada` em linha (regra da SPEC-232) e
  passa a aparecer no kardex (SPEC-231 G).
- E: import de fornecedor pela planilha → `scripts/importar_produtos_estoque.py` (ou script novo), rodar com cuidado (o
  UPDATE em massa dispara gatilhos).
- A: renomear em `systems` (Central), título/menu do app e textos. O slug pode ficar o mesmo.

### Critérios de aceite

- Venda Parcial: Matheus passa 1 unidade de reserva para entrega futura e volta. Vendedora e Vitória não veem a ação, e
  o banco recusa se chamarem direto.
- Novo Orçamento: peça desativada é recusada com aviso. Fora de linha sem saldo é recusada. Fora de linha com saldo
  aceita até o disponível e recusa acima.
- 8840 mostra o selo "Fora de linha". Peça em lançamento mostra "Lançamento".
- Fornecedor aparece na peça para as peças que têm fornecedor na Connect.
- Duplo clique em cliente/projeto/arquiteto/engenheiro abre a busca, com CPF/CNPJ.
- Depois de mover de setor, o saldo da tela muda sem recarregar.

## Realizado

- 27/10/2026: SPEC criada a partir da Reunião.02. Conferidos no banco: `movimentar_peca_venda` / `_mov_pode`,
  `produtos.ativo` / `status_comercial` e a cobertura de `fornecedor_principal_id`.

## Pendências

- [ ] A troca de reserva **entre** vendas (SPEC-098/149) continua liberada para as vendedoras? Na reunião o Vinicius disse
      "aqui tá habilitado para as meninas" e "só o Matheus", mas no contexto do ajuste dentro da mesma venda.
- [ ] B: além de reserva ⇄ entrega futura, incluir "separação → reserva" (a função já tem)?
- [ ] E: confirmar a fonte do fornecedor (planilha Connect `CodFornecedor`) e se vale importar para as 4.918 peças.
- [ ] I: desenho do boleto pelo Contas a Receber e do ajuste de datas. Fecha junto com SPEC-231 F4 / SPEC-234 C.
