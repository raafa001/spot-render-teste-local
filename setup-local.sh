#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT=$(cd "$(dirname "$0")" && pwd)
BASE_DIR=${BASE_DIR:-$(dirname "$REPO_ROOT")}
REPOSITORIES=(spot-render-infra-aws spot-render-api spot-render-portal spot-render-cli spot-render-argo spot-render-observability spot-render-config)
GIT_REMOTE=${GIT_REMOTE:-https://github.com/raafa001}
CLUSTER_MODE=${CLUSTER_MODE:-auto}
HOST_STORAGE_ROOT=${HOST_STORAGE_ROOT:-/tmp/spot-render-storage}
API_SHA=$(cd "$BASE_DIR/spot-render-api" && git rev-parse --short HEAD)
PORTAL_SHA=$(cd "$BASE_DIR/spot-render-portal" && git rev-parse --short HEAD)
WORKER_SHA=$(cd "$BASE_DIR/spot-render-argo" && git rev-parse --short HEAD)
API_IMAGE=${API_IMAGE:-spot-render-backend:$API_SHA}
PORTAL_IMAGE=${PORTAL_IMAGE:-spot-render-web:$PORTAL_SHA}
WORKER_IMAGE=${WORKER_IMAGE:-spot-render-worker:$WORKER_SHA}
PORTAL_API_URL=${PORTAL_API_URL:-http://api.spot-render.local}
PORTAL_ENV_FILE="$BASE_DIR/spot-render-portal/.env.local"

function info(){ echo "[+] $1"; }
function warn(){ echo "[!] $1"; }
function require_cmd(){ command -v "$1" >/dev/null || { echo "Command '$1' not found"; exit 1; }; }

patch_rollout_image() {
  local rollout=$1
  local namespace=$2
  local image=$3
  if ! kubectl get rollout "$rollout" -n "$namespace" >/dev/null 2>&1; then
    warn "Rollout $rollout não encontrado; pulei atualização"
    return
  fi
  local patch_file
  patch_file=$(mktemp)
  cat <<EOF >"$patch_file"
[
  {"op":"replace","path":"/spec/template/spec/containers/0/image","value":"$image"}
]
EOF
  if ! kubectl -n "$namespace" patch rollout "$rollout" --type='json' --patch-file "$patch_file" >/dev/null; then
    warn "Falha ao atualizar rollout $rollout"
  fi
  rm -f "$patch_file"
}

require_cmd git
require_cmd kubectl
require_cmd helm
require_cmd docker
if ! command -v kustomize >/dev/null 2>&1; then
  info "kustomize não encontrado, executando instalador local"
  "$REPO_ROOT/scripts/install-kustomize.sh"
  export PATH="$HOME/.local/bin:$PATH"
fi

if [[ $CLUSTER_MODE == auto ]]; then
  context=$(kubectl config current-context 2>/dev/null || echo "")
  if [[ -z $context ]]; then
    CLUSTER_MODE=kind
  elif [[ $context == kind* ]]; then
    CLUSTER_MODE=kind
  elif [[ $context == docker-desktop* ]]; then
    CLUSTER_MODE=docker
  elif [[ $context == minikube* ]]; then
    CLUSTER_MODE=minikube
  else
    CLUSTER_MODE=existing
  fi
fi

info "Cluster mode: $CLUSTER_MODE"
info "Portal build usará NEXT_PUBLIC_API_URL=$PORTAL_API_URL"

for repo in "${REPOSITORIES[@]}"; do
  path="$BASE_DIR/$repo"
  if [[ -d "$path/.git" ]]; then
    info "Updating $repo"
    (cd "$path" && git pull --ff-only)
  else
    info "Cloning $repo"
    git clone "$GIT_REMOTE/$repo.git" "$path"
  fi
done

case "$CLUSTER_MODE" in
  kind)
    require_cmd kind
    if ! kind get clusters | grep -q "spot-render-local"; then
      (cd "$REPO_ROOT" && make kind-up)
    fi
    ;;
  minikube)
    require_cmd minikube
    if ! minikube status >/dev/null 2>&1; then
      minikube start
    fi
    ;;
  docker)
    context=$(kubectl config current-context)
    if [[ $context != docker-desktop* ]]; then
      warn "Kubectl context is '$context'. Switch to docker-desktop manually."
    fi
    ;;
  existing)
    warn "Using existing cluster context $(kubectl config current-context)" ;;
esac

