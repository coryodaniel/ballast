defmodule Ballast.NodePool.Adapters.GKETest do
  use ExUnit.Case, async: true
  alias Ballast.NodePool.Adapters.GKE
  alias Ballast.NodePool

  @moduletag :external
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
      assert false
      # iex> node_pool = Ballast.NodePool.new("my-proj", "my-loc", "my-cluster", "my-pool")
      # ...> target = %Ballast.PoolPolicy.Target{pool: node_pool, target_capacity_percent: 30, minimum_instances: 1, autoscaling_enabled: false}
      # ...> source_instance_count = 10
      # ...> changeset = Ballast.PoolPolicy.Changeset.new(target, source_instance_count)
      # ...> Ballast.NodePool.scale(changeset)
      #   # Adapter.setSize, setAutoscaling
      #   IO.puts(changeset.minimum_count)
      #   IO.puts("#{inspect(changeset.pool)}")
    end

    test "when autoscaling is enabled" do
      assert false
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
    test "sets current size to a NodePool with data" do
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
