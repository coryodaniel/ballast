defmodule Ballast.NodePool.Adapters.GKE do
  @moduledoc """
  GKE `Ballast.NodePool` implementation.
  """
  @behaviour Ballast.NodePool.Adapters

  @instance_group_manager_pattern ~r{projects/(?<project>[^/]+)/zones/(?<zone>[^/]+)/instanceGroupManagers/(?<name>[^/]+)}

  alias GoogleApi.Container.V1.Api.Projects, as: Container
  alias GoogleApi.Compute.V1.Api.InstanceGroups

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
      error -> error
    end
  end

  @impl Ballast.NodePool.Adapters
  def scale(%Ballast.PoolPolicy.Changeset{} = changeset, conn) do
    case autoscaling_enabled?(changeset.pool) do
      true -> set_autoscaling(changeset.pool, changeset.minimum_count, conn)
      false -> set_size(changeset.pool, changeset.minimum_count, conn)
    end
  end


  defp set_autoscaling(pool, minimum_count, conn) do
    id = Ballast.NodePool.id(pool)
    old_autoscaling = pool.data.autoscaling
    new_autoscaling = Map.put(old_autoscaling, :minNodeCount, minimum_count)

    # conn needs to be passed in like the other functions @@
    # conn, name, [body: ]
    # body =  %GoogleApi.Container.V1.Model.SetNodePoolAutoscalingRequest{
    #   autoscaling: %GoogleApi.Container.V1.Model.NodePoolAutoscaling{
    #     enabled: any(),
    #     maxNodeCount: any(),
    #     minNodeCount: any()
    #   },
    #   #name: any()
    # }

    body = %{autoscaling: new_autoscaling}
    opts = [body: body]
    resp = Container.container_projects_locations_clusters_node_pools_set_autoscaling(conn, id, opts)
    IO.puts "Resp: #{inspect(resp)}"

    IO.puts "Would autoscaling"
    :ok
  end

  defp set_size(pool, minimum_count, conn) do
    # conn, name, [body: ]
    # body = %GoogleApi.Container.V1.Model.SetNodePoolSizeRequest{
    #   name: any(),
    #   nodeCount: any(),
    # }

    # Container.container_projects_locations_clusters_node_pools_set_size/N
    IO.puts "Would size"
    :ok
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

  @impl Ballast.NodePool.Adapters
  def autoscaling_enabled?(%Ballast.NodePool{data: %{autoscaling: %{enabled: true}}}), do: true
  def autoscaling_enabled?(_), do: false

  defp validate_instance_group_manager_params(%{"project" => p, "zone" => z, "name" => n}), do: {:ok, p, z, n}
  defp validate_instance_group_manager_params(_), do: {:error, :invalid_instance_group_url}
end
