defmodule Ballast.NodePool.Adapters.GKETest do
  use ExUnit.Case, async: true
  alias Ballast.NodePool.Adapters.GKE
  alias Ballast.NodePool

  @integration_config "test/support/integration_config.yaml"

  defp config() do
    conf = YamlElixir.read_from_file!(@integration_config)

    %{
      "cluster" => cluster,
      "location" => location,
      "pool" => pool,
      "project" => project
    } = conf["gke"]

    {project, location, cluster, pool}
  end

  describe "list/2" do
    test "returns a list of node pools" do
      {:ok, conn} = Ballast.conn()
      {project, location, cluster, _} = config()
      node_pool = NodePool.new(project, location, cluster)

      {:ok, response} = GKE.list(conn, node_pool)
      pool = List.first(response)

      assert match?(%{autoscaling: _, instanceGroupUrls: _, name: _}, pool)
    end
  end

  describe "get/2" do
    test "returns a node pool" do
      {:ok, conn} = Ballast.conn()
      {project, location, cluster, pool} = config()
      node_pool = NodePool.new(project, location, cluster, pool)

      {:ok, response} = GKE.get(conn, node_pool)

      assert match?(%{autoscaling: _, instanceGroupUrls: _, name: _}, response)
    end
  end

  describe "size/2" do
    test "sets current size to a NodePool with data" do
      {:ok, conn} = Ballast.conn()
      {project, location, cluster, pool} = config()
      node_pool = NodePool.new(project, location, cluster, pool)
      {:ok, response} = GKE.get(conn, node_pool)

      node_pool = %NodePool{data: response}
      {:ok, size} = GKE.size(conn, node_pool)

      assert is_integer(size)
    end
  end
end
