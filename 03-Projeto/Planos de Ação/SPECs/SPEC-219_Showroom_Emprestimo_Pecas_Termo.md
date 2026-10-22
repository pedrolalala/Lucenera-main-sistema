---
titulo: "SPEC-219 — Showroom: empréstimo de peças com termo para o cliente assinar"
status: pendente
data_ultima_modificacao: 2026-10-22
sistemas_envolvidos:
  - Showroom (showroom-qtq8er2dk) — tela /admin
  - Banco (Supabase SP) — tabelas e RPCs novas showroom_emprestimo*
---

# SPEC-219 — Showroom: empréstimo de peças com termo para o cliente assinar

## Checklist de Ação

- [x] Migration `20261022_231_spec219_showroom_emprestimos` escrita, ensaiada em ROLLBACK e **APLICADA no Supabase SP em 22/10/2026**: tabelas `showroom_emprestimos` e `showroom_emprestimo_itens` (RLS ligado, sem policy, `REVOKE ALL FROM anon, authenticated`)
- [x] RPCs `SECURITY DEFINER` com credencial do /admin (`showroom_cred_ok`): buscar cliente, listar empresas, criar, listar, obter, registrar devolução e cancelar empréstimo
- [x] Aba nova **"Empréstimos"** no /admin do Showroom (lista + novo empréstimo + detalhe/devolução)
- [x] PDF "Termo de Empréstimo de Peças" no navegador (`pdf-lib`, mesmo padrão da Compras/SPEC-211)
- [x] Atualizar `04-Sistemas/showroom-qtq8er2dk/supabase/AI_DB_CONTEXT.md` (+ `supabase/docs/relationships.md`)
- [x] `CHANGELOG.md` + ponteiro do submodule
- [x] **Fase 2 — fotos** (pedido do Pedro, 22/10): foto de como as peças saíram (obrigatória ao criar) e de como cada peça voltou (obrigatória na devolução, OK ou com dano). Migration `20261022_232_spec219_showroom_emprestimo_fotos` APLICADA; anexo de fotos no PDF

### Passos manuais do usuário

- [ ] Validar o texto das cláusulas do termo (seção "Texto do termo") — de preferência com o jurídico/contador
- [x] Autorizar a aplicação da migration no Supabase SP (22/10)
- [ ] Testar um empréstimo real: criar, imprimir, assinar, registrar devolução

## Objetivo

O showroom empresta peças a clientes (para testar a peça na obra, mostrar ao arquiteto etc.) e hoje isso não fica registrado. Esta SPEC cria, dentro do /admin do Showroom, uma aba para registrar o empréstimo (cliente, empresa, peças e prazo) e gerar um PDF parecido com um orçamento para o cliente assinar. No termo, o cliente se compromete a devolver as peças no mesmo estado e a pagar o valor integral de qualquer peça que ele danificar. O sistema também controla a devolução: prazo, empréstimos em aberto ou atrasados e devolução peça a peça (OK ou com dano).

## Decisões aprovadas (Pedro, 22/10/2026)

1. **Estoque não muda.** O empréstimo é só registro: `produtos.estoque_showroom` não é alterado e a vitrine continua igual. Não há movimentação para o setor "Amostra / Emprestado".
2. **Cliente vem do cadastro** (`contatos`). Busca por nome, CPF ou CNPJ.
3. **A devolução é controlada:** cada empréstimo tem data prevista e a devolução é registrada peça a peça.
4. **A empresa é escolhida em cada empréstimo** (tabela `empresas`). O cabeçalho do termo usa os dados dela.

## Definição

### Estado atual

- O /admin do Showroom **não tem sessão Supabase**: o client é sempre `anon`, e o login é a credencial única conferida por `showroom_cred_ok` (ver `AI_DB_CONTEXT.md` do sistema). Por isso todo acesso a dado de cliente precisa passar por RPC `SECURITY DEFINER` que confere `p_user/p_senha`. Nada de `select` direto em `contatos`, que tem dado pessoal (regra 4 da SPEC-196).
- Para escolher as peças já existe `showroom_buscar_produto(p_termo)`, que devolve código, nome, marca, estoque e valor.

### Banco

**`showroom_emprestimos`**

