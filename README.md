# spot-render-teste-local

> Harness para executar toda a plataforma Spot Render (API, portal, Argo Workflows, observabilidade e SonarQube local) em um cluster Kubernetes local (Kind, Minikube ou Docker Desktop) com persistência de dados.

## Requisitos
- Git, Docker, kubectl, helm
- Kind (para modo padrão) ou Minikube / Docker Desktop
- Acesso aos repositórios `spot-render-*`
- Kustomize CLI (>= v5) – usado para renderizar os overlays locais (caso não esteja instalado, `setup-local.sh` e `scripts/bootstrap.sh` executam automaticamente `scripts/install-kustomize.sh` e instalam em `~/.local/bin`).

## Uso rápido (script automatizado)
```bash
cd spot-render-teste-local
./setup-local.sh
```
O script:
1. Garante que todos os repositórios `spot-render-*` estejam clonados e atualizados (padrão `..`); utilize `BASE_DIR=/c/repos ./setup-local.sh` para personalizar.  
2. Detecta o cluster em uso (Kind, Minikube, Docker Desktop) e cria/inicializa se necessário.  
3. Provisiona namespaces, storage compartilhado e instala Argo Workflows/Events, Prometheus + Grafana e SonarQube **com volumes persistentes**.  
4. Constrói as imagens (`spot-render-api`, `spot-render-portal`, `spot-render-worker`) e as disponibiliza ao cluster.  
5. Aplica os manifests (API canário, portal, workflows locais e observabilidade).  
6. Exibe instruções finais (port-forward, envio de jobs etc.).

### Componentes opcionais
- Durante `setup-local.sh`, o script pergunta se você deseja instalar **Prometheus + Grafana** (kube-prometheus-stack) e/ou **SonarQube**.  
- Se já existir uma instalação no cluster, o script informa e pergunta se deseja reaproveitar ou criar uma nova instância.  
- Para rodar sem interação, defina as variáveis: `INSTALL_PROM_STACK=true|false`, `INSTALL_SONAR=true|false`, `SONAR_MONITORING_PASSCODE=<passcode>`.

### Variáveis úteis
- `HOST_STORAGE_ROOT`: caminho local compartilhado com o cluster (padrão `/tmp/spot-render-storage`).  
- `INSTALL_PROM_STACK` / `INSTALL_SONAR`: definem se Prometheus/Grafana e SonarQube devem (ou não) ser instalados sem prompt.  
- `SONAR_MONITORING_PASSCODE`: passcode necessário para o chart do SonarQube quando instalado.  
- `BASE_DIR`: diretório onde os repositórios `spot-render-*` serão clonados/atualizados.  
- `API_IMAGE`, `PORTAL_IMAGE`, `WORKER_IMAGE`: substituem as imagens geradas automaticamente pelo `setup-local.sh` (por padrão cada imagem recebe a tag `sha-<git-short>`).  
- Os targets `make deploy-api` e `make deploy-argo` renderizam os overlays com `kustomize build --load-restrictor LoadRestrictionsNone ... | kubectl apply -f -`, portanto o binário `kustomize` precisa estar instalado (override com `KUSTOMIZE=/caminho/para/kustomize`).  
- `ARGO_ROLLOUTS_VERSION`: versão utilizada para instalar automaticamente os CRDs/Controller do Argo Rollouts (padrão `v1.6.6`). O bootstrap detecta namespaces `argo-*` existentes (ex.: `argo-rollouts`, `argo-cd`) e reutiliza-os quando já presentes.
- `KUSTOMIZE_LOAD_RESTRICTOR=LoadRestrictionsNone`: já aplicado automaticamente nos `make deploy-api`/`deploy-argo`, permitindo que os overlays façam referência aos manifests hospedados nos outros repositórios `spot-render-*`.

> **WSL/Docker Desktop:** defina `HOST_STORAGE_ROOT` apontando para um diretório disponível no Windows, por exemplo `HOST_STORAGE_ROOT=/run/desktop/mnt/host/c/tmp/spot-render-storage ./setup-local.sh`. Esse caminho será montado nos pods e preservará os dados (render lists, frames, Sonar, Grafana, Prometheus).

## Passos manuais (opcional)
Caso deseje executar manualmente:
```bash
make kind-up
make bootstrap
make build-api build-portal build-argo
make load-images   # apenas para Kind/Minikube
make deploy-api deploy-portal deploy-argo deploy-observability
```

