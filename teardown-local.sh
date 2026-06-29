#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT=$(cd "$(dirname "$0")" && pwd)
HOST_STORAGE_ROOT=${HOST_STORAGE_ROOT:-/tmp/spot-render-storage}

if [[ ! -x "$REPO_ROOT/scripts/cleanup.sh" ]]; then
  echo "Cleanup script not found in scripts/cleanup.sh"
  exit 1
fi

HOST_STORAGE_ROOT="$HOST_STORAGE_ROOT" "$REPO_ROOT/scripts/cleanup.sh"