| coluna | tipo | obs. |
|---|---|---|
| id | uuid PK | |
| numero | int, sequence própria, único | aparece como `EMP-0001` |
| empresa_id | uuid FK `empresas` NOT NULL | |
| contato_id | uuid FK `contatos` NOT NULL | |
| cliente_snapshot | jsonb NOT NULL | nome, CPF/CNPJ, telefone, e-mail e endereço **no momento do empréstimo**: o termo assinado não muda se o cadastro for editado depois |
| data_emprestimo | date NOT NULL default hoje | |
| data_prevista_devolucao | date NOT NULL | precisa ser ≥ data_emprestimo |
| observacoes | text | |
| cancelado_em / cancelado_motivo | timestamptz / text | cancelar só é permitido antes de qualquer devolução |
| criado_por | text | usuário do /admin |
| criado_em | timestamptz default now() | |

**`showroom_emprestimo_itens`**

| coluna | tipo | obs. |
|---|---|---|
| id | uuid PK | |
| emprestimo_id | uuid FK ON DELETE CASCADE | |
| produto_id | uuid FK `produtos` | |
| codigo_produto / nome / referencia | snapshot | |
| quantidade | int > 0 | |
| valor_unitario | numeric NOT NULL | `valor_venda` no dia do empréstimo; é o valor cobrado em caso de dano |
| situacao | text CHECK (`emprestado`, `devolvido`, `devolvido_com_dano`) | default `emprestado` |
| data_devolucao | date | |
| descricao_dano | text | obrigatória quando houver dano |
| valor_dano | numeric | default = `valor_unitario × quantidade` (valor integral), editável só para baixo, por exemplo quando só 1 de 2 unidades voltar danificada |
| devolvido_registrado_por | text | |

**Status do empréstimo** (calculado na RPC de listagem, não gravado):
`Cancelado` → `Em aberto` (algum item ainda `emprestado`) → `Atrasado` (em aberto e `data_prevista_devolucao < hoje`) → `Devolvido` (todos devolvidos sem dano) → `Devolvido com dano` (algum item com dano).

**RPCs** (todas `SECURITY DEFINER`, `SET search_path = public`, primeiro passo `showroom_cred_ok(p_user, p_senha)`):

- `showroom_emp_buscar_cliente(p_user, p_senha, p_termo)`: `contatos` ativos do tipo `cliente`, limite 20, só os campos do termo.
- `showroom_emp_listar_empresas(p_user, p_senha)`: empresas ativas (id, nome).
- `showroom_emp_em_aberto_por_peca(p_user, p_senha, p_codigos int[])`: quantidade emprestada em aberto e `estoque_showroom` de cada peça (para o aviso de quantidade).
- `showroom_emp_criar(p_user, p_senha, p_empresa_id, p_contato_id, p_data_prevista, p_observacoes, p_itens jsonb [{codigo_produto, quantidade}])`: grava o snapshot do cliente e o valor de cada peça; devolve id e número.
- `showroom_emp_listar(p_user, p_senha, p_status text default null, p_termo text default null)`: lista com status calculado, total de peças e valor total.
- `showroom_emp_obter(p_user, p_senha, p_id)`: cabeçalho, itens e dados completos da empresa (razão social, CNPJ, IE, endereço) para montar o PDF.
- `showroom_emp_registrar_devolucao(p_user, p_senha, p_item_id, p_com_dano bool, p_descricao_dano, p_valor_dano)`
- `showroom_emp_cancelar(p_user, p_senha, p_id, p_motivo)`

`REVOKE ALL ON FUNCTION ... FROM public, authenticated` + `GRANT EXECUTE ... TO anon` (o Supabase dá EXECUTE a `authenticated` por padrão; só revogar de `public` não basta) (é o único papel do Showroom). As tabelas não recebem grant nenhum.

**Aviso de quantidade (não bloqueia):** como o estoque não muda, ao criar o empréstimo a tela avisa quando a soma emprestada em aberto de uma peça passa de `estoque_showroom`.

### Tela: aba "Empréstimos" no /admin

