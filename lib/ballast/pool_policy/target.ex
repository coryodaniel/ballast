defmodule Ballast.PoolPolicy.Target do
  @moduledoc """
  A target pool
  """
  alias Ballast.NodePool
  require Logger

  defstruct [:pool, :minimum_instances, :target_capacity_percent]

  @type t :: %__MODULE__{
          pool: NodePool.t(),
          target_capacity_percent: pos_integer,
          minimum_instances: pos_integer
        }

  @doc """
  Parse resource `target` spec and annotate with `NodePool` data from API.
  """
  @spec new(map(), binary(), binary()) :: t() | nil
  def new(target_spec, project, cluster) do
    %{
      "targetCapacityPercent" => tp,
      "minimumInstances" => mi,
      "poolName" => name,
      "location" => location
    } = target_spec

    pool = NodePool.new(project, location, cluster, name)

    with {:ok, conn} <- Ballast.conn(), {:ok, pool} <- NodePool.get(pool, conn) do
      %__MODULE__{
        pool: pool,
        target_capacity_percent: cast_target_capacity_percent(tp),
        minimum_instances: cast_minimum_instances(mi)
      }
    else
      {:error, %Tesla.Env{status: status}} ->
        Logger.warn("Skipping misconfigured target #{NodePool.id(pool)}. HTTP Status: #{status}")
        nil
    end
  end

  @spec cast_target_capacity_percent(String.t() | pos_integer) :: pos_integer
  defp cast_target_capacity_percent(tp) when is_integer(tp), do: tp
  defp cast_target_capacity_percent(tp) when is_binary(tp), do: String.to_integer(tp)
  defp cast_target_capacity_percent(_), do: Ballast.default_target_capacity_percent()

  @spec cast_minimum_instances(String.t() | pos_integer) :: pos_integer
  defp cast_minimum_instances(mi) when is_integer(mi), do: mi
  defp cast_minimum_instances(mi) when is_binary(mi), do: String.to_integer(mi)
  defp cast_minimum_instances(_), do: Ballast.default_minimum_instances()
end
