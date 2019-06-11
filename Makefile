.PHONY: all build clean compile help integration lint push test setup
.PHONY: dev.cluster.apply dev.cluster.delete
.PHONY: operator.apply operator.delete
.PHONY: dev.policy.apply dev.policy.delete
.PHONY: dev.scale.down dev.scale.start dev.scale.totals dev.scale.up dev.scale.where
.PHONY: dev.start.iex dev.start.in-cluster
.PHONY: dev.roll.autoscaling dev.roll.fixed dev.roll.preemptible
.PHONY: dev.sourcepool.enable dev.sourcepool.disable

IMAGE=quay.io/coryodaniel/ballast

help: ## Show this help
help:
	@grep -E '^[a-zA-Z0-9._%-]+:.*?## .*$$' Makefile | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

guard-%: # Creates an environment variable requirement by setting a prereq of guard-YOUR_ENV_VAR
	@ if [ -z '${${*}}' ]; then \
		echo "Environment variable $* not set"; \
		exit 1;\
	fi

all: ## Lints, tests, compiles, and pushes "latest" docker tag.
all: lint test compile build push

setup: ## Setup

test: ## Run unit tests with coverage
	mix test --exclude external:true --cover

integration: ## Run integration tests with coverage.
	mix test --cover

lint: ## run format, credo, and dialyzer
	mix lint

compile: ## Compile ballast
	mix deps.get
	mix compile

build: ## Build docker image
build: guard-IMAGE compile
	docker build -t ${IMAGE} .

push: ## Release 'latest' docker image
push: guard-IMAGE
	docker push ${IMAGE}:latest

clean: ## Clean builds, dependencies, coverage reports, and docs
	rm -rf _build
	rm -rf deps
	rm -rf cover
	rm -rf doc

dev.cluster.apply: ## Create / Update development cluster
dev.cluster.apply:
	cd terraform && terraform init && \
		terraform apply -var-file=terraform.tfvars

dev.cluster.delete: ## Delete development cluster
	cd terraform && terraform destroy -var-file=terraform.tfvars

operator.apply: ## Run operator.yaml in kubectl current context using the latest docker image
	-@kubectl delete -f ./operator.yaml
	kubectl apply -f ./operator.yaml

operator.delete: ## Delete the operator in kubectl current context
	kubectl delete -f ./operator.yaml

dev.policy.apply: ## Create / Update example PoolPolicy
dev.policy.apply:
	-@kubectl delete -f ./terraform/ballast-poolpolicy.yaml
	kubectl apply -f ./terraform/ballast-poolpolicy.yaml

dev.policy.delete: ## Delete example PoolPolicy
dev.policy.delete:
	kubectl delete -f ./terraform/ballast-poolpolicy.yaml

dev.scale.start: ## Start an nginx deployment
	kubectl apply -f ./test-scale-up.yaml

dev.scale.up: ## Scale nginx deployment to a lot
dev.scale.up: dev.scale.start
	kubectl scale --replicas=20 -f ./test-scale-up.yaml

dev.scale.down: ## Destroy nginx deployment
	kubectl delete -f ./test-scale-up.yaml

dev.scale.where: ## Show which nodes scaled nginx test is on
	kubectl get pods -o wide --sort-by="{.spec.nodeName}" --chunk-size=0

dev.scale.totals: ## Show count of pods on node pools
	$(MAKE) dev.scale.where | grep -Fo -e other -e preemptible -e autoscaling -e fixed | uniq -c

dev.roll.autoscaling: ## Rolling replace the autoscaling (target) node pool
dev.roll.autoscaling: _roll_cluster.autoscaling
dev.roll.fixed: ## Rolling replace the fixed (target) node pool
dev.roll.fixed: _roll_cluster.fixed
dev.roll.preemptible: ## Rolling replace the preemptible (source) node pool
dev.roll.preemptible: _roll_cluster.preemptible

_roll_cluster.%:
	gcloud compute instance-groups managed list |\
		grep gke-ballast-ballast-$* |\
		awk '{print $$1}' |\
		xargs -I '{}' gcloud compute instance-groups managed rolling-action replace '{}' --zone us-central1-a --max-unavailable 100 --max-surge 1

dev.start.iex: ## Deploys CRD and RBAC to kubectl current context, but runs ballast in iex
	- rm manifest.yaml
	mix bonny.gen.manifest
	kubectl apply -f ./manifest.yaml
	iex --dot-iex .iex.exs -S mix

dev.start.in-cluster: ## Deploys "latest" docker image into kubectl current context w/ a newly generated manifest.yaml
	- rm manifest.yaml
	mix bonny.gen.manifest --image ${IMAGE}
	kubectl apply -f ./manifest.yaml

SOURCE_POOL=$(shell kubectl get nodes | grep preemptible | awk '{print $$1}')
dev.sourcepool.disable: ## Disable the source pool
	for node in ${SOURCE_POOL} ; do (kubectl drain $$node --force --ignore-daemonsets &); done

dev.sourcepool.enable: ## Enabled the source pool
	for node in ${SOURCE_POOL} ; do (kubectl uncordon $$node &); done

dev.pools.count: ## Show number of nodes in pool
	kubectl get nodes | grep -Fo -e other -e preemptible -e autoscaling -e fixed | uniq -c
