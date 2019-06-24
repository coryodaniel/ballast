# credo:disable-for-this-file
defmodule Ballast.NodePool.Adapters.Mock do
  @moduledoc false

  @behaviour Ballast.NodePool.Adapters
  @list_json "test/support/node_pool_list.json"

  alias Ballast.NodePool

  @impl true
  def label_selector(), do: ""

  @impl true
  def label_selector(_), do: ""

  @impl true
  def id(%NodePool{} = pool) do
    "#{pool.project}/#{pool.location}/#{pool.cluster}/#{pool.name}"
  end

  @impl true
  def get(%NodePool{name: "invalid-pool"}, _conn) do
    {:error, %Tesla.Env{status: 403}}
  end

  @impl true
  def get(%NodePool{name: "pool-without-autoscaling"}, _conn) do
    {:ok, pool} = get(nil, nil)
    pool_without_autoscaling = Map.delete(pool, :autoscaling)
    {:ok, pool_without_autoscaling}
  end

  @impl true
  def get(pool, _conn) do
    data =
      @list_json
      |> File.read!()
      |> Jason.decode!(keys: :atoms)
      |> Map.get(:nodePools)
      |> List.last()

    pool = %NodePool{pool | instance_count: 10, data: data}

    {:ok, pool}
  end

  @impl true
  def scale(_, _), do: {:ok, %{}}

  @impl true
  def autoscaling_enabled?(_), do: true
end
