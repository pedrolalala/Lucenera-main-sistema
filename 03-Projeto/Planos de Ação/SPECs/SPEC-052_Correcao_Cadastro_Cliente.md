---
titulo: "SPEC-052 — Correções do Cadastro de Cliente (rótulos, campos ausentes, autopreenchimento CEP/CNPJ)"
status: implementado e publicado em produção (Skip) em 2026-08-04, incluindo Tipo Cliente e Regime de Apuração como Select fixo — pendente homologação manual do usuário
data_ultima_modificacao: 2026-08-04
sistemas_envolvidos:
  - CRM (lucenera-crm-3bd29 (1))
  - Orçamentos (gestao-financeira-clone-544cb (1))
  - Supabase (banco central)
dependencias: []
---

# SPEC-052 — Correções do Cadastro de Cliente

> Origem: reunião com Vinicius em 27/07/2026, `02-Reunioes/12. lucenera (Vinicius) - 27.07.2026_ correcoes necessarias/Reunião.01.txt`. Desmembrada de uma SPEC única (cliente + produto + devolução) por decisão do usuário em 2026-07-27 — cada frente tem sistemas e prioridades diferentes.

## Checklist de Ação

- [x] `lucenera-crm-3bd29 (1)/src/pages/contatos/Clientes.tsx`: renomear label do campo `nome` para "Nome e Razão Social".
- [x] Mesmo arquivo: renomear label do campo `nome_empresa` (hoje "Empresa") para "Nome Fantasia".
- [x] Mesmo arquivo: adicionar campo `inscricao_estadual` (coluna já existe em `contatos`, só não está no formulário).
- [x] Mesmo arquivo: adicionar campo `regime_apuracao` (coluna já existe; **implementado como Input de texto livre** — o print de referência do Vinicius com as opções exatas não chegou; ver Pendências).
- [x] Mesmo arquivo: implementar busca automática de CEP (ViaCEP) no campo `cep` existente, seguindo o mesmo padrão já usado em `cadastro-lucenera-b86fe/src/components/clientes/AddressBlock.tsx`.
- [x] Mesmo arquivo: implementar busca automática de CNPJ via **BrasilAPI** (decisão do usuário, 2026-07-27: provedor gratuito) quando `cpf_cnpj` tiver 14 dígitos, preenchendo `nome` (razão social) e `nome_empresa` (nome fantasia) — sem sobrescrever campos que já tiverem algum valor.
- [x] Mesmo arquivo: adicionar dois novos blocos de endereço — "Endereço de Entrega" (`cep_entrega`/`endereco_entrega`/`numero_entrega`/`bairro_entrega`/`cidade_entrega`/`estado_entrega`) e "Endereço de Cobrança" (`cep_cobranca`/`endereco_cobranca`/`numero_cobranca`/`bairro_cobranca`/`cidade_cobranca`/`estado_cobranca`) — todas as colunas já existem em `contatos`, nenhuma migration necessária.
- [x] Aplicar o mesmo tratamento (relabel + campos que faltam + CEP/CNPJ + blocos de entrega/cobrança) em `gestao-financeira-clone-544cb (1)/src/components/ClientCreateModal.tsx`. Esse arquivo já tinha `inscricao_estadual` e `regime_apuracao` no formulário (apenas ganharam relabel/comentário), faltavam apenas relabel de `nome`/`nome_empresa`, autofill de CEP/CNPJ e os blocos de entrega/cobrança.
- [x] Nenhuma migration de banco foi necessária — todas as colunas citadas já existiam em `contatos` (confirmado em `supabase/db/current/01_schema_full.sql`, linhas 4483-4540).

### Passos manuais do usuário

- [ ] Confirmar com Vinicius **qual das telas de cliente** (CRM `/contatos/clientes`, ou o modal "Criar Cliente" dentro de Orçamentos) foi a que ele testou (ambas foram corrigidas nesta implementação, então esse passo é só para registro/confirmação, não bloqueia nada).
- [ ] Enviar (ou reenviar) o print do "regime tributário" mencionado nas Reuniões 01 e 02, para decidir se `regime_apuracao` deve virar um Select fixo (hoje está como texto livre nos dois sistemas).
- [ ] Homologação manual no navegador em ambos os sistemas (não há suíte de testes automatizada): criar cliente com CNPJ real e conferir autopreenchimento de nome/nome fantasia; preencher CEP em cada um dos 3 blocos de endereço e conferir que não há cruzamento de dados entre blocos; salvar e reabrir para conferir persistência de `inscricao_estadual`, `regime_apuracao` e dos 3 blocos de endereço.
- [ ] `git push` do submodule `lucenera-crm-3bd29 (1)` e de `gestao-financeira-clone-544cb (1)`, e atualização do ponteiro do submodule no repo central — não realizado por este agente (implementador não commita/publica).
- [ ] Rodar o agente `revisor` antes de qualquer commit.

