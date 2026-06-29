CLUSTER_NAME ?= spot-render-local
KIND_NODE_IMAGE ?= kindest/node:v1.30.0

.PHONY: kind-up kind-down bootstrap build-api build-portal build-argo load-images deploy-storage deploy-api deploy-portal deploy-argo deploy-observability submit-local

kind-up:
	kind create cluster --name $(CLUSTER_NAME) --image $(KIND_NODE_IMAGE) --config kind-config.yaml

kind-down:
	kind delete cluster --name $(CLUSTER_NAME)

bootstrap:
	./scripts/bootstrap.sh

deploy-storage:
	mkdir -p /tmp/spot-render-storage/input /tmp/spot-render-storage/output /tmp/spot-render-storage/error /tmp/spot-render-storage/renderlists
	kubectl apply -f k8s/storage.yaml

build-api:
	cd ../spot-render-api && docker build -t spot-render-api:dev .

build-portal:
	cd ../spot-render-portal && docker build -t spot-render-portal:dev .

build-argo:
	cd ../spot-render-argo && docker build -t spot-render-worker:dev -f Dockerfile.worker .

load-images:
	kind load docker-image --name $(CLUSTER_NAME) spot-render-api:dev
	kind load docker-image --name $(CLUSTER_NAME) spot-render-portal:dev
	kind load docker-image --name $(CLUSTER_NAME) spot-render-worker:dev

deploy-api: deploy-storage
	kubectl apply -k k8s/overlays/api-local

deploy-portal:
	kubectl apply -n spot-render -f ../spot-render-portal/k8s/services.yaml
	kubectl apply -n spot-render -f ../spot-render-portal/k8s/rollout.yaml
	kubectl apply -n spot-render -f ../spot-render-portal/k8s/hpa.yaml

deploy-argo: deploy-storage
	kubectl apply -k k8s/overlays/argo-local

deploy-observability:
	kubectl apply -n monitoring -f ../spot-render-observability/prometheus/alerts/canary-rules.yaml
	kubectl apply -n monitoring -f ../spot-render-observability/grafana/dashboards

submit-local:
	@if [ -z "$(KEY)" ]; then echo "Use make submit-local KEY=path/to/file project=..."; exit 1; fi
	argo submit -n rendering --from workflowtemplate/render-workflow-local \
		-p key=$(KEY) -p project=$(PROJECT) -p variation=$(VARIATION) -p artist=$(ARTIST)