1. **Lista**: número, cliente, empresa, data, prazo, nº de peças, valor e status em selo (Atrasado em vermelho). Filtros por status e busca por cliente ou número. Botão **Novo empréstimo**.
2. **Novo empréstimo** (diálogo):
   - Empresa (select), Cliente (busca no cadastro, mostra nome + CPF/CNPJ)
   - Peças: busca reaproveitando `showroom_buscar_produto`, com quantidade; mostra o valor unitário e o total
   - Data prevista de devolução e observações
   - **Salvar** grava o empréstimo e já oferece **Baixar termo (PDF)**. Segue a SPEC-216: Enter pula de campo e só o clique salva.
3. **Detalhe**: dados, itens com situação e botões **Baixar termo (PDF)**, **Registrar devolução** por peça (OK ou Com dano + descrição + valor) e **Cancelar empréstimo** (só se nada foi devolvido).

### PDF "Termo de Empréstimo de Peças"

Gerado no navegador com `pdf-lib` (carregada só no clique), no mesmo visual do PDF de pedido da Compras (SPEC-211):

- Cabeçalho: logo, nome, razão social, CNPJ e endereço da **empresa escolhida**, mais o número `EMP-0001` e a data
- Bloco **Cliente**: nome, CPF/CNPJ, telefone, e-mail e endereço (do snapshot)
- Tabela: código, peça, referência, quantidade, valor unitário e valor total; no rodapé, o **valor total das peças**
- Data prevista de devolução
- Cláusulas (abaixo)
- Local e data; linhas de assinatura **Cliente** (nome + CPF/CNPJ) e **Empresa** (responsável)

### Texto do termo (rascunho, a validar)

1. O CLIENTE recebe as peças listadas acima, a título de empréstimo gratuito, e declara que as recebeu em perfeito estado de conservação e funcionamento.
2. O CLIENTE se compromete a devolver as peças até a data prevista de devolução, no mesmo estado em que as recebeu, com embalagens e acessórios.
3. Em caso de dano, perda, furto ou extravio causado pelo CLIENTE ou ocorrido enquanto as peças estiverem sob sua responsabilidade, o CLIENTE pagará o **valor integral da peça** indicado neste termo.
4. As peças continuam sendo propriedade da [EMPRESA] e não podem ser vendidas, cedidas ou emprestadas a terceiros.
5. A conferência na devolução será feita pela [EMPRESA], que registrará o estado de cada peça.

### Fase 2 — fotos de saída e volta (22/10/2026)

- **Saída**: no Novo empréstimo é obrigatório escolher pelo menos 1 foto (câmera ou galeria) de como as peças estão saindo. As fotos sobem logo depois de gravar o empréstimo; se falharem, o empréstimo fica gravado, a lista mostra "Sem foto da saída" e as fotos podem ser adicionadas no detalhe.
- **Volta**: "Devolvida OK" e "Com dano" abrem um painel com fotos obrigatórias de como a peça voltou (substitui o clique direto, que não tinha confirmação).
- **Armazenamento**: bucket privado `showroom-emprestimos` (registro interno, diferente da vitrine pública). Envio e leitura só com liberação temporária criada por RPC com a credencial do /admin; sem troca nem exclusão de foto pela tela.
- **PDF**: anexo "Fotos de como as peças saíram" (4 por página, rubrica do cliente); cláusula 1 passa a dizer "conforme as fotos anexas a este termo, que dele fazem parte".
- Fotos são reduzidas no navegador para JPEG de até 1600 px. HEIC fora do Safari não abre: a tela pede JPG/PNG (no celular, a câmera do navegador já entrega JPEG).

### Fora do escopo

- Movimentar estoque ou esconder a peça da vitrine (decisão 1)
- Gerar cobrança ou conta a receber pelo dano: o valor fica registrado e a cobrança é feita fora do sistema
- Guardar o termo assinado digitalizado (pode virar fase 2)

### Critérios de aceite

- Criar um empréstimo com 2 peças gera o `EMP-000N` e o PDF sai com empresa, cliente, peças, valores e cláusulas
- Editar o cadastro do cliente depois não altera o PDF de um empréstimo já criado
- Devolver uma peça OK e outra com dano deixa o status "Devolvido com dano", com o valor registrado
- Passado o prazo sem devolução, o status aparece como "Atrasado"
- Testado como `anon` em ROLLBACK: sem credencial válida, toda RPC falha; `select` direto nas tabelas e em `contatos` pela chave anon não devolve nada
- `estoque_showroom` e a vitrine não mudam

### Rollback

