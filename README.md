# spot-render-teste-local

> Ambiente de referência para rodar **Spot Render** ponta a ponta em um cluster Kubernetes local (Kind ou Minikube). Inclui scripts para criar namespaces, instalar dependências (Argo, Prometheus/Grafana) e implantar API, Portal e workflows usando as imagens construídas nos demais repositórios.

## Visão geral

- Namespaces utilizados: `spot-render` (API/portal), `rendering` (workflows) e `monitoring` (Prometheus/Grafana).  
- Render list padrão (arquivos `render-list*.csv/xlsx`) **não são versionados**. Armazene-os em `assets/renderlists/` e faça upload via portal/CLI ou utilizando o flag `--set-default`.

## Pré-requisitos
- Kind ou Minikube + kubectl + helm.  
- Docker local capaz de construir as imagens dos repositórios `spot-render-*`.  
- Clonar todos os repositórios lado a lado:
  ```
  git clone https://github.com/raafa001/spot-render-api.git
  git clone https://github.com/raafa001/spot-render-portal.git
  git clone https://github.com/raafa001/spot-render-argo.git
  git clone https://github.com/raafa001/spot-render-observability.git
  git clone https://github.com/raafa001/spot-render-cli.git
  git clone https://github.com/raafa001/spot-render-infra-aws.git (para consultar variáveis)
  git clone https://github.com/raafa001/spot-render-teste-local.git
  ```

## Passos rápidos

```bash
cd spot-render-teste-local
make kind-up           # cria cluster local com ingress
make bootstrap         # namespaces, storage compartilhado, Argo, Prometheus/Grafana
make build-api         # (opcional) constrói imagem local
make load-images       # carrega imagens no Kind
make deploy-api        # aplica overlay local (PVC + STORAGE_MODE=local)
make deploy-portal
make deploy-argo       # aplica workflow local (render-workflow-local)
make deploy-observability
```

Para disparar um render manualmente (até termos watcher automático):

```bash
make submit-local KEY="input/projeto/variacao/timestamp/arquivo.blend" PROJECT=projeto VARIATION=variacao ARTIST=nome
```

Use `ls /tmp/spot-render-storage/input` para encontrar o `KEY` criado após o upload.

Após o deploy:
- Portal disponível em `https://spot-render.local` (ingress nginx).  
- API em `https://api.spot-render.local`.  
- Prometheus/Grafana expostos via porta local (`kubectl port-forward`).

## Render lists
- Coloque a lista padrão em `assets/renderlists/default.xlsx` (não commitado).  
- Use o portal ou CLI para enviar listas por projeto.  
- Para promover uma lista padrão para todos: marque “Nova render list padrão” e informe `username=admin`, `password=admin` (somente ambiente de teste). Em produção, troque as credenciais via Secrets Manager.

## Estrutura
```
assets/
  renderlists/        # colocar arquivos privados aqui
k8s/
  namespaces.yaml
kind-config.yaml
Makefile
scripts/bootstrap.sh
docs/
  index.md
mkdocs.yml
```

## Observabilidade local
- `make deploy-observability` aplica o exporter + ServiceMonitor.  
- Grafana dashboard import: use `spot-render-observability/grafana/dashboards/rendering.json`.  
- Alertas simulados (Prometheus) podem ser habilitados rodando `make deploy-alerts` (futuro).

## Local TechDocs
- `docs/index.md` descreve o fluxo end-to-end, permitindo publicação no Backstage como guia de sandbox.
