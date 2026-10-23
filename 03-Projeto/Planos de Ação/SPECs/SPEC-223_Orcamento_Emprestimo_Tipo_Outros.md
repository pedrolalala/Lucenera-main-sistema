---
titulo: "SPEC-223 — Orçamento de empréstimo (Tipo de Operação: Outros → EMPRÉSTIMO), com devolução e virar venda"
status: implementado (falta teste do usuário)
data_ultima_modificacao: 2026-10-23
sistemas_envolvidos:
  - Orçamentos (gestao-financeira-clone-544cb) — Novo Orçamento, lista de orçamentos, detalhe
  - Showroom (showroom-qtq8er2dk) — aba Empréstimos do /admin (SPEC-219), passa a mostrar também os empréstimos feitos pelo orçamento
  - Cadastro (cadastro-lucenera-b86fe) — linha "Amostra / Emprestado" nos Setores da peça
  - Banco (Supabase SP) — showroom_emprestimos* (SPEC-219), orcamentos, aprovar_orcamento_financeiro
---

# SPEC-223 — Orçamento de empréstimo dentro do Novo Orçamento

> Origem: pedido do usuário (22/10/2026): "colocar a mesma funcionalidade [do empréstimo do Showroom] dentro de um novo
> orçamento, tipo de operação: Outros, dentro de Tipo abrir essa opção, com a mesma lógica, podendo transformar um
> orçamento de empréstimo em venda, e devolução também caso o cliente queira devolver".
> Base: SPEC-219 (empréstimo no /admin do Showroom, migrations 231/232) e
> `02-Reunioes/35. Lucenera (Vinicius) - 22.10.2026_ Reuniões gerais/Reunião.03` ([00:00]–[05:09]).

## Objetivo

Hoje o empréstimo de peça só existe no /admin do Showroom (SPEC-219). O comercial monta tudo no Novo Orçamento e o
Vinicius pediu um **"orçamento de empréstimo"**: o cliente leva várias peças, sabe o valor de cada uma, assina o termo e
depois **devolve tudo**, **devolve uma parte e fica com o resto** ou **fica com tudo**. O que ele ficar vira **venda**
(aí sim baixa estoque e gera financeiro). Exemplo dele: Casa Cor — as peças decorativas entram como empréstimo e
continuam disponíveis.

Esta SPEC coloca o empréstimo no Novo Orçamento como mais uma opção do campo **Tipo** quando o Tipo de Operação é
**Outros**, usando **o mesmo registro, termo, fotos e devolução** da SPEC-219 — um empréstimo só, visto pelos dois
lados (Orçamentos e /admin do Showroom).

## O que o Vinicius disse (Reunião.03)

1. "Um orçamento de empréstimo é um empréstimo, material é nosso ainda." Sai do setor em que estiver (estoque geral ou
   showroom), vai para o setor empréstimo e **o saldo disponível permanece**.
2. "Não mexe no valor, no número de itens do estoque, não gera financeiro, não gera nada."
3. Três situações: devolve tudo (volta para os setores de origem); fica com uma parte (dá baixa nas outras e a parte
   que ficou vira venda); fica com tudo (o orçamento de empréstimo vira orçamento de venda: baixa estoque, gera
   financeiro).
4. Peça devolvida quebrada ou com defeito: o cliente arca com o prejuízo (já está no termo da SPEC-219).

## Como está hoje (conferido no código e no banco em 22/10)

- **Tipo de Operação** no Novo Orçamento (`BudgetFormPage.tsx`): Venda, Devolução, Outros e SAC
  (`orcamentos.natureza_operacao`). O campo **Tipo** (`orcamentos.subgrupo`) tem uma lista fixa por operação
  (`SUBGRUPOS_POR_TIPO`); em Outros: CASA COR SAIDA, REMESSA TRANSP, RETORNO, TRANSFERENCIA, GARANTIA, BONIFICACAO etc.
  **Não existe EMPRÉSTIMO.**
- **Risco atual:** `aprovar_orcamento_financeiro` só tem caminho próprio para `devolucao`; **qualquer outro tipo
  (inclusive Outros) é aprovado como venda** — cria reserva, entrega futura (abre necessidade de compra), parcelas e
  boletos. Por isso o empréstimo **não pode** passar pela aprovação financeira.
