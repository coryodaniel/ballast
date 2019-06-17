defmodule Ballast.NodePool.Adapters.Mock do
  @moduledoc false

  @behaviour Ballast.NodePool.Adapters
  @list_json "test/support/node_pool_list.json"

  alias Ballast.NodePool

  @impl Ballast.NodePool.Adapters

  def get(%NodePool{name: "invalid-pool"}, _conn) do
    {:error, %Tesla.Env{status: 403}}
  end

  def get(%NodePool{name: "pool-without-autoscaling"}, _conn) do
    {:ok, pool} = get(nil, nil)
    pool_without_autoscaling = Map.delete(pool, :autoscaling)
    {:ok, pool_without_autoscaling}
  end

  def get(_pool, _conn) do
    pool =
      @list_json
      |> File.read!()
      |> Jason.decode!(keys: :atoms)
      |> Map.get(:nodePools)
      |> List.last()

    {:ok, pool}
  end

  @impl Ballast.NodePool.Adapters
  def scale(_, _), do: {:ok, %{}}

  @impl Ballast.NodePool.Adapters
  def size(%NodePool{name: "invalid-pool"}, _conn) do
    {:error, %Tesla.Env{status: 403}}
  end

  def size(_, _), do: {:ok, 10}

  @impl Ballast.NodePool.Adapters
  def autoscaling_enabled?(_), do: true
end
