defmodule Ballast.PoolPolicy.Changeset do
  @moduledoc """
  Changes to apply to a managed pool
  """

  alias Ballast.NodePool
  alias Ballast.PoolPolicy.{Changeset, ManagedPool}

  defstruct [:pool, :minimum_count, :source_count, :strategy]

  @typedoc """
  * `pool` - the managed pool changeset will be applied to
  * `minimum_count` - the new minimum count for the autoscaler or cluster
  * `source_count` - the current count of the source pool
  * `strategy` - what ballast thinks is happening to the source pool - poor name.
  """
  @type t :: %__MODULE__{
          pool: NodePool.t(),
          source_count: integer,
          minimum_count: integer,
          strategy: :nothing | :scale_up | :scale_down
        }

  @doc """
  Creates a new `Changeset` given a `Ballast.PoolPolicy.ManagedPool` and a current source `NodePool`.

  ## Examples
      iex> managed_pool = %Ballast.PoolPolicy.ManagedPool{pool: %Ballast.NodePool{name: "managed-pool"}, minimum_percent: 30, minimum_instances: 1}
      ...> source_pool = %Ballast.NodePool{instance_count: 10}
      ...> Ballast.PoolPolicy.Changeset.new(managed_pool, source_pool)
      %Ballast.PoolPolicy.Changeset{source_count: 10, minimum_count: 3, pool: %Ballast.NodePool{cluster: nil, data: nil, instance_count: nil, location: nil, name: "managed-pool", project: nil, under_pressure: nil}, strategy: :scale_down}
  """
  @spec new(ManagedPool.t(), NodePool.t()) :: t
  def new(managed_pool, %NodePool{instance_count: source_count} = source_pool) do
    calculated_minimum_count =
      calc_new_minimum_count(source_count, managed_pool.minimum_percent, managed_pool.minimum_instances)

    %Changeset{
      pool: managed_pool.pool,
      source_count: source_count,
      minimum_count: calculated_minimum_count,
      strategy: strategy(managed_pool.pool, source_pool)
    }
  end

  @doc """
  Rules:
  * If source pool is zero, assume scale to 0 and :scale_down
    * NOTE: this is possibly *not* true for Preemptible source pools
  * If the source pool has more nodes
    * calculate and scale UP that managed pool's minimum count. `:scale_up`
  * Else; source is lower because its scaling down, or preempted/stockedout.
    * If source is under pressure
      * `:nothing` Nothing to do, autoscaler should be adding nodes to source and managed pools
    * Else
      * `:scale_down` calculate and scale DOWN that managed pool's minimum count.
      * Note: There is a case when the source pools count is 0, the managed pool will be scaled down. This isn't optimal, but we dont know _why_ the source pool is zero. To mitigate scaling managed pools to zero, set the `minimumInstances`.


  ## Examples
    When the source pool instance count is zero
      iex> managed_pool = %Ballast.NodePool{instance_count: 5}
      ...> source_pool = %Ballast.NodePool{instance_count: 0}
      ...> Ballast.PoolPolicy.Changeset.strategy(managed_pool, source_pool)
      :scale_down

    When the source pool instance count is greater
      iex> managed_pool = %Ballast.NodePool{instance_count: 5}
      ...> source_pool = %Ballast.NodePool{instance_count: 10, under_pressure: false}
      ...> Ballast.PoolPolicy.Changeset.strategy(managed_pool, source_pool)
      :scale_up

    When the source pool instance count is lower and the source pool is under pressure
      iex> managed_pool = %Ballast.NodePool{instance_count: 5}
      ...> source_pool = %Ballast.NodePool{instance_count: 1, under_pressure: true}
      ...> Ballast.PoolPolicy.Changeset.strategy(managed_pool, source_pool)
      :nothing

    When the source pool instance count is lower and the source pool is not under pressure
      iex> managed_pool = %Ballast.NodePool{instance_count: 5}
      ...> source_pool = %Ballast.NodePool{instance_count: 1, under_pressure: false}
      ...> Ballast.PoolPolicy.Changeset.strategy(managed_pool, source_pool)
      :scale_down
  """
  @spec strategy(NodePool.t(), NodePool.t()) :: :nothing | :scale_up | :scale_down
  def strategy(_, %NodePool{instance_count: 0}), do: :scale_down
  def strategy(%NodePool{instance_count: mic}, %NodePool{instance_count: sic}) when sic >= mic, do: :scale_up
  def strategy(_, %NodePool{under_pressure: true}), do: :nothing
  def strategy(_, _), do: :scale_down

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
