#!/usr/bin/env bash
# ==============================================================================
# build.sh: Build Qualcomm Yocto Image / SDK with meta-qcom-qim-product-sdk
# ==============================================================================

# Note: do not use set -u because Yocto / Poky setup scripts rely on expanding unset variables
set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# If executed on host NixOS outside the FHS sandbox, re-run inside the FHS environment.
# We verify presence of /usr/bin/python3 and /usr/bin/gcc (which only exist inside the FHS chroot).
if [[ ! -x /usr/bin/python3 || ! -x /usr/bin/gcc ]]; then
  echo "[+] Outside FHS container. Launching Qualcomm Yocto FHS sandbox..."
  exec "$SCRIPT_DIR/enter-env.sh" "$0" "$@"
fi

# Ensure FHS system paths are prioritized so host/direnv tools never shadow FHS binaries
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:${PATH}"

# Detect workspace root
WORKSPACE_DIR=""
if [[ -f "./setup-environment" ]]; then
  WORKSPACE_DIR="$(pwd)"
elif [[ -f "$SCRIPT_DIR/workspace/setup-environment" ]]; then
  WORKSPACE_DIR="$SCRIPT_DIR/workspace"
elif [[ -f "$SCRIPT_DIR/setup-environment" ]]; then
  WORKSPACE_DIR="$SCRIPT_DIR"
fi

if [[ -z "$WORKSPACE_DIR" ]]; then
  echo "[-] Error: setup-environment not found in current directory or workspace/."
  echo "    Please run ./init-workspace.sh first to sync the Qualcomm BSP."
  exit 1
fi

cd "$WORKSPACE_DIR"

# Defaults
export MACHINE="${MACHINE:-qcs6490-rb3gen2-vision-kit}"
export DISTRO="${DISTRO:-qcom-wayland}"
export EXTRALAYERS="${EXTRALAYERS:-meta-qcom-qim-product-sdk}"
export SHELL=/bin/bash

# Default target
TARGET="${1:-qcom-qim-product-sdk}"
shift || true

echo "=========================================================="
echo " Starting Qualcomm Yocto Build"
echo " Workspace:   $WORKSPACE_DIR"
echo " Machine:     $MACHINE"
echo " Distro:      $DISTRO"
echo " ExtraLayers: $EXTRALAYERS"
echo " Target:      $TARGET $@"
echo "=========================================================="

# Source Qualcomm Linux build setup environment
# Note: Explicitly specify "build-${DISTRO}" so caller positional arguments are not inherited.
# Temporarily disable -e and -u since setup-environment and oe-init-build-env rely on unset variables.
set +u
set +e
source setup-environment "build-${DISTRO}"
set -e

# Execute BitBake
# Ensure uninative is disabled and virtual/crypt-native is built by Yocto on NixOS FHS
CONF_FILE="$WORKSPACE_DIR/build-${DISTRO}/conf/local.conf"
if [[ -f "$CONF_FILE" ]]; then
  if ! grep -q 'INHERIT:remove = "uninative"' "$CONF_FILE"; then
    echo "[+] Disabling uninative in $CONF_FILE to ensure host toolchain compatibility..."
    echo -e '\n# Disable uninative on NixOS FHS (host environment is already hermetic and reproducible)\nINHERIT:remove = "uninative"' >> "$CONF_FILE"
  fi
  if ! grep -q 'virtual/crypt-native' "$CONF_FILE"; then
    echo "[+] Ensuring virtual/crypt-native is built in sysroot (NixOS FHS compatibility)..."
    echo -e '# Build libxcrypt-native within Yocto sysroot rather than assuming host libcrypt\nASSUME_PROVIDED:remove = "virtual/crypt-native"' >> "$CONF_FILE"
  fi
fi

echo "[+] Invoking bitbake $TARGET $@..."
bitbake "$TARGET" "$@"
