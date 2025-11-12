#!/usr/bin/env bash

# Developer convenience script for working on the Bedrock Text2SQL project.
#
# Usage:
#   source activate-env.sh
#
# The script will create (if needed) and activate a Python virtual environment
# named "agent-txt2sql" under the local .venv/ directory, then ensure the
# repository dependencies are installed.

# Preserve caller shell options so sourcing this script doesn't leave
# unexpected settings (e.g. `set -e`) behind.
if [ -n "${BASH:-}" ]; then
  __TXT2SQL_OLD_OPTS=$(set +o)
fi

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VENV_DIR="$REPO_ROOT/.venv/agent-txt2sql"
PYTHON_BIN="${PYTHON_BIN:-python3}"

if [ ! -d "$VENV_DIR" ]; then
  echo "[env] Creating virtual environment at $VENV_DIR"
  "$PYTHON_BIN" -m venv "$VENV_DIR"
fi

# shellcheck disable=SC1090
source "$VENV_DIR/bin/activate"

if [ -f "$REPO_ROOT/streamlit_app/requirements.txt" ]; then
  echo "[env] Installing project requirements"
  pip install --upgrade pip
  pip install -r "$REPO_ROOT/streamlit_app/requirements.txt"
fi

echo "[env] Virtual environment 'agent-txt2sql' is active."

# Restore previous shell options if we saved them (only when sourced in bash).
if [ -n "${BASH:-}" ]; then
  eval "$__TXT2SQL_OLD_OPTS"
  unset __TXT2SQL_OLD_OPTS
fi