`DROP FUNCTION showroom_emp_*`, `DROP TABLE showroom_emprestimo_itens, showroom_emprestimos` (com backup no schema `backup` se já houver dado real) e reverter o commit do Showroom.

## Realizado

### 2026-10-22

- Migration `supabase/db/migrations/20261022_231_spec219_showroom_emprestimos/` (`001_showroom_emprestimos.sql` + `rollback.sql`) escrita. 2 tabelas, 1 função interna de status e 8 RPCs.
- Ensaio no Supabase SP em transação com ROLLBACK, usando credencial de teste trocada só dentro da transação:
  - criação com 3 linhas (peça repetida somada em 1) gerou `EMP-0001` com 2 itens e o valor de venda gravado;
  - aviso de quantidade: emprestar 2 de uma peça que tem `estoque_showroom` 1 é detectado;
  - devolução OK + devolução com dano levam ao status `devolvido_com_dano`, com valor integral;
  - cancelar após devolução é recusado; prazo no passado é recusado; senha errada é recusada;
  - `anon` e `authenticated` não leem as tabelas; `authenticated` não executa as RPCs;
  - `estoque_showroom` intacto; depois do ROLLBACK, 0 tabelas criadas e credencial original intacta.
- Migration 231 **aplicada** no Supabase SP (transação única). Conferido: 2 tabelas com RLS e sem grant; 8 RPCs executáveis só por `anon`; função de status sem grant; pela API pública, senha errada é recusada e a tabela não pode ser lida.
- Showroom `ead135a` (push no GitHub, a Cloudflare publica): aba **Empréstimos** no /admin (filtros Em aberto/Atrasados/Com dano/Todos, busca), diálogo **Novo empréstimo** (empresa, cliente do cadastro, peças com quantidade e aviso de estoque, prazo, observações) e detalhe (devolução OK/com dano, cancelar, **Baixar termo (PDF)**). PDF com `pdf-lib` 1.17.1 (mesma versão da Compras), logo Lucenera + dados da empresa escolhida. Build e lint ok; PDF de exemplo conferido visualmente.
- **Fase 2 (fotos)**: migration 232 escrita; ensaio em ROLLBACK com 20 verificações. Todas ok:
  - envio sem liberação, reenvio e foto de outro momento ou de outra peça são recusados;
  - devolução sem foto e com foto não enviada são recusadas;
  - leitura vale só com a liberação ativa;
  - `authenticated` fica bloqueado; sobra só 1 versão de `registrar_devolucao`.
- O ensaio pegou um bug (`path` ambíguo em `ON CONFLICT`), corrigido. Migration 232 **APLICADA**.
- Teste real pela API de Storage, com empréstimo de teste nº 999999 apagado depois:
  - envio liberado funciona; sem liberação ou sobrescrevendo dá 403;
  - URL pública não abre (bucket privado); link assinado baixa a foto (200);
  - delete pela API não apaga nada; link novo é recusado depois que a liberação vence.
- Sequence de número zerada (os ensaios tinham consumido 3 números).
- Achado: `empresas` tem só **MANOELLA, ISLIGHT e FOCO ILUMINACAO**, não existe empresa "Lucenera". O termo sai em nome de uma dessas três.

## Pendências

- [ ] Validar o texto das cláusulas do termo de empréstimo (SPEC-219) antes do primeiro uso real.
- [ ] Logo do termo: o código só tem o logo da Lucenera, mas a tabela `empresas` só tem MANOELLA, ISLIGHT e FOCO ILUMINACAO. Decidir se o termo usa o logo Lucenera (marca) com os dados da empresa escolhida, ou o logo de cada empresa (SPEC-219).
- [ ] Busca de cliente do empréstimo filtra só `contatos.tipo = 'cliente'`. Confirmar se arquitetos (867 cadastrados) também pegam peça emprestada; se sim, incluir o tipo na RPC (SPEC-219).
- [ ] Snapshot `supabase/db/current/` não regenerado para a migration 231 (o snapshot já não reflete o domínio showroom desde a SPEC-148) (SPEC-219).
- [ ] Testar a aba Empréstimos no /admin publicado (showroom-lucenera.pages.dev) com a credencial real: criar, baixar termo, devolver OK e com dano. A IA não tem a senha do /admin e testou só as RPCs (SPEC-219).
