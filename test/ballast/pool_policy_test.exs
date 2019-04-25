defmodule Ballast.PoolPolicyTest do
  @moduledoc false
  use ExUnit.Case, async: true
  alias Ballast.PoolPolicy
  doctest Ballast.PoolPolicy

  describe "from_resource/1" do
    test "parses a valid resource" do
      resource = make_resource()
      policy = PoolPolicy.from_resource(resource)

      expected = %Ballast.PoolPolicy{
        pool: %Ballast.NodePool{
          cluster: "my-cluster",
          project: "my-project",
          location: "my-source-region-or-zone",
          name: "my-source-pool",
          data: %{}
        },
        changesets: [],
        targets: [
          %{
            pool: %Ballast.NodePool{
              cluster: "my-cluster",
              project: "my-project",
              location: "my-target-region-or-zone",
              name: "my-target-pool",
              data: %{}
            },
            target_capacity_percent: 30,
            minimum_instances: 1
          }
        ]
      }

      assert policy == expected
    end
  end

  describe "changesets/1" do
    test "gets the size of the source pool and calculates target pool counts" do
      policy_with_changesets =
        make_resource()
        |> PoolPolicy.from_resource()
        |> PoolPolicy.changesets()

      %PoolPolicy{changesets: changesets} = policy_with_changesets

      changeset = %{
        # This is a mystery guest.
        # The NodePoolMock adapter returns a current count of 10
        # `make_resource` below is creating a 30% target capacity
        minimum_count: 3,
        pool: %Ballast.NodePool{
          cluster: "my-cluster",
          project: "my-project",
          location: "my-target-region-or-zone",
          name: "my-target-pool",
          data: %{}
        }
      }

      expected = [changeset]
      assert changesets == expected
    end
  end

  defp make_resource() do
    YamlElixir.read_from_file!("test/support/resource.yaml")
  end
end
