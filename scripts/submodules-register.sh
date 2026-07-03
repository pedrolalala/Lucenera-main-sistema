#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "Erro: esta pasta ainda nao e um repositorio Git."
  echo "Rode 'git init' no repo central antes de registrar submodules."
  exit 1
fi

path_registered() {
  local path="$1"
  [ -f ".gitmodules" ] || return 1
  git config -f .gitmodules --get-regexp '^submodule\..*\.path$' 2>/dev/null \
    | sed 's/^[^ ]* //' \
    | grep -Fxq "$path"
}

path_empty_dir() {
  local path="$1"
  [ -d "$path" ] && [ -z "$(find "$path" -mindepth 1 -maxdepth 1 -print -quit)" ]
}

submodule_repo_ahead() {
  local path="$1"
  if git -C "$path" rev-parse --abbrev-ref --symbolic-full-name '@{u}' >/dev/null 2>&1; then
    local ahead
    ahead="$(git -C "$path" rev-list --count '@{u}..HEAD')"
    [ "$ahead" != "0" ]
  else
    return 1
  fi
}

add_submodule() {
  local url="$1"
  local path="$2"

  if path_registered "$path"; then
    echo "OK: $path ja registrado"
    return
  fi

  mkdir -p "$(dirname "$path")"

  if [ -e "$path" ]; then
    if [ -d "$path/.git" ]; then
      if [ -n "$(git -C "$path" status --porcelain)" ]; then
        echo "PULAR: $path tem mudancas locais. Commit/push antes de registrar como submodule."
        return
      fi

      if submodule_repo_ahead "$path"; then
        echo "PULAR: $path tem commits locais ainda nao enviados ao GitHub."
        return
      fi

      echo "Registrando repo existente: $path"
      git submodule add -f "$url" "$path"
      return
    fi

    if path_empty_dir "$path"; then
      rmdir "$path"
      echo "Clonando submodule: $path"
      git submodule add "$url" "$path"
      return
    fi

    echo "PULAR: $path existe, mas nao e um repo Git nem uma pasta vazia."
    echo "       Mova/renomeie essa pasta ou substitua por um clone limpo antes de registrar."
    return
  fi

  echo "Clonando submodule: $path"
  git submodule add "$url" "$path"
}

add_submodule "https://github.com/pedrolalala/central-lucenera.git" "04-Sistemas/central-lucenera-dashboard-1c9ba"
add_submodule "https://github.com/pedrolalala/administra--o-bancaria.git" "04-Sistemas/retorno-bancario-bradesco-5392a"
add_submodule "https://github.com/pedrolalala/Lucenera---Gest-o-Financeira.git" "04-Sistemas/gestao-financeira-clone-544cb (1)"
add_submodule "https://github.com/pedrolalala/lucenera-crm.git" "04-Sistemas/lucenera-crm-3bd29 (1)"
add_submodule "https://github.com/pedrolalala/dashboard-rh-lucenera-6g2endmv7.git" "04-Sistemas/dashboard-rh-lucenera-5fe9c"
add_submodule "https://github.com/pedrolalala/lucenera-logistics-bz5s7xehm.git" "04-Sistemas/lucenera-logistics-b7cd1"
add_submodule "https://github.com/pedrolalala/cadastro-lucenera.git" "04-Sistemas/cadastro-lucenera-b86fe"

echo
echo "Registro finalizado. Revise com:"
echo "  git status"
echo "  git submodule status"
