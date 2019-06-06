defmodule Ballast.NodePool.Adapters.GKE do
  @moduledoc """
  GKE `Ballast.NodePool` implementation.
  """
  @behaviour Ballast.NodePool.Adapters

  @instance_group_manager_pattern ~r{projects/(?<project>[^/]+)/zones/(?<zone>[^/]+)/instanceGroupManagers/(?<name>[^/]+)}

  alias GoogleApi.Container.V1.Api.Projects, as: Container
  alias GoogleApi.Compute.V1.Api.InstanceGroups
  require Logger

  @impl Ballast.NodePool.Adapters
  def get(%Ballast.NodePool{} = pool, conn) do
    %Ballast.NodePool{project: project, location: zone, cluster: cluster, name: name} = pool
    Container.container_projects_zones_clusters_node_pools_get(conn, project, zone, cluster, name)
  end

  @impl Ballast.NodePool.Adapters
  def size(%Ballast.NodePool{data: %{instanceGroupUrls: urls}}, conn) do
    url = List.first(urls)

    with {:ok, project, zone, name} <- parse_instance_group_manager_params(url),
         {:ok, %{size: size}} <- InstanceGroups.compute_instance_groups_get(conn, project, zone, name) do
      {:ok, size}
    else
      {:error, error} when is_atom(error) ->
        Logger.error("Error getting NodePool size: #{error}")

      {:error, error = %Tesla.Env{}} ->
        Ballast.log_http_error(error)
    end
  end

  @impl Ballast.NodePool.Adapters
  def scale(%Ballast.PoolPolicy.Changeset{} = changeset, conn) do
    Logger.info("Scaling #{changeset.pool.name} to #{changeset.minimum_count}")

    case autoscaling_enabled?(changeset.pool) do
      true -> set_autoscaling(changeset.pool, changeset.minimum_count, conn)
      false -> set_size(changeset.pool, changeset.minimum_count, conn)
    end
  end

  @spec set_autoscaling(Ballast.NodePool.t(), pos_integer, Tesla.Client.t()) :: :ok | {:error, Tesla.Env.t()}
  defp set_autoscaling(pool, minimum_count, conn) do
    id = Ballast.NodePool.id(pool)
    old_autoscaling = pool.data.autoscaling
    new_autoscaling = Map.put(old_autoscaling, :minNodeCount, minimum_count)

    body = %{autoscaling: new_autoscaling}

    conn
    |> Container.container_projects_locations_clusters_node_pools_set_autoscaling(id, body: body)
    |> handle_response()
  end

  @spec set_size(Ballast.NodePool.t(), pos_integer, Tesla.Client.t()) :: :ok | {:error, Tesla.Env.t()}
  defp set_size(pool, minimum_count, conn) do
    id = Ballast.NodePool.id(pool)
    body = %{nodeCount: minimum_count}

    conn
    |> Container.container_projects_locations_clusters_node_pools_set_size(id, body: body)
    |> handle_response
  end

  @spec handle_response({:ok, any} | {:error, any}) :: :ok | {:error, any}
  def handle_response({:ok, _}), do: :ok
  def handle_response({:error, error = %Tesla.Env{}}), do: Ballast.log_http_error(error)

  @doc """
  Parses a Google API `instanceGroupUrl` into arguments for `GoogleApi.Compute.V1.Api.InstanceGroups`.

  *Note:* The URL expected is for `instanceGroupManagers`, but `instanceGroups` use the same ID and provide a `size` response.

  ## Examples
      iex> Ballast.NodePool.parse_instance_group_manager_params("/projects/my-project/zones/my-zone/instanceGroupManagers/my-igm")
      {:ok, "my-project", "my-zone", "my-igm"}

      iex> Ballast.NodePool.parse_instance_group_manager_params("projects/zones/instanceGroupManagers")
      {:error, :invalid_instance_group_url}
  """
  @spec parse_instance_group_manager_params(String.t()) :: {:ok, String.t(), String.t(), String.t()} | {:error, atom}
  def parse_instance_group_manager_params(url) do
    @instance_group_manager_pattern
    |> Regex.named_captures(url)
    |> validate_instance_group_manager_params
  end

  @impl Ballast.NodePool.Adapters
  def autoscaling_enabled?(%Ballast.NodePool{data: %{autoscaling: %{enabled: true}}}), do: true
  def autoscaling_enabled?(_), do: false

  defp validate_instance_group_manager_params(%{"project" => p, "zone" => z, "name" => n}), do: {:ok, p, z, n}
  defp validate_instance_group_manager_params(_), do: {:error, :invalid_instance_group_url}
end
