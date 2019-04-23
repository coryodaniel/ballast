defmodule Ballast.PoolPolicy do
  @moduledoc """
  Internal representation of `Ballast.Controller.V1.ReservePoolPolicy` custom resource.
  """

  alias Ballast.{NodePool, PoolPolicy}

  @type target_t :: %{
          pool: Ballast.NodePool.t(),
          target_capacity_percent: pos_integer,
          minimum_instances: pos_integer
        }

  @typedoc "PoolPolicy"
  @type t :: %__MODULE__{
          pool: Ballast.NodePool.t(),
          targets: list(target_t),
          changeset: map()
        }

  defstruct pool: nil, targets: [], changeset: %{}

  @doc """
  Converts a `Ballast.Controller.V1.ReservePoolPolicy` resource to a `Ballast.PoolPolicy`
  """
  @spec from_resource(map) :: PoolPolicy.t()
  def from_resource(resource) do
    pool = NodePool.new(resource)
    targets = make_targets(resource)

    %PoolPolicy{pool: pool, targets: targets}
    |> get_source_pool_current_size
  end

  @spec get_source_pool_current_size(PoolPolicy.t()) :: PoolPolicy.t()
  defp get_source_pool_current_size(policy) do
    policy
  end

  # defp validate(), do: nil
  # defp apply(), do: nil
  # defp calculate(), do: nil # ditch changeset

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
end
