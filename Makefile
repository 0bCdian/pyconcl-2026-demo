RATE     ?= 100
DURATION ?= 30m
RAMP_TO  ?= 0
MEMORY   ?= 2Gi
SPOT     ?= false

TOFU = tofu -chdir=infra
out  = $$($(TOFU) output -raw $(1))

.PHONY: board init plan up down kubeconfig images monitoring cnpg deploy load startup proxy rollout status lint local local-load local-down

init:
	$(TOFU) init

plan:
	$(TOFU) plan -var stage=on -var spot=$(SPOT)

up:
	$(TOFU) apply -var stage=on -var spot=$(SPOT)
	$(MAKE) kubeconfig images monitoring cnpg deploy

down:
	-gcloud container clusters get-credentials $(call out,cluster_name) --zone $(call out,zone) --project $(call out,project_id) \
		&& kubectl delete namespace demo --ignore-not-found && kubectl wait --for=delete pv --all --timeout=300s
	$(TOFU) apply -var stage=off

kubeconfig:
	gcloud container clusters get-credentials $(call out,cluster_name) --zone $(call out,zone) --project $(call out,project_id)

images:
	gcloud builds submit . --config cloudbuild.yaml --project $(call out,project_id) --region $(call out,region) \
		--service-account $(call out,build_service_account) --gcs-source-staging-dir $(call out,build_staging_dir) \
		--substitutions _REPO=$(call out,registry)

monitoring:
	helm repo add prometheus-community https://prometheus-community.github.io/helm-charts --force-update
	helm upgrade --install kps prometheus-community/kube-prometheus-stack --version 92.14.1 \
		-n monitoring --create-namespace -f k8s/monitoring-values.yaml --wait
	kubectl -n monitoring create configmap shop-dashboard --from-file=shop.json=k8s/dashboard.json --dry-run=client -o yaml \
		| kubectl label --local -f - grafana_dashboard=1 -o yaml | kubectl apply -f -

cnpg:
	helm repo add cnpg https://cloudnative-pg.github.io/charts --force-update
	helm upgrade --install cnpg cnpg/cloudnative-pg --version 0.29.1 -n cnpg-system --create-namespace --wait

deploy:
	kubectl create namespace demo --dry-run=client -o yaml | kubectl apply -f -
	kubectl -n demo create configmap db-schema --from-file=schema.sql=db/schema.sql --dry-run=client -o yaml | kubectl apply -f -
	kubectl apply -f k8s/postgres.yaml
	kubectl -n demo wait --for=condition=Ready cluster/postgres --timeout=300s
	sed -e "s|REPO|$(call out,registry)|g" -e 's|MEMORY_LIMIT|$(MEMORY)|g' -e "s|CATALOG_URI_VALUE|$(call out,catalog_uri)|g" \
		k8s/demo.yaml | kubectl apply -f -

load:
	kubectl -n demo delete job k6 --ignore-not-found
	kubectl -n demo create configmap k6-script --from-file=k6/test.js --dry-run=client -o yaml | kubectl apply -f -
	sed -e 's|RATE_VALUE|$(RATE)|' -e 's|DURATION_VALUE|$(DURATION)|' -e 's|RAMP_TO_VALUE|$(RAMP_TO)|' k8s/k6.yaml | kubectl apply -f -

startup:
	./scripts/startup.sh

proxy:
	@echo "Grafana:    http://localhost:8001/api/v1/namespaces/monitoring/services/kps-grafana:80/proxy/"
	@echo "Prometheus: http://localhost:8001/api/v1/namespaces/monitoring/services/kps-kube-prometheus-stack-prometheus:9090/proxy/"
	@echo "Arena:      http://localhost:8001/api/v1/namespaces/demo/services/arena:80/proxy/screen?$$(kubectl -n demo logs deploy/arena | grep -m1 -o 'token=[^ ]*')"
	kubectl proxy --port 8001

board:
	@kubectl -n demo logs deploy/arena | grep -m1 -o 'token=[^ ]*' | sed 's|^|Tablero: http://localhost:8081/screen?|'
	while true; do kubectl -n demo port-forward svc/arena 8081:80; sleep 1; done

rollout:
	kubectl -n demo rollout restart deploy/bad deploy/good

status:
	kubectl -n demo get pods -o wide

lint:
	for f in deploy/bad/Dockerfile deploy/good/Dockerfile; do echo "== $$f"; podman run --rm -i ghcr.io/hadolint/hadolint:v2.15.1 < $$f; done

local:
	./scripts/local.sh up

local-load:
	RATE=$(RATE) DURATION=$(DURATION) ./scripts/local.sh load

local-down:
	./scripts/local.sh down
