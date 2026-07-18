---
titulo: "SPEC-029 — Subagentes de IA especializados para o fluxo de desenvolvimento"
status: pendente
data_ultima_modificacao: 2026-07-16
sistemas_envolvidos:
  - Meta/Processo (repositório central — não altera sistemas de negócio nem schema)
  - dashboard-lucenera-b02z85wa3 (destino do agente de Métricas/Relatórios)
---

# SPEC-029 — Subagentes de IA especializados para o fluxo de desenvolvimento

> Toda vez que a SPEC for editada, atualizar `data_ultima_modificacao`.

## Checklist de Ação

- [x] Criar `03-Projeto/Planos de Ação/SPECs/SPEC-029_Subagentes_IA_Fluxo_Desenvolvimento.md` (este arquivo)
- [x] Criar `.claude/agents/planner.md` — gera SPEC seguindo `COMO_CRIAR_SPEC.md`, nunca edita código
- [x] Criar `.claude/agents/revisor.md` — revisão read-only pós-implementação
- [x] Criar `.claude/agents/implementador.md` — edita código do sistema + redige (não aplica) migration
- [x] Criar `.claude/agents/metricas.md` — leitura read-only sobre views `vw_*`, constrói relatórios dentro de `04-Sistemas/dashboard-lucenera-b02z85wa3`
- [x] Validar os prompts (planner/implementador/revisor) com um caso real — ver SPEC-030 (fix de filtro de tipo fornecedor em `compras-lucenera`), ponta a ponta sem achado crítico. Agente `metricas` ainda não testado.

### Passos manuais do usuário

- [ ] Pedro testa os 4 agentes em uma SPEC real e ajusta os prompts com base no resultado
- [ ] Pedro decide, quando `dashboard-lucenera-b02z85wa3` ganhar a primeira página de métricas, se ela deve ficar exposta no Hub (`central-lucenera-dashboard`) ou só internamente

## Objetivo

Formalizar como subagentes Claude Code (`.claude/agents/*.md`) três papéis que hoje já existem de forma implícita/manual no dia a dia (spec, revisão, execução), e criar um quarto papel novo (métricas/relatórios) para atender uma dor já verbalizada mais de uma vez pelo Filippo ("falta de chat de IA para relatórios", "dashboards não confiáveis"). **Não** cria um agente autônomo para aplicar migration no Supabase real — essa etapa continua manual.

## Decisões aprovadas

- Aplicação de migration no Supabase real **não** vira agente autônomo — é o passo de maior risco (dinheiro, fiscal, folha) e menor ganho (o gargalo observado nas migrations de 14-16/07 é validar efeito colateral, não o comando de aplicar).
- Nenhum agente decide regra de negócio (classificação Fixo×Variável, controle de acesso, o que fazer com dados órfãos) — isso sempre sobe para Pedro/Filippo, replicando o que as SPECs 020-028 já fazem hoje.
- Agentes seguem o padrão **de cada sistema individualmente** (services vs. acesso direto, Zustand vs. Context, oxlint+oxfmt vs. eslint+Prettier) em vez de impor um house style único — os 8 sistemas divergiram do mesmo template ("skip-react-template") sem nunca sincronizar, e forçar um padrão novo geraria mais inconsistência, não menos.
- Nenhum agente pode exigir "rodar suite de testes" como critério de aceite — não existe teste real em nenhum dos 8 sistemas (todos têm apenas `"test": "echo ... && exit 0"`).
- `retorno-bancario-bradesco-5392a` recebe cautela extra no prompt do Implementador — é o único sistema com proteção de idempotência (hash SHA-256 + RPC transacional `processar_retorno_bancario`) e o de maior volume de migrations (14), por lidar diretamente com conciliação bancária/dinheiro.
- O agente de Métricas/Relatórios **não** vira chat dentro de `gestao-financeira-clone-544cb` (scaffold de chat existente fica de fora do escopo desta SPEC) nem vira página nova no dashboard Streamlit em Python. Ele opera exclusivamente dentro de `04-Sistemas/dashboard-lucenera-b02z85wa3`, construindo páginas/telas novas ali, sempre consumindo views `vw_*`/`v_*` já existentes — nunca escrevendo SQL de negócio ad-hoc.

## Definição da SPEC

### Papéis e escopo de ferramentas

| Agente | Lê | Escreve | Autonomia de decisão |
|---|---|---|---|
| Planner | tudo (specs, memória, código, reuniões) | só a SPEC | zero — SPEC sempre revisada por Pedro antes de implementar |
| Implementador | código do sistema + SPEC aprovada | código do app + arquivo `.sql` de migration (não aplica) | zero em regra de negócio; segue padrão já existente do sistema |
| Revisor | diff/código gerado pelo Implementador | nada (só relatório) | zero — reporta severidade, não decide |
| Métricas | views `vw_*` já existentes + código de `dashboard-lucenera-b02z85wa3` | páginas/componentes novos dentro de `dashboard-lucenera-b02z85wa3` | zero — nunca cria view/tabela nova sem SPEC própria |

### Achados que moldaram os prompts

- Zero CI/teste real em 8 sistemas → Revisor é o único gate de qualidade automatizado possível.
- Gargalo real é aplicar+validar migration, não escrever código → Implementador rascunha, nunca aplica.
- Tipos `Database` gerados ficam defasados de views novas (`as any` recorrente em pelo menos 2 sistemas) → Revisor não reprova por `any` quando é contorno de tipo desatualizado, mas sinaliza quando é preguiça evitável.
- `dashboard-lucenera-b02z85wa3` já segue o padrão do template comum (React 19 + Vite + shadcn/ui + Tailwind + recharts, `lib/supabase/{client,types}.ts`, sem camada `services/`), com páginas `Index`, `Login`, `Logs`, `Settings`, `Sync` — é onde o agente de Métricas deve seguir a convenção existente, não inventar uma nova.
- `retorno-bancario-bradesco-5392a` é o sistema mais sensível (CNAB, hash de dedup, RPC transacional) — Implementador precisa de aviso explícito para não quebrar esse mecanismo.

## Realizado

### 2026-07-16

- Análise completa do processo (`AGENTS.md`, `FLUXO_DE_TRABALHO.md`, `COMO_CRIAR_SPEC.md`), das 9 reuniões com o Filippo (insights de automação + transcrição bruta da reunião de 13/07), das SPECs 020-028, das migrations de 14-16/07, e dos 8 sistemas em `04-Sistemas/` (incluindo 3 submodules que precisaram ser inicializados via `git submodule update --init`) + dashboard Streamlit.
- Definição final dos 4 papéis de subagente e criação desta SPEC.
- Criação dos 4 arquivos de subagente em `.claude/agents/`.
- Validação ponta a ponta com caso real: SPEC-030 (bug de filtro de tipo fornecedor em `compras-lucenera`) rodada seguindo os papéis `planner` → `implementador` → `revisor`. Nenhum ajuste de prompt necessário até aqui.

## Pendências

- [ ] Validar os 4 prompts em um caso real (uma SPEC pequena de ponta a ponta) e ajustar com base no resultado — nenhum dos agentes foi testado em uso real ainda.
