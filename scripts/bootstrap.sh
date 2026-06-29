#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT=$(cd "$(dirname "$0")/.." && pwd)
HOST_STORAGE_ROOT=${HOST_STORAGE_ROOT:-/tmp/spot-render-storage}
SONAR_MONITORING_PASSCODE=${SONAR_MONITORING_PASSCODE:-spotrender}
INSTALL_PROM_STACK=${INSTALL_PROM_STACK:-}
INSTALL_SONAR=${INSTALL_SONAR:-}
ARGO_ROLLOUTS_VERSION=${ARGO_ROLLOUTS_VERSION:-v1.6.6}
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

function detect_argo_namespace() {
  local existing
  existing=$(kubectl get ns -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' | grep '^argo' || true)
  if [[ -n "$existing" ]]; then
    echo "$existing" | head -n1
  else
    echo "argo-rollouts"
  fi
}

function ensure_kustomize() {
  if command -v kustomize >/dev/null 2>&1; then
    return
  fi
  info "kustomize não encontrado; instalando versão ${KUSTOMIZE_VERSION:-v5.4.1}"
  "$REPO_ROOT/scripts/install-kustomize.sh"
  export PATH="$HOME/.local/bin:$PATH"
}

function ensure_argo_rollouts() {
  if kubectl get crd rollouts.argoproj.io >/dev/null 2>&1; then
    info "Argo Rollouts CRDs já presentes"
    return
  fi
  local answer=${INSTALL_ARGO_ROLLOUTS:-}
  if [[ -z "$answer" ]]; then
    read -r -p "Argo Rollouts não encontrado. Deseja instalar localmente? [Y/n]: " answer || true
  fi
  answer=${answer,,}
  if [[ "$answer" == "n" || "$answer" == "no" ]]; then
    warn "Argo Rollouts não será instalado. Rollouts customizados podem falhar." 
    return
  fi
  local ns
  ns=$(detect_argo_namespace)
  if kubectl get namespace "$ns" >/dev/null 2>&1; then
    info "Reutilizando namespace '$ns' para Argo Rollouts"
  else
    info "Criando namespace '$ns' para Argo Rollouts"
    kubectl create namespace "$ns" >/dev/null
  fi
  info "Instalando Argo Rollouts ${ARGO_ROLLOUTS_VERSION} em '$ns'"
  kubectl apply -n "$ns" -f "https://github.com/argoproj/argo-rollouts/releases/download/${ARGO_ROLLOUTS_VERSION}/install.yaml" >/dev/null
}

function helm_release_exists() {
  local release=$1
  local namespace=$2
  helm status "$release" -n "$namespace" >/dev/null 2>&1
}

function parse_bool() {
  local value="${1:-}"
  value=${value,,}
  if [[ "$value" == "y" || "$value" == "yes" || "$value" == "true" || "$value" == "1" ]]; then
    return 0
  fi
  return 1
}

function ask_install_component() {
  local __var=$1
  local prompt=$2
  local current=${!__var:-}
  if [[ -n "$current" ]]; then
    if parse_bool "$current"; then
      printf -v "$__var" "true"
    else
      printf -v "$__var" "false"
    fi
    return
  fi
  local answer
  read -r -p "$prompt [y/N]: " answer || true
  if parse_bool "$answer"; then
    printf -v "$__var" "true"
  else
    printf -v "$__var" "false"
  fi
}

function is_yes_default_yes() {
  local answer="${1:-}"
  if [[ -z "$answer" ]]; then
    return 0
  fi
  parse_bool "$answer"
}

function is_yes_default_no() {
  local answer="${1:-}"
  if [[ -z "$answer" ]]; then
    return 1
  fi
  parse_bool "$answer"
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

function maybe_install_release() {
  local release=$1
  local namespace=$2
  local friendly=$3
  local chart=$4
  shift 4
  if helm_release_exists "$release" "$namespace"; then
    info "Release '$release' já existe no namespace '$namespace'."
    local reuse_answer
    read -r -p "Deseja reutilizar esta instância de $friendly? [Y/n]: " reuse_answer || true
    if is_yes_default_yes "$reuse_answer"; then
      info "Reutilizando instância existente de $friendly."
      return
    fi
    local new_answer
    read -r -p "Deseja instalar uma nova instância separada de $friendly? [y/N]: " new_answer || true
    if ! is_yes_default_no "$new_answer"; then
      info "Mantendo apenas a instância existente de $friendly."
      return
    fi
    local new_release
    read -r -p "Informe o nome do novo release (padrão: ${release}-extra): " new_release || true
    new_release=${new_release:-${release}-extra}
    install_if_missing "$new_release" "$namespace" "$chart" "$@"
    return
  fi
  install_if_missing "$release" "$namespace" "$chart" "$@"
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

ensure_kustomize
ensure_argo_rollouts

install_if_missing argo-workflows rendering argo/argo-workflows \
  --set server.extraArgs="{--auth-mode=server}" \
  --set server.persistentVolume.enabled=true \
  --set server.persistentVolume.storageClassName=$STORAGE_CLASS \
  --set server.persistentVolume.size=5Gi

install_if_missing argo-events rendering argo/argo-events

ask_install_component INSTALL_PROM_STACK "Deseja instalar Prometheus + Grafana (kube-prometheus-stack)?"
if [[ "$INSTALL_PROM_STACK" == "true" ]]; then
  maybe_install_release kube-prometheus-stack monitoring "Prometheus + Grafana" prometheus-community/kube-prometheus-stack \
    --set prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.storageClassName=$STORAGE_CLASS \
    --set prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.resources.requests.storage=20Gi \
    --set grafana.persistence.enabled=true \
    --set grafana.persistence.storageClassName=$STORAGE_CLASS \
    --set grafana.persistence.size=5Gi
else
  info "Prometheus + Grafana marcados como opcionais. Pulando instalação."
fi

ask_install_component INSTALL_SONAR "Deseja instalar SonarQube local?"
if [[ "$INSTALL_SONAR" == "true" ]]; then
  maybe_install_release spot-sonarqube monitoring "SonarQube" sonarqube/sonarqube \
    --set community.enabled=true \
    --set monitoringPasscode=$SONAR_MONITORING_PASSCODE \
    --set persistence.enabled=true \
    --set persistence.storageClass=$STORAGE_CLASS \
    --set persistence.size=20Gi \
    --set postgresql.persistence.enabled=true \
    --set postgresql.persistence.storageClass=$STORAGE_CLASS \
    --set postgresql.persistence.size=10Gi
else
  info "SonarQube marcado como opcional. Pulando instalação."
fi

info "Bootstrap complete for context '$CLUSTER_CONTEXT'."
