defmodule Ballast.PoolPolicy do
  @moduledoc """
  Internal representation of `Ballast.Controller.V1.ReservePoolPolicy` custom resource.
  """

  alias Ballast.{NodePool, PoolPolicy}

  @type changeset_t :: %{
          pool: Ballast.NodePool.t(),
          minimum_count: integer
        }

  @type target_t :: %{
          pool: Ballast.NodePool.t(),
          target_capacity_percent: pos_integer,
          minimum_instances: pos_integer
        }

  @typedoc "PoolPolicy"
  @type t :: %__MODULE__{
          pool: Ballast.NodePool.t(),
          targets: list(target_t),
          changesets: list(changeset_t)
        }

  defstruct pool: nil, targets: [], changesets: []

  @doc """
  Converts a `Ballast.Controller.V1.ReservePoolPolicy` resource to a `Ballast.PoolPolicy`
  """
  @spec from_resource(map) :: PoolPolicy.t()
  def from_resource(resource) do
    pool =
      resource
      |> NodePool.new()

    targets = make_targets(resource)

    %PoolPolicy{pool: pool, targets: targets}
  end

  @doc """
  Generates optimistic changesets for target pools.

  Source pool's size is checked and target/minimum count is calculated for all targets *without* checking the size of the targets.

  Idea being that in a continually changing system it'll be faster to perform a no-op update than to check if an update is needed and perform if so.
  """
  @spec changesets(PoolPolicy.t()) :: PoolPolicy.t()
  def changesets(%PoolPolicy{targets: targets} = policy) do
    {:ok, conn} = Ballast.conn()
    {:ok, node_pool} = NodePool.size(policy.pool, conn)

    changesets = make_changesets(targets, node_pool.instance_count)
    %PoolPolicy{policy | changesets: changesets}
  end

  @spec make_changesets(list(target_t), pos_integer) :: list(changeset_t)
  defp make_changesets(targets, source_count) do
    Enum.map(targets, fn target ->
      new_minimum_count = calc_new_minimum_count(source_count, target.target_capacity_percent, target.minimum_instances)
      %{pool: target.pool, minimum_count: new_minimum_count}
    end)
  end

  @spec make_targets(map) :: list(target_t)
  defp make_targets(%{"spec" => %{"targetPools" => targets}} = resource) do
    {project, cluster} = get_project_and_cluster(resource)

    Enum.map(targets, fn target -> make_target(target, project, cluster) end)
  end

  @spec make_target(map(), binary(), binary()) :: target_t
  defp make_target(target, project, cluster) do
    %{
      "targetCapacityPercent" => tp,
      "minimumInstances" => mi,
      "poolName" => name,
      "location" => location
    } = target

    %{
      pool: NodePool.new(project, location, cluster, name),
      target_capacity_percent: cast_target_capacity_percent(tp),
      minimum_instances: cast_minimum_instances(mi)
    }
  end

  @spec get_project_and_cluster(map) :: {String.t(), String.t()}
  defp get_project_and_cluster(%{"spec" => %{"projectId" => p, "clusterName" => c}}), do: {p, c}

  @spec cast_target_capacity_percent(String.t() | pos_integer) :: pos_integer
  defp cast_target_capacity_percent(tp) when is_integer(tp), do: tp
  defp cast_target_capacity_percent(tp) when is_binary(tp), do: String.to_integer(tp)
  defp cast_target_capacity_percent(_), do: Ballast.default_target_capacity_percent()

  @spec cast_minimum_instances(String.t() | pos_integer) :: pos_integer
  defp cast_minimum_instances(mi) when is_integer(mi), do: mi
  defp cast_minimum_instances(mi) when is_binary(mi), do: String.to_integer(mi)
  defp cast_minimum_instances(_), do: Ballast.default_minimum_instances()

  @doc """
  Calculates the target instance count

  Returns the calculated target count when the target count is above the minimum instance count, else returns the minimum instance count.

  ## Examples
    Targcalc_instance_countet count is less than minimum
      iex> {current_source_count, target_percent, minimum_count} = {10, 10, 2}
      ...> PoolPolicy.calc_new_minimum_count(current_source_count, target_percent, minimum_count)
      2

    Target count is greater than minimum
      iex> {current_source_count, target_percent, minimum_count} = {10, 50, 2}
      ...> PoolPolicy.calc_new_minimum_count(current_source_count, target_percent, minimum_count)
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
