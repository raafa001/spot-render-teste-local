# Spot Render Teste Local – TechDocs

## Objetivo
Executar toda a stack Spot Render em um cluster local (Kind/Minikube/Docker Desktop) com dados persistidos.

## Passos automatizados
```
./setup-local.sh
```
- Clona/atualiza todos os repositórios.  
- Detecta cluster e cria (Kind) ou valida (Minikube/Docker Desktop).  
- Provisiona storage hostPath (configurável via `HOST_STORAGE_ROOT`).  
- Instala Argo, Prometheus/Grafana e SonarQube com `persistence.enabled=true`.  
- Constrói e carrega as imagens locais.  
- Aplica os manifestos (API, portal, workflows e observabilidade).

Para clusters docker-desktop no WSL2, execute com `HOST_STORAGE_ROOT=/run/desktop/mnt/host/c/tmp/spot-render-storage`.

## Passos manuais
1. `make kind-up`
2. `make bootstrap`
3. `make build-api build-portal build-argo`
4. `make load-images` (Kind/Minikube)
5. `make deploy-api deploy-portal deploy-argo deploy-observability`
6. `make submit-local KEY=... PROJECT=... VARIATION=... ARTIST=...`

## Render lists
- Arquivos confidenciais permanecem em `assets/renderlists/`.  
- Faça upload via portal/CLI ou utilize `make submit-local` após copiar os arquivos para `HOST_STORAGE_ROOT/shared`.

## Observabilidade
- Grafana: `kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80`.  
- SonarQube local: `kubectl port-forward -n monitoring svc/spot-sonarqube-sonarqube 9000:9000`.  
- Prometheus mantém dados em PVC provisionado automaticamente.
