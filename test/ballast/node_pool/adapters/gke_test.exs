defmodule Ballast.NodePool.Adapters.GKETest do
  use ExUnit.Case, async: true
  alias Ballast.NodePool.Adapters.GKE
  alias Ballast.NodePool
  doctest Ballast.NodePool.Adapters.GKE

  @moduletag :external

  defp config() do
    gcp_project = System.get_env("GCP_PROJECT")
    {gcp_project, "us-central1", "ballast", "ballast-pvm-n1-1"}
  end

  describe "autoscaling_enabled?/1" do
    test "returns false when disabled" do
      pool = %NodePool{
        data: %{
          autoscaling: %{enabled: false}
        }
      }

      refute GKE.autoscaling_enabled?(pool)
    end

    test "returns true when enabled" do
      pool = %NodePool{
        data: %{
          autoscaling: %{enabled: true}
        }
      }

      assert GKE.autoscaling_enabled?(pool)
    end
  end

  describe "scale/1" do
    test "when autoscaling is disabled" do
      {:ok, conn} = Ballast.conn()
      {project, location, cluster, _} = config()
      pool = "ballast-pvm-n1-2"

      data = %{}
      node_pool = NodePool.new(project, location, cluster, pool, data)

      managed_pool = %Ballast.PoolPolicy.ManagedPool{pool: node_pool, minimum_percent: 10, minimum_instances: 1}
      source_pool = %Ballast.NodePool{instance_count: 10}
      changeset = Ballast.PoolPolicy.Changeset.new(managed_pool, source_pool)

      refute GKE.autoscaling_enabled?(changeset.pool)
      assert {:ok, _} = GKE.scale(changeset, conn)
    end

    test "when autoscaling is enabled" do
      {:ok, conn} = Ballast.conn()
      {project, location, cluster, pool} = config()

      data = %{autoscaling: %{enabled: true, maxNodeCount: 3}}
      node_pool = NodePool.new(project, location, cluster, pool, data)

      managed_pool = %Ballast.PoolPolicy.ManagedPool{pool: node_pool, minimum_percent: 10, minimum_instances: 1}
      source_pool = %Ballast.NodePool{instance_count: 10}
      changeset = Ballast.PoolPolicy.Changeset.new(managed_pool, source_pool)

      assert GKE.autoscaling_enabled?(changeset.pool)
      assert {:ok, _} = GKE.scale(changeset, conn)
    end
  end

  describe "get/2" do
    test "returns a node pool" do
      {:ok, conn} = Ballast.conn()
      {project, location, cluster, pool} = config()
      node_pool = NodePool.new(project, location, cluster, pool)

      {:ok, response} = GKE.get(node_pool, conn)

      assert %NodePool{} = response
    end

    test "gets the current instance count" do
      {:ok, conn} = Ballast.conn()
      {project, location, cluster, pool} = config()
      node_pool = NodePool.new(project, location, cluster, pool)

      {:ok, response} = GKE.get(node_pool, conn)
      %NodePool{instance_count: instance_count} = response
      assert instance_count
    end

    test "captures the response in `data`" do
      {:ok, conn} = Ballast.conn()
      {project, location, cluster, pool} = config()
      node_pool = NodePool.new(project, location, cluster, pool)

      {:ok, response} = GKE.get(node_pool, conn)
      assert match?(%NodePool{data: %{autoscaling: _, instanceGroupUrls: _, name: _}}, response)
    end
  end
end