Para disparar um workflow local:
```bash
make submit-local KEY="input/<projeto>/<variacao>/<timestamp>/<arquivo>" \
  PROJECT=<projeto> VARIATION=<variacao> ARTIST=<artista>
```
(obtenha o `KEY` inspecionando `HOST_STORAGE_ROOT/shared`).

### URLs e acesso (Local)
> **PT-BR:** Portal em `https://spot-render.local` (Ingress) utilizando `NEXT_PUBLIC_API_URL=https://api.spot-render.local`. Use o formulário para enviar arquivos/render lists e acompanhar o progresso. A API fica em `https://api.spot-render.local` e aceita `POST /uploads`, `GET /jobs`, `PATCH /jobs/{id}/progress`. Exemplo: `curl -k -X POST https://api.spot-render.local/uploads/ -F file=@scene.blend -F project=demo -F variation=v1 -F artist=alice`.  
> **EN:** Portal lives at `https://spot-render.local` (Ingress) with `NEXT_PUBLIC_API_URL=https://api.spot-render.local`. Use the upload form to send files/render lists; call the API (`POST /uploads`, `GET /jobs`, `PATCH /jobs/{id}/progress`) for automation.

### URLs e acesso (AWS/Produção)
> **PT-BR:** Portal oficial: `https://portal.spot-render.aws.company.com` (UI leve com logo **SPOT-RENDER**). API: `https://api.spot-render.aws.company.com`. Ao publicar o portal, defina `NEXT_PUBLIC_API_URL=https://api.spot-render.aws.company.com`. Para automação, utilize tokens/SAML e chame `curl -H 'Authorization: Bearer <token>' https://api.spot-render.aws.company.com/jobs`.  
> **EN:** Production portal: `https://portal.spot-render.aws.company.com` (same lightweight UX, SPOT-RENDER branding). API endpoint: `https://api.spot-render.aws.company.com`. Configure `NEXT_PUBLIC_API_URL` before building and call the API with the appropriate auth token.

## Render lists
- Coloque as listas privadas em `assets/renderlists/` (não versionadas).  
- Faça upload via portal/CLI selecionando o campo **Render list** ou marcando “Nova render list padrão” (credenciais default `admin/admin`).

## SonarQube, Argo, Grafana, Prometheus
- O script instala os charts com `persistence.enabled=true` usando o caminho configurado em `HOST_STORAGE_ROOT`.  
- Mesmo que os pods sejam recriados, os dados continuam no diretório host (Sonar issues, dashboards Grafana, séries Prometheus, histórico de Argo Server).  
- Para AWS, utilize os arquivos em `spot-render-config/helm-values/` (gp3/EFS) para manter o mesmo comportamento.

## Observabilidade
- `kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80`  → Grafana (importar dashboard `spot-render-observability/grafana/dashboards/rendering.json`).  
- `kubectl port-forward -n monitoring svc/spot-sonarqube-sonarqube 9000:9000` → SonarQube local.

## Limpeza rápida
- `./scripts/cleanup.sh` ou `./teardown-local.sh` (atalho na raiz) removem os releases Helm (Argo, Prometheus, Sonar), excluem os manifests aplicados (`k8s/overlays/*`, storage, namespaces) e apagam o diretório host configurado em `HOST_STORAGE_ROOT` (por padrão `/tmp/spot-render-storage`). Ideal para garantir que não fiquem resíduos de testes.
- O script de limpeza valida a existência dos recursos antes de tentar removê-los, evitando erros quando nada foi instalado.

## Spot Render Sync (AWS)
- O portal disponibilizará downloads do **Spot Render Sync** (Windows `.msi`, macOS `.dmg`, Linux `.AppImage`) em `https://portal.spot-render.aws.company.com/downloads/spot-render-sync-<os>`.  
- O agente monitora as pastas configuradas pelos artistas (por projeto) e envia automaticamente os arquivos para os buckets definidos no `PROJECT_ROUTE_CONFIG`, sem precisar abrir o portal.  
- Interface leve/tray, com a logo **SPOT-RENDER**, pensada para ambientes AWS; em ambientes locais continue utilizando portal/API/CLI.

## Estrutura
```
assets/renderlists/.gitkeep
k8s/namespaces.yaml
k8s/storage-hostpath.yaml.tpl
k8s/overlays/api-local/
k8s/overlays/argo-local/
kind-config.yaml
Makefile
scripts/bootstrap.sh
setup-local.sh
teardown-local.sh
```

## TechDocs
Documentação detalhada em `docs/index.md` + `mkdocs.yml`, consumida pelo Backstage.
