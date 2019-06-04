defmodule Ballast.NodePool.Adapters.GKETest do
  use ExUnit.Case, async: true
  alias Ballast.NodePool.Adapters.GKE
  alias Ballast.NodePool

  @moduletag :external

  defp config() do
    gcp_project = System.get_env("GCP_PROJECT")
    {gcp_project, "us-central1-a", "ballast-demo", "ballast-demo-on-demand-autoscaling"}
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
      pool = "ballast-demo-on-demand-fixed"
      node_pool = NodePool.new(project, location, cluster, pool)

      target = %Ballast.PoolPolicy.Target{pool: node_pool, target_capacity_percent: 10, minimum_instances: 1}
      source_instance_count = 10
      changeset = Ballast.PoolPolicy.Changeset.new(target, source_instance_count)

      refute GKE.autoscaling_enabled?(changeset.pool)
      assert :ok = GKE.scale(changeset, conn)
    end

    test "when autoscaling is enabled" do
      {:ok, conn} = Ballast.conn()
      {project, location, cluster, pool} = config()

      data = %{autoscaling: %{enabled: true, maxNodeCount: 3}}
      node_pool = NodePool.new(project, location, cluster, pool, data)

      target = %Ballast.PoolPolicy.Target{pool: node_pool, target_capacity_percent: 10, minimum_instances: 1}
      source_instance_count = 10
      changeset = Ballast.PoolPolicy.Changeset.new(target, source_instance_count)

      assert GKE.autoscaling_enabled?(changeset.pool)
      assert :ok = GKE.scale(changeset, conn)
    end
  end

  describe "get/2" do
    test "returns a node pool" do
      {:ok, conn} = Ballast.conn()
      {project, location, cluster, pool} = config()
      node_pool = NodePool.new(project, location, cluster, pool)

      {:ok, response} = GKE.get(node_pool, conn)

      assert match?(%{autoscaling: _, instanceGroupUrls: _, name: _}, response)
    end
  end

  describe "size/2" do
    test "gets the current size of a NodePool" do
      {:ok, conn} = Ballast.conn()
      {project, location, cluster, pool} = config()
      node_pool = NodePool.new(project, location, cluster, pool)
      {:ok, response} = GKE.get(node_pool, conn)

      node_pool = %NodePool{data: response}
      {:ok, size} = GKE.size(node_pool, conn)

      assert is_integer(size)
    end
  end
end
