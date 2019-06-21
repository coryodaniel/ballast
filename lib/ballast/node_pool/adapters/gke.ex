defmodule Ballast.NodePool.Adapters.GKE do
  @moduledoc """
  GKE `Ballast.NodePool` implementation.

  Note: `@spec`s are added to `@impl` here because credo has an [open proposal](https://github.com/rrrene/credo/issues/427) to solve the issue.
  """
  @behaviour Ballast.NodePool.Adapters
  @instance_group_manager_pattern ~r{projects/(?<project>[^/]+)/zones/(?<zone>[^/]+)/instanceGroupManagers/(?<name>[^/]+)}

  alias Ballast.NodePool
  alias GoogleApi.Container.V1.Api.Projects, as: Container
  alias GoogleApi.Compute.V1.Api.InstanceGroups

  @impl true
  @spec label_selector() :: binary
  @doc """
  Returns the label selector to get all GKE nodes in the cluster.

  ## Example
    iex> Ballast.NodePool.Adapters.GKE.label_selector()
    "cloud.google.com/gke-nodepool"
  """
  def label_selector() do
    "cloud.google.com/gke-nodepool"
  end

  @impl true
  @spec label_selector(Ballast.NodePool.t()) :: binary
  @doc """
  Returns the label selector to get all the given pool's nodes in the cluster.

  ## Example
    NodePool without response data
      iex> pool = Ballast.NodePool.new("foo", "bar", "baz", "qux")
      ...> Ballast.NodePool.Adapters.GKE.label_selector(pool)
      "cloud.google.com/gke-nodepool=qux"
  """
  def label_selector(%NodePool{name: name}) do
    "#{label_selector()}=#{name}"
  end

  @impl true
  @spec get(Ballast.NodePool.t(), Tesla.Client.t()) :: {:ok, Ballast.NodePool.t()} | {:error, Tesla.Env.t()}
  def get(%NodePool{} = pool, conn) do
    %NodePool{project: project, location: zone, cluster: cluster, name: name} = pool
    Container.container_projects_zones_clusters_node_pools_get(conn, project, zone, cluster, name)
  end

  @impl true
  @spec size(Ballast.NodePool.t(), Tesla.Client.t()) :: {:ok, integer} | {:error, Tesla.Env.t()} | {:error, atom}
  def size(%NodePool{data: %{instanceGroupUrls: urls}}, conn) do
    url = List.first(urls)

    with {:ok, project, zone, name} <- parse_instance_group_manager_params(url),
         {:ok, %{size: size}} <- InstanceGroups.compute_instance_groups_get(conn, project, zone, name) do
      {:ok, size}
    end
  end

  @impl true
  @spec scale(Ballast.PoolPolicy.Changeset.t(), Tesla.Client.t()) :: {:ok, map} | {:error, Tesla.Env.t()}
  def scale(%Ballast.PoolPolicy.Changeset{} = changeset, conn) do
    case autoscaling_enabled?(changeset.pool) do
      true -> set_autoscaling(changeset.pool, changeset.minimum_count, conn)
      false -> set_size(changeset.pool, changeset.minimum_count, conn)
    end
  end

  @doc """
  Generates the URL identifier for the GKE API

  ## Example
    NodePool without response data
      iex> pool = Ballast.NodePool.new("foo", "bar", "baz", "qux")
      ...> Ballast.NodePool.Adapters.GKE.id(pool)
      "projects/foo/locations/bar/clusters/baz/nodePools/qux"
  """
  @impl true
  @spec id(Ballast.NodePool.t()) :: String.t()
  def id(%NodePool{} = pool) do
    "projects/#{pool.project}/locations/#{pool.location}/clusters/#{pool.cluster}/nodePools/#{pool.name}"
  end

  @spec set_autoscaling(Ballast.NodePool.t(), pos_integer, Tesla.Client.t()) :: :ok | {:error, Tesla.Env.t()}
  defp set_autoscaling(pool, minimum_count, conn) do
    id = id(pool)
    old_autoscaling = pool.data.autoscaling
    new_autoscaling = Map.put(old_autoscaling, :minNodeCount, minimum_count)

    body = %{autoscaling: new_autoscaling}

    Container.container_projects_locations_clusters_node_pools_set_autoscaling(conn, id, body: body)
  end

  @spec set_size(Ballast.NodePool.t(), pos_integer, Tesla.Client.t()) :: :ok | {:error, Tesla.Env.t()}
  defp set_size(pool, minimum_count, conn) do
    id = id(pool)
    body = %{nodeCount: minimum_count}

    Container.container_projects_locations_clusters_node_pools_set_size(conn, id, body: body)
  end

  @doc """
  Parses a Google API `instanceGroupUrl` into arguments for `GoogleApi.Compute.V1.Api.InstanceGroups`.

  *Note:* The URL expected is for `instanceGroupManagers`, but `instanceGroups` use the same ID and provide a `size` response.

  ## Examples
      iex> Ballast.NodePool.Adapters.GKE.parse_instance_group_manager_params("/projects/my-project/zones/my-zone/instanceGroupManagers/my-igm")
      {:ok, "my-project", "my-zone", "my-igm"}

      iex> Ballast.NodePool.Adapters.GKE.parse_instance_group_manager_params("projects/zones/instanceGroupManagers")
      {:error, :invalid_instance_group_url}
  """
  @spec parse_instance_group_manager_params(String.t()) :: {:ok, String.t(), String.t(), String.t()} | {:error, atom}
  def parse_instance_group_manager_params(url) do
    @instance_group_manager_pattern
    |> Regex.named_captures(url)
    |> validate_instance_group_manager_params
  end

  @impl Ballast.NodePool.Adapters
  @spec autoscaling_enabled?(Ballast.NodePool.t()) :: boolean()
  def autoscaling_enabled?(%NodePool{data: %{autoscaling: %{enabled: true}}}), do: true
  def autoscaling_enabled?(_), do: false

  @spec validate_instance_group_manager_params(map) ::
          {:ok, binary, binary, binary} | {:error, :invalid_instance_group_url}
  defp validate_instance_group_manager_params(%{"project" => p, "zone" => z, "name" => n}), do: {:ok, p, z, n}
  defp validate_instance_group_manager_params(_), do: {:error, :invalid_instance_group_url}
end
