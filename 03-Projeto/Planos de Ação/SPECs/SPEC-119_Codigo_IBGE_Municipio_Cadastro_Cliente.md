---
titulo: "SPEC-119 — Capturar Código IBGE do Município no cadastro de cliente (via CEP)"
status: concluído (Orçamentos) — CRM não coberto
data_ultima_modificacao: 2026-08-21
sistemas_envolvidos:
  - Orçamentos (gestao-financeira-clone-544cb, Skip 32554) — `ClientCreateModal.tsx`, `services/cepService.ts`, `hooks/use-document-lookup.ts`
  - CRM (lucenera-crm-3bd29, Skip 24580) — cadastro de cliente, se usar o mesmo padrão de CEP
  - Banco: tabela `contatos`
dependencias:
  - SPEC-075 (CEP/CNPJ autofill — já concluída; esta SPEC estende o mesmo mecanismo)
---

# SPEC-119 — Código IBGE do Município no cadastro de cliente

> Origem: reunião Vinícius 21/08/2026 ("Venda Real e aplicações no sistema"), [09:32]-[11:53].

## Objetivo

Capturar e armazenar o Código IBGE do Município do cliente automaticamente durante a busca de CEP (SPEC-075), para eliminar a falha de emissão de nota fiscal por falta desse dado — hoje descoberta tarde, na hora de emitir a nota.

## Contexto (por que isso importa)

Na demonstração ao vivo, Vinícius foi emitir a nota fiscal de uma venda real e o sistema legado recusou: *"Código do IBGE do município, conteúdo inválido"* ([09:32]). A causa era o cadastro do cliente estar sem esse código — ele teve que sair da rotina de nota, ir no cadastro do cliente, buscar manualmente "IBGE batatais" e colar o código à mão ([11:01]-[11:38]) antes de conseguir emitir.

Esse é o mesmo tipo de fricção que a SPEC-075 já resolveu para logradouro/bairro/cidade/UF (autopreenchimento por CEP) — só que o Código IBGE nunca foi incluído.

## Estado atual confirmado no código

- Tabela `contatos`: existem `cidade`, `cidade_comercial`, `cidade_entrega`, `cidade_cobranca` — **nenhuma coluna de Código IBGE** em lugar nenhum.
- `services/cepService.ts` (Orçamentos): consulta ViaCEP como fonte primária, com BrasilAPI como fallback. O tipo `EnderecoCep` retorna só `{cep, logradouro, bairro, cidade, uf}`.
- **Achado importante**: a resposta real da ViaCEP já inclui um campo `ibge` (código IBGE do município) — o serviço já recebe esse dado da API e descarta, só não está mapeado na interface `EnderecoCep`. Ou seja, capturar isso não exige uma chamada de rede nova, só ler um campo que já vem na resposta.
- BrasilAPI (`/api/cep/v1/`, o fallback usado aqui) **não** inclui código IBGE nessa versão da API — só a v2 tem (`city_ibge`). Então o autopreenchimento funcionaria sempre que o ViaCEP responder (path primário) e ficaria sem IBGE só quando cair no fallback.
- Nenhuma SPEC anterior menciona "IBGE".

## Proposta (não implementar sem aprovação)

1. Migration: adicionar coluna `contatos.ibge_cidade` (ou nome equivalente a definir) — `text`, opcional.
2. Estender `EnderecoCep` (`cepService.ts`) com o campo `ibge` (mapear `data.ibge` da resposta ViaCEP; ficar `undefined`/vazio no fallback BrasilAPI v1).
3. Em `ClientCreateModal.tsx` (e no cadastro de cliente do CRM, se usar CEP lookup próprio), gravar o IBGE retornado junto com o resto do endereço, sem exigir digitação manual.
4. Não bloquear o cadastro quando o IBGE não vier (CEP raro, fallback sem IBGE) — só preencher quando disponível; o preenchimento manual continua possível como hoje.
5. A confirmar com o usuário: como este código será efetivamente *usado* — se é só para consulta manual (como Vinícius fez ao vivo) ou se algum fluxo nosso (ex.: integração futura com emissor de nota terceirizado) vai precisar ler esse campo como input.

## Fora de escopo

- Emissão de nota fiscal em si — já é decisão tomada (SPEC de decisão: emissor terceirizado, fora do escopo deste sistema). Esta SPEC só garante que o dado exista no cadastro, para quando for necessário alimentar esse emissor (ou qualquer relatório fiscal).
- Backfill dos clientes já cadastrados sem esse campo — a confirmar se vale a pena rodar uma rotina de preenchimento retroativo via CEP já salvo, ou deixar para quando o cliente for reeditado.

## Análise de ecossistema

- **Depende de**: nenhuma migration/tabela pré-existente além de `contatos` (só adiciona coluna).
- **Afeta**: cadastro de cliente (Orçamentos e possivelmente CRM). Nenhuma regra de negócio existente muda — é um campo novo, opcional, silencioso.

## Realizado

### 2026-08-21

- Migration `20260821_122_spec119_ibge_cidade_contatos` aplicada no banco real: `contatos.ibge_cidade text`, nullable.
- `services/cepService.ts`: `EnderecoCep` ganhou o campo opcional `ibge`, mapeado de `data.ibge` na resposta ViaCEP (fica `undefined` no fallback BrasilAPI v1, que não traz esse campo).
- `ClientCreateModal.tsx`: schema, `defaultValues` e payload de criação passam `ibge_cidade`; `buscarEnderecoBloco` grava o valor só quando o bloco é o endereço principal (`keys.cidade === 'cidade'`) — os blocos de entrega/cobrança não têm coluna IBGE própria.
- Publicado Skip 32554 v0.0.353 — QA limpo.
- **Testado ao vivo**: criei um contato de teste ("TESTE SPEC-119 IBGE NAO USAR") com CEP 01310-100 (Av. Paulista) pelo modal "Criar Novo Cliente" dentro de Novo Orçamento. Confirmado no banco: `ibge_cidade = '3550308'` (código IBGE real de São Paulo), junto com cidade/bairro/UF preenchidos automaticamente. Contato de teste apagado em seguida.

## Pendências

- [ ] **P-1**: CRM (`lucenera-crm`) não foi tocado nesta rodada — não verificado se o cadastro de cliente lá usa CEP lookup próprio e se precisa do mesmo tratamento.
- [ ] **P-2**: backfill retroativo dos clientes já cadastrados sem esse campo — não feito; fica pendente de decisão.
- [ ] **P-3**: campo capturado mas ainda sem consumidor real (emissor de nota terceirizado/relatório) — permanece "guardado, não usado" até essa integração existir.