## Objetivo

Corrigir rótulos e adicionar campos que faltam no formulário de cadastro de cliente do CRM (e replicar no modal equivalente de Orçamentos), a partir das correções pontuais que Vinicius apontou em reunião. Nenhuma mudança estrutural de banco é necessária — é 100% gap de formulário sobre colunas que já existem.

## Decisões aprovadas

- Nenhuma coluna nova é necessária em `contatos` — `rg`, `inscricao_estadual`, `inscricao_municipal`, `regime_apuracao`, `razao_social`/`nome`, `nome_empresa`, `cep_entrega`/`endereco_entrega`/..., `cep_cobranca`/`endereco_cobranca`/... já existem no schema real.
- **Provedor de CNPJ (decisão do usuário, 2026-07-27)**: gratuito (BrasilAPI ou ReceitaWS — implementador escolhe entre os dois na hora, sem custo/chave a configurar), mesmo padrão já usado para CEP (ViaCEP) no ecossistema.

## Definição da SPEC

### Estado atual (achado central)

Existem **três formulários de criação/edição de cliente/contato** em produção ou quase-produção, com campos e rótulos diferentes entre si:

| Sistema | Arquivo | Rota | Está no ar? |
|---|---|---|---|
| CRM | `lucenera-crm-3bd29 (1)/src/pages/contatos/Clientes.tsx` | `/contatos/clientes` | Sim |
| Orçamentos | `gestao-financeira-clone-544cb (1)/src/components/ClientCreateModal.tsx` | modal a partir do fluxo de orçamento | Sim |
| Cadastro | `cadastro-lucenera-b86fe/src/components/modals/ClienteModal.tsx` | `/clientes` | **Não** — `App.tsx` redireciona `/clientes` para `/pecas` desde a SPEC-CAD-06. Código morto hoje, apesar de ser (ironicamente) o mais completo dos três: já tem CEP automático via ViaCEP, RG, Inscrição Estadual/Municipal, Regime de Apuração e 3 blocos de endereço. |

O texto de Vinicius ("aqui no nome... aqui na empresa...") bate quase palavra por palavra com os rótulos reais da tela do **CRM** (`Clientes.tsx`): campo `nome` rotulado apenas "Nome", campo `nome_empresa` rotulado "Empresa" com placeholder "Razão Social ou Fantasia". Por isso esta SPEC toma o CRM como alvo principal, com o modal de Orçamentos como alvo secundário.

### Tabela de gaps (CRM `Clientes.tsx`)

| Pedido de Vinicius | Estado hoje | Coluna já existe? | Classificação |
|---|---|---|---|
| "nome" → "Nome e Razão Social" | Label fixo "Nome" | `contatos.nome` (sim) | claro, aplicar direto |
| "empresa" → "Nome Fantasia" | Label "Empresa", campo `nome_empresa` | `contatos.nome_empresa` (sim) | claro, aplicar direto |
| Busca automática por CNPJ | Não existe (`cpf_cnpj` é texto livre) | `contatos.cpf_cnpj`/`cnpj` (sim) | decidido — BrasilAPI/ReceitaWS |
| Busca automática por CEP | Não existe (`cep` é texto livre) | `contatos.cep` (sim) | claro — ViaCEP grátis, já é padrão no ecossistema |
| RG | Já existe no formulário | `contatos.rg` | nada a fazer |
| Inscrição Estadual | Ausente do formulário | `contatos.inscricao_estadual` (sim) | claro, só adicionar campo |
| Mais tipos de endereço (cobrança/entrega) | Só 1 bloco de endereço | colunas já existem, não usadas | claro, só adicionar 2 blocos |
| Regime tributário | Ausente do formulário | `contatos.regime_apuracao` (sim) | print prometido não chegou; opções exatas incertas |

### Comportamento proposto de autopreenchimento

- **CEP**: ao completar 8 dígitos em qualquer um dos três campos de CEP (principal, entrega, cobrança), consultar ViaCEP e preencher logradouro/bairro/cidade/UF daquele bloco especificamente (não misturar entre blocos).
- **CNPJ**: ao completar 14 dígitos em `cpf_cnpj`, consultar BrasilAPI/ReceitaWS e preencher `nome` (razão social retornada) e `nome_empresa` (nome fantasia retornado) — sem sobrescrever se o usuário já tiver digitado algo manualmente nesses campos.

