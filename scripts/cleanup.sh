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

info "Removing Spot Render Helm releases"
for release in kube-prometheus-stack argo-workflows argo-events spot-sonarqube; do
  if helm status "$release" -n monitoring >/dev/null 2>&1; then
    helm uninstall "$release" -n monitoring >/dev/null 2>&1 || warn "Failed to uninstall $release"
  fi
done
if helm status argo-workflows -n rendering >/dev/null 2>&1; then
  helm uninstall argo-workflows -n rendering >/dev/null 2>&1 || true
fi
if helm status argo-events -n rendering >/dev/null 2>&1; then
  helm uninstall argo-events -n rendering >/dev/null 2>&1 || true
fi

info "Removing local Spot Render manifests"
kubectl delete -k "$REPO_ROOT/k8s/overlays/api-local" --ignore-not-found >/dev/null 2>&1 || true
kubectl delete -k "$REPO_ROOT/k8s/overlays/argo-local" --ignore-not-found >/dev/null 2>&1 || true
kubectl delete -f "$REPO_ROOT/k8s/namespaces.yaml" --ignore-not-found >/dev/null 2>&1 || true
kubectl delete -f "$REPO_ROOT/k8s/storage.yaml" --ignore-not-found >/dev/null 2>&1 || true

info "Deleting namespaces (spot-render, rendering, monitoring)"
for ns in spot-render rendering monitoring; do
  kubectl delete namespace "$ns" --ignore-not-found >/dev/null 2>&1 || true
done

if [[ -d "$HOST_STORAGE_ROOT" ]]; then
  info "Cleaning host storage at $HOST_STORAGE_ROOT"
  rm -rf "$HOST_STORAGE_ROOT"
fi

info "Cleanup complete."
