---
titulo: "SPEC-172 — Catálogo Ubiqua: desconto %, PDF real, cadastro completo de cliente e envio por e-mail"
status: pendente
data_ultima_modificacao: 2026-09-30
sistemas_envolvidos:
  - Catálogo Peças Ubiqua (catalogo-pecas-ubiqua-e6fa0, Skip 33302)
  - Supabase (compartilhado)
---

# SPEC-172 — Catálogo Ubiqua: desconto %, PDF real, cadastro completo de cliente e envio por e-mail (mailto)

## Checklist de Ação

- [x] 1. Desconto global em % (0–100) no Novo Orçamento; grava `desconto_percentual`, `valor_desconto` (R$ calculado) e `valor_total`
- [x] 2. Edge Function nova `gerar-pdf-orcamento-ubiqua` (pdf-lib, layout portado do `generate-report` da Lucenera) — "Baixar PDF" baixa `.pdf` de verdade
- [x] 2b. Tabela `configuracao_empresa_ubiqua` (linha única) com os dados da Ubiqua usados no documento — sem nenhum fallback da Lucenera
- [x] 4. Cadastro completo de cliente (`informacoes_cliente_ubiqua`): endereço, IE, regime tributário, entrega, cobrança, transportadora, e-mail comercial/financeiro; CEP com busca automática (cepService da Lucenera)
- [x] 3a. Logo da Ubiqua no PDF: logo laranja do site oficial (ubiqualamps.com, `ubiqua-logo-orange-400x104-1.png`) no bucket público `Logo/ubiqua-logo-orange.png`, gravado em `configuracao_empresa_ubiqua.logo_url` (pedido do usuário, 30/09)
- [ ] 3b. Preencher dados reais da Ubiqua (razão social, CNPJ, IE, endereço, telefone, e-mail) — aguardando usuário
- [x] 5. "Enviar por E-mail" abre o cliente de e-mail do computador via `mailto:` com assunto e corpo preenchidos (`src/lib/email-orcamento.ts`); modal e chamada à `enviar-confirmacao-email` removidos
- [x] 6. Restaurar `generate-report`, `salvar-projeto` e `parse-budget-pdf` no ar (regrediram no apply v0.0.95) — feito na v0.0.97

### Passos manuais do usuário

- [x] Aplicar a migration `supabase/db/migrations/20260930_172_ubiqua_orcamento_pdf_cliente/` (aplicada 30/09)
- [ ] Informar os dados cadastrais da Ubiqua e o arquivo do logo
- [ ] Autorizar a publicação do Skip 33302 (deploya só a função nova + frontend)

## Objetivo

O orçamento do Catálogo Ubiqua saía como `.html` com dados fictícios ("Ubiqua Peças", "João da Silva"), o desconto era só em R$, o cadastro de cliente tinha 4 campos e o "Enviar por E-mail" nunca funcionou (a função `enviar-confirmacao-email` só faz `console.log` e a chamada no front passava argumentos errados).

## Decisões aprovadas

- Lucenera e Ubiqua são empresas diferentes: todo documento/e-mail do Catálogo Ubiqua usa só logo e dados da Ubiqua. Dado que não existir no sistema é perguntado, nunca inventado.
- `empresa_ubiqua` é a tabela de **empresas parceiras** (representantes) — não serve como "dados da Ubiqua". O caminho Ubiqua do `generate-report` (`.limit(1)` em `empresa_ubiqua` + fallbacks fixos da Lucenera) **não** é usado.
- O PDF é gerado numa função própria do Ubiqua para não tocar no `generate-report` compartilhado com a Lucenera.
- Itens 1, 2 e 4 implementados primeiro (usuário, 30/09); 3 aguarda dados.
- Item 5 (usuário, 30/09): **sem SMTP, sem backend, sem conta Gmail** — só `mailto:`, como a Lucenera (SPEC-067). Sem anexo (mailto não suporta); todo o orçamento vai no corpo em texto. Destinatário pré-preenchido com o e-mail do cliente (editável no programa de e-mail).

## Definição da SPEC

