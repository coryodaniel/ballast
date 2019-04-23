defmodule Ballast.NodePool.Adapters.Mock do
  @behaviour Ballast.NodePool.Adapters
  @list_json "test/support/node_pool_list.json"

  alias Ballast.NodePool

  @impl Ballast.NodePool.Adapters
  def list(_conn, %NodePool{}) do
    pools =
      @list_json
      |> File.read!()
      |> Jason.decode!(keys: :atoms)
      |> Map.get(:nodePools)

    {:ok, pools}
  end

  @impl Ballast.NodePool.Adapters
  def get(_conn, %NodePool{}) do
    pool =
      @list_json
      |> File.read!()
      |> Jason.decode!(keys: :atoms)
      |> Map.get(:nodePools)
      |> List.last()

    {:ok, pool}
  end

  @impl Ballast.NodePool.Adapters
  def size(_, _), do: {:ok, 3}
end