info "Running bootstrap"
HOST_STORAGE_ROOT="$HOST_STORAGE_ROOT" "$REPO_ROOT/scripts/bootstrap.sh"

info "Garantindo diretórios em $HOST_STORAGE_ROOT"
mkdir -p "$HOST_STORAGE_ROOT"/shared "$HOST_STORAGE_ROOT"/input "$HOST_STORAGE_ROOT"/output "$HOST_STORAGE_ROOT"/error "$HOST_STORAGE_ROOT"/renderlists

info "Reconciliando PV/PVC spot-render-storage"
kubectl delete pvc spot-render-storage -n spot-render --ignore-not-found >/dev/null 2>&1 || true
kubectl delete pvc spot-render-storage -n rendering --ignore-not-found >/dev/null 2>&1 || true
kubectl delete pv spot-render-storage --ignore-not-found >/dev/null 2>&1 || true

info "Aplicando manifests de storage"
kubectl apply -f "$REPO_ROOT/k8s/storage.yaml"
HOST_STORAGE_ROOT="$HOST_STORAGE_ROOT" envsubst < "$REPO_ROOT/k8s/storage-hostpath.yaml.tpl" | kubectl apply -f -

if [[ -n "$PORTAL_ENV_FILE" ]]; then
  info "Configurando $PORTAL_ENV_FILE com NEXT_PUBLIC_API_URL=$PORTAL_API_URL"
  cat <<EOF > "$PORTAL_ENV_FILE"
NEXT_PUBLIC_API_URL=$PORTAL_API_URL
EOF
fi

info "Building container images"
(cd "$BASE_DIR/spot-render-api" && docker build -t "$API_IMAGE" .)
(cd "$BASE_DIR/spot-render-portal" && docker build --build-arg NEXT_PUBLIC_API_URL="$PORTAL_API_URL" -t "$PORTAL_IMAGE" .)
(cd "$BASE_DIR/spot-render-argo" && docker build -t "$WORKER_IMAGE" -f Dockerfile.worker .)

if [[ $CLUSTER_MODE == kind ]]; then
  kind load docker-image --name spot-render-local "$API_IMAGE"
  kind load docker-image --name spot-render-local "$PORTAL_IMAGE"
  kind load docker-image --name spot-render-local "$WORKER_IMAGE"
elif [[ $CLUSTER_MODE == minikube ]]; then
  require_cmd minikube
  minikube image load "$API_IMAGE"
  minikube image load "$PORTAL_IMAGE"
  minikube image load "$WORKER_IMAGE"
else
  info "Skipping image load (cluster uses host Docker daemon)"
fi

info "Deploying API/portal/Argo/observability"
(cd "$REPO_ROOT" && make deploy-api deploy-portal deploy-argo deploy-observability)

if kubectl get crd rollouts.argoproj.io >/dev/null 2>&1; then
  patch_rollout_image spot-render-backend spot-render "$API_IMAGE"
  patch_rollout_image spot-render-web spot-render "$PORTAL_IMAGE"
else
  warn "CRD rollouts.argoproj.io não disponível; pulando atualização dos rollouts"
fi

if kubectl get workflowtemplate render-workflow-local -n rendering >/dev/null 2>&1; then
  info "Updating render-workflow-local worker image to $WORKER_IMAGE"
  patch_file=$(mktemp)
  cat <<EOF > "$patch_file"
[
  {"op":"replace","path":"/spec/templates/1/container/image","value":"$WORKER_IMAGE"},
  {"op":"replace","path":"/spec/templates/2/container/image","value":"$WORKER_IMAGE"}
]
EOF
  kubectl -n rendering patch workflowtemplate render-workflow-local --type='json' --patch-file "$patch_file" >/dev/null || warn "Falha ao atualizar render-workflow-local"
  rm -f "$patch_file"
fi

cat <<MSG
[√] Ambiente local pronto.
- API: http://spot-render.local (via ingress)
- Portal: http://spot-render.local
- SonarQube local: kubectl port-forward -n monitoring svc/spot-sonarqube-sonarqube 9000:9000
- Grafana: kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80

Para processar arquivos:
1. Faça upload via portal ou CLI com STORAGE_MODE=local
2. Liste os arquivos em $HOST_STORAGE_ROOT/shared e rode:
   make submit-local KEY="input/<proj>/<var>/<timestamp>/<arquivo>" PROJECT=<proj> VARIATION=<var> ARTIST=<nome>

Quando terminar, execute ./teardown-local.sh (ou ./scripts/cleanup.sh) para remover os recursos e limpar o storage local.
MSG
