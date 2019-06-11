defmodule Ballast.Evictor do
  @moduledoc """
  [Eviction API](https://kubernetes.io/docs/tasks/administer-cluster/safely-drain-node/#the-eviction-api)
  """

  @label "ballast.bonny.run/evictable"
  @minimum_lifetime_in_minutes 1
  @minimum_lifetime_in_seconds @minimum_lifetime_in_minutes * 60
  @pod_batch_size 500
  @cluster_name :default

  require Logger
  alias K8s.Client

  @doc """
  POST /api/v1/namespaces/{namespace}/pods/{name}/eviction
  """
  @spec evict(map) :: :ok
  def evict(pod = %{"metadata" => %{"name" => name, "namespace" => ns}}) do
    operation = K8s.Operation.build(:get, "v1", :pod, namespace: ns, name: name)

    with {:ok, base_url} <- K8s.Cluster.url_for(operation, @cluster_name),
         {:ok, cluster_connection_config} <- K8s.Cluster.conf(@cluster_name),
         {:ok, request_options} <- K8s.Conf.RequestOptions.generate(cluster_connection_config),
         {:ok, body} <- eviction_body(ns, name) do
      eviction_url = "#{base_url}/eviction"
      headers = request_options.headers ++ [{"Accept", "application/json"}, {"Content-Type", "application/json"}]
      options = [ssl: request_options.ssl_options]

      node = pod["spec"]["nodeName"]
      Logger.info("Evicting #{ns}/#{name} from #{node}")

      HTTPoison.post(eviction_url, body, headers, options)
    end
  end

  @doc """
  Gets all pods with eviction enabled.
  TODO: if continue, gather all pods first and return
  """
  def candidates() do
    operation = Client.list("v1", :pod, namespace: :all)
    response = Client.run(operation, @cluster_name, params: pod_query())

    case response do
      {:ok, response} -> {:ok, Map.get(response, "items")}
      error -> error
    end
  end

  def evictable() do
    cutoff_time = DateTime.add(DateTime.utc_now(), -@minimum_lifetime_in_seconds, :second)

    with {:ok, candidates} <- candidates(),
         pods <- Enum.filter(candidates, &pod_started_before(&1, cutoff_time)) do
      {:ok, pods}
    end
  end

  def evictable(match: pattern) do
    with {:ok, candidates} <- evictable(),
         pods <- Enum.filter(candidates, &pod_spec_node_name_matches(&1, pattern)) do
      {:ok, pods}
    end
  end

  @doc """
  Determines if a pod's assigned node matches a substring

  ## Examples
      iex> Ballast.Evictor.pod_spec_node_name_matches(%{"spec" => %{"nodeName" => "cloud-cool-pool-65678"}}, "cool-pool")
      true

      iex> Ballast.Evictor.pod_spec_node_name_matches(%{"spec" => %{"nodeName" => "cloud-cool-pool-65678"}}, "uncool-pool")
      false
  """
  def pod_spec_node_name_matches(%{"spec" => %{"nodeName" => name}}, substring), do: String.contains?(name, substring)
  def pod_spec_node_name_matches(_, _), do: false

  @doc """
  Check if a pod started before a given time

  ## Examples
      iex> start_time = DateTime.utc_now |> DateTime.add(-30, :second) |> DateTime.to_string
      ...> cutoff_time = DateTime.utc_now
      ...> Ballast.Evictor.pod_started_before(%{"status" => %{"startTime" => start_time}}, cutoff_time)
      true

      iex> start_time = DateTime.utc_now |> DateTime.to_string
      ...> cutoff_time = DateTime.utc_now |> DateTime.add(-30, :second)
      ...> Ballast.Evictor.pod_started_before(%{"status" => %{"startTime" => start_time}}, cutoff_time)
      false
  """
  def pod_started_before(%{"status" => %{"startTime" => start_time}}, cutoff_time) do
    with {:ok, start_time, _} <- DateTime.from_iso8601(start_time),
         :lt <- DateTime.compare(start_time, cutoff_time) do
      true
    else
      _ -> false
    end
  end

  def pod_started_before(_, _), do: false

  defp pod_query() do
    [
      {"labelSelector", "#{@label}=true"},
      {"limit", @pod_batch_size}
    ]
  end

  defp eviction_body(ns, name) do
    manifest = %{
      apiVersion: "policy/v1beta1",
      kind: "Eviction",
      metadata: %{
        name: name,
        namespace: ns
      }
    }

    Jason.encode(manifest)
  end
end
