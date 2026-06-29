# Spot Render Teste Local – TechDocs

## Objetivo
Executar toda a stack Spot Render em um cluster local (Kind/Minikube/Docker Desktop) com dados persistidos e recursos equivalentes ao ambiente AWS.

> Pré-requisitos principais: `git`, `kubectl`, `helm`, `docker`, `kustomize` (v5+) e acesso aos repositórios `spot-render-*`.

## Passos automatizados
```
./setup-local.sh
```
- Clona/atualiza todos os repositórios `spot-render-*`.  
- Detecta o cluster atual (Kind/Minikube/Docker Desktop) e cria/valida se necessário.  
- Provisiona o storage hostPath (configurável via `HOST_STORAGE_ROOT`).  
- Instala Argo Workflows/Events e pergunta se você deseja provisionar Prometheus + Grafana e/ou SonarQube com PVCs persistentes.  
- Constrói/carrega imagens locais e aplica os manifestos (API, portal, workflows, observabilidade).

Para clusters Docker Desktop no WSL2, execute com `HOST_STORAGE_ROOT=/run/desktop/mnt/host/c/tmp/spot-render-storage`.

## Variáveis úteis
- `INSTALL_PROM_STACK=true|false` – força (ou pula) a instalação do kube-prometheus-stack sem prompt.  
- `INSTALL_SONAR=true|false` – idem para SonarQube.  
- `SONAR_MONITORING_PASSCODE=<valor>` – define o passcode exigido pelo chart do SonarQube.  
- `HOST_STORAGE_ROOT=<path>` – diretório local compartilhado com o cluster.
- `API_IMAGE`, `PORTAL_IMAGE`, `WORKER_IMAGE` – sobrescrevem as imagens tagueadas com `sha-<git-short>` geradas automaticamente pelo `setup-local.sh`.  
- Os targets `make deploy-api`/`deploy-argo` renderizam os overlays via `kustomize build --load-restrictor LoadRestrictionsNone <path> | kubectl apply -f -`, permitindo o uso de manifestos armazenados nos demais repositórios `spot-render-*`. Durante o bootstrap, o script garante a instalação do Argo Rollouts (variável `ARGO_ROLLOUTS_VERSION`, padrão `v1.6.6`) reutilizando o namespace `argo-rollouts` existente ou criando-o caso não exista.

## Passos manuais
1. `make kind-up`
2. `make bootstrap`
3. `make build-api build-portal build-argo`
4. `make load-images` (Kind/Minikube)
5. `make deploy-api deploy-portal deploy-argo deploy-observabilidade`
6. `make submit-local KEY=... PROJECT=... VARIATION=... ARTIST=...`

## URLs
- **Local:** Portal `https://spot-render.local`, API `https://api.spot-render.local`. Ajuste `NEXT_PUBLIC_API_URL` para o endpoint local antes do build do portal.  
- **AWS:** Portal `https://portal.spot-render.aws.company.com`, API `https://api.spot-render.aws.company.com` (autenticada). A UI deve permanecer leve, intuitiva e com a logo **SPOT-RENDER**.

## Render lists
- Arquivos confidenciais permanecem em `assets/renderlists/`.  
- Faça upload via portal/CLI ou utilize `make submit-local` após copiar os arquivos para `HOST_STORAGE_ROOT/shared`.

## Observabilidade
- Grafana: `kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80`.  
- SonarQube local: `kubectl port-forward -n monitoring svc/spot-sonarqube-sonarqube 9000:9000`.  
- Prometheus mantém dados em PVC provisionado automaticamente.

## Limpeza rápida
- `./scripts/cleanup.sh` remove releases Helm, deleta os manifestos aplicados (`k8s/overlays/*`, storage, namespaces) e limpa `HOST_STORAGE_ROOT` (padrão `/tmp/spot-render-storage`).
- `./teardown-local.sh` é um atalho na raiz que chama o script acima.

## Spot Render Sync (AWS)
- O portal disponibilizará o executável **Spot Render Sync** em `https://portal.spot-render.aws.company.com/downloads/spot-render-sync-<os>` (Windows/macOS/Linux).  
- O agente monitora as pastas configuradas pelos artistas e publica automaticamente no bucket da AWS, mantendo a interface leve com a logo SPOT-RENDER. Disponível apenas no ambiente AWS; localmente utilize portal/API/CLI.

## TechDocs
- Publicar com `mkdocs.yml` deste repositório.
