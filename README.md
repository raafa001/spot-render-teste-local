# spot-render-teste-local

> Harness para executar toda a plataforma Spot Render (API, portal, Argo Workflows, observabilidade e SonarQube local) em um cluster Kubernetes local (Kind, Minikube ou Docker Desktop) com persistência de dados.

## Requisitos
- Git, Docker, kubectl, helm
- Kind (para modo padrão) ou Minikube / Docker Desktop
- Acesso aos repositórios `spot-render-*`

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
```

## TechDocs
Documentação detalhada em `docs/index.md` + `mkdocs.yml`, consumida pelo Backstage.
