defmodule Ballast.NodePool.Changeset do
  @moduledoc """
  Changes to apply to a `Ballast.NodePool`.
  """
  alias Ballast.NodePool.Changeset

  @doc """
  Calculates the target instance count

  Returns the calculated target count when the target count is above the minimum instance count, else returns the minimum instance count.

  ## Examples
    Target count is less than minimum
      iex> {current_source_count, target_percent, minimum_count} = {10, 10, 2}
      ...> Changeset.calc_instance_count(current_source_count, target_percent, minimum_count)
      2

    Target count is greater than minimum
      iex> {current_source_count, target_percent, minimum_count} = {10, 50, 2}
      ...> Changeset.calc_instance_count(current_source_count, target_percent, minimum_count)
      5
  """
  @spec calc_instance_count(pos_integer, pos_integer, pos_integer) :: pos_integer
  def calc_instance_count(current, target_percent, minimum) do
    target = round(current * (target_percent / 100))
    do_calc_instance_count(target, minimum)
  end

  defp do_calc_instance_count(target, minimum) when target > minimum, do: target
  defp do_calc_instance_count(_, minimum), do: minimum
end
