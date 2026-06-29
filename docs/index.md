# Spot Render Teste Local – TechDocs

## Objetivo
Executar toda a stack Spot Render em um cluster local (Kind/Minikube) para desenvolvimento e QA.

## Passos
1. Clone todos os repositórios `spot-render-*` no mesmo diretório.  
2. `make kind-up` para criar o cluster.  
3. `make bootstrap` para instalar namespaces, Argo, Prometheus/Grafana.  
4. Construa as imagens localmente (`make build-api build-portal build-argo`) e carregue (`make load-images`).  
5. Implante serviços (`make deploy-api deploy-portal deploy-argo deploy-observability`).  
6. Para processar um arquivo específico, use `make submit-local KEY=... PROJECT=... VARIATION=... ARTIST=...` e monitore o workflow `render-workflow-local`.

## Render lists
- Armazene arquivos confidenciais em `assets/renderlists/`.  
- Para teste, faça upload via portal/CLI ou substitua a lista padrão usando o campo "Nova render list padrão" (admin/admin em sandbox).

## Observabilidade
- Grafana disponível via `kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80`.  
- Use o dashboard `rendering.json` do repositório `spot-render-observability`.

## TechDocs
- Publicar com `mkdocs.yml` deste repositório.
