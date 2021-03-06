defmodule Ballast.PoolPolicyTest do
  @moduledoc false
  use ExUnit.Case, async: true
  doctest Ballast.PoolPolicy
  alias Ballast.{NodePool, PoolPolicy}

  describe "from_resource/1" do
    test "parses a valid resource" do
      resource = make_resource()
      {:ok, policy} = PoolPolicy.from_resource(resource)

      expected = %PoolPolicy{
        cooldown_seconds: 60,
        name: "example-policy",
        pool: %NodePool{
          instance_count: 10,
          cluster: "my-cluster",
          project: "my-project",
          location: "my-source-region-or-zone",
          name: "my-source-pool",
          under_pressure: false,
          data: mock_data_response()
        },
        changesets: [],
        managed_pools: [
          %PoolPolicy.ManagedPool{
            pool: %NodePool{
              instance_count: 10,
              cluster: "my-cluster",
              project: "my-project",
              location: "my-managed-pool-region-or-zone",
              name: "my-managed-pool",
              data: mock_data_response()
            },
            minimum_percent: 30,
            minimum_instances: 1
          }
        ]
      }

      assert policy == expected
    end

    test "returns an error when it fails to GET the node pool" do
      resource = make_resource("invalid-pool")

      assert {:error, _} = PoolPolicy.from_resource(resource)
    end
  end

  @spec make_resource() :: map()
  defp make_resource() do
    YamlElixir.read_from_file!("test/support/resource.yaml")
  end

  @spec make_resource() :: map()
  defp make_resource(source_pool_name) do
    make_resource()
    |> put_in(["spec", "poolName"], source_pool_name)
  end

  @spec mock_data_response() :: map()
  def mock_data_response() do
    %{
      autoscaling: %{enabled: true, maxNodeCount: 5, minNodeCount: 3},
      initialNodeCount: 1,
      instanceGroupUrls: [
        "https://www.googleapis.com/compute/v1/projects/my-project/zones/us-central1-a/instanceGroupManagers/gke-demo-demo-preemptible"
      ],
      name: "demo-preemptible",
      selfLink:
        "https://container.googleapis.com/v1/projects/my-project/zones/us-central1-a/clusters/demo/nodePools/demo-preemptible",
      status: "RUNNING"
    }
  end
end