### Banco (migration 20260930_172)

- `informacoes_cliente_ubiqua` + colunas: `tipo_pessoa`, `cep, endereco, numero, complemento, bairro, cidade, estado`, `inscricao_estadual`, `regime_tributario` (CHECK: simples_nacional, mei, lucro_presumido, lucro_real, outro), `email_comercial`, `email_financeiro`, `transportadora`, `entrega_igual_principal` + `*_entrega`, `cobranca_igual_principal` + `*_cobranca` (mesmos nomes do `contatos` da Lucenera).
- `configuracao_empresa_ubiqua` (id = 1): nome_fantasia, razao_social, cnpj, inscricao_estadual, endereço, telefone, email, site, logo_url. SELECT para authenticated; escrita só admin do Ubiqua (`usuarios_ubiqua.nivel_acesso = 'admin'`).
- `orcamentos_revenda_ubiqua.desconto_percentual` já existia (CHECK 0–100) e passa a ser usado.

### Cálculo do desconto

`valor_desconto = round(subtotal × pct / 100, 2)`; `valor_total = subtotal − valor_desconto`. Mesma conta na tela, no banco e no PDF (o PDF usa o `valor_total` gravado).

### PDF

Edge Function `gerar-pdf-orcamento-ubiqua` (verify_jwt padrão; confere usuário). Entrada `{ quote_id }`, saída `application/pdf`. Layout do `generate-report` Lucenera: cabeçalho com logo + dados da empresa, bloco "Aprovação do Cliente", número/data, dados do cliente (endereço, CPF/CNPJ, IE), itens (Referência, Descrição, Qtd, Vl. Unit., Subtotal), SubTotal/Desconto (%)/Valor Total, condições, prazo, observações e aviso de ST. Montagem em `_shared/pdf-orcamento-ubiqua.ts` para o e-mail (item 5) reaproveitar.

### Critérios de aceite

- Desconto 10% sobre R$ 1.000,00 → total R$ 900,00 na tela, no banco e no PDF; valores fora de 0–100 são recusados.
- "Baixar PDF" baixa `Orcamento_<numero>.pdf` que abre em leitor de PDF.
- Nenhum texto/dado da Lucenera no PDF do Ubiqua.
- Cliente PJ exige IE (ou "ISENTO") e regime; endereço de entrega/cobrança herdam do principal até desmarcar "igual ao principal"; tudo reabre na edição.

## Realizado

### 2026-09-30

- Itens 1, 2, 2b e 4 implementados; migration aplicada; Skip 33302 v0.0.95 (`f51afe2`).
- O apply da v0.0.95 redeployou as 15 Edge Functions do Ubiqua (arquivo novo em `_shared/`); 3 regrediram (ver Pendências).
- Item 5 via `mailto:`: Skip v0.0.96 (`c373674`), nenhuma função redeployada. Corpo testado com ORC-2026-000008 real (URL 1.815 caracteres, CRLF = `%0D%0A`, decodifica idêntico). Acima de 2.000 caracteres o corpo também é copiado para a área de transferência (Outlook clássico corta mailto longo).
- Restauração (autorizada pelo usuário): as 3 cópias boas gravadas no Skip 33302 e aplicadas (v0.0.97 `6d253b3`). Só essas 3 foram redeployadas (generate-report v102, salvar-projeto v85, parse-budget-pdf v68); o download do que está no ar bate com as cópias do Compras, CRM e Cadastro. O Ubiqua agora carrega essas versões, então as próximas publicações dele não as revertem.

## Pendências

- [ ] Dados cadastrais reais da Ubiqua (razão social, CNPJ, IE, endereço, telefone, e-mail) — o PDF já tem o logo (30/09), mas embaixo dele só aparece "UBIQUA".
- [ ] Publicar o Skip 33302 (v0.0.97) em produção.
- [ ] Teste manual do "Enviar por E-mail" num computador com programa de e-mail configurado.
- [ ] Decidir se a notificação interna do `process-budget-pdf` (para vinicius@/pedro@lucenera.com.br) continua.
