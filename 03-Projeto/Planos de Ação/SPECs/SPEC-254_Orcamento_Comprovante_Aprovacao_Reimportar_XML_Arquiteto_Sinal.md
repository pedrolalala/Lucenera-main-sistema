---
titulo: "SPEC-254 — Orçamento: comprovante anexado na aprovação, reimportar XML, arquiteto e sinal"
status: pendente
data_ultima_modificacao: 2026-11-06
sistemas_envolvidos:
  - Orçamentos (04-Sistemas/gestao-financeira-clone-544cb (1))
  - Banco (Supabase SP) — anexos do orçamento (bucket privado), importação de XML
  - Revisão financeira (mesma tela de Orçamentos)
---

# SPEC-254 — Orçamento: comprovante, XML, arquiteto e sinal

> Origem: reunião 06/11 (min. 24–29, 78–93). Relacionadas: SPEC-202/203 (XML), SPEC-167, SPEC-215 (entrada com antecipação), AGENTS.md (bucket privado, regra 10).

## Checklist de Ação

- [x] A. **Anexar comprovante (Pix etc.)** na ação "Aprovar e enviar ao financeiro", logo abaixo da confirmação da previsão de entrega, não no corpo do orçamento.
- [x] B. **Revisão financeira** mostra um indicador (clipe) de que há anexo e abre o arquivo (URL assinada).
- [x] C. **Reimportar XML**: o XML da Connect **não traz** desconto geral, frete, sinal nem arquiteto (só itens, com desconto por item, e o total); então o sistema **avisa** o que ficou como estava e precisa ser conferido à mão.
- [x] D. Aviso quando o arquiteto/RT vier **do vínculo** de outros orçamentos e não do XML ("preenchido do cadastro; confirme").
- [x] E. Orçamento em aprovação financeira ao reimportar XML: a regra já existia (o XML só atualiza até a Aprovação da Equipe; depois a tela explica que precisa voltar etapa). Nada a mudar.
- [x] F. Conferir que o **sinal** é abatido antes do desconto em R$ ou %; sinal pode vir pré-preenchido depois.
- [ ] G. (Depois) permitir ajustar quantidade de item com **observação obrigatória** (erro de quantidade por devolução na Connect).

### Passos manuais do usuário

- [ ] Aplicar a migration 294 e publicar o Orçamentos (aguarda o OK).
- [ ] Equipe: ao fechar na Connect, completar no sistema novo as datas de pagamento (parcelas, forma) antes de aprovar.
- [ ] Financeiro (Lana/Carol): dizer o que querem ver na revisão (tipo de anexo, nome do arquivo).

## Objetivo

Acabar com o envio de comprovante por e-mail: tudo dentro do sistema, visível para o financeiro, e deixar a reimportação do XML previsível.

## Decisões aprovadas (reunião)

- O comprovante (Pix, depósito) entra na **aprovação**, porque é nessa hora que a equipe confirma a previsão de entrega. Boleto é gerado depois.
- Reimportar XML do mesmo orçamento **atualiza** (testado: valor de itens, lâmpada trocada, item embutido). Duplicar só ocorre ao criar orçamento novo.
- Desconto pode ser em reais ou em porcentagem; o sinal entra antes: tira o sinal, depois o desconto.
- Código do cliente digitado na busca encontra o cliente (testado: código 36 → cliente já criado).

## Definição da SPEC

### Como está (visto na reunião)

- Reimportar XML: "Editar → Importar XML"; aparece "atualizar"; atualizou valores e itens, **não** o desconto (ajustado à mão para 35); mantém datas como estavam (13/11 e 13/12).
- O arquiteto veio preenchido do vínculo mesmo sem estar no orçamento; pode estar errado quando a venda não tem RT.
- Orçamento já em aprovação financeira exige voltar etapa para reimportar ("pelo menos para a aprovação da equipe").
- Hoje não há onde anexar o comprovante com visibilidade para o financeiro.