### Análise de ecossistema

- **Depende de**: `contatos` (nenhuma coluna nova). Não depende de `orcamentos`, `produtos`, `projetos`.
- **Afeta**: CRM (alvo principal), Orçamentos (`ClientCreateModal.tsx`, alvo secundário). Não afeta Cadastro (tela morta), Compras, Estoque, Financeiro, RH, Hub/TI.
- **Observação de ecossistema (fora do escopo desta SPEC)**: existem 3 formulários de cliente divergentes hoje, sem fonte única de verdade de UI — cada correção de campo precisa ser replicada manualmente. Vale avaliar consolidação futura (ver SPEC-CAD-01 do Escopo de Cadastro).

## Critérios de aceite

- Campo antes rotulado "Nome" aparece como "Nome e Razão Social".
- Campo antes rotulado "Empresa" aparece como "Nome Fantasia".
- Digitar um CEP válido de 8 dígitos em qualquer um dos 3 blocos de endereço preenche logradouro/bairro/cidade/UF daquele bloco.
- Digitar um CNPJ válido de 14 dígitos preenche razão social e nome fantasia.
- Inscrição Estadual e Regime Tributário aparecem como campos editáveis e são persistidos em `contatos`.
- Salvar um cliente com endereço de entrega e/ou cobrança diferentes do principal e reabrir a edição mostra os três blocos preenchidos corretamente, sem mistura entre eles.

## Testes obrigatórios

Verificação manual no navegador (sem suíte automatizada): criar cliente novo preenchendo CNPJ real e conferir autopreenchimento; preencher CEP em cada um dos 3 blocos e conferir que não há cruzamento de dados entre blocos; salvar e reabrir para conferir persistência de todos os campos novos.

## Realizado

**2026-07-27** — Implementado nos dois formulários vivos (CRM alvo principal, Orçamentos alvo secundário). `cadastro-lucenera-b86fe/src/components/modals/ClienteModal.tsx` não foi tocado (código morto), mas serviu de referência de padrão (ViaCEP + 3 blocos de endereço).

**2026-07-27 — revisão (agente revisor) e correção:**

- Achado 🟡: o relabel de `nome` → "Nome e Razão Social" foi copiado do CRM para `ClientCreateModal.tsx` (Orçamentos) sem notar que esse formulário já tem um campo **dedicado** `razao_social` (ligado a `contatos.razao_social`, coluna documentada como "razão social (nome jurídico)... diferente de `nome` (nome fantasia/comercial)" desde a migration `20260703_017_razao_social_clientes`). O relabel criava dois campos com semântica sobreposta na mesma tela, e o autofill de CNPJ escrevia a razão social retornada pela BrasilAPI em `nome` em vez do campo `razao_social` que existe especificamente para isso.
- Corrigido: label de `nome` em `ClientCreateModal.tsx` revertido para "Nome Completo / Fantasia" (o original, antes desta SPEC); autofill de CNPJ agora preenche `razao_social` com `data.razao_social` (só se vazio) e `nome`/`nome_empresa` com `data.nome_fantasia` (fallback `data.razao_social`). Nenhuma mudança no CRM (`Clientes.tsx`), que não tem campo `razao_social` separado — lá `nome` continua sendo o campo correto para "Nome e Razão Social", conforme decisão original.
- `npx tsc --noEmit` limpo após a correção.

