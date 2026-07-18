# Submodules dos Sistemas

Decisao: os sistemas com repositorio proprio devem ser submodules dentro de `04-Sistemas/`.

O repositorio central guarda memoria, specs, contexto e o ponteiro de commit de cada sistema. O codigo continua sendo commitado no repositorio GitHub proprio de cada app.

## Clonar tudo pela primeira vez

```bash
git clone --recurse-submodules <URL_DO_REPO_CENTRAL> "Lucenera - ADAPTA PASS"
cd "Lucenera - ADAPTA PASS"
./scripts/submodules-clone-all.sh
```

## Se ja clonou sem submodules

```bash
cd "Lucenera - ADAPTA PASS"
git submodule update --init --recursive --jobs 8
```

## Depois de puxar atualizacoes do repo central

```bash
git pull
git submodule sync --recursive
git submodule update --init --recursive --jobs 8
```

## Registrar submodules no repo central

Use quando o repo central ja tiver sido inicializado com Git e os submodules ainda nao estiverem registrados:

```bash
cd "Lucenera - ADAPTA PASS"
./scripts/submodules-register.sh
git status
```

Depois revisar o status, fazer commit do `.gitmodules` e dos ponteiros:

```bash
git status
git add .gitmodules scripts 00-Contexto README.md AGENTS.md CHANGELOG.md
# Adicione somente os paths que aparecerem no git status como submodules registrados.
# Nao rode "git add 04-Sistemas" de forma ampla.
git add "04-Sistemas/central-lucenera-dashboard-1c9ba"
git add "04-Sistemas/retorno-bancario-bradesco-5392a"
git add "04-Sistemas/gestao-financeira-clone-544cb (1)"
git add "04-Sistemas/lucenera-crm-3bd29 (1)"
git add "04-Sistemas/dashboard-rh-lucenera-5fe9c"
git add "04-Sistemas/lucenera-logistics-b7cd1"
git add "04-Sistemas/cadastro-lucenera-b86fe"
git commit -m "chore: configure system submodules"
```

Se algum path foi pulado pelo script, nao adicione esse path no commit.

## Atualizar codigo de um sistema

```bash
cd "04-Sistemas/<sistema>"
git checkout main
git pull
# fazer alteracoes
git add .
git commit -m "feat: descreve a mudanca"
git push
```

Depois atualizar o ponteiro no repo central:

```bash
cd ../..
git add "04-Sistemas/<sistema>" CHANGELOG.md "03-Projeto/Planos de Ação/SPECs/<SPEC>.md"
git commit -m "chore: update <sistema> submodule"
```

## Regra critica

Nao commitar no repo central um ponteiro de submodule para commit local que ainda nao foi enviado ao GitHub do sistema. Se isso acontecer, outro desenvolvedor nao conseguira clonar aquele commit.

## Submodules planejados

| Sistema | Path | Repo |
| --- | --- | --- |
| Central Lucenera / Hub | `04-Sistemas/central-lucenera-dashboard-1c9ba` | `https://github.com/pedrolalala/central-lucenera.git` |
| Administracao Bancaria / Financeiro | `04-Sistemas/retorno-bancario-bradesco-5392a` | `https://github.com/pedrolalala/administra--o-bancaria.git` |
| Orcamentos | `04-Sistemas/gestao-financeira-clone-544cb (1)` | `https://github.com/pedrolalala/Lucenera---Gest-o-Financeira.git` |
| Lucenera CRM | `04-Sistemas/lucenera-crm-3bd29 (1)` | `https://github.com/pedrolalala/lucenera-crm.git` |
| Dashboard RH Lucenera | `04-Sistemas/dashboard-rh-lucenera-5fe9c` | `https://github.com/pedrolalala/dashboard-rh-lucenera-6g2endmv7.git` |
| Logistica Lucenera | `04-Sistemas/lucenera-logistics-b7cd1` | `https://github.com/pedrolalala/lucenera-logistics-bz5s7xehm.git` |
| Cadastro Lucenera | `04-Sistemas/cadastro-lucenera-b86fe` | `https://github.com/pedrolalala/cadastro-lucenera.git` |
| Compras Lucenera / Necessidade de Compra | `04-Sistemas/compras-lucenera-3o23t98ee` | `https://github.com/pedrolalala/compras-lucenera-3o23t98ee.git` |
| Dashboard Lucenera | `04-Sistemas/dashboard-lucenera-b02z85wa3` | `https://github.com/pedrolalala/dashboard-lucenera-b02z85wa3.git` |
| Catalogo de Pecas Ubiqua | `04-Sistemas/catalogo-pecas-ubiqua-e6fa0` | `https://github.com/pedrolalala/cat-logo-pe-as-ubiqua-.git` |

## Pendencias

- `lucenera-logistica-atual-backup`: manter como backup ate a migracao.
- `Lucenera-Power-point`: repo de apoio; adicionar como submodule apenas se o time quiser versionar o artefato dentro do central.
