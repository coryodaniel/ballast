.PHONY: all build clean compile help integration lint push test
.PHONY: dev.cluster.apply dev.cluster.delete
.PHONY: dev.operator.apply dev.operator.delete
.PHONY: dev.policy.apply dev.policy.delete
.PHONY: dev.scale.down dev.scale.start dev.scale.totals dev.scale.up dev.scale.where

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

include local.Makefile

# dev.setup:
# local.Makefile:
# 	touch local.Makefile
# 	echo "IMAGE=quay.io/coryodaniel/ballast" >> local.Makefile
# 	echo "# GCP_PROJECT=project-id-here" >> local.Makefile
# 	echo "# GOOGLE_APPLICATION_CREDENTIALS=path-to-project-credentials" >> local.Makefile
# 	echo "# export IMAGE=quay.io/coryodaniel/ballast" >> local.Makefile

dev.cluster.apply: ## Create / Update development cluster
dev.cluster.apply:
	cd terraform && terraform init && \
		terraform apply -var-file=terraform.tfvars

dev.cluster.delete: ## Delete development cluster
	cd terraform && terraform destroy -var-file=terraform.tfvars

dev.operator.apply: ## Run operator.yaml in kubectl current context
	-@kubectl delete -f ./operator.yaml
	kubectl apply -f ./operator.yaml

dev.operator.delete: ## Delete the operator in kubectl current context
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

dev.scale.up: ## Scale nginx deployment to 250
dev.scale.up: dev.scale.start
	kubectl scale --replicas=250 -f ./test-scale-up.yaml

dev.scale.down: ## Destroy nginx deployment
	kubectl delete -f ./test-scale-up.yaml

dev.scale.where: ## Show which nodes scaled nginx test is on
	kubectl get pods -o wide --sort-by="{.spec.nodeName}" --chunk-size=0

dev.scale.totals: ## Node pool to pod count
	$(MAKE) dev.scale.where | grep -Fo -e preemptible -e autoscaling -e fixed | uniq -c

dev.roll.%: ## Rolling replace a node pool by "name": autoscaling, fixed, preemptible
	gcloud compute instance-groups managed list |\
		grep gke-ballast-ballast-$* |\
		awk '{print $$1}' |\
		xargs -I '{}' gcloud compute instance-groups managed rolling-action replace '{}' --zone us-central1-a --max-unavailable 100 --max-surge 1
