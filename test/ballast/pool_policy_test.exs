defmodule Ballast.PoolPolicyTest do
  @moduledoc false
  use ExUnit.Case, async: true
  doctest Ballast.PoolPolicy

  alias Ballast.{NodePool, PoolPolicy}
  import ExUnit.CaptureLog

  describe "apply/1" do
    test "applies each target against it" do
    end
  end

  describe "from_resource/1" do
    test "parses a valid resource" do
      resource = make_resource()
      {:ok, policy} = PoolPolicy.from_resource(resource)

      expected = %PoolPolicy{
        pool: %NodePool{
          cluster: "my-cluster",
          project: "my-project",
          location: "my-source-region-or-zone",
          name: "my-source-pool",
          data: mock_data_response()
        },
        changesets: [],
        targets: [
          %PoolPolicy.Target{
            pool: %NodePool{
              cluster: "my-cluster",
              project: "my-project",
              location: "my-target-region-or-zone",
              name: "my-target-pool",
              data: mock_data_response()
            },
            target_capacity_percent: 30,
            minimum_instances: 1,
            autoscaling_enabled: true
          }
        ]
      }

      assert policy == expected
    end

    test "returns an error when it fails to GET the node pool" do
      resource = make_resource("invalid-pool")

      capture_log(fn ->
        assert {:error, _} = PoolPolicy.from_resource(resource)
      end)
    end
  end

  describe "changesets/1" do
    test "gets the size of the source pool and calculates target pool counts" do
      {:ok, policy} = PoolPolicy.from_resource(make_resource())

      {:ok, policy_with_changesets} = PoolPolicy.changesets(policy)

      %PoolPolicy{changesets: changesets} = policy_with_changesets

      changeset = %PoolPolicy.Changeset{
        # This is a mystery guest.
        # The NodePoolMock adapter returns a current count of 10
        # `make_resource` below is creating a 30% target capacity
        minimum_count: 3,
        pool: %NodePool{
          cluster: "my-cluster",
          project: "my-project",
          location: "my-target-region-or-zone",
          name: "my-target-pool",
          data: mock_data_response()
        }
      }

      expected = [changeset]
      assert changesets == expected
    end

    test "returns an error when it fails to get the node pool size" do
      resource = make_resource("invalid-pool")
      pool = NodePool.new(resource)
      policy = %PoolPolicy{pool: pool}

      capture_log(fn ->
        assert {:error, _} = PoolPolicy.changesets(policy)
      end)
    end
  end

  defp make_resource() do
    YamlElixir.read_from_file!("test/support/resource.yaml")
  end

  defp make_resource(source_pool_name) do
    make_resource()
    |> put_in(["spec", "poolName"], source_pool_name)
  end

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