- **`lucenera-crm-3bd29 (1)/src/pages/contatos/Clientes.tsx`**:
  - Label `nome` → "Nome e Razão Social"; label `nome_empresa` → "Nome Fantasia".
  - Adicionados campos `inscricao_estadual` e `regime_apuracao` ao formulário (schema Zod, defaultValues, `openNewModal`, `openEditModal` e UI).
  - Busca automática de CEP via ViaCEP (`buscarEnderecoPorCep`) reutilizada nos 3 blocos de endereço (principal, entrega, cobrança), preenchendo apenas o bloco correspondente, sem cruzar dados. Erro de rede/CEP inválido dispara `toast` de aviso sem bloquear o formulário.
  - Busca automática de CNPJ via BrasilAPI (`buscarDadosPorCnpj`), disparada ao completar 14 dígitos em `cpf_cnpj`. Preenche `nome` (razão social) e `nome_empresa` (nome fantasia) **apenas se o campo estiver vazio no momento da consulta** — decisão de implementação: em vez de rastrear "foi editado nesta sessão" com refs adicionais, optei por checar `form.getValues(...)` vazio no momento do preenchimento, o que cobre tanto o caso de edição manual pelo usuário quanto dados já carregados do banco ao editar um cliente existente. Erro de rede/CNPJ não encontrado dispara `toast` sem bloquear.
  - Adicionados os blocos "Endereço de Entrega" e "Endereço de Cobrança" com os 6 campos cada (`cep_entrega`/`endereco_entrega`/`numero_entrega`/`bairro_entrega`/`cidade_entrega`/`estado_entrega` e equivalentes `_cobranca`), cada um com autofill de CEP próprio.
  - `npm run build` e `npm run lint` (oxlint) rodados com sucesso; `oxfmt` aplicado. Nenhum warning novo introduzido (o único warning pré-existente no arquivo, `react-hooks/exhaustive-deps` no `useEffect` de `fetchClients`, já existia antes desta mudança).

- **`gestao-financeira-clone-544cb (1)/src/components/ClientCreateModal.tsx`**:
  - Label `nome` → "Nome e Razão Social"; label `nome_empresa` (antes "Nome da Empresa") → "Nome Fantasia".
  - `inscricao_estadual` e `regime_apuracao` já existiam no formulário (não fazia parte do checklist original do CRM, mas o modal de Orçamentos já os tinha); apenas foi adicionado o comentário sobre a decisão de manter `regime_apuracao` como texto livre.
  - Mesmas funções `buscarEnderecoPorCep`/`buscarDadosPorCnpj` replicadas (usando `toast.warning` do `sonner`, padrão já usado neste arquivo, em vez do `useToast` do CRM). CNPJ só é consultado quando `tipo_pessoa === 'juridica'` (este formulário tem CPF/CNPJ combinados com toggle de tipo de pessoa, diferente do CRM).
  - Adicionados os mesmos 12 campos de endereço de entrega/cobrança ao schema, `defaultValues`, payload de insert e UI, com autofill de CEP por bloco.
  - `npm run build`, `npm run lint` (oxlint) e `npx prettier --write` rodados com sucesso (este sistema usa oxlint + Prettier, não ESLint — não há `eslint.config.js` no repo apesar do script `lint` mencionar apenas oxlint). Nenhum warning novo introduzido no arquivo.

- **Decisão de implementação registrada**: `regime_apuracao` foi implementado como `Input` de texto livre simples em ambos os arquivos, e não como `Select` com opções fixas, porque o print de referência do Vinicius com as opções exatas do regime tributário nunca chegou (ver Pendências). Isso está documentado em comentário no código, em ambos os arquivos, próximo à definição do campo no schema Zod e no `FormField`.

- **Não realizado por este agente** (fora do escopo do implementador): nenhuma migration foi criada ou aplicada (não havia nenhuma pendente nesta SPEC); nenhum commit/push foi feito nos submodules; nenhuma publicação no Skip Cloud.

## Pendências

- [ ] Confirmar com Vinicius qual tela de cliente ele testou de fato (CRM vs. modal de Orçamentos) — informativo, ambas já foram corrigidas.
- [x] Opções de "Regime Apuração" — usuário confirmou em 2026-08-04: apenas `Simples Nacional` e `Regime Normal` (não as 3 do código morto em `ClienteModal.tsx`, que ficou desatualizado/incorreto). Migration `20260804_070_spec052_regime_apuracao_fixo` aplicada; campo virou Select fixo no CRM e na Gestão Financeira. Ver `CHANGELOG.md` (2026-08-04 (5)).
- [x] Fornecedores no CRM — resolvido em 2026-08-04, ver `CHANGELOG.md` (2026-08-04 (3)): nova aba `src/pages/contatos/Fornecedores.tsx` publicada no Skip.
- [x] "Tipo Cliente" (consumidor/não contribuinte/indústria/revendedor) — usuário confirmou em 2026-08-04 que deve ser criado como Select fixo. Migration `20260804_069_spec052_tipo_cliente` aplicada no Supabase real (`contatos.tipo_cliente`); frontend publicado no CRM (`ClientFormFields.tsx`/`ContatoDetail.tsx`) e na Gestão Financeira (`ClientCreateModal.tsx`). Ver `CHANGELOG.md` (2026-08-04 (4)). Escopo: só cliente, campo opcional (nullable), sem backfill dos contatos existentes.