### Anexo (A/B)

- Tabela de anexos do orçamento com RLS e `REVOKE anon`; arquivo em bucket **privado**; leitura por `createSignedUrl` (AGENTS.md). Quem vê: equipe do orçamento e financeiro.
- Campo opcional na ação; vários arquivos; exibir nome, quem anexou e quando.

## Critérios de aceite

- Aprovar com comprovante: o financeiro vê o indicador na revisão e abre o arquivo; sem comprovante, nada muda.
- Reimportar XML com desconto diferente: atualiza ou avisa.
- Arquiteto vindo do vínculo mostra o aviso.

## Realizado

### 2026-11-06 (A, B, C, D, E, F — migration 294 em rascunho com dry-run OK, NÃO aplicada; código commitado 57d201c, NÃO publicado)

- **Migration 294 (`20261106_294_spec254_orcamento_anexos`):** tabela `orcamento_anexos` (RLS: vê quem enxerga o orçamento; anexa quem enxerga e tem permissão de editar orçamentos; apaga só quem anexou; `REVOKE` de `anon`) e **bucket privado** `orcamento-anexos` (10 MB, PDF/PNG/JPG/WEBP; o bucket `orcamentos` existente é público e não serve para comprovante). Caminho `<orcamento_id>/<arquivo>`, com política de storage pela função `orcamento_anexo_pode_acessar`. Dry-run com ROLLBACK, como a Marina (projetista de equipe restrita): anexa no orçamento da equipe dela, é barrada no de outra equipe, não enxerga anexo de outra equipe, caminho inválido recusado, `anon` barrado, bucket `public = false`.
- **Orçamentos (commit 57d201c, `gestao-financeira-clone-544cb (1)`):** (A) na janela "Confirmar Previsão de Entrega" da Aprovação da Equipe, campo de **comprovante** (PDF/imagem, vários, até 10 MB); os arquivos sobem **antes** de aprovar (se o envio falhar, nada é aprovado) e a observação do histórico registra quantos foram. (B) na revisão financeira: bloco **Anexos do orçamento** (abre por URL assinada de 5 min) ou "Sem comprovante anexado pela equipe", e **clipe** na fila ao lado do número. (C) ao reimportar XML, aviso "Confira em Condições de pagamento" listando desconto geral, sinal e frete que o XML não traz. (D) aviso quando o arquiteto vem preenchido do cadastro do projeto. (E/F) conferidos: o XML só atualiza até a Aprovação da Equipe (mensagem já existia) e o sinal já é abatido antes do desconto (`budget-financial-summary.ts` e a tela).
- Erros de tipo: 184 antes e depois (dívida antiga de `types.ts`; checagem feita sem o `ignoreDeprecations` inválido do `tsconfig.app.json`); nenhum nos arquivos novos. `vite build` ok.
- **Atenção na publicação:** o repositório tem alterações antigas **não commitadas** em `App.tsx` e `Login.tsx` (SPEC-242 C, cadastro fechado) que não devem ir junto: o build para publicar foi feito sem elas (guardadas com `git stash`) e o commit tem só os arquivos desta SPEC. Há também o commit local `976976b` (SPEC-246, trava contra o banco antigo) ainda não enviado, que seguirá no push.

## Pendências

- [ ] Aplicar a 294 e publicar (aguarda o OK).
- [ ] Orçamento já em Aprovação Financeira não aceita anexo novo pela janela da equipe: se o comprovante chegar depois, falta um botão "Anexar" na própria venda/revisão (não pedido na reunião; confirmar se é necessário).
- [ ] Confirmar se o desconto deve ser sempre sobrescrito pela reimportação ou só avisar.
- [ ] Confirmar o limite de tamanho e os tipos de arquivo do anexo.
- [ ] Decidir se o anexo continua visível depois da aprovação final (histórico do orçamento).
- [ ] Decidir G (edição com observação) com o Vinicius.
