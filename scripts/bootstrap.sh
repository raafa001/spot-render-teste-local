#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT=$(cd "$(dirname "$0")/.." && pwd)
HOST_STORAGE_ROOT=${HOST_STORAGE_ROOT:-/tmp/spot-render-storage}
SONAR_MONITORING_PASSCODE=${SONAR_MONITORING_PASSCODE:-spotrender}
CLUSTER_CONTEXT=$(kubectl config current-context 2>/dev/null || echo "")
if [[ -z "$CLUSTER_CONTEXT" ]]; then
  echo "[!] kubectl current-context not set. Please create a cluster (kind/minikube/docker-desktop) before running bootstrap."
  exit 1
fi

function info() {
  echo "[+] $1"
}

function ensure_local_path() {
  if kubectl get sc local-path >/dev/null 2>&1; then
    return
  fi
  info "Installing local-path-provisioner"
  kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/master/deploy/local-path-storage.yaml >/dev/null
  kubectl -n local-path-storage patch storageclass local-path -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}' >/dev/null
}

function helm_release_exists() {
  local release=$1
  local namespace=$2
  helm status "$release" -n "$namespace" >/dev/null 2>&1
}

function install_if_missing() {
  local release=$1
  local namespace=$2
  local chart=$3
  shift 3
  if helm_release_exists "$release" "$namespace"; then
    info "Helm release '$release' already present in namespace '$namespace'. Reutilizando implantação existente."
    return
  fi
  info "Installing Helm release '$release' ($chart)"
  helm upgrade --install "$release" "$chart" --namespace "$namespace" --create-namespace "$@" >/dev/null
}

if [[ $CLUSTER_CONTEXT == kind* ]]; then
  STORAGE_CLASS=${STORAGE_CLASS:-local-path}
  ensure_local_path
elif [[ $CLUSTER_CONTEXT == docker-desktop* ]]; then
  STORAGE_CLASS=${STORAGE_CLASS:-hostpath}
elif [[ $CLUSTER_CONTEXT == minikube* ]]; then
  STORAGE_CLASS=${STORAGE_CLASS:-standard}
else
  STORAGE_CLASS=${STORAGE_CLASS:-standard}
fi

info "Using storage class '$STORAGE_CLASS'"

info "Creating namespaces"
kubectl apply -f "$REPO_ROOT/k8s/namespaces.yaml"

info "Preparing shared storage under $HOST_STORAGE_ROOT"
mkdir -p "$HOST_STORAGE_ROOT"/shared "$HOST_STORAGE_ROOT"/input "$HOST_STORAGE_ROOT"/output "$HOST_STORAGE_ROOT"/error "$HOST_STORAGE_ROOT"/renderlists
HOST_STORAGE_ROOT="$HOST_STORAGE_ROOT" envsubst < "$REPO_ROOT/k8s/storage-hostpath.yaml.tpl" | kubectl apply -f -

info "Adding helm repos"
helm repo add argo https://argoproj.github.io/argo-helm >/dev/null
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts >/dev/null
helm repo add sonarqube https://SonarSource.github.io/helm-chart-sonarqube >/dev/null
helm repo update >/dev/null

install_if_missing argo-workflows rendering argo/argo-workflows \
  --set server.extraArgs="{--auth-mode=server}" \
  --set server.persistentVolume.enabled=true \
  --set server.persistentVolume.storageClassName=$STORAGE_CLASS \
  --set server.persistentVolume.size=5Gi

install_if_missing argo-events rendering argo/argo-events

install_if_missing kube-prometheus-stack monitoring prometheus-community/kube-prometheus-stack \
  --set prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.storageClassName=$STORAGE_CLASS \
  --set prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.resources.requests.storage=20Gi \
  --set grafana.persistence.enabled=true \
  --set grafana.persistence.storageClassName=$STORAGE_CLASS \
  --set grafana.persistence.size=5Gi

install_if_missing spot-sonarqube monitoring sonarqube/sonarqube \
  --set monitoringPasscode=$SONAR_MONITORING_PASSCODE \
  --set persistence.enabled=true \
  --set persistence.storageClass=$STORAGE_CLASS \
  --set persistence.size=20Gi \
  --set postgresql.persistence.enabled=true \
  --set postgresql.persistence.storageClass=$STORAGE_CLASS \
  --set postgresql.persistence.size=10Gi

info "Bootstrap complete for context '$CLUSTER_CONTEXT'."
