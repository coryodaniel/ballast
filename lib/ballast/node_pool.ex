defmodule Ballast.NodePool do
  @moduledoc """
  Interface for interacting with Kubernetes NodePools.
  """

  @adapter Application.get_env(:ballast, :node_pool_adapter, Ballast.NodePool.Adapters.GKE)
  @node_pool_pressure_percent 90
  @node_pool_pressure_threshold @node_pool_pressure_percent / 100

  alias Ballast.{NodePool}
  alias Ballast.PoolPolicy.Changeset
  alias Ballast.Sys.Instrumentation, as: Inst

  defstruct [
    :cluster,
    :instance_count,
    :minimum_count,
    :maximum_count,
    :project,
    :location,
    :name,
    :data,
    :under_pressure
  ]

  @typedoc "Node pool metadata"
  @type t :: %__MODULE__{
          cluster: String.t(),
          project: String.t(),
          location: String.t(),
          instance_count: integer | nil,
          minimum_count: integer | nil,
          maximum_count: integer | nil,
          name: String.t(),
          data: map | nil,
          under_pressure: boolean | nil
        }

  @doc """
  Creates a `Ballast.NodePool` struct from a CRD resource's `spec` attribute

  ## Example
      iex> resource = %{"spec" => %{"clusterName" => "foo", "projectId" => "bar", "location" => "baz", "poolName" => "qux"}}
      ...> Ballast.NodePool.new(resource)
      %Ballast.NodePool{cluster: "foo", project: "bar", location: "baz", name: "qux", data: %{}}
  """
  @spec new(map) :: t
  def new(%{"spec" => spec}), do: new(spec)

  def new(%{"projectId" => p, "location" => l, "clusterName" => c, "poolName" => n}) do
    new(p, l, c, n)
  end

  def new(_invalid) do
    # TODO: emit formatting error (should ship a openapi spec w/ bonny)
    # TODO: how to handle return value here ...?
    %__MODULE__{}
  end

  @doc """
  Creates a `Ballast.NodePool` struct with or without metadata. Used for `get` queries and responses.

  ## Example
    NodePool without response data
      iex> Ballast.NodePool.new("project", "location", "cluster", "name")
      %Ballast.NodePool{cluster: "cluster", project: "project", location: "location", name: "name", data: %{}}

    NodePool with response data
      iex> Ballast.NodePool.new("project", "location", "cluster", "name", %{"foo" => "bar"})
      %Ballast.NodePool{cluster: "cluster", project: "project", location: "location", name: "name", data: %{"foo" => "bar"}}
  """
  @spec new(String.t(), String.t(), String.t(), String.t(), map | nil) :: t
  def new(project, location, cluster, name, data \\ %{}) do
    %NodePool{cluster: cluster, project: project, location: location, name: name, data: data}
  end

  @doc """
  Updates a `NodePool`'s `:under_pressure` field based on `under_pressure?/1`
  """
  @spec set_pressure_status(NodePool.t()) :: NodePool.t()
  def set_pressure_status(pool) do
    under_pressure = NodePool.under_pressure?(pool)
    %NodePool{pool | under_pressure: under_pressure}
  end

  @doc """
  Gets a node pool.

  ## Example
      iex> node_pool = Ballast.NodePool.new("my-project", "us-central1-a", "my-cluster", "my-pool")
      ...> {:ok, conn} = Ballast.conn()
      ...> Ballast.NodePool.get(node_pool, conn)
      {:ok, %Ballast.NodePool{cluster: "my-cluster", location: "us-central1-a", name: "my-pool", project: "my-project", instance_count: 10, data: %{autoscaling: %{enabled: true, maxNodeCount: 5, minNodeCount: 3}, instanceGroupUrls: ["https://www.googleapis.com/compute/v1/projects/my-project/zones/us-central1-a/instanceGroupManagers/gke-demo-demo-preemptible"], name: "demo-preemptible", selfLink: "https://container.googleapis.com/v1/projects/my-project/zones/us-central1-a/clusters/demo/nodePools/demo-preemptible", status: "RUNNING", initialNodeCount: 1}}}
  """
  @spec get(t, Tesla.Client.t()) :: {:ok, t} | {:error, Tesla.Env.t()}
  def get(pool, conn) do
    {duration, response} = :timer.tc(adapter_for(pool), :get, [pool, conn])
    measurements = %{duration: duration}

    case response do
      {:ok, pool_w_instance_count} ->
        Inst.provider_get_pool_succeeded(measurements, %{pool: pool_w_instance_count.name})
        {:ok, pool_w_instance_count}

      {:error, %Tesla.Env{status: status}} = error ->
        Inst.provider_get_pool_failed(measurements, %{status: status, pool: pool.name})
        error
    end
  end

  @doc """
  Scales a `NodePool`

  ## Examples
      iex> node_pool = Ballast.NodePool.new("my-proj", "my-loc", "my-cluster", "my-pool")
      ...> managed_pool = %Ballast.PoolPolicy.ManagedPool{pool: node_pool, minimum_percent: 30, minimum_instances: 1}
      ...> source_pool = %Ballast.NodePool{instance_count: 10}
      ...> changeset = Ballast.PoolPolicy.Changeset.new(managed_pool, source_pool)
      ...> Ballast.NodePool.scale(changeset, Ballast.conn())
      :ok
  """
  @spec scale(Changeset.t(), Tesla.Client.t()) :: :ok | {:error, Tesla.Env.t()}
  def scale(%Changeset{strategy: :nothing} = changeset, _) do
    {measurements, metadata} = measurements_and_metadata(changeset)
    Inst.provider_scale_pool_skipped(measurements, metadata)
    :ok
  end

  def scale(%Changeset{minimum_count: count, pool: %NodePool{instance_count: count}} = changeset, _) do
    {measurements, metadata} = measurements_and_metadata(changeset)
    Inst.provider_scale_pool_skipped(measurements, metadata)
    :ok
  end

  def scale(%Changeset{} = changeset, conn) do
    adapter = adapter_for(changeset.pool)
    {duration, response} = :timer.tc(adapter, :scale, [changeset, conn])
    {measurements, metadata} = measurements_and_metadata(changeset)

    measurements = Map.put(measurements, :duration, duration)

    case response do
      {:ok, _} ->
        Inst.provider_scale_pool_succeeded(measurements, metadata)
        :ok

      {:error, %Tesla.Env{status: status}} = error ->
        metadata = Map.put(metadata, :status, status)
        Inst.provider_scale_pool_failed(measurements, metadata)
        error
    end
  end

  @doc """
  Determines if autoscaling is enabled for a pool
  """
  @spec autoscaling_enabled?(Ballast.NodePool.t()) :: boolean()
  def autoscaling_enabled?(pool), do: adapter_for(pool).autoscaling_enabled?(pool)

  @doc """
  Determine if a pool is under pressure.

  A pool is considered under pressure when more than #{@node_pool_pressure_percent} percent of its nodes are under pressure.

  Notes:
  * Assumes there is pressure if there is an error from the k8s API.
  * Considers no nodes returned as under pressure.
  """
  @spec under_pressure?(Ballast.NodePool.t()) :: boolean()
  def under_pressure?(%Ballast.NodePool{} = pool) do
    label_selector = adapter_for(pool).label_selector(pool)
    params = %{labelSelector: label_selector}

    with {:ok, [_h | _t] = nodes} <- Ballast.Kube.Node.list(params) do
      nodes_under_pressure = Enum.filter(nodes, fn node -> node_under_pressure?(node) end)

      percent_under_pressure = length(nodes_under_pressure) / length(nodes)
      percent_under_pressure >= @node_pool_pressure_threshold
    else
      _error -> true
    end
  end

  @spec node_under_pressure?(map) :: boolean()
  defp node_under_pressure?(node) do
    !Ballast.Kube.Node.ready?(node) || Ballast.Kube.Node.resources_constrained?(node)
  end

  @doc false
  @spec measurements_and_metadata(Changeset.t()) :: {map, map}
  defp measurements_and_metadata(changeset) do
    measurements = %{
      source_pool_current_count: changeset.source_count,
      managed_pool_current_count: changeset.pool.instance_count,
      managed_pool_current_minimum_count: changeset.pool.minimum_count,
      managed_pool_new_minimum_count: changeset.minimum_count
    }

    metadata = %{pool: changeset.pool.name, strategy: changeset.strategy}

    {measurements, metadata}
  end

  # Mocking out for multi-provider. Should take a NodePool or PoolPolicy and determine which cloud provider to use.
  @spec adapter_for(Ballast.NodePool.t()) :: module()
  defp adapter_for(_), do: @adapter
end
