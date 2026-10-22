---
titulo: "SPEC-223 — Orçamento de empréstimo (Tipo de Operação: Outros → EMPRÉSTIMO), com devolução e virar venda"
status: não iniciado
data_ultima_modificacao: 2026-10-22
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

## Decisões (propostas — ver "Pontos para confirmar")

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
- [ ] A1. Colunas novas em `showroom_emprestimos`, `showroom_emprestimo_itens` e `orcamentos`; situação `convertido_venda`
- [ ] A2. Funções internas comuns + RPCs `emprestimo_*` para `authenticated` (com `REVOKE` de `public`/`anon`)
- [ ] A3. Trava de `outros/EMPRESTIMO` em `aprovar_orcamento_financeiro` (com `DROP` da assinatura antiga se ela mudar)
- [ ] A4. Ação nova na matriz do Hub (ex.: `orcamentos.emprestar`) para os papéis que o usuário indicar
- [ ] A5. "Amostra / Emprestado" na `vw_cadastro_produto_setores` vindo dos empréstimos em aberto
- [ ] A6. Dry-run em ROLLBACK: anon e usuário sem acesso bloqueados; empréstimo não cria reserva, entrega futura,
      parcela nem boleto; necessidade de compra não muda; converter parcial e devolver o resto

**B. Orçamentos**
- [ ] B1. Opção EMPRÉSTIMO no Tipo (Outros) e campos do empréstimo no formulário
- [ ] B2. Confirmar empréstimo com fotos + termo PDF (reaproveitando o PDF da SPEC-219)
- [ ] B3. Detalhe: devolução, virar venda, cancelar; filtro na lista
- [ ] B4. Orçamento de venda com origem no empréstimo

**C. Showroom e Cadastro**
- [ ] C1. /admin lista os empréstimos do orçamento (origem + número)
- [ ] C2. Setores da peça com "Amostra / Emprestado"

**Entrega**
- [ ] Migration com rollback, telas, publicar (Orçamentos, Showroom, Cadastro), CHANGELOG, ponteiros

### Passos manuais do usuário
- [ ] Responder os "Pontos para confirmar"
- [ ] Validar as cláusulas do termo (pendente desde a SPEC-219) — o mesmo termo vale para o orçamento
- [ ] Teste real: empréstimo de 3 peças → devolver 1, 1 com dano, 1 vira venda

## Pontos para confirmar

1. **Estoque não muda (recomendado) ou move para o setor empréstimo?** O Vinicius falou em "jogar para o setor
   empréstimo e o disponível permanece". Mover de verdade hoje **tiraria a peça do disponível** (a venda só olha o
   local "Estoque") e contrariaria a SPEC-219. Recomendação: **não mover**; mostrar "Amostra / Emprestado" só como
   informação, e avisar na venda quando a peça estiver emprestada.
2. **Um registro só para Showroom e Orçamentos?** Recomendação: **sim** (mesmo `EMP-`, mesmo termo).
3. **Venda que veio do empréstimo:** a peça já está com o cliente. Recomendação: na aprovação financeira essas peças
   vão **direto para Entregue** (sem Separação), baixando o estoque como uma entrega normal.
4. **Quem pode criar empréstimo pelo orçamento?** Recomendação: quem já cria orçamento, com a ação nova no Hub para
   poder restringir depois.
5. **Peça sem estoque pode ser emprestada?** Recomendação: **aviso, sem bloqueio** (igual ao /admin), porque o
   estoque da Connect pode estar atrasado.
6. **Projeto obrigatório?** Recomendação: **opcional** (Casa Cor e empréstimo para arquiteto nem sempre têm projeto).

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

(vazio)
