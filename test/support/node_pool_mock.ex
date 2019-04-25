defmodule Ballast.NodePool.Adapters.Mock do
  @moduledoc false

  @behaviour Ballast.NodePool.Adapters
  @list_json "test/support/node_pool_list.json"

  alias Ballast.NodePool

  @impl Ballast.NodePool.Adapters
  def get(%NodePool{}, _conn) do
    pool =
      @list_json
      |> File.read!()
      |> Jason.decode!(keys: :atoms)
      |> Map.get(:nodePools)
      |> List.last()

    {:ok, pool}
  end

  @impl Ballast.NodePool.Adapters
  def size(_, _), do: {:ok, 10}
end
