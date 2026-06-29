#!/usr/bin/env bash
set -euo pipefail

KUSTOMIZE_VERSION=${KUSTOMIZE_VERSION:-v5.4.1}
INSTALL_DIR=${INSTALL_DIR:-$HOME/.local/bin}

function info(){ echo "[kustomize] $1"; }
function err(){ echo "[kustomize] $1" >&2; }

if command -v kustomize >/dev/null 2>&1; then
  info "kustomize já instalado em $(command -v kustomize)"
  exit 0
fi

OS=$(uname -s | tr '[:upper:]' '[:lower:]')
ARCH=$(uname -m)
case "$ARCH" in
  x86_64|amd64) ARCH=amd64 ;;
  arm64|aarch64) ARCH=arm64 ;;
  *) err "Arquitetura $ARCH não suportada automaticamente."; exit 1 ;;
esac

TARBALL="kustomize_${KUSTOMIZE_VERSION}_${OS}_${ARCH}.tar.gz"
URL="https://github.com/kubernetes-sigs/kustomize/releases/download/kustomize/${KUSTOMIZE_VERSION}/${TARBALL}"

TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

info "Baixando $URL"
curl -fsSL "$URL" -o "$TMPDIR/kustomize.tgz"

info "Extraindo para $INSTALL_DIR"
mkdir -p "$INSTALL_DIR"
tar -xzf "$TMPDIR/kustomize.tgz" -C "$TMPDIR"
chmod +x "$TMPDIR/kustomize"
mv "$TMPDIR/kustomize" "$INSTALL_DIR/kustomize"

case ":$PATH:" in
  *":$INSTALL_DIR:"*) ;;
  *) info "Adicione '$INSTALL_DIR' ao PATH se ainda não estiver." ;;
esac

info "kustomize ${KUSTOMIZE_VERSION} instalado em $INSTALL_DIR/kustomize"
