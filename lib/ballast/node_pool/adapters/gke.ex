defmodule Ballast.NodePool.Adapters.GKE do
  @moduledoc """
  GKE `Ballast.NodePool` implementation.
  """
  @behaviour Ballast.NodePool.Adapters

  @instance_group_manager_pattern ~r{projects/(?<project>[^/]+)/zones/(?<zone>[^/]+)/instanceGroupManagers/(?<name>[^/]+)}

  alias GoogleApi.Container.V1.Api.Projects, as: Container
  alias GoogleApi.Compute.V1.Api.InstanceGroups

  @impl Ballast.NodePool.Adapters
  def list(conn, %Ballast.NodePool{project: p, location: l, cluster: c}) do
    parent = "projects/#{p}/locations/#{l}/clusters/#{c}"
    response = Container.container_projects_locations_clusters_node_pools_list(conn, parent)

    case response do
      {:ok, %{nodePools: pools}} -> {:ok, pools}
      error -> error
    end
  end

  @impl Ballast.NodePool.Adapters
  def get(conn, %Ballast.NodePool{} = pool) do
    %Ballast.NodePool{project: project, location: zone, cluster: cluster, name: name} = pool
    Container.container_projects_zones_clusters_node_pools_get(conn, project, zone, cluster, name)
  end

  @impl Ballast.NodePool.Adapters
  def size(conn, %Ballast.NodePool{data: %{instanceGroupUrls: urls}}) do
    url = List.first(urls)

    with {:ok, project, zone, name} <- parse_instance_group_manager_params(url),
         {:ok, %{size: size}} <- InstanceGroups.compute_instance_groups_get(conn, project, zone, name) do
      {:ok, size}
    else
      error -> error
    end
  end

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

  defp validate_instance_group_manager_params(%{"project" => p, "zone" => z, "name" => n}), do: {:ok, p, z, n}
  defp validate_instance_group_manager_params(_), do: {:error, :invalid_instance_group_url}
end
