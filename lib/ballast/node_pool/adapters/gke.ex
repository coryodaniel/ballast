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

  # HACK: container_projects_locations_clusters_node_pools_get is in master, but there is a syntax error. 
  # Manually including function here.
  alias GoogleApi.Container.V1.Connection
  alias GoogleApi.Gax.{Request, Response}

  @impl true
  @spec label_selector() :: binary
  @doc """
  Returns the label selector to get all GKE nodes in the cluster.

  ## Example
    iex> Ballast.NodePool.Adapters.GKE.label_selector()
    "cloud.google.com/gke-nodepool"
  """
  def label_selector(), do: "cloud.google.com/gke-nodepool"

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

  @impl true
  @spec scale(Ballast.PoolPolicy.Changeset.t(), Tesla.Client.t()) :: {:ok, map} | {:error, Tesla.Env.t()}
  def scale(%Ballast.PoolPolicy.Changeset{} = changeset, conn) do
    case autoscaling_enabled?(changeset.pool) do
      true -> set_autoscaling(changeset.pool, changeset.minimum_count, conn)
      false -> set_size(changeset.pool, changeset.minimum_count, conn)
    end
  end

  @impl true
  @spec get(Ballast.NodePool.t(), Tesla.Client.t()) :: {:ok, Ballast.NodePool.t()} | {:error, Tesla.Env.t()}
  def get(%NodePool{} = pool, conn) do
    id = id(pool)
    response = container_projects_locations_clusters_node_pools_get(conn, id)

    with {:ok, data} <- response,
         pool_with_data <- %NodePool{pool | data: data},
         minimum_count <- get_minimum_node_count(pool_with_data), 
         instance_count <- get_node_pool_size(pool_with_data, conn) do
      {:ok, %NodePool{pool_with_data | instance_count: instance_count, minimum_count: minimum_count}}
    end
  end
  
  @spec get_node_pool_size(Ballast.NodePool.t(), Tesla.Client.t()) :: integer
  defp get_node_pool_size(%NodePool{data: %{instanceGroupUrls: urls}}, conn) do
    Enum.reduce(urls, 0, fn url, agg -> agg + get_instance_group_size(url, conn) end)
  end

  @spec get_instance_group_size(String.t(), Tesla.Client.t()) :: integer
  defp get_instance_group_size(url, conn) do
    with {:ok, project, zone, name} <- parse_instance_group_manager_params(url),
         {:ok, %{size: size}} <- InstanceGroups.compute_instance_groups_get(conn, project, zone, name) do
      Ballast.Sys.Instrumentation.provider_get_pool_size_succeeded(%{}, %{})
      size
    else
      _ ->
        Ballast.Sys.Instrumentation.provider_get_pool_size_failed(%{}, %{})
        0
    end
  end
  
  @spec get_minimum_node_count(Ballast.NodePool.t()) :: integer | nil
  defp get_minimum_node_count(%NodePool{data: %{autoscaling: %{minNodeCount: minimum_count, enabled: true}}}) do
    minimum_count
  end  
  
  defp get_minimum_node_count(_pool), do: nil
  
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

  # HACK
  @spec container_projects_locations_clusters_node_pools_get(
          Tesla.Client.t(),
          String.t(),
          Keyword.t() | nil,
          Keyword.t() | nil
        ) :: {:ok, %GoogleApi.Container.V1.Model.NodePool{}} | {:error, any()}
  def container_projects_locations_clusters_node_pools_get(
        connection,
        name,
        optional_params \\ [],
        opts \\ []
      ) do
    optional_params_config = %{
      :"$.xgafv" => :query,
      :access_token => :query,
      :alt => :query,
      :callback => :query,
      :fields => :query,
      :key => :query,
      :oauth_token => :query,
      :prettyPrint => :query,
      :quotaUser => :query,
      :uploadType => :query,
      :upload_protocol => :query,
      :clusterId => :query,
      :nodePoolId => :query,
      :projectId => :query,
      :zone => :query
    }

    request =
      Request.new()
      |> Request.method(:get)
      |> Request.url("/v1/{+name}", %{"name" => URI.encode(name, &URI.char_unreserved?/1)})
      |> Request.add_optional_params(optional_params_config, optional_params)

    connection
    |> Connection.execute(request)
    |> Response.decode(opts ++ [struct: %GoogleApi.Container.V1.Model.NodePool{}])
  end
end
