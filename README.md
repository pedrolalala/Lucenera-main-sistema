# Lucenera - ADAPTA PASS

Repositorio central de memoria, contexto, documentos, banco consolidado e coordenacao dos sistemas da Lucenera.

Este repositorio nao substitui os repositorios proprios de cada sistema. Ele e a fonte compartilhada para entender o ecossistema inteiro antes de mexer em codigo, banco, relatorios, specs ou processos.

## Fontes de verdade

- `supabase/`: fonte de verdade do banco, relacionamentos, migrations centrais e contexto tecnico.
- `03-Projeto/`: relatorios finais, escopos, plano de acao e SPECs.
- `02-Reunioes/`: transcricoes, atas, fluxos, decisoes e pendencias vindas das reunioes.
- `01-Documento/`: planilhas, arquivos de entrada, videos e descritivos operacionais.
- `04-Sistemas/`: espelho local e inventario dos sistemas. O codigo de cada app deve ser atualizado tambem no repositorio GitHub proprio.
- `00-Contexto/`: regras de trabalho, inventario de repositorios e instrucoes para manter a memoria compartilhada.

## Leitura obrigatoria antes de qualquer mudanca

1. `AGENTS.md`
2. `00-Contexto/FLUXO_DE_TRABALHO.md`
3. `04-Sistemas/00 - Sumario Sistemas.md`
4. `03-Projeto/00_INDICE.md`
5. `supabase/README.md`
6. `supabase/docs/ai_context_global.md`

Se a mudanca envolver banco ou relacionamento entre sistemas, ler tambem:

1. `supabase/docs/relationships.md`
2. `supabase/docs/table_index.md`
3. O dominio afetado em `supabase/db/domains/`
4. `supabase/db/current/`, quando nomes exatos de tabela, coluna, view, trigger, funcao ou policy forem necessarios.

## Regra de ouro

Toda alteracao relevante precisa deixar rastro nos dois lugares certos:

1. Repositorio do sistema afetado: codigo, teste, ajuste local e contexto local do sistema.
2. Repositorio central `Lucenera - ADAPTA PASS`: SPEC, changelog, contexto, relatorio, banco consolidado ou decisao atualizada.

## Clone com submodules

O desenvolvedor deve clonar o repositorio central trazendo os sistemas dentro de `04-Sistemas/`:

```bash
git clone --recurse-submodules <URL_DO_REPO_CENTRAL> "Lucenera - ADAPTA PASS"
cd "Lucenera - ADAPTA PASS"
./scripts/submodules-clone-all.sh
```

Se o clone ja foi feito sem submodules:

```bash
cd "Lucenera - ADAPTA PASS"
git submodule update --init --recursive --jobs 8
```

Leia `00-Contexto/SUBMODULES.md` para registrar, atualizar e publicar mudancas de submodule.

## Ambiente local

Criar manualmente um arquivo `.env` na raiz deste repositorio para acesso ao Supabase. Esse arquivo nao deve ser commitado no GitHub.

Use `.env.example` como base:

```bash
cp .env.example .env
```

Variaveis esperadas:

- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`
- `SUPABASE_SERVICE_ROLE_KEY`
- `SUPABASE_DB_URL`

Nunca publicar valores reais dessas variaveis em commits, PRs, logs, prints ou documentos.

## Estrutura alvo

```text
Lucenera - ADAPTA PASS/
  00-Contexto/     Regras de trabalho, memoria operacional e inventario.
  01-Documento/    Dados de entrada, planilhas, videos e materiais brutos.
  02-Reunioes/     Historico de reunioes, decisoes, fluxos e pendencias.
  03-Projeto/      Relatorios, escopos, planos de acao e SPECs.
  04-Sistemas/     Espelho/inventario dos sistemas e ponte para repos proprios.
  supabase/        Fonte de verdade tecnica do banco e funcoes.
  AGENTS.md        Instrucao geral para IA/desenvolvedor.
  CHANGELOG.md     Registro cronologico das mudancas de memoria e processo.
```

## Observacao sobre Git

Decisao: os sistemas com repositorio proprio devem entrar como submodules em `04-Sistemas/`.

O repo central versiona o ponteiro de commit de cada sistema. Para atualizar codigo, alterar o repo do sistema, fazer commit/push nele e depois atualizar o ponteiro do submodule no repo central.

Nao commitar `.env`, `node_modules`, `dist` ou arquivos temporarios.
