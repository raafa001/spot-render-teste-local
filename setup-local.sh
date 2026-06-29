#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT=$(cd "$(dirname "$0")" && pwd)
BASE_DIR=${BASE_DIR:-$(dirname "$REPO_ROOT")}
REPOSITORIES=(spot-render-infra-aws spot-render-api spot-render-portal spot-render-cli spot-render-argo spot-render-observability spot-render-config)
GIT_REMOTE=${GIT_REMOTE:-https://github.com/raafa001}
CLUSTER_MODE=${CLUSTER_MODE:-auto}
HOST_STORAGE_ROOT=${HOST_STORAGE_ROOT:-/tmp/spot-render-storage}

function info(){ echo "[+] $1"; }
function warn(){ echo "[!] $1"; }
function require_cmd(){ command -v "$1" >/dev/null || { echo "Command '$1' not found"; exit 1; }; }

require_cmd git
require_cmd kubectl
require_cmd helm
require_cmd docker

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

info "Building container images"
(cd "$BASE_DIR/spot-render-api" && docker build -t spot-render-api:dev .)
(cd "$BASE_DIR/spot-render-portal" && docker build -t spot-render-portal:dev .)
(cd "$BASE_DIR/spot-render-argo" && docker build -t spot-render-worker:dev -f Dockerfile.worker .)

if [[ $CLUSTER_MODE == kind ]]; then
  kind load docker-image --name spot-render-local spot-render-api:dev
  kind load docker-image --name spot-render-local spot-render-portal:dev
  kind load docker-image --name spot-render-local spot-render-worker:dev
elif [[ $CLUSTER_MODE == minikube ]]; then
  require_cmd minikube
  minikube image load spot-render-api:dev
  minikube image load spot-render-portal:dev
  minikube image load spot-render-worker:dev
else
  info "Skipping image load (cluster uses host Docker daemon)"
fi

info "Deploying API/portal/Argo/observability"
(cd "$REPO_ROOT" && make deploy-api deploy-portal deploy-argo deploy-observability)

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
MSG
