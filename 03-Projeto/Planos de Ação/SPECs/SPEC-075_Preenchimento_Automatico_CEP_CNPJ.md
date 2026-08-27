---
titulo: "SPEC-075 — Preenchimento automático de endereço via CEP e dados de empresa via CNPJ"
status: publicado em produção (3 sistemas)
data_ultima_modificacao: 2026-08-11
sistemas_envolvidos:
  - Orçamentos (gestão-financeira-clone-544cb, projectId Skip 32554) — ClientCreateModal.tsx
  - CRM (lucenera-crm-3bd29, projectId Skip 24580) — ClientFormFields.tsx
  - Compras (compras-lucenera-3o23t98ee, projectId Skip 40326) — FornecedorModal.tsx (novo)
dependencias: []
---

# SPEC-075 — Preenchimento automático via CEP/CNPJ

> Origem: pedido genérico ("adicionar ao projeto atual") num repositório
> com 10+ sistemas — perguntado ao usuário em quais sistemas isso deveria
> entrar. Resposta: Compras (fornecedores), Orçamentos (modal de cliente),
> CRM (cadastro de clientes/contatos).

## Achado antes de implementar

Orçamentos e CRM **já tinham** busca de CEP (ViaCEP) e CNPJ (BrasilAPI)
implementada inline em `ClientCreateModal.tsx`/`ClientFormFields.tsx`
(SPEC-052/061), sem fallback, sem debounce, sem cache e sem indicador de
carregamento. Perguntado ao usuário se refatorava pra versão completa
(fallback + debounce + cache + loading, extraído pra serviço dedicado) —
confirmado.

Compras **não tinha nenhum formulário de fornecedor** — fornecedor só
existia como vínculo (buscar por nome já cadastrado e linkar à marca em
`FornecedoresDaMarcaPanel.tsx`), nunca criado/editado diretamente.
Perguntado ao usuário se construía o formulário do zero — confirmado.

## Achado crítico ao publicar (mesmo padrão da SPEC-073/074)

Antes de sobrescrever `ClientCreateModal.tsx` (Orçamentos) com a versão
refatorada, `skip_file_read` revelou que o código real publicado tinha
features inteiras ausentes do checkout local (SPEC-052 `tipo_cliente`,
SPEC-061 `complemento` nos 3 blocos de endereço, e-mail obrigatório,
Vendedor/Vendedor Padrão vindo de `funcionarios` em vez de `usuarios`).
A refatoração foi refeita em cima do conteúdo real (não do checkout
local desatualizado) antes de publicar — ver
`feedback_skip_local_pode_ter_menos_que_producao` na memória do projeto.

## Arquitetura (replicada nos 3 sistemas, cada um com sua própria cópia)

- `src/services/cepService.ts` — `buscarEnderecoPorCep(cep)`: ViaCEP
  primário, BrasilAPI (`/api/cep/v1/{cep}`) como fallback (falha de rede
  ou CEP não encontrado numa das duas). Cache em memória por CEP (8
  dígitos) via `Map`, válido pela sessão da aba.
- `src/services/cnpjService.ts` — `buscarDadosCnpj(cnpj)`: BrasilAPI
  primária, ReceitaWS (`/v1/cnpj/{cnpj}`) como fallback — ReceitaWS tem
  limite de 3 req/min, por isso só é chamada quando a BrasilAPI falha.
  Cache em memória por CNPJ (14 dígitos).
- `src/hooks/use-document-lookup.ts` — `useCepLookup()`/`useCnpjLookup()`:
  debounce de 300ms (setTimeout, cancelado a cada nova tecla), estado
  `loading` pra desabilitar o campo + mostrar "Buscando...", callbacks
  `onResult`/`onError` (erro nunca lança exceção pro componente — sempre
  vira mensagem amigável via toast do próprio sistema, sonner em
  Orçamentos, use-toast em CRM/Compras).

Cada sistema mantém sua própria cópia dos 3 arquivos (mesmo padrão já
usado pra `cross-system-auth.ts` no ecossistema) — não há pacote
compartilhado entre os 10 sistemas.

## Por sistema

### Orçamentos (`ClientCreateModal.tsx`)
- CEP em 3 blocos (principal/entrega/cobrança), cada um focando o campo
  "Número" correspondente após preencher.
- CNPJ preenche `razao_social`/`nome`/`nome_empresa` (só se vazios) e,
  se a BrasilAPI retornar endereço junto, completa o bloco principal
  também (endereço/bairro/cidade/estado/número); se retornar só o CEP
  sem logradouro, dispara a busca de CEP como complemento.

### CRM (`ClientFormFields.tsx`)
- Mesmo padrão de 3 blocos. Bloco principal não tem campo "Número"
  separado no schema (`numero` vai embutido no texto de `endereco`,
  placeholder "Rua, Número, Complemento") — foco após CEP vai para o
  campo Endereço nesse caso específico.

### Compras (`FornecedorModal.tsx`, novo)
- Formulário criado do zero: nome/razão social, CNPJ, nome fantasia,
  telefone, celular, e-mail, endereço completo (CEP/número/complemento/
  bairro/cidade/UF), observações.
- `src/services/fornecedores.ts` (novo): fornecedor é um registro em
  `contatos` — mas a busca fuzzy usada no resto do sistema
  (`buscar_fornecedores_fuzzy`) consulta a tabela auxiliar
  `contato_tipos` (many-to-many, um contato pode ser cliente E
  fornecedor), não só a coluna legada `contatos.tipo`. `criarFornecedor`
  grava nas duas tabelas.
- Integrado como opção "Cadastrar novo fornecedor" na busca existente de
  `FornecedoresDaMarcaPanel.tsx` — ao criar, já vincula automaticamente
  o novo fornecedor à marca em edição.

## Critérios de aceitação (do pedido original)

- [x] CEP válido preenche endereço automaticamente (3 sistemas)
- [x] CNPJ válido preenche dados da empresa automaticamente (3 sistemas)
- [x] Fallback silencioso (ViaCEP→BrasilAPI, BrasilAPI→ReceitaWS)
- [x] CEP/CNPJ inexistente mostra mensagem clara, não trava o formulário
- [x] Usuário pode editar manualmente qualquer campo depois do preenchimento
- [x] Indicador de carregamento aparece/some corretamente, campo desabilitado durante busca
- [x] Debounce de 300ms, cache em memória por sessão
- [x] Código segue os padrões já existentes (react-hook-form + zod, services/ por domínio)

## Verificação

- `npm run build` limpo nos 3 sistemas.
- QA do Skip (setup/static/build/integrations/test) limpo nos 3 ao aplicar.
- Conteúdo publicado conferido byte-a-byte (diff local vs `skip_file_read`)
  antes de cada `apply_changes`, incluindo o arquivo de 52KB do Orçamentos.
- Verificação visual ao vivo não foi possível (mesma instabilidade de
  automação de browser já registrada na SPEC-074) — recomendo conferência
  manual rápida quando possível, principalmente o fluxo de criação de
  fornecedor em Compras (única tela 100% nova).

## Pendências

- [ ] Verificação visual manual dos 3 formulários em produção.
- [ ] Compras: não foi criada uma tela de listagem/edição de fornecedores
  já cadastrados — só criação (via busca sem resultado) e edição não tem
  entrada própria ainda. Se precisar editar um fornecedor depois de
  criado, é direto no banco ou espera uma tela futura.
