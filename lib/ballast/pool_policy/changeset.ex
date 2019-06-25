defmodule Ballast.PoolPolicy.Changeset do
  @moduledoc """
  Changes to apply to a managed pool
  """

  alias Ballast.PoolPolicy.{Changeset, ManagedPool}
  alias Ballast.Sys.Instrumentation, as: Inst

  defstruct [:pool, :minimum_count]

  @type t :: %__MODULE__{
          pool: Ballast.NodePool.t(),
          minimum_count: pos_integer
        }

  @doc """
  Creates a new `Changeset` given a `Ballast.PoolPolicy.ManagedPool` and a current source pool instance count.

  ## Examples
      iex> managed_pool = %Ballast.PoolPolicy.ManagedPool{minimum_percent: 30, minimum_instances: 1}
      iex> source_count = 10
      ...> Ballast.PoolPolicy.Changeset.new(managed_pool, source_count)
      %Ballast.PoolPolicy.Changeset{minimum_count: 3}
  """
  @spec new(ManagedPool.t(), integer) :: t
  def new(managed_pool, source_count) do
    new_minimum_count =
      calc_new_minimum_count(source_count, managed_pool.minimum_percent, managed_pool.minimum_instances)

    %Changeset{pool: managed_pool.pool, minimum_count: new_minimum_count}
  end

  @doc """
  Rules:
  * If the source pool has more nodes
    * calculate and scale UP that managed pool's minimum count. `:scale_up`
  * Else; source is lower because its scaling down, or preempted/stockedout
    * If source is under pressure
      * `:nothing` Nothing to do, autoscaler should be adding nodes to source and managed pools
    * Else
      * `:scale_down` calculate and scale DOWN that managed pool's minimum count.

  ## Examples
    When the source pool's instance count is greater
      iex> managed_pool = %Ballast.PoolPolicy.ManagedPool{pool: %Ballast.NodePool{instance_count: 5}}
      ...> source_count = 10
      ...> Ballast.PoolPolicy.Changeset.strategy(managed_pool, source_count, false)
      {:scale, :up}

    When the source pool's instance count is lower and the source pool is under pressure
      iex> managed_pool = %Ballast.PoolPolicy.ManagedPool{pool: %Ballast.NodePool{instance_count: 5}}
      ...> source_count = 1
      ...> Ballast.PoolPolicy.Changeset.strategy(managed_pool, source_count, true)
      :nothing

    When the source pool's instance count is lower and the source pool is not under pressure
      iex> managed_pool = %Ballast.PoolPolicy.ManagedPool{pool: %Ballast.NodePool{instance_count: 5}}
      ...> source_count = 1
      ...> Ballast.PoolPolicy.Changeset.strategy(managed_pool, source_count, false)
      {:scale, :down}
  """
  @spec strategy(ManagedPool.t(), integer, boolean) :: :nothing | {:scale, :up | :down}
  def strategy(%ManagedPool{pool: pool} = managed_pool, source_count, pool_under_pressure) do
    metadata = %{pool: pool.name}

    if source_count >= managed_pool.pool.instance_count do
      Inst.node_pool_scale_up(%{}, metadata)
      {:scale, :up}
    else
      if pool_under_pressure do
        Inst.node_pool_scale_skip(%{}, metadata)
        :nothing
      else
        Inst.node_pool_scale_down(%{}, metadata)
        {:scale, :down}
      end
    end
  end

  @doc """
  Calculates the managed pool's new minimum instance count

  Returns the calculated minimum count when the managed pool's count is above the minimum instance count, else returns the minimum instance count.

  ## Examples
    Managed pool's count is less than minimum
      iex> {current_source_count, minimum_percent, minimum_count} = {10, 10, 2}
      ...> Ballast.PoolPolicy.Changeset.calc_new_minimum_count(current_source_count, minimum_percent, minimum_count)
      2

    Managed pool's count is greater than minimum
      iex> {current_source_count, minimum_percent, minimum_count} = {10, 50, 2}
      ...> Ballast.PoolPolicy.Changeset.calc_new_minimum_count(current_source_count, minimum_percent, minimum_count)
      5
  """
  @spec calc_new_minimum_count(pos_integer, pos_integer, pos_integer) :: pos_integer
  def calc_new_minimum_count(source_pool_current_count, minimum_percent, minimum_instances) do
    new_minimum_count = round(source_pool_current_count * (minimum_percent / 100))
    do_calc_new_minimum_count(new_minimum_count, minimum_instances)
  end

  defp do_calc_new_minimum_count(new_minimum_count, minimum_instances) when new_minimum_count > minimum_instances,
    do: new_minimum_count

  defp do_calc_new_minimum_count(_, minimum_instances), do: minimum_instances
end
