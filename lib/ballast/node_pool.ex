defmodule Ballast.NodePool do
  @moduledoc """
  Interface for interacting with Kubernetes NodePools.
  """

  @adapter Application.get_env(:ballast, :node_pool_adapter, Ballast.NodePool.Adapters.GKE)
  alias Ballast.{NodePool}
  alias Ballast.Sys.Instrumentation, as: Inst

  defstruct [:cluster, :instance_count, :project, :location, :name, :data]

  @typedoc "Node pool metadata"
  @type t :: %NodePool{
          cluster: String.t(),
          project: String.t(),
          location: String.t(),
          instance_count: integer | nil,
          name: String.t(),
          data: map | nil
        }

  @doc """
  Creates a `Ballast.NodePool` struct from a CRD resource's `spec` attribute

  ## Example
      iex> resource = %{"spec" => %{"clusterName" => "foo", "projectId" => "bar", "location" => "baz", "poolName" => "qux"}}
      ...> Ballast.NodePool.new(resource)
      %Ballast.NodePool{cluster: "foo", project: "bar", location: "baz", name: "qux", data: %{}}
  """
  @spec new(map) :: t
  def new(%{"spec" => spec}), do: NodePool.new(spec)

  def new(%{"projectId" => p, "location" => l, "clusterName" => c, "poolName" => n}), do: new(p, l, c, n)

  def new(_invalid), do: %__MODULE__{}

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
  def new(project, location, cluster, name, data \\ %{}),
    do: %NodePool{cluster: cluster, project: project, location: location, name: name, data: data}

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
      {:ok, updated_pool} ->
        Inst.provider_get_pool_succeeded(measurements, %{pool: updated_pool.name})
        {:ok, updated_pool}

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
      ...> source_instance_count = 10
      ...> changeset = Ballast.PoolPolicy.Changeset.new(managed_pool, source_instance_count)
      ...> Ballast.NodePool.scale(changeset, Ballast.conn())
      :ok
  """
  @spec scale(Ballast.PoolPolicy.Changeset.t(), Tesla.Client.t()) :: :ok | {:error, Tesla.Env.t()}
  def scale(changeset, conn) do
    pool = changeset.pool

    {duration, response} = :timer.tc(adapter_for(pool), :scale, [changeset, conn])
    measurements = %{duration: duration}

    case response do
      {:ok, _} ->
        Inst.provider_scale_pool_succeeded(measurements, %{pool: pool.name})
        :ok

      {:error, %Tesla.Env{status: status}} = error ->
        Inst.provider_scale_pool_failed(measurements, %{status: status, pool: pool.name})
        error
    end
  end

  @spec autoscaling_enabled?(Ballast.NodePool.t()) :: boolean()
  def autoscaling_enabled?(pool), do: adapter_for(pool).autoscaling_enabled?(pool)

  @doc """
  Mocking out for multi-provider. Should take a NodePool or PoolPolicy and determine which cloud provider to use.
  """
  @spec adapter_for(Ballast.NodePool.t()) :: module()
  def adapter_for(_), do: @adapter
end
