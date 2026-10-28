---
titulo: "SPEC-236 — Pedido de compra: endereço de entrega fixo no PDF (com exceção por fornecedor) e WhatsApp do Compras no e-mail"
status: no ar
data_ultima_modificacao: 2026-10-28
sistemas_envolvidos:
  - Compras (compras-lucenera-3o23t98ee) — PDF do pedido (pdf-pedido-fornecedor*.ts) e e-mail .eml (email-pedido-fornecedor.ts)
  - Banco (Supabase SP) — empresas, contatos (campos *_entrega), configuração nova do Compras
---

# SPEC-236 — Endereço de entrega no PDF do pedido e WhatsApp do Compras no e-mail

> Origem: pedido do usuário em 28/10/2026 (tarefa "Necessidade de Compras — endereço de entrega fixo no PDF + WhatsApp
> no e-mail"). Relacionadas: SPEC-211 (PDF do pedido), SPEC-214 (Enviar ao fornecedor, .eml).

## Checklist de Ação

- [x] Responder as perguntas da seção "Pendências" (razão social, endereço do showroom, onde cadastrar a exceção).
- [x] Migration: configuração central do Compras (empresa de entrega padrão + WhatsApp do Compras).
- [x] PDF: bloco "Endereço de entrega" automático (fornecedor com endereço próprio → ele; senão → estoque).
- [x] Tela para cadastrar o endereço de entrega próprio do fornecedor (Manoella, Islight → showroom).
- [x] E-mail: linha "Qualquer dúvida, fale com o setor de Compras pelo WhatsApp: (16) 99711-2520" vinda da configuração.
- [ ] Testar: pedido de fornecedor comum (estoque), pedido da Manoella/Islight (showroom), e-mail .eml no Outlook.

## Objetivo

O PDF do pedido de compra mostra sozinho onde entregar (sem digitar a cada pedido), e o e-mail ao fornecedor traz o
WhatsApp do Compras. Endereço e WhatsApp ficam em um lugar só.

## Estado atual (conferido em 28/10)

- **PDF** (`src/lib/pdf-pedido-fornecedor-desenho.ts`, pdf-lib no navegador): já tem um campo "Local de entrega" com
  `pedidos_compra.local_entrega` — texto digitado no pedido, **vazio nos 62 pedidos**. O cabeçalho usa a empresa do
  pedido (`empresas`) e um telefone fixo no código `(16) 3442 - 3545`.
- **E-mail** (`src/lib/email-pedido-fornecedor.ts`, `textoPadrao`): texto fixo, sem contato do Compras.
- **Endereço do estoque já existe** no cadastro de empresas, linha **FOCO ILUMINACAO**: Rua Doutor Hugo Fortes, 1010 —
  Parque Industrial Lagoinha — Ribeirão Preto/SP — CEP 14095-260. **Razão social gravada: "FOCO ILUMINACAO EIRELI –
  ME"** (o pedido fala em "FOCO ILUMINAÇÃO LTDA").
- **Showroom:** as empresas ISLIGHT e MANOELLA estão cadastradas com Rua Ayrton Roxo, 867 — Alto da Boa Vista —
  Ribeirão Preto/SP — CEP 14025-270.
- **Contatos já têm campos de endereço de entrega** (`endereco_entrega`, `numero_entrega`, `complemento_entrega`,
  `bairro_entrega`, `cidade_entrega`, `estado_entrega`, `cep_entrega`), usados hoje só para cliente (3 preenchidos);
  **nenhum fornecedor** os usa. Os fornecedores MANOELLA ZAUITH LEITE LOPES e ISLIGHT COMERCIO E SERVICOS DE
  ILUMINACAO LTDA existem em `contatos` (tipo fornecedor). Nenhuma tela edita esses campos para fornecedor.
- **WhatsApp (16) 99711-2520** não existe em nenhum lugar do sistema. Não há tabela de configuração do Compras
  (`showroom_config` é chave/valor só do Showroom).

## Definição proposta

1. **Configuração central** — tabela nova `compras_config` (uma linha) com `empresa_entrega_padrao_id` → `empresas`
   (FOCO ILUMINACAO) e `whatsapp_compras` texto. RLS: leitura para quem tem o sistema Compras, gravação só admin;
   REVOKE anon. O endereço continua vindo do cadastro da empresa (não duplicado).
2. **Exceção por fornecedor** — reaproveitar os campos `*_entrega` do próprio contato do fornecedor. Preenchidos →
   o PDF usa eles; vazios → usa a empresa padrão. Cadastrar Manoella e Islight com o endereço do showroom.
3. **PDF** — o bloco "Local de entrega" vira "Endereço de entrega" com razão social + endereço completo resolvidos pela
   regra acima. Se o pedido tiver `local_entrega` digitado, ele aparece como observação de entrega (não some).
4. **E-mail** — `textoPadrao` ganha a linha do WhatsApp (de `compras_config`), antes de "Atenciosamente".

## Critérios de aceite

- Pedido de fornecedor comum: PDF com o endereço do estoque sem digitar nada.
- Pedido da Manoella ou da Islight: PDF com o endereço do showroom.
- Trocar o WhatsApp na configuração muda o texto do próximo e-mail sem mexer no código.
- Botão PDF e "Enviar ao fornecedor" continuam funcionando para os pedidos antigos.

## Decisões aprovadas (usuário, 28/10)

- Atualizar o cadastro da empresa: razão social "FOCO ILUMINAÇÃO LTDA" (vale para o sistema todo).
- Showroom (Manoella/Islight) = Rua Ayrton Roxo, 867 — Alto da Boa Vista — CEP 14025-270 — Ribeirão Preto/SP.
- O endereço de entrega próprio do fornecedor é cadastrado no Compras.

## Realizado

- 28/10/2026: levantamento do código e do banco (seção "Estado atual").
- 28/10/2026 — **migration 256 APLICADA**; conferido: razão social, WhatsApp, 2 fornecedores com o showroom, RLS ligada e
  anon sem acesso. Compras `f7723c6`.
- 28/10/2026 — implementado:
  - **Migration 256** `20261028_256_spec236_compras_config_entrega`: razão social da FOCO → "FOCO ILUMINAÇÃO LTDA";
    tabela `compras_config` (uma linha: empresa de entrega padrão = FOCO, WhatsApp "(16) 99711-2520"), RLS: lê quem
    tem `necessidade-de-compra` ou admin, grava só admin, anon sem acesso; Manoella e Islight com os campos
    `*_entrega` = showroom. Dry-run ok (Débora lê e não altera; vendedora sem Compras não vê; admin altera; anon bloqueado).
  - `src/lib/entrega-pedido.ts` (novo, sem banco): tipos, regra fornecedor → padrão e linhas do endereço.
  - `src/services/compras-config.ts` (novo): lê `compras_config` + empresa, lê/grava o endereço de entrega do fornecedor.
  - `src/lib/pdf-pedido-fornecedor.ts`: carrega os campos de entrega do fornecedor e a configuração (se falhar, o PDF sai
    sem o endereço padrão).
  - `src/lib/pdf-pedido-fornecedor-desenho.ts`: "Local de entrega" virou o bloco "Endereço de entrega" (razão social +
    rua + bairro + CEP/cidade); o `local_entrega` digitado, se houver, sai como "Obs.". PDFs de teste conferidos
    (estoque e showroom).
  - `src/lib/email-pedido-fornecedor.ts`: `textoPadrao` com a linha do WhatsApp do Compras.
  - `src/components/compra/EnviarFornecedorDialog.tsx`: seção "Endereço de entrega no PDF" (Padrão / Endereço próprio
    deste fornecedor), grava no cadastro do fornecedor antes de gerar o PDF; texto do e-mail já vem com o WhatsApp.
  - Build ok.

## Pendências

- [x] Razão social do estoque: o cadastro está "FOCO ILUMINACAO EIRELI – ME". Atualizar a empresa para "FOCO ILUMINAÇÃO
      LTDA" (vale para todo o sistema, inclusive nota fiscal) ou só mostrar "LTDA" no PDF?
- [x] Endereço do showroom para Manoella/Islight é o das empresas (Rua Ayrton Roxo, 867 — Alto da Boa Vista — CEP
      14025-270)?
- [x] Onde cadastrar o endereço de entrega próprio do fornecedor: no Compras (recomendado) ou no CRM?
