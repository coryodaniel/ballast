defmodule Ballast.PoolPolicy.Changeset do
  @moduledoc """
  Changes to apply to a target pool
  """

  alias Ballast.PoolPolicy

  defstruct [:pool, :minimum_count]

  @type t :: %__MODULE__{
          pool: Ballast.NodePool.t(),
          minimum_count: pos_integer
        }

  @doc """
  Creates a new `Changeset` given a `Ballast.PoolPolicy.Target` and a current source pool instance count.

  ## Examples
      iex> target = %Ballast.PoolPolicy.Target{target_capacity_percent: 30, minimum_instances: 1}
      iex> source_count = 10
      ...> Ballast.PoolPolicy.Changeset.new(target, source_count)
      %Ballast.PoolPolicy.Changeset{minimum_count: 3}
  """
  @spec new(PoolPolicy.Target.t(), integer) :: t
  def new(target, source_count) do
    new_minimum_count = calc_new_minimum_count(source_count, target.target_capacity_percent, target.minimum_instances)
    %PoolPolicy.Changeset{pool: target.pool, minimum_count: new_minimum_count}
  end

  @doc """
  Calculates the target instance count

  Returns the calculated target count when the target count is above the minimum instance count, else returns the minimum instance count.

  ## Examples
    Targcalc_instance_countet count is less than minimum
      iex> {current_source_count, target_percent, minimum_count} = {10, 10, 2}
      ...> Ballast.PoolPolicy.Changeset.calc_new_minimum_count(current_source_count, target_percent, minimum_count)
      2

    Target count is greater than minimum
      iex> {current_source_count, target_percent, minimum_count} = {10, 50, 2}
      ...> Ballast.PoolPolicy.Changeset.calc_new_minimum_count(current_source_count, target_percent, minimum_count)
      5
  """
  @spec calc_new_minimum_count(pos_integer, pos_integer, pos_integer) :: pos_integer
  def calc_new_minimum_count(current, target_percent, minimum) do
    target = round(current * (target_percent / 100))
    do_calc_new_minimum_count(target, minimum)
  end

  defp do_calc_new_minimum_count(target, minimum) when target > minimum, do: target
  defp do_calc_new_minimum_count(_, minimum), do: minimum
end
