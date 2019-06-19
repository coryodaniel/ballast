defmodule Ballast.Resources.Eviction do
  @moduledoc """
  Encapsulates a Kubernetes [`Eviction` resource](https://kubernetes.io/docs/reference/generated/kubernetes-api/v1.14/#create-eviction-pod-v1-core)

  ## Links

  * [Eviction API](https://kubernetes.io/docs/tasks/administer-cluster/safely-drain-node/#the-eviction-api)
  """

  @api_version "policy/v1beta1"
  @cluster_name :default
  @default_headers [{"Accept", "application/json"}, {"Content-Type", "application/json"}]

  alias __MODULE__
  alias K8s.{Cluster, Operation}
  alias K8s.Conf.RequestOptions
  alias Ballast.Instrumentation, as: Inst

  @doc """
  Returns an `Eviction` Kubernetes manifest

  ## Examples
      iex> Ballast.Resources.Eviction.manifest("default", "aged-nginx")
      %{apiVersion: "policy/v1beta1", kind: "Eviction", metadata: %{namespace: "default", name: "aged-nginx"}}
  """
  @spec manifest(binary, binary) :: map
  def manifest(namespace, name) do
    %{
      apiVersion: @api_version,
      kind: "Eviction",
      metadata: %{
        namespace: namespace,
        name: name
      }
    }
  end

  @doc """
  Creates a new eviction against a pod by POSTing a new `Eviction` to the Kubernetes API.

  `POST /api/v1/namespaces/{namespace}/pods/{name}/eviction`
  """
  @spec create(map) :: {:ok, HTTPoison.Response.t()} | {:error, HTTPoison.Error.t()}
  def create(%{"metadata" => %{"name" => name, "namespace" => ns}} = pod) do
    operation = Operation.build(:get, "v1", :pod, namespace: ns, name: name)
    eviction_name = name
    manifest = Eviction.manifest(ns, eviction_name)

    with {:ok, url} <- eviction_url(operation),
         {:ok, cluster_connection_config} <- Cluster.conf(@cluster_name),
         {:ok, request_options} <- RequestOptions.generate(cluster_connection_config),
         {:ok, body} <- Jason.encode(manifest) do
      headers = request_options.headers ++ @default_headers
      options = [ssl: request_options.ssl_options]

      {duration, response} = :timer.tc(HTTPoison, :post, [url, body, headers, options])

      measurements = %{duration: duration}
      metadata = %{node: pod["spec"]["nodeName"], pod: name}

      case response do
        {:ok, _} = resp ->
          Inst.pod_eviction_succeeded(measurements, metadata)
          resp

        error ->
          Inst.pod_eviction_failed(measurements, metadata)
          error
      end
    end
  end

  @spec eviction_url(K8s.Operation.t()) :: {:ok, binary} | {:error, atom}
  def eviction_url(operation) do
    with {:ok, base_url} <- Cluster.url_for(operation, @cluster_name) do
      {:ok, "#{base_url}/eviction"}
    end
  end
end
