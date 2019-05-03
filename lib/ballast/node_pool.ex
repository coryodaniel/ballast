defmodule Ballast.NodePool do
  @moduledoc """
  Interface for interacting with Kubernetes NodePools.
  """

  @adapter Application.get_env(:ballast, :node_pool_adapter, Ballast.NodePool.Adapters.GKE)

  require Logger
  alias Ballast.{NodePool}

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
  Generates a NodePool identifier

  TODO: Implement as adapter behavior

  ## Example
    NodePool without response data
      iex> pool = Ballast.NodePool.new("foo", "bar", "baz", "qux")
      ...> Ballast.NodePool.id(pool)
      "projects/foo/locations/bar/clusters/baz/nodePools/qux"
  """
  @spec id(Ballast.NodePool.t()) :: String.t()
  def id(%NodePool{} = pool) do
    "projects/#{pool.project}/locations/#{pool.location}/clusters/#{pool.cluster}/nodePools/#{pool.name}"
  end

  @doc """
  Gets a node pool.

  ## Example
      iex> node_pool = Ballast.NodePool.new("my-project", "us-central1-a", "my-cluster", "my-pool")
      ...> {:ok, conn} = Ballast.conn()
      ...> Ballast.NodePool.get(node_pool, conn)
      {:ok, %Ballast.NodePool{cluster: "my-cluster", location: "us-central1-a", name: "my-pool", project: "my-project", data: %{autoscaling: %{enabled: true, maxNodeCount: 5, minNodeCount: 3}, instanceGroupUrls: ["https://www.googleapis.com/compute/v1/projects/my-project/zones/us-central1-a/instanceGroupManagers/gke-demo-demo-preemptible"], name: "demo-preemptible", selfLink: "https://container.googleapis.com/v1/projects/my-project/zones/us-central1-a/clusters/demo/nodePools/demo-preemptible", status: "RUNNING", initialNodeCount: 1}}}
  """
  @spec get(t, Tesla.Client.t()) :: {:ok, t} | {:error, Tesla.Env.t()}
  def get(pool, conn) do
    case @adapter.get(pool, conn) do
      {:ok, response} ->
        node_pool = %NodePool{pool | data: response}
        {:ok, node_pool}

      error ->
        error
    end
  end

  @doc """
  Scales a `NodePool`

  ## Examples
      iex> node_pool = Ballast.NodePool.new("my-proj", "my-loc", "my-cluster", "my-pool")
      ...> target = %Ballast.PoolPolicy.Target{pool: node_pool, target_capacity_percent: 30, minimum_instances: 1, autoscaling_enabled: false}
      ...> source_instance_count = 10
      ...> changeset = Ballast.PoolPolicy.Changeset.new(target, source_instance_count)
      ...> Ballast.NodePool.scale(changeset, Ballast.conn())
      :ok
  """
  @spec scale(Ballast.PoolPolicy.Changeset.t, Tesla.Client.t()) :: :ok | {:error, Tesla.Env.t()}
  def scale(changeset, conn), do: @adapter.scale(changeset, conn)

  @doc """
  Returns the size of a pool by checking `size` from the pool's `InstanceGroupManager`

  ## Examples
    Returns the size when the pool exists
      iex> pool = %Ballast.NodePool{data: %{"foo" => "bar"}}
      ...> {:ok, conn} = Ballast.conn()
      ...> Ballast.NodePool.size(pool, conn)
      {:ok, %Ballast.NodePool{instance_count: 10, data: %{"foo" => "bar"}}}
  """
  @spec size(t, Tesla.Client.t()) :: {:ok, t} | {:error, Tesla.Env.t()}
  def size(%Ballast.NodePool{} = pool, conn) do
    case @adapter.size(pool, conn) do
      {:ok, count} ->
        {:ok, %NodePool{pool | instance_count: count}}

      error ->
        error
    end
  end

  @spec autoscaling_enabled?(Ballast.NodePool.t()) :: boolean()
  def autoscaling_enabled?(pool), do: @adapter.autoscaling_enabled?(pool)
end
