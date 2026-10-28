#!/usr/bin/env bash
# ==============================================================================
# init-workspace.sh: Initialize Qualcomm Linux Yocto BSP Workspace on NixOS
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# If executed on host NixOS outside the FHS sandbox, re-run inside the FHS environment.
# We verify presence of /usr/bin/python3 and /usr/bin/gcc (which only exist inside the FHS chroot).
if [[ ! -x /usr/bin/python3 || ! -x /usr/bin/gcc ]]; then
  echo "[+] Outside FHS container. Launching Qualcomm Yocto FHS sandbox..."
  exec "$SCRIPT_DIR/enter-env.sh" "$0" "$@"
fi

# Default configuration
DEFAULT_WORKSPACE="$SCRIPT_DIR/workspace"
DEFAULT_MANIFEST="qcom-6.6.142-QLI.1.9.1-Ver.1.0_qim-product-sdk-2.5.0.xml"
DEFAULT_BRANCH="qcom-linux-scarthgap"
DEFAULT_JOBS="$(nproc 2>/dev/null || echo 8)"

WORKSPACE="${WORKSPACE:-$DEFAULT_WORKSPACE}"
MANIFEST="${MANIFEST:-$DEFAULT_MANIFEST}"
BRANCH="${BRANCH:-$DEFAULT_BRANCH}"
JOBS="${JOBS:-$DEFAULT_JOBS}"
DRY_RUN=0

usage() {
  cat <<EOF
Usage: $0 [options]

Options:
  -w, --workspace <dir>   Target workspace directory (default: workspace)
  -m, --manifest <xml>    Qualcomm release manifest file (default: $DEFAULT_MANIFEST)
  -b, --branch <branch>   Manifest git branch (default: $DEFAULT_BRANCH)
  -j, --jobs <num>        Number of parallel sync jobs (default: $DEFAULT_JOBS)
  --dry-run               Initialize repo without running full repo sync
  -h, --help              Show this help message

Examples:
  $0
  $0 --workspace my-release --jobs 12
  $0 --manifest qcom-6.6.142-QLI.1.9.1-Ver.1.1.xml
EOF
  exit 0
}

# Parse command line options
while [[ $# -gt 0 ]]; do
  case "$1" in
    -w|--workspace)
      WORKSPACE="$2"
      shift 2
      ;;
    -m|--manifest)
      MANIFEST="$2"
      shift 2
      ;;
    -b|--branch)
      BRANCH="$2"
      shift 2
      ;;
    -j|--jobs)
      JOBS="$2"
      shift 2
      ;;
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    -h|--help)
      usage
      ;;
    *)
      echo "[-] Unknown option: $1"
      usage
      ;;
  esac
done

echo "=========================================================="
echo " Initializing Qualcomm Linux Yocto Workspace"
echo " Workspace: $WORKSPACE"
echo " Manifest:  $MANIFEST"
echo " Branch:    $BRANCH"
echo " Sync Jobs: $JOBS"
echo "=========================================================="

# Check git user identity
GIT_USER="$(git config --get user.name || true)"
GIT_EMAIL="$(git config --get user.email || true)"
if [[ -z "$GIT_USER" || -z "$GIT_EMAIL" ]]; then
  echo "[-] Git user identity is not set. Please run:"
  echo "    git config --global user.name 'Your Name'"
  echo "    git config --global user.email 'you@example.com'"
  exit 1
fi
echo "[+] Git identity: $GIT_USER <$GIT_EMAIL>"

mkdir -p "$WORKSPACE"
cd "$WORKSPACE"

# Initialize repo manifest
echo "[+] Initializing repo with manifest: $MANIFEST..."
repo init -u https://github.com/qualcomm-linux/qcom-manifest -b "$BRANCH" -m "$MANIFEST"

if [[ "$DRY_RUN" -eq 1 ]]; then
  echo "[+] --dry-run specified: skipping repo sync."
  exit 0
fi

# Synchronize repositories
echo "[+] Synchronizing layers (repo sync -j$JOBS)..."
repo sync -j"$JOBS"

# Ensure submodules are initialized
if [[ -f "$SCRIPT_DIR/.gitmodules" && (! -f "$SCRIPT_DIR/meta-qcom-qim-product-sdk/conf/layer.conf") ]]; then
  echo "[+] Initializing Git submodules (meta-qcom-qim-product-sdk)..."
  git -C "$SCRIPT_DIR" submodule update --init --recursive
fi

# Link local meta-qcom-qim-product-sdk if present
mkdir -p "$WORKSPACE/layers"
if [[ -d "$SCRIPT_DIR/meta-qcom-qim-product-sdk" && -f "$SCRIPT_DIR/meta-qcom-qim-product-sdk/conf/layer.conf" ]]; then
  TARGET_LAYER="$WORKSPACE/layers/meta-qcom-qim-product-sdk"
  if [[ -L "$TARGET_LAYER" ]]; then
    echo "[+] Layer layers/meta-qcom-qim-product-sdk already linked to local repository."
  elif [[ -d "$TARGET_LAYER" ]]; then
    echo "[+] Backing up repo-synced meta-qcom-qim-product-sdk and linking local development layer..."
    mv "$TARGET_LAYER" "${TARGET_LAYER}.upstream.bak"
    ln -s "$SCRIPT_DIR/meta-qcom-qim-product-sdk" "$TARGET_LAYER"
  else
    echo "[+] Linking local meta-qcom-qim-product-sdk repository to layers/..."
    ln -s "$SCRIPT_DIR/meta-qcom-qim-product-sdk" "$TARGET_LAYER"
  fi
fi

# Ensure setup-environment is linked
if [[ -f "$WORKSPACE/layers/meta-qcom-distro/set_bb_env.sh" && ! -e "$WORKSPACE/setup-environment" ]]; then
  echo "[+] Linking setup-environment -> layers/meta-qcom-distro/set_bb_env.sh..."
  ln -s layers/meta-qcom-distro/set_bb_env.sh "$WORKSPACE/setup-environment"
fi

echo "=========================================================="
echo " Workspace initialized successfully!"
echo " Next steps:"
echo " 1. cd $WORKSPACE"
echo " 2. ../build.sh [target]"
echo "    e.g. ../build.sh qcom-qim-product-sdk"
echo "    or   ../build.sh qcom-multimedia-image"
echo "=========================================================="
