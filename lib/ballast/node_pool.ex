defmodule Ballast.NodePool do
  @moduledoc """
  Interface for interacting with Kubernetes NodePools.
  """

  @adapter Application.get_env(:ballast, :node_pool_adapter, Ballast.NodePool.Adapters.GKE)
  alias Ballast.NodePool

  defstruct [:cluster, :instance_count, :project, :location, :name, :data]

  @typedoc "Node pool metadata"
  @type t :: %NodePool{
          cluster: String.t(),
          project: String.t(),
          location: String.t(),
          instance_count: integer | nil,
          name: String.t() | nil,
          data: map | nil
        }

  @doc """
  Creates a `Ballast.NodePool` struct from a CRD resource's `spec` attribute

  ## Example
      iex> resource = %{"spec" => %{"clusterName" => "foo", "projectId" => "bar", "location" => "baz", "poolName" => "qux"}}
      ...> Ballast.NodePool.new(resource)
      %Ballast.NodePool{cluster: "foo", project: "bar", location: "baz", name: "qux", data: %{}}
  """
  @spec new(map) :: NodePool.t()
  def new(%{"spec" => spec}), do: NodePool.new(spec)

  def new(%{"projectId" => p, "location" => l, "clusterName" => c, "poolName" => n}), do: new(p, l, c, n)

  def new(_invalid), do: %__MODULE__{}

  @doc """
  Creates an unnamed `Ballast.NodePool` struct. Useful in `list` requests

  ## Example
    iex> Ballast.NodePool.new("project", "location", "cluster")
    %Ballast.NodePool{cluster: "cluster", project: "project", location: "location", name: nil, data: nil}

  """
  @spec new(String.t(), String.t(), String.t()) :: NodePool.t()
  def new(project, location, cluster),
    do: %NodePool{cluster: cluster, project: project, location: location}

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
  @spec new(String.t(), String.t(), String.t(), String.t(), map | nil) :: Ballast.NodePool.t()
  def new(project, location, cluster, name, data \\ %{}),
    do: %NodePool{cluster: cluster, project: project, location: location, name: name, data: data}

  @doc """
  Gets a list of node pools.

  *Note:* Argument 2 is an "unidentified" `NodePool` as it does not contain the pool name. This is used
  by `list/2` to query the project/location/cluster.

  ## Example
      iex> node_pool = Ballast.NodePool.new("my-project", "us-central1-a", "my-cluster")
      iex> Ballast.NodePool.list(Ballast.conn(), node_pool)
      {:ok, [%Ballast.NodePool{cluster: "my-cluster", data: %{autoscaling: nil, initialNodeCount: 1, instanceGroupUrls: ["https://www.googleapis.com/compute/v1/projects/my-project/zones/us-central1-a/instanceGroupManagers/gke-demo-demo-on-demand"], name: "demo-on-demand", selfLink: "https://container.googleapis.com/v1/projects/my-project/zones/us-central1-a/clusters/demo/nodePools/demo-on-demand", status: "RUNNING"}, location: "us-central1-a", name: "demo-on-demand", project: "my-project"}, %Ballast.NodePool{cluster: "my-cluster", data: %{autoscaling: %{enabled: true, maxNodeCount: 5, minNodeCount: 3}, initialNodeCount: 1, instanceGroupUrls: ["https://www.googleapis.com/compute/v1/projects/my-project/zones/us-central1-a/instanceGroupManagers/gke-demo-demo-preemptible"], name: "demo-preemptible", selfLink: "https://container.googleapis.com/v1/projects/my-project/zones/us-central1-a/clusters/demo/nodePools/demo-preemptible", status: "RUNNING"}, location: "us-central1-a", name: "demo-preemptible", project: "my-project"}]}
  """
  @spec list(Tesla.Client.t(), NodePool.t()) :: {:ok, list(NodePool.t())} | {:error, Tesla.Env.t()}
  def list(conn, query) do
    case @adapter.list(conn, query) do
      {:error, error} ->
        {:error, error}

      {:ok, response} ->
        node_pools =
          Enum.map(response, fn pool ->
            from_response(query.project, query.location, query.cluster, pool)
          end)

        {:ok, node_pools}
    end
  end

  @doc """
  Gets a node pool.

  ## Example
      iex> node_pool = Ballast.NodePool.new("my-project", "us-central1-a", "my-cluster", "my-pool")
      iex> Ballast.NodePool.get(Ballast.conn(), node_pool)
      {:ok, %Ballast.NodePool{cluster: "my-cluster", location: "us-central1-a", name: "my-pool", project: "my-project", data: %{autoscaling: %{enabled: true, maxNodeCount: 5, minNodeCount: 3}, instanceGroupUrls: ["https://www.googleapis.com/compute/v1/projects/my-project/zones/us-central1-a/instanceGroupManagers/gke-demo-demo-preemptible"], name: "demo-preemptible", selfLink: "https://container.googleapis.com/v1/projects/my-project/zones/us-central1-a/clusters/demo/nodePools/demo-preemptible", status: "RUNNING", initialNodeCount: 1}}}
  """
  @spec get(Tesla.Client.t(), NodePool.t()) :: {:ok, NodePool.t()} | {:error, Tesla.Env.t()}
  def get(conn, pool) do
    case @adapter.get(conn, pool) do
      {:error, error} ->
        {:error, error}

      {:ok, response} ->
        node_pool = %NodePool{pool | data: response}
        {:ok, node_pool}
    end
  end

  @doc false
  @spec from_response(String.t(), String.t(), String.t(), map()) :: NodePool.t()
  def from_response(project, location, cluster, %{name: name} = response) do
    NodePool.new(project, location, cluster, name, response)
  end

  @doc """
  Returns the size of a pool by checking `size` from the pool's `InstanceGroupManager`

  ## Examples
    Returns the size when the pool exists
      iex> pool = %Ballast.NodePool{data: %{"foo" => "bar"}}
      ...> Ballast.NodePool.size(Ballast.conn, pool)
      {:ok, %Ballast.NodePool{instance_count: 10, data: %{"foo" => "bar"}}}
  """
  @spec size(Tesla.Client.t(), NodePool.t()) :: {:ok, NodePool.t()} | {:error, Tesla.Env.t()}
  def size(conn, %Ballast.NodePool{} = pool) do
    case @adapter.size(conn, pool) do
      {:error, error} ->
        {:error, error}

      {:ok, count} ->
        {:ok, %NodePool{pool | instance_count: count}}
    end
  end
end
