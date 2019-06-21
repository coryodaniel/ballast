defmodule Ballast.PoolPolicy.ManagedPool do
  @moduledoc """
  A managed pool
  """
  alias Ballast.NodePool

  defstruct [:pool, :minimum_instances, :minimum_percent]

  @type t :: %__MODULE__{
          pool: NodePool.t(),
          minimum_percent: pos_integer,
          minimum_instances: pos_integer
        }

  @doc """
  Parse resource `managed_pool` spec and annotate with `NodePool` data from API.
  """
  @spec new(map(), binary(), binary()) :: {:ok, t()} | {:error, atom}
  def new(managed_pool_spec, project, cluster) do
    %{
      "minimumPercent" => mp,
      "minimumInstances" => mi,
      "poolName" => name,
      "location" => location
    } = managed_pool_spec

    pool = NodePool.new(project, location, cluster, name)

    with {:ok, conn} <- Ballast.conn(), {:ok, pool} <- NodePool.get(pool, conn) do
      {:ok,
       %__MODULE__{
         pool: pool,
         minimum_percent: cast_minimum_percent(mp),
         minimum_instances: cast_minimum_instances(mi)
       }}
    else
      {:error, _} ->
        {:error, :pool_not_found}
    end
  end

  @spec cast_minimum_percent(String.t() | pos_integer) :: pos_integer
  defp cast_minimum_percent(mp) when is_integer(mp), do: mp
  defp cast_minimum_percent(mp) when is_binary(mp), do: String.to_integer(mp)
  defp cast_minimum_percent(_), do: Ballast.Config.default_minimum_percent()

  @spec cast_minimum_instances(String.t() | pos_integer) :: pos_integer
  defp cast_minimum_instances(mi) when is_integer(mi), do: mi
  defp cast_minimum_instances(mi) when is_binary(mi), do: String.to_integer(mi)
  defp cast_minimum_instances(_), do: Ballast.Config.default_minimum_instances()
end
