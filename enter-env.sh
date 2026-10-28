#!/usr/bin/env bash
# ==============================================================================
# enter-env.sh: Enter the Qualcomm Yocto FHS Build Environment on NixOS
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

FHS_BIN="$SCRIPT_DIR/fhs-bin/bin/yocto-fhs-env"

# Ensure FHS environment wrapper is built
if [[ ! -x "$FHS_BIN" ]]; then
  echo "[+] Building FHS sandbox wrapper..."
  if command -v nix >/dev/null 2>&1 && nix flake --help >/dev/null 2>&1; then
    nix build .#fhs --out-link "$SCRIPT_DIR/fhs-bin"
  elif command -v nix-build >/dev/null 2>&1; then
    nix-build "$SCRIPT_DIR/default.nix" -o "$SCRIPT_DIR/fhs-bin"
  else
    echo "[-] Error: Neither 'nix' (with flakes) nor 'nix-build' was found."
    exit 1
  fi
fi

# Disarm direnv within the child container to prevent recursive namespace loops
export DIRENV_DIR=""
export DIRENV_FILE=""

if [[ $# -eq 0 ]]; then
  echo "[+] Entering Qualcomm Yocto FHS build environment (interactive bash)..."
  echo "[+] Type 'exit' to return to host NixOS."
  exec "$FHS_BIN"
else
  exec "$FHS_BIN" -c '"$@"' -- "$@"
fi