- **Empréstimo do Showroom (SPEC-219):** tabelas `showroom_emprestimos` / `_itens` / `_fotos`, número `EMP-0001`,
  termo em PDF, fotos obrigatórias na saída e na volta, devolução peça a peça (OK / com dano, valor integral), status
  calculado (Em aberto, Atrasado, Devolvido, Devolvido com dano, Cancelado). **Estoque não muda.** As RPCs
  `showroom_emp_*` só funcionam com a credencial do /admin e só para `anon` — o Orçamentos (usuário logado,
  `authenticated`) não consegue chamá-las. Hoje há 2 empréstimos, os dois cancelados (testes).
- **Estoque:** a reserva de venda olha só `estoque_itens` local `Estoque`. O setor **"Amostra / Emprestado"** já aparece
  (zerado) nos Setores da peça no Cadastro (SPEC-174 N6c), lido de `estoque_itens` local de mesmo nome — que hoje não
  tem nenhuma linha.

## Decisões (confirmadas em 23/10 — ver "Pontos confirmados")

1. **Um empréstimo só, dois lugares.** O orçamento de empréstimo grava no mesmo `showroom_emprestimos` (coluna nova
   `orcamento_id`). Mesmo número `EMP-`, mesmo termo, mesmas fotos, mesma devolução. O /admin do Showroom lista os dois
   (com a origem: "Showroom" ou "Orçamento ORC-xxxx").
2. **Estoque e disponível não mudam** (igual à SPEC-219 e ao que o Vinicius disse do disponível). A peça emprestada
   continua contada no estoque geral / showroom e continua vendável; o setor "Amostra / Emprestado" passa a mostrar
   **quanto está emprestado e com quem**, como informação (lido dos empréstimos em aberto, não de `estoque_itens`).
3. **Não passa pela aprovação financeira.** Não gera reserva, entrega futura, necessidade de compra, parcela nem boleto.
4. **Devolução** = a devolução da SPEC-219 (peça a peça, com foto, OK ou com dano). **Não** é o Tipo de Operação
   "Devolução" (esse é crédito de uma venda e não se aplica aqui).
5. **Virar venda** cria um **orçamento de venda novo**, ligado ao empréstimo, só com as peças que o cliente ficou. Esse
   orçamento segue o fluxo normal (aprovação do cliente → aprovação financeira → financeiro).

## Definição

### Banco (migration nova, número livre na hora de implementar)

**`showroom_emprestimos`** (colunas novas)

| coluna | tipo | obs. |
|---|---|---|
| orcamento_id | uuid FK `orcamentos` NULL, único | preenchido quando o empréstimo nasceu de um orçamento |
| origem | text CHECK (`showroom`, `orcamento`) default `showroom` | |
| projeto_id | uuid FK `projetos` NULL | do orçamento, quando houver |

**`showroom_emprestimo_itens`**

- `situacao` ganha o valor **`convertido_venda`** (cliente ficou com a peça).
- Coluna nova `orcamento_venda_id` (uuid FK `orcamentos`) — o orçamento de venda para onde a peça foi.
- Quantidade parcial: se o cliente ficou com 1 de 3 unidades da mesma linha, a linha é **dividida** (1 convertida,
  2 devolvidas), para cada parte ter sua situação e foto.

**`orcamentos`**

- Coluna nova `emprestimo_origem_id` (uuid FK `showroom_emprestimos`) no orçamento de **venda** gerado pela conversão.
- Subgrupo novo **`EMPRESTIMO`** em `natureza_operacao = 'outros'`.

**Status do empréstimo** (calculado, como na SPEC-219, com um caso a mais): Cancelado → Em aberto → Atrasado →
Devolvido → Devolvido com dano → **Virou venda** (todas as peças convertidas) → **Parcial: venda + devolução** (parte
convertida, parte devolvida).

**RPCs novas para o usuário logado** (`SECURITY DEFINER`, `SET search_path = public`, só `authenticated`, permissão
pela matriz do Hub — `hub_pode_executar(auth.uid(), 'orcamentos', NULL, '<ação>')`, sem regra fixa no código):

- `emprestimo_confirmar_orcamento(p_orcamento_id, p_data_prevista)` — cria o `EMP-` a partir dos itens do orçamento
  (snapshot do cliente e valor de cada peça), status do orçamento → **"Empréstimo em aberto"**. Recusa se o orçamento
  não for Outros/EMPRESTIMO, se já tiver empréstimo ou se não tiver itens.
