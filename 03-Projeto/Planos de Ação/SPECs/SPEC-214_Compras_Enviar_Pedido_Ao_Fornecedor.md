---
titulo: "SPEC-214 — Compras: botão Enviar ao fornecedor (e-mail do Outlook já com o PDF anexado)"
status: pendente
data_ultima_modificacao: 2026-10-21
sistemas_envolvidos:
  - Compras (compras-lucenera-3o23t98ee, compras-lucenera.pages.dev)
---

# SPEC-214 — Compras: Enviar pedido ao fornecedor

## Checklist de Ação

- [x] Pedidos › Aguardando aprovar: botão **Enviar ao fornecedor** ao lado do PDF
- [x] Janela com os e-mails do fornecedor (do cadastro), assunto e texto padrão, todos editáveis
- [x] E-mail que for digitado/alterado fica gravado no cadastro do fornecedor (`contatos.email` / `email_alternativo`)
- [x] "Abrir no Outlook" baixa um e-mail pronto (.eml) com o PDF anexado; abrindo o arquivo, o Outlook clássico mostra o e-mail novo
- [x] Nome padrão do PDF (no botão PDF e no anexo): `Pedido_Compra_<número>_<Fornecedor>.pdf`
- [x] `vite build` ok; .eml conferido (Para, assunto e texto com acento, PDF anexado idêntico)
- [x] Publicar

### Passos manuais do usuário

- [ ] Em Aguardando aprovar, clicar em Enviar ao fornecedor num pedido, conferir os e-mails e clicar em Abrir no Outlook
- [ ] Abrir o arquivo baixado e conferir no Outlook: Para, assunto, texto e o PDF anexado (enviar para um e-mail interno primeiro)
- [ ] Dica: no Chrome, na seta do arquivo baixado, "Sempre abrir arquivos deste tipo" — aí o Outlook abre sozinho

## Objetivo

Pedido do usuário em 21/10/2026: "um botão de enviar ao fornecedor, já com o PDF, mesmo que não seja automático,
mas que abra uma janela do Outlook com um e-mail padrão e já com os endereços de e-mail preenchidos ... hoje temos
que salvar o PDF, abrir o e-mail padrão, anexar ... podemos definir o assunto padrão do e-mail e o nome de como
salva o PDF".

Decisões do usuário (21/10): usam o **Outlook clássico** (Windows); e-mail que faltar é **digitado e gravado no
cadastro**; assunto/texto/nome do PDF = **sugestão** abaixo.

## Definição da SPEC

- O navegador não consegue abrir o Outlook com anexo (`mailto:` não aceita anexo). Por isso o sistema gera e baixa
  um rascunho `.eml` com o cabeçalho `X-Unsent: 1`: o Outlook clássico abre esse arquivo como e-mail novo, com
  Para, Assunto, texto e o PDF anexado. Nada é enviado pelo sistema; quem envia é a pessoa, no Outlook (sai da conta
  dela, com a assinatura do Outlook dela).
- Para: `email` + `email_alternativo` do fornecedor (`contatos`). Aceita mais de um por campo, separado por `;`.
  Hoje só 3 dos 18 fornecedores com pedido têm e-mail; o que for digitado na janela é gravado no cadastro
  (RLS `spec069_contatos_update`: quem edita na Necessidade de Compra ou no Cadastro). Sem permissão, avisa e gera
  o e-mail mesmo assim.
- Assunto: `Pedido de Compra nº <número> - <empresa que compra>`.
- Texto:
  > Prezados,
  >
  > Segue em anexo o Pedido de Compra nº <número> da <empresa>.
  >
  > Por favor, confirmem o recebimento deste pedido e o prazo de entrega.
  > Pedimos que o número do pedido seja mencionado na nota fiscal.
  >
  > Atenciosamente,
  > <nome de quem está logado>
  > <empresa>
- PDF: o mesmo da SPEC-211/213. Nome `Pedido_Compra_<número>_<Fornecedor>.pdf` (sem acento/espaço); o .eml
  baixa com o mesmo nome.
- Sem migration.

## Realizado

### 2026-10-21

- Compras: `EnviarFornecedorDialog.tsx`, `lib/email-pedido-fornecedor.ts`, `nomeArquivoPedido` em
  `lib/pdf-pedido-fornecedor.ts`; serviços `getEmailsFornecedor`/`salvarEmailsFornecedor`/`getNomeUsuario`.
- Teste: .eml montado com o mesmo código, lido de volta (Para, assunto UTF-8, texto, anexo igual byte a byte).
  Não deu para abrir no Outlook aqui (o Outlook desta máquina não tem conta configurada) — conferir no da Débora.
