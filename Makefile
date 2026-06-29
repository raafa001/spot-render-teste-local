CLUSTER_NAME ?= spot-render-local
KIND_NODE_IMAGE ?= kindest/node:v1.30.0

.PHONY: kind-up kind-down bootstrap build-api build-portal build-argo load-images deploy-api deploy-portal deploy-argo deploy-observability

kind-up:
	kind create cluster --name $(CLUSTER_NAME) --image $(KIND_NODE_IMAGE) --config kind-config.yaml

kind-down:
	kind delete cluster --name $(CLUSTER_NAME)

bootstrap:
	./scripts/bootstrap.sh

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

deploy-api:
	kubectl apply -n spot-render -f ../spot-render-api/k8s/services.yaml
	kubectl apply -n spot-render -f ../spot-render-api/k8s/analysis.yaml
	kubectl apply -n spot-render -f ../spot-render-api/k8s/rollout.yaml
	kubectl apply -n spot-render -f ../spot-render-api/k8s/hpa.yaml
	kubectl apply -n monitoring -f ../spot-render-api/k8s/servicemonitor.yaml

deploy-portal:
	kubectl apply -n spot-render -f ../spot-render-portal/k8s/services.yaml
	kubectl apply -n spot-render -f ../spot-render-portal/k8s/rollout.yaml
	kubectl apply -n spot-render -f ../spot-render-portal/k8s/hpa.yaml

deploy-argo:
	kubectl apply -n rendering -f ../spot-render-argo/workflows/render.yaml
	kubectl apply -n rendering -f ../spot-render-argo/sensors/s3-listener.yaml

deploy-observability:
	kubectl apply -n monitoring -f ../spot-render-observability/prometheus/alerts/canary-rules.yaml
	kubectl apply -n monitoring -f ../spot-render-observability/grafana/dashboards
