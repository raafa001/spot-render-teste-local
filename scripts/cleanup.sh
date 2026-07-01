#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT=$(cd "$(dirname "$0")/.." && pwd)
HOST_STORAGE_ROOT=${HOST_STORAGE_ROOT:-/tmp/spot-render-storage}

function info() {
  echo "[+] $1"
}

function warn() {
  echo "[!] $1"
}

function uninstall_release() {
  local release=$1
  local namespace=$2
  if helm status "$release" -n "$namespace" >/dev/null 2>&1; then
    info "Removing Helm release '$release' (namespace: $namespace)"
    helm uninstall "$release" -n "$namespace" >/dev/null 2>&1 || warn "Failed to uninstall $release"
  else
    info "Helm release '$release' (ns: $namespace) não encontrado. OK."
  fi
}

info "Removing Spot Render Helm releases"
uninstall_release argo-workflows rendering
uninstall_release argo-events rendering
uninstall_release kube-prometheus-stack monitoring
uninstall_release spot-sonarqube monitoring

if kubectl get ns ingress-nginx >/dev/null 2>&1; then
  info "Removing ingress-nginx controller"
  kubectl delete ns ingress-nginx --ignore-not-found >/dev/null 2>&1 || true
fi

info "Removing local Spot Render manifests"
kubectl delete -k "$REPO_ROOT/k8s/overlays/api-local" --ignore-not-found >/dev/null 2>&1 || true
kubectl delete -k "$REPO_ROOT/k8s/overlays/argo-local" --ignore-not-found >/dev/null 2>&1 || true
kubectl delete -f "$REPO_ROOT/k8s/namespaces.yaml" --ignore-not-found >/dev/null 2>&1 || true
kubectl delete -f "$REPO_ROOT/k8s/storage.yaml" --ignore-not-found >/dev/null 2>&1 || true
if command -v envsubst >/dev/null 2>&1; then
  HOST_STORAGE_ROOT="$HOST_STORAGE_ROOT" envsubst < "$REPO_ROOT/k8s/storage-hostpath.yaml.tpl" | kubectl delete -f - --ignore-not-found >/dev/null 2>&1 || true
else
  warn "envsubst não encontrado; pulei remoção dos recursos storage-hostpath"
fi

info "Deleting namespaces (spot-render, rendering, monitoring)"
for ns in spot-render rendering monitoring; do
  kubectl delete namespace "$ns" --ignore-not-found >/dev/null 2>&1 || true
done

# ─── Derrubar serviços Docker de infraestrutura local ───────────────────────
info "Derrubando serviços de infraestrutura local (PostgreSQL, Redis, LocalStack)..."
REPO_ROOT=$(cd "$(dirname "$0")/.." && pwd)
if docker compose -f "$REPO_ROOT/docker-compose.local.yml" down --volumes --remove-orphans >/dev/null 2>&1; then
  info "Serviços Docker parados e volumes removidos"
else
  warn "Falha ao derrubar serviços Docker (ou docker compose não disponível)"
fi

# Limpar diretório de dados local
if [[ -d "$REPO_ROOT/data" ]]; then
  info "Limpando dados locais em $REPO_ROOT/data"
  rm -rf "$REPO_ROOT/data"
fi

if [[ -d "$HOST_STORAGE_ROOT" ]]; then
  info "Cleaning host storage at $HOST_STORAGE_ROOT"
  rm -rf "$HOST_STORAGE_ROOT"
fi

info "Cleanup complete."
