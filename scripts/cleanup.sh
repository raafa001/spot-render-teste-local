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
  # Usar sudo se necessário (arquivos criados pelo Docker podem ter permissões de root)
  rm -rf "$REPO_ROOT/data" 2>/dev/null || \
    sudo rm -rf "$REPO_ROOT/data" 2>/dev/null || \
    warn "  Não foi possível limpar alguns dados (permissão negada)"
fi

if [[ -d "$HOST_STORAGE_ROOT" ]]; then
  info "Cleaning host storage at $HOST_STORAGE_ROOT"
  rm -rf "$HOST_STORAGE_ROOT" 2>/dev/null || \
    sudo rm -rf "$HOST_STORAGE_ROOT" 2>/dev/null || \
    warn "  Não foi possível limpar storage (permissão negada)"
fi

# ─── Limpar AIOps Agents ──────────────────────────────────────────────────────
cleanup_aiops() {
    info "Limpando AIOps Agents..."

    # Limpar relatórios de segurança antigos (manter últimos 30 dias)
    if [[ -d "$REPO_ROOT/security-reports" ]]; then
        local OLD_REPORTS=$(find "$REPO_ROOT/security-reports" -name "*.json" -mtime +30 2>/dev/null || true)
        if [[ -n "$OLD_REPORTS" ]]; then
            echo "$OLD_REPORTS" | xargs rm -f 2>/dev/null || true
            info "  ✓ Relatórios de segurança antigos removidos"
        fi
    fi

    # Limpar artefatos antigos
    if [[ -d "$REPO_ROOT/artifacts" ]]; then
        local OLD_ARTIFACTS=$(find "$REPO_ROOT/artifacts" -name "*.json" -mtime +7 2>/dev/null || true)
        if [[ -n "$OLD_ARTIFACTS" ]]; then
            echo "$OLD_ARTIFACTS" | xargs rm -f 2>/dev/null || true
            info "  ✓ Artefatos antigos removidos"
        fi
    fi

    info "  ✓ AIOps Agents limpo"
}

cleanup_aiops

echo ""
info "=========================================="
info "  Cleanup Concluído"
info "=========================================="
echo ""
info "Se tiver erros de permissão nos diretórios data/:"
info "  sudo rm -rf $REPO_ROOT/data"
info ""
info "Para iniciar novamente:"
info "  bash setup-local.sh"
info "==========================================="
