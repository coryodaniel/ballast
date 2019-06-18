defmodule Ballast.PoolPolicy.ManagedPoolTest do
  @moduledoc false
  use ExUnit.Case, async: true
  doctest Ballast.PoolPolicy.ManagedPool
  alias Ballast.PoolPolicy.ManagedPool

  describe "new/3" do
    test "gets pool data" do
      spec = %{
        "minimumPercent" => "30",
        "minimumInstances" => "2",
        "poolName" => "managed-pool",
        "location" => "us-central1-a"
      }

      {:ok, target} = ManagedPool.new(spec, "my-project", "my-cluster")
      assert %Ballast.NodePool{} = target.pool
    end

    test "formats minimum_percent" do
      spec = %{
        "minimumPercent" => "30",
        "minimumInstances" => "2",
        "poolName" => "managed-pool",
        "location" => "us-central1-a"
      }

      {:ok, target} = ManagedPool.new(spec, "my-project", "my-cluster")
      assert target.minimum_percent == 30
    end

    test "formats minimum_instances" do
      spec = %{
        "minimumPercent" => "30",
        "minimumInstances" => "2",
        "poolName" => "managed-pool",
        "location" => "us-central1-a"
      }

      {:ok, target} = ManagedPool.new(spec, "my-project", "my-cluster")
      assert target.minimum_instances == 2
    end

    test "returns nil when the pool cannot be found" do
      spec = %{
        "poolName" => "invalid-pool",
        "minimumPercent" => "30",
        "minimumInstances" => "2",
        "location" => "us-central1-a"
      }

      assert {:error, pool_not_found} = ManagedPool.new(spec, "my-project", "my-cluster")
    end
  end
end