- `emprestimo_obter(p_id)` / `emprestimo_listar(p_status, p_termo)` — mesmos dados da SPEC-219, para o Orçamentos.
- `emprestimo_registrar_devolucao(p_item_id, p_quantidade, p_com_dano, p_descricao_dano, p_valor_dano)` — com foto
  obrigatória (mesma regra da fase 2 da SPEC-219).
- `emprestimo_converter_em_venda(p_id, p_itens jsonb [{item_id, quantidade}])` — cria o orçamento de venda (mesmo
  cliente, empresa, projeto, vendedor e equipe; itens com o valor do empréstimo, editável depois), marca as peças como
  `convertido_venda` e devolve o id do orçamento novo.
- `emprestimo_cancelar(p_id, p_motivo)` — só antes de qualquer devolução ou conversão.
- Fotos: as mesmas liberações temporárias da SPEC-219, em versão para `authenticated`.

As RPCs do /admin (`showroom_emp_*`) continuam; a lógica comum (status, devolução, snapshot) vira função interna usada
pelos dois lados, para não divergir. As tabelas continuam sem grant e com RLS (SPEC-196).

**Trava na aprovação:** `aprovar_orcamento_financeiro` passa a **recusar** orçamento `outros/EMPRESTIMO` ("Empréstimo
não passa pela aprovação financeira. Para cobrar, use Virar venda.").

### Tela: Novo Orçamento

1. Tipo de Operação **Outros** → campo **Tipo** com a opção nova **EMPRÉSTIMO** (primeira da lista).
2. Com EMPRÉSTIMO:
   - Cliente obrigatório (do cadastro), empresa obrigatória (vai no cabeçalho do termo), projeto opcional.
   - Itens pela busca normal de peças, com quantidade e valor de venda (o valor é o cobrado em caso de dano).
   - Somem: frete, condições/forma de pagamento, parcelas, sinal, previsão de entrega. Aparece **Data prevista de
     devolução** (obrigatória).
   - Aviso (não bloqueia) quando a quantidade passa do que há em estoque geral + showroom menos o já emprestado.
3. **Salvar** grava como rascunho (pode editar). **Confirmar empréstimo** pede as fotos de saída (obrigatórias, como
   na SPEC-219), cria o `EMP-` e oferece **Baixar termo (PDF)**. Depois de confirmado, os itens não podem mais ser
   editados. SPEC-216 vale: Enter pula de campo, só o clique salva.

### Tela: orçamento de empréstimo aberto (detalhe)

- Selo do status e o número `EMP-`; lista das peças com situação (Emprestada / Devolvida / Com dano / Virou venda).
- **Baixar termo (PDF)** — o mesmo da SPEC-219.
- **Registrar devolução** — escolhe as peças (e a quantidade de cada), OK ou com dano, fotos obrigatórias. "Devolver
  tudo" marca todas de uma vez (ainda com foto).
- **Virar venda** — escolhe as peças e quantidades que o cliente ficou → cria o orçamento de venda e abre ele. Se
  ainda sobrar peça emprestada, o empréstimo continua em aberto com o resto.
- **Cancelar empréstimo** — só antes de qualquer devolução ou conversão.
- A lista de orçamentos mostra os empréstimos com o status do empréstimo; filtro "Empréstimos em aberto / atrasados".

### Orçamento de venda que nasceu do empréstimo

- Mostra "Origem: empréstimo EMP-0003" e o empréstimo mostra o link para a venda.
- Segue o fluxo normal de venda. **Ponto a confirmar (3):** a peça já está com o cliente — na aprovação financeira ela
  não deveria ir para Separação/Entrega como uma venda comum.

### Showroom (/admin)

- A aba Empréstimos lista também os empréstimos vindos do orçamento, com a origem e o número do orçamento. Devolução
  pode ser registrada dos dois lados; **Virar venda** só no Orçamentos (o /admin não tem usuário logado nem financeiro).

### Cadastro (Setores da peça)

- "Amostra / Emprestado" = soma das peças em empréstimo em aberto (Showroom + Orçamentos), com a lista de `EMP-` e
  cliente ao passar o mouse. Texto de ajuda: "já incluído no Estoque Geral / Showroom".

## Checklist de Ação

**A. Banco**
- [x] A1. Colunas novas em `showroom_emprestimos`, `showroom_emprestimo_itens` e `orcamentos`; situação `convertido_venda`
- [x] A2. Funções internas comuns + RPCs `emprestimo_*` para `authenticated` (com `REVOKE` de `public`/`anon`)
- [x] A3. Trava de `outros/EMPRESTIMO` em `aprovar_orcamento_financeiro`
- [x] A4. Permissão: as ações `criar`/`editar` que já existem no Orçamentos (decisão 4: "os mesmos que fazem atualmente") — sem ação nova
- [ ] A5. ~~"Amostra / Emprestado" na `vw_cadastro_produto_setores`~~ — **não feito**: a SPEC-224 (Movimentação de Peças, outra sessão, 23/10) passou a usar "Amostra / Emprestado" como setor físico de verdade (`estoque_itens`). Misturar com o empréstimo (que não move estoque) confundiria. Ver Pendências.
- [x] A6. Dry-run em ROLLBACK: anon e usuário sem acesso bloqueados; empréstimo não cria reserva, entrega futura, parcela nem boleto; converter parcial e devolver o resto

**B. Orçamentos**
- [x] B1. Opção EMPRÉSTIMO no Tipo (Outros) e campos do empréstimo no formulário
- [x] B2. Confirmar empréstimo com fotos + termo PDF (reaproveitando o PDF da SPEC-219)
- [x] B3. Detalhe: devolução, virar venda, cancelar; aba "Empréstimos" na lista
- [x] B4. Orçamento de venda com origem no empréstimo ("Peças que já estão com o cliente", desmarcável)

**C. Showroom e Cadastro**
- [x] C1. /admin lista os empréstimos do orçamento (origem + número), status novos e filtro "Viraram venda"
- [ ] C2. Setores da peça — ver A5

**Entrega**
- [x] Migration com rollback, telas, CHANGELOG, ponteiros

### Passos manuais do usuário
- [x] Responder os pontos (23/10)
- [ ] Validar as cláusulas do termo (pendente desde a SPEC-219) — o mesmo termo vale para o orçamento
- [ ] Teste real: empréstimo de 3 peças → devolver 1, 1 com dano, 1 vira venda

## Pontos confirmados (usuário, 23/10/2026)

1. **Estoque não muda** — sim. "Amostra / Emprestado" é só informação.
2. **Um registro só** para Showroom e Orçamentos — sim.
3. **Venda que veio do empréstimo vai direto para Entregue** — sim, **podendo ser alterado**: cada peça da venda
   convertida vem marcada "Já está com o cliente" (vai direto para Entregue na aprovação financeira); dá para desmarcar
   e ela segue o fluxo normal (reserva / separação).
4. **Quem cria empréstimo** — os mesmos que criam orçamento hoje.
5. **Peça sem estoque** — não bloqueia (a peça precisa estar fisicamente aqui para ser emprestada; o estoque da Connect
   pode estar atrasado). Só aviso.
6. **Cliente obrigatório**; projeto opcional.

## Fora do escopo

- Transferência de setor (estoque geral ↔ showroom ↔ Casa Cor) — SPEC própria (citada na SPEC-220/221)
- Cobrar o dano pelo sistema (o valor fica registrado, como na SPEC-219)
- Casa Cor Saída/Entrada como fluxo próprio (continua só como Tipo, sem efeito em estoque)
- Nota fiscal de remessa de empréstimo (se o contador exigir, SPEC própria com a Focus NFe)

## Critérios de aceite

- Orçamento Outros/EMPRÉSTIMO confirmado gera `EMP-` com termo e fotos, e aparece também no /admin do Showroom
- Nenhuma reserva, entrega futura, parcela, boleto ou necessidade de compra é criada pelo empréstimo
- Tentar a aprovação financeira de um empréstimo é recusado com a mensagem certa
- Devolver 1, registrar 1 com dano e converter 1 deixa o status "Parcial: venda + devolução" e cria um orçamento de
  venda só com a peça convertida, ligado ao empréstimo
- "Amostra / Emprestado" nos Setores da peça mostra a quantidade em aberto e zera quando tudo volta
- Testado como anon e como usuário sem a permissão: nada é lido nem gravado

## Rollback

Migration com `rollback.sql` (remove colunas/RPCs novas e volta `aprovar_orcamento_financeiro`; empréstimos já criados
pelo orçamento vão para o schema `backup` antes). Reverter os commits dos três sistemas.

## Realizado

### 2026-10-23

- Migration `supabase/db/migrations/20261023_238_spec223_orcamento_emprestimo/` (001 + rollback). Os números 236 e
  237 foram usados pela SPEC-224 (outra sessão) no mesmo dia; a pasta foi renomeada para 238 depois de aplicada (o
  conteúdo é o mesmo; o commit do Orçamentos cita "237").
  - Colunas: `showroom_emprestimos.origem/orcamento_id/projeto_id`, `showroom_emprestimo_itens.orcamento_venda_id` e
    situação `convertido_venda`, `orcamentos.data_prevista_devolucao/emprestimo_origem_id`, status `emprestimo`,
    `orcamento_itens.ja_com_cliente`.
  - Travas: `trg_2_orcamento_emprestimo_guard` (empréstimo só fica em rascunho → emprestimo → cancelado; status
    `emprestimo` só muda pelas RPCs) e `trg_orcamento_itens_emprestimo_guard` (peças de empréstimo confirmado não mudam).
  - Funções internas comuns a /admin e Orçamentos: `showroom_emp_detalhe`, `_listar_int`, `_separar_item` (devolução
    ou venda de parte da linha), `_devolver_item`, `_liberar_fotos_int`, `_liberar_leitura_int`; status ganhou
    `virou_venda` e `parcial`. As RPCs do /admin passaram a usar essas internas (mesma assinatura; `showroom_emp_listar`
    ganhou `origem/orcamento_id/orcamento_numero`).
  - RPCs do Orçamentos (só `authenticated`; `criar`/`editar` do Hub; regra de equipe da SPEC-200):
    `emprestimo_confirmar_orcamento`, `_obter`, `_do_orcamento`, `_listar`, `_liberar_fotos`, `_confirmar_fotos_saida`,
    `_liberar_leitura_fotos`, `_registrar_devolucao` (com quantidade), `_converter_em_venda`, `_cancelar`,
    `_em_aberto_por_produto`. Policies de storage do bucket `showroom-emprestimos` também para `authenticated`.
  - `aprovar_orcamento_financeiro` recusa empréstimo e manda peça `ja_com_cliente` direto para Entregue (movimento
    `entregue`, origem `emprestimo`); `replace_orcamento_itens` grava/compara `ja_com_cliente`.
- Ensaio em transação com ROLLBACK (usuário `funcionario` com criar/editar): orçamento de empréstimo não vai para o
  cliente; confirmar gera EMP- com o valor do orçamento; confirmar de novo, mudar peça e mudar status são recusados;
  devolução sem foto recusada; devolver 1 de 2 divide a linha; virar venda cria ORC de venda em rascunho (projeto e
  equipe copiados, peças "já com o cliente"); cancelar depois de devolução recusado; dano acima do integral recusado;
  status final `parcial`; aprovar a venda → saldos só em Entregue, 1 parcela; aprovar o empréstimo recusado; estoque
  físico igual; usuário sem permissão, anon e senha errada do /admin recusados. Rollback também ensaiado.
- Migration **aplicada** no Supabase SP (23/10). Sequence do EMP- devolvida para o último número real (os ensaios tinham
  consumido 3).
- Orçamentos: Tipo EMPRESTIMO, data prevista de devolução, projeto opcional, sem a aba de pagamento; quadro
  "Empréstimo" no orçamento (fotos da saída + Confirmar e baixar termo; depois devolução por peça/quantidade com foto,
  Virar venda, Cancelar, termo PDF igual ao do Showroom com `pdf-lib` 1.17.1); aviso de estoque (não bloqueia); aba
  "Empréstimos" na lista (inclui os do Showroom); rascunho de empréstimo mostra "Confirmar empréstimo" no lugar de
  "Enviar para o Cliente"; venda que veio de empréstimo mostra "Peças que já estão com o cliente".
- Showroom: status "Virou venda"/"Parcial", filtro "Viraram venda", origem "(orçamento ORC-…)" na lista e número da
  venda na peça convertida.

## Pendências

- [ ] Setor "Amostra / Emprestado": a SPEC-224 usa como setor físico. Decidir se o empréstimo (que hoje não move
  estoque, decisão 1) deve passar a mover a peça para esse setor pela Movimentação de Peças, ou se continua só registro.
- [ ] Teste real do usuário logado (criar, confirmar com foto, termo, devolver parte, virar venda, aprovar a venda).
