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
        changeset: %{},
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
            minimum_instances: 3
          }
        ]
      }

      assert policy == expected
    end
  end

  defp make_resource() do
    YamlElixir.read_from_file!("test/support/resource.yaml")
  end
end
