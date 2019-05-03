defmodule Ballast.PoolPolicy.TargetTest do
  @moduledoc false
  use ExUnit.Case, async: true
  doctest Ballast.PoolPolicy.Target
  alias Ballast.PoolPolicy.Target
  import ExUnit.CaptureLog

  describe "new/3" do
    test "gets pool data" do
      spec = %{
        "targetCapacityPercent" => "30",
        "minimumInstances" => "2",
        "poolName" => "target-pool",
        "location" => "us-central1-a"
      }

      target = Target.new(spec, "my-project", "my-cluster")
      assert %Ballast.NodePool{} = target.pool
    end

    test "formats target_capacity_percent" do
      spec = %{
        "targetCapacityPercent" => "30",
        "minimumInstances" => "2",
        "poolName" => "target-pool",
        "location" => "us-central1-a"
      }

      target = Target.new(spec, "my-project", "my-cluster")
      assert target.target_capacity_percent == 30
    end

    test "formats minimum_instances" do
      spec = %{
        "targetCapacityPercent" => "30",
        "minimumInstances" => "2",
        "poolName" => "target-pool",
        "location" => "us-central1-a"
      }

      target = Target.new(spec, "my-project", "my-cluster")
      assert target.minimum_instances == 2
    end

    test "returns nil when the pool cannot be found" do
      spec = %{
        "poolName" => "invalid-pool",
        "targetCapacityPercent" => "30",
        "minimumInstances" => "2",
        "location" => "us-central1-a"
      }

      capture_log(fn ->
        target = Target.new(spec, "my-project", "my-cluster")
        refute target
      end)
    end
  end
end
