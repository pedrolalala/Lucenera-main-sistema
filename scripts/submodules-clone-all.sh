#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "Erro: esta pasta ainda nao e um repositorio Git."
  echo "Clone o repo central ou rode 'git init' antes."
  exit 1
fi

if [ ! -f ".gitmodules" ]; then
  echo "Erro: .gitmodules nao encontrado."
  echo "Registre os submodules primeiro com: ./scripts/submodules-register.sh"
  exit 1
fi

JOBS="${JOBS:-8}"

echo "Sincronizando URLs dos submodules..."
git submodule sync --recursive

echo "Clonando/atualizando submodules com $JOBS jobs..."
git submodule update --init --recursive --jobs "$JOBS"

echo
echo "Status dos submodules:"
git submodule status --recursive

