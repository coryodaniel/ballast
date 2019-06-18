defmodule Ballast.PoolPolicy.Changeset do
  @moduledoc """
  Changes to apply to a managed pool
  """

  alias Ballast.PoolPolicy

  defstruct [:pool, :minimum_count]

  @type t :: %__MODULE__{
          pool: Ballast.NodePool.t(),
          minimum_count: pos_integer
        }

  @doc """
  Creates a new `Changeset` given a `Ballast.PoolPolicy.ManagedPool` and a current source pool instance count.

  ## Examples
      iex> target = %Ballast.PoolPolicy.ManagedPool{minimum_percent: 30, minimum_instances: 1}
      iex> source_count = 10
      ...> Ballast.PoolPolicy.Changeset.new(target, source_count)
      %Ballast.PoolPolicy.Changeset{minimum_count: 3}
  """
  @spec new(PoolPolicy.ManagedPool.t(), integer) :: t
  def new(target, source_count) do
    new_minimum_count = calc_new_minimum_count(source_count, target.minimum_percent, target.minimum_instances)
    %PoolPolicy.Changeset{pool: target.pool, minimum_count: new_minimum_count}
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

  defp do_calc_new_minimum_count(_, minimum), do: minimum_instances
end
