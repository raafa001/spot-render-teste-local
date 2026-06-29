#!/usr/bin/env bash
set -euo pipefail

CLUSTER_NAME="spot-render-local"
STORAGE_PATH="/tmp/spot-render-storage"

function info() {
  echo "[+] $1"
}

info "Creating namespaces"
kubectl apply -f k8s/namespaces.yaml

info "Preparing shared storage at $STORAGE_PATH"
mkdir -p "$STORAGE_PATH/input" "$STORAGE_PATH/output" "$STORAGE_PATH/error" "$STORAGE_PATH/renderlists"
kubectl apply -f k8s/storage.yaml

info "Installing Argo Workflows"
helm repo add argo https://argoproj.github.io/argo-helm >/dev/null
helm upgrade --install argo-workflows argo/argo-workflows \
  --namespace rendering --create-namespace \
  --set server.extraArgs="{--auth-mode=server}" >/dev/null

info "Installing Argo Events"
helm upgrade --install argo-events argo/argo-events \
  --namespace rendering >/dev/null

info "Installing Prometheus + Grafana"
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts >/dev/null
helm upgrade --install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  --namespace monitoring --create-namespace >/dev/null

info "Done. Use 'kubectl get pods -A' to verify"
