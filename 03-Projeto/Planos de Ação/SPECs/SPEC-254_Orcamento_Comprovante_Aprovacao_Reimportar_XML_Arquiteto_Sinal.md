---
titulo: "SPEC-254 — Orçamento: comprovante anexado na aprovação, reimportar XML, arquiteto e sinal"
status: não iniciado
data_ultima_modificacao: 2026-11-06
sistemas_envolvidos:
  - Orçamentos (04-Sistemas/gestao-financeira-clone-544cb (1))
  - Banco (Supabase SP) — anexos do orçamento (bucket privado), importação de XML
  - Revisão financeira (mesma tela de Orçamentos)
---

# SPEC-254 — Orçamento: comprovante, XML, arquiteto e sinal

> Origem: reunião 06/11 (min. 24–29, 78–93). Relacionadas: SPEC-202/203 (XML), SPEC-167, SPEC-215 (entrada com antecipação), AGENTS.md (bucket privado, regra 10).

## Checklist de Ação

- [ ] A. **Anexar comprovante (Pix etc.)** na ação "Aprovar e enviar ao financeiro", logo abaixo da confirmação da previsão de entrega, não no corpo do orçamento.
- [ ] B. **Revisão financeira** mostra um indicador (clipe) de que há anexo e abre o arquivo (URL assinada).
- [ ] C. **Reimportar XML**: o desconto também deve ser atualizado, ou o sistema avisa que o desconto precisa ser conferido à mão.
- [ ] D. Aviso quando o arquiteto/RT vier **do vínculo** de outros orçamentos e não do XML ("preenchido do cadastro; confirme").
- [ ] E. Orçamento em aprovação financeira ao reimportar XML: confirmar a regra de voltar etapa (ver abaixo) e mostrar o aviso na tela.
- [ ] F. Conferir que o **sinal** é abatido antes do desconto em R$ ou %; sinal pode vir pré-preenchido depois.
- [ ] G. (Depois) permitir ajustar quantidade de item com **observação obrigatória** (erro de quantidade por devolução na Connect).

### Passos manuais do usuário

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

Nada implementado.

## Pendências

- [ ] Confirmar se o desconto deve ser sempre sobrescrito pela reimportação ou só avisar.
- [ ] Confirmar o limite de tamanho e os tipos de arquivo do anexo.
- [ ] Decidir se o anexo continua visível depois da aprovação final (histórico do orçamento).
- [ ] Decidir G (edição com observação) com o Vinicius.
