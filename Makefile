.PHONY: help
.PHONY: clean ci lint test analyze docs
.PHONY: build compile push
.PHONY: dev.setup dev.destroy
.PHONY: dev.run-externally dev.run-in-cluster
.PHONY: dev.apply-policy dev.delete-policy
.PHONY: deploy pools.list


help: ## Show this help
help:
	@grep -E '^[a-zA-Z0-9._-]+:.*?## .*$$' Makefile | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

guard-%: # Creates an environment variable requirement by setting a prereq of guard-YOUR_ENV_VAR
	@ if [ -z '${${*}}' ]; then \
		echo "Environment variable $* not set"; \
		exit 1;\
	fi

include local.Makefile

all: ## Compiles and builds a remote operator - refactor name
all: clean compile build apply

ci: ## Test, lint, and generate docs
ci:
	mix lint
	mix test --exclude external:true --cover

test: ## Run tests with coverage
	mix test --cover

docs: ## Generate docs
	mix docs

compile: ## Compile ballast
	mix deps.get
	mix compile

build: ## Build docker image
build: guard-IMAGE compile
	docker build -t ${IMAGE} .

push: ## Release 'latest' docker image
push: guard-IMAGE
	docker push ${IMAGE}:latest

dev.setup: ## Setup dev/test cluster
dev.setup:
	cd terraform && terraform init && \
		terraform apply -var-file=terraform.tfvars

dev.destroy: ## Destroy dev/test cluster
	cd terraform && terraform destroy -var-file=terraform.tfvars

dev.run-externally: ## Compile and run operator external to cluster connecting to `CLUSTER_CONTEXT`
dev.run-externally: compile
dev.run-externally:
	- rm manifest.yaml
	mix bonny.gen.manifest
	kubectl apply -f ./manifest.yaml --context=${CLUSTER_CONTEXT}
	iex --dot-iex .iex.exs -S mix

dev.run-in-cluster: ## Run operator on `CLUSTER_CONTEXT` using the docker image `IMAGE`
dev.run-in-cluster:
	- rm manifest.yaml
	mix bonny.gen.manifest --image ${IMAGE}
	kubectl apply -f ./manifest.yaml --context=${CLUSTER_CONTEXT}

deploy: ## Run operator.yaml on `CLUSTER_CONTEXT`
deploy:
	-@kubectl delete -f ./manifest.yaml --context=${CLUSTER_CONTEXT}
	-@kubectl delete -f ./operator.yaml --context=${CLUSTER_CONTEXT}
	kubectl apply -f ./operator.yaml

dev.apply-policy: ## Create/Update example PoolPolicy
dev.apply-policy:
	-@kubectl delete -f ./example.yaml
	kubectl apply -f ./example.yaml

dev.delete-policy: ## Delete example PoolPolicy
dev.delete-policy:
	kubectl delete -f ./example.yaml

clean:
	rm -rf _build
	rm -rf deps
	rm -rf cover
	rm -rf doc

# .PHONY: crds
# crds:
# 	kubectl get crd  --context=${CLUSTER_CONTEXT}

# .PHONY: list
# list:
# 	kubectl get pod,deploy,service,pp --context=${CLUSTER_CONTEXT}
