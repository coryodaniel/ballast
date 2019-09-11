defmodule Ballast.PoolPolicy.Changeset do
  @moduledoc """
  Changes to apply to a managed pool
  """

  alias Ballast.{NodePool, PoolPolicy}
  alias Ballast.PoolPolicy.{Changeset, ManagedPool}

  defstruct [:managed_pool, :minimum_count, :policy, :strategy]

  @typedoc """
  * `managed_pool` - the managed pool changeset will be applied to
  * `minimum_count` - the new minimum count for the autoscaler or cluster
  * `strategy` - what ballast thinks is happening to the source pool - poor name.
  * `policy` - the policy being applied
  """
  @type t :: %__MODULE__{
          managed_pool: ManagedPool.t(),
          minimum_count: integer,
          strategy: :nothing | :scale_up | :scale_down,
          policy: PoolPolicy.t()
        }

  @doc """
  Creates a new `Changeset` given a `Ballast.PoolPolicy.ManagedPool` and a current source `NodePool`.

  ## Examples
      iex> managed_pool = %Ballast.PoolPolicy.ManagedPool{pool: %Ballast.NodePool{name: "managed-pool"}, minimum_percent: 30, minimum_instances: 1}
      ...> source_pool = %Ballast.NodePool{instance_count: 10}
      ...> policy = %Ballast.PoolPolicy{pool: source_pool, managed_pools: [managed_pool]}
      ...> Ballast.PoolPolicy.Changeset.new(managed_pool, policy)
      %Ballast.PoolPolicy.Changeset{
        managed_pool: %Ballast.PoolPolicy.ManagedPool{
          minimum_instances: 1,
          minimum_percent: 30,
          pool: %Ballast.NodePool{
            cluster: nil,
            data: nil,
            instance_count: nil,
            location: nil,
            maximum_count: nil,
            minimum_count: nil,
            name: "managed-pool",
            project: nil,
            under_pressure: nil,
            zone_count: nil
          }
        },
        minimum_count: 3,
        policy: %Ballast.PoolPolicy{
          changesets: [],
          cooldown_seconds: nil,
          managed_pools: [
            %Ballast.PoolPolicy.ManagedPool{
              minimum_instances: 1,
              minimum_percent: 30,
              pool: %Ballast.NodePool{
                cluster: nil,
                data: nil,
                instance_count: nil,
                location: nil,
                maximum_count: nil,
                minimum_count: nil,
                name: "managed-pool",
                project: nil,
                under_pressure: nil,
                zone_count: nil
              }
            }
          ],
          name: nil,
          pool: %Ballast.NodePool{
            cluster: nil,
            data: nil,
            instance_count: 10,
            location: nil,
            maximum_count: nil,
            minimum_count: nil,
            name: nil,
            project: nil,
            under_pressure: nil,
            zone_count: nil
          }
        },
        strategy: :scale_down
      }
  """
  @spec new(ManagedPool.t(), PoolPolicy.t()) :: t
  def new(%ManagedPool{} = managed_pool, %PoolPolicy{} = policy) do
    changeset = %Changeset{
      managed_pool: managed_pool,
      minimum_count: managed_pool.minimum_instances,
      strategy: strategy(managed_pool.pool, policy.pool),
      policy: policy
    }

    calculate_minimum_and_update(changeset)
  end

  @spec calculate_minimum_and_update(Changeset.t()) :: Changeset.t()
  def calculate_minimum_and_update(%Changeset{} = changeset) do
    calculated_minimum =
      calc_new_minimum_count(
        changeset.policy.pool.instance_count,
        changeset.policy.pool.zone_count,
        changeset.managed_pool.minimum_percent,
        changeset.managed_pool.minimum_instances,
        changeset.managed_pool.pool.maximum_count
      )

    %Changeset{changeset | minimum_count: calculated_minimum}
  end

  @doc "Metrics/logging metadata and measurements"
  @spec measurements_and_metadata(Changeset.t()) :: {map, map}
  def measurements_and_metadata(%Changeset{} = changeset), do: {measurements(changeset), metadata(changeset)}

  @spec measurements(Changeset.t()) :: map
  defp measurements(%Changeset{} = changeset) do
    %{
      source_pool_current_instance_count: changeset.policy.pool.instance_count,
      source_pool_zone_count: changeset.policy.pool.zone_count,
      managed_pool_current_instance_count: changeset.managed_pool.pool.instance_count,
      managed_pool_current_autoscaling_minimum: changeset.managed_pool.pool.minimum_count,
      managed_pool_current_autoscaling_maximum: changeset.managed_pool.pool.maximum_count,
      managed_pool_conf_minimum_percent: changeset.managed_pool.minimum_percent,
      managed_pool_conf_minimum_instances: changeset.managed_pool.minimum_instances,
      managed_pool_new_autoscaling_minimum: changeset.minimum_count
    }
  end

  @spec metadata(Changeset.t()) :: map
  defp metadata(%Changeset{} = changeset) do
    %{pool: changeset.managed_pool.pool.name, strategy: changeset.strategy, policy: changeset.policy.name}
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
  Calculates the managed pool's new minimum instance count.

  ## Examples
    When the calculated count is less than the minimum count, return minimum
      iex> {current_source_instance_count, source_zone_count, minimum_percent, minimum_count, maximum_count} = {10, 1, 10, 2, 100}
      ...> Ballast.PoolPolicy.Changeset.calc_new_minimum_count(current_source_instance_count, source_zone_count, minimum_percent, minimum_count, maximum_count)
      2

    When the calculated count is greater than minimum count, return calculated
      iex> {current_source_instance_count, source_zone_count, minimum_percent, minimum_count, maximum_count} = {10, 1, 50, 2, 100}
      ...> Ballast.PoolPolicy.Changeset.calc_new_minimum_count(current_source_instance_count, source_zone_count, minimum_percent, minimum_count, maximum_count)
      5

    When the calculated count is greater than maximum count, return maximum
      iex> {current_source_instance_count, source_zone_count, minimum_percent, minimum_count, maximum_count} = {200, 1, 100, 2, 33}
      ...> Ballast.PoolPolicy.Changeset.calc_new_minimum_count(current_source_instance_count, source_zone_count, minimum_percent, minimum_count, maximum_count)
      33

    For a regional cluster when the calculated count is greater than minimum count, return calculated
      iex> {current_source_instance_count, source_zone_count, minimum_percent, minimum_count, maximum_count} = {10, 3, 50, 2, 100}
      ...> Ballast.PoolPolicy.Changeset.calc_new_minimum_count(current_source_instance_count, source_zone_count, minimum_percent, minimum_count, maximum_count)
      2
  """
  @spec calc_new_minimum_count(integer, integer, integer, integer, integer) :: integer
  def calc_new_minimum_count(
        source_pool_current_count,
        source_pool_zone_count,
        minimum_percent,
        minimum_instances,
        managed_pool_max_count
      ) do
    source_pool_zone_count = source_pool_zone_count || 1
    minimum_instances_for_cluster = source_pool_current_count * (minimum_percent / 100)
    new_minimum_count = round(minimum_instances_for_cluster / source_pool_zone_count)

    do_calc_new_minimum_count(new_minimum_count, minimum_instances, managed_pool_max_count)
  end

  defp do_calc_new_minimum_count(new_minimum_count, _, managed_pool_max_count)
       when is_integer(managed_pool_max_count) and new_minimum_count >= managed_pool_max_count,
       do: managed_pool_max_count

  defp do_calc_new_minimum_count(new_minimum_count, minimum_instances, _)
       when new_minimum_count > minimum_instances,
       do: new_minimum_count

  defp do_calc_new_minimum_count(_, minimum_instances, _), do: minimum_instances
end
