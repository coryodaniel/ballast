# Ballast

Ballast is a kubernetes operator that relatively scales GKE NodePools.

It is particularly useful for running **preemptible** node pools with _on demand_ node pools as fallbacks to help optimize cost of kubernetes clusters.

- [Ballast](#ballast)
  - [Getting Started](#getting-started)
    - [Create a GCP Service Account](#create-a-gcp-service-account)
    - [Create a Kubernetes Secret w/ the GCP Service Account Keys](#create-a-kubernetes-secret-w-the-gcp-service-account-keys)
    - [Deploy the operator](#deploy-the-operator)
  - [Managing Ballast PoolPolicies](#managing-ballast-poolpolicies)
    - [Example `PoolPolicy`](#example-poolpolicy)
    - [Optimizing costs with preemptible pools and node affinity](#optimizing-costs-with-preemptible-pools-and-node-affinity)
  - [Development](#development)
    - [Setting up a development/test cluster](#setting-up-a-developmenttest-cluster)
      - [Using docker-desktop](#using-docker-desktop)
      - [Using terraform and GKE](#using-terraform-and-gke)
    - [Deploying operator CRDs to test against](#deploying-operator-crds-to-test-against)
    - [Testing](#testing)
    - [Developing](#developing)
  - [Links](#links)

## Getting Started

There are 3 steps to deploy the **ballast-operator**:

1. Create a GCP Service Account
2. Create a Kubernetes Secret w/ the GCP Service Account Keys
3. Deploy the operator

### Create a GCP Service Account

The ballast `Deployment` will need to run as a _GCP service account_ with access to your clusters' node pools.

The following script will create a GCP service account with permissions to view and manage cluster pool sizes.

```shell
export GCP_PROJECT=my-project-id
export SERVICE_ACCOUNT=ballast-operator

gcloud iam service-accounts create ${SERVICE_ACCOUNT}

gcloud projects add-iam-policy-binding ${GCP_PROJECT} \
  --member serviceAccount:${SERVICE_ACCOUNT}@${GCP_PROJECT}.iam.gserviceaccount.com \
  --role roles/container.admin

gcloud projects add-iam-policy-binding ${GCP_PROJECT} \
  --member serviceAccount:${SERVICE_ACCOUNT}@${GCP_PROJECT}.iam.gserviceaccount.com \
  --role roles/compute.viewer
```

*Note:* ballast only needs a few permissions. Security minded users may prefer to create a custom role with the following permissions instead:

- container.clusters.get
- container.clusters.update
- compute.instanceGroups.get

### Create a Kubernetes Secret w/ the GCP Service Account Keys

The following script will create a secret named `ballast-operator-sa-keys` that contains the GCP service account JSON keys.

```shell
gcloud iam service-accounts keys create /tmp/ballast-keys.json \
  --iam-account ${SERVICE_ACCOUNT}@${GCP_PROJECT}.iam.gserviceaccount.com

kubectl create secret generic ballast-operator-sa-keys --from-file=gcp.json=/tmp/ballast-keys.json

rm /tmp/ballast-keys.json
```

### Deploy the operator

[`operator.yaml`](./operator.yaml) is a pre-built manifest that expects `secret/ballast-operator-sa-keys` to exist in the same namespace.

```shell
kubectl apply -f ./operator.yaml
```

**Note:** In the [`Makefile`](./Makefile) you'll see references to `manifest.yaml` and `operator.yaml`. `manifest.yaml` is an operator manifest created for development and testing. `operator.yaml` is the current stable operator release.

## Managing Ballast PoolPolicies

### Example `PoolPolicy`

Ballast requires that all node-pools be created in advanced. Ballast only scales *target* pools' _minimum count_ (or _current size_ in the case autoscaling is disabled) to match the required minimums of the *source* pool.

```yaml
apiVersion: ballast.bonny.run/v1
kind: PoolPolicy
metadata:
  name: ballast-example
spec:
  projectId: gcp-project-id-here
  location: us-central1-a # zone that main/source pool of preemptible nodes exist in
  clusterName: your-cluster-name
  poolName: my-preemptible-pool # name of the main/source pool of preemptible nodes
  cooldownSeconds: 300
  targetPools: # list of pools to scale relative to main pool
  - poolName: my-autoscaling-pool
    minimumInstances: 1
    targetCapacityPercent: 25
    location: us-central1-a
  - poolName: my-fixed-pool
    minimumInstances: 5
    targetCapacityPercent: 50
    location: us-central1-a
  - poolName: my-other-cluster-autoscaling-pool
    minimumInstances: 5
    targetCapacityPercent: 50
    location: us-east4-a
    clusterName: my-other-cluster # supports scaling node-pools in other clusters
```

Multiple target pools can be specified. A mix of autoscaling and fixed size pools can be used, as well as pools of different instance types/sizes.

### Optimizing costs with preemptible pools and node affinity

The following steps will cause Kubernetes to *prefer* scheduling workloads on your preemptible nodes, but schedule workloads on your on-demand pools when it must.

1. Add the label `node-group:a-good-name-for-your-node-group` to **_all_** of your node pools that will be referenced in your `PoolPolicy`.
2. Add the label `node-type:preemptible` to your main/source pool referenced in your `PoolPolicy`.
3. Add the following affinity to your `Pod`, `Deployment`, or other workload..

```yaml
spec:
  affinity:
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
        - matchExpressions:
          - key: node-group
            operator: In
            values:
            - a-good-name-for-your-node-group
      preferredDuringSchedulingIgnoredDuringExecution:
      - weight: 1
        preference:
          matchExpressions:
          - key: node-type
            operator: In
            values:
            - "preemptible"
```

## Development

Ballast is built with the [bonny operator framework](https://github.com/coryodaniel/bonny) and Elixir. [Terraform](https://terraform.io) is used to provision test clusters.

A number of make targets exist to aid in development and testing:

```shell
make help
```

### Setting up a development/test cluster

#### Using docker-desktop

Two test suites are provided, both require a function kubernetes server. [Docker Desktop](https://www.docker.com/products/docker-desktop) ships with a version of kubernetes to get started locally quickly.

Alternatively you can use [terraform](https://www.terraform.io/downloads.html) to provision a cluster on GKE with `make dev.cluster.apply`. You will be charged for resources when using this approach.

#### Using terraform and GKE

First you will need to configure terraform with your GCP project and credentials:

```shell
touch ./terraform/terraform.tfvars
echo 'gcp_project = "my-project-id"' >> ./terraform/terraform.tfvars
echo 'gcp_credentials_path = "path/to/my/gcp-credentials.json"' >> ./terraform/terraform.tfvars
```

Now create the cluster, this can take a while:

```shell
make dev.cluster.apply
```

When you are done destroy the cluster with:

```shell
make dev.cluster.delete
```

### Deploying operator CRDs to test against

After setting up your test cluster you'll need to deploy the operator CRDs so that the cluster has the features the test suite will exercise.

```shell
make dev.start.in-cluster
```

### Testing

Two test suites exist:

- `make test` - elixir unit test suite on underlying controller code
- `make integration` - scales node pools on GKE

Additionally `make lint` will run the mix code formatter, credo, and dialyzer.

### Developing

You'll need a function cluster to connect to. Ballast will use your `current-context` in `~/.kube/config`. This can be changed in `config/dev.exs`.

Two environment variables must be exported to start the application.

```shell
export GOOGLE_APPLICATION_CREDENTIALS=/abs/path/to/creds.json
export GCP_PROJECT=your-project-id
```

Then run the following to generate a development manifest, apply it to your cluster, and start `iex`:

```shell
make dev.start.iex
```

## Links

- GKE Docs
  - [Instance Manager Groups REST API](https://cloud.google.com/compute/docs/reference/rest/v1/instanceGroupManagers)
  - [Node Pools REST API](https://cloud.google.com/kubernetes-engine/docs/reference/rest/v1/projects.locations.clusters.nodePools)
  - [Elixir Container Docs](https://hexdocs.pm/google_api_container/GoogleApi.Container.V1.Api.Projects.html)
  - [Elixir Compute Docs](https://hexdocs.pm/google_api_compute)
- GKE API Explorer
  - [setAutoscaling](https://cloud.google.com/kubernetes-engine/docs/reference/rest/v1/projects.locations.clusters.nodePools/setAutoscaling)
  - [setSize](https://cloud.google.com/kubernetes-engine/docs/reference/rest/v1/projects.locations.clusters.nodePools/setSize)
  - [nodePools get](https://cloud.google.com/kubernetes-engine/docs/reference/rest/v1/projects.locations.clusters.nodePools/get)
  - [instanceGroups get](https://cloud.google.com/compute/docs/reference/rest/v1/instanceGroups/get)
