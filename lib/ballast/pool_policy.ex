defmodule Ballast.PoolPolicy do
  @moduledoc """
  Internal representation of `Ballast.Controller.V1.PoolPolicy` custom resource.
  """
  @default_cooldown_seconds 300

  alias Ballast.{NodePool, PoolPolicy}
  alias PoolPolicy.Changeset

  defstruct name: nil, pool: nil, managed_pools: [], changesets: [], cooldown_seconds: nil

  @typedoc "PoolPolicy"
  @type t :: %__MODULE__{
          name: nil | String.t(),
          pool: NodePool.t(),
          cooldown_seconds: pos_integer,
          managed_pools: list(PoolPolicy.ManagedPool.t()),
          changesets: list(Changeset.t())
        }

  @doc """
  Converts a `Ballast.Controller.V1.PoolPolicy` resource to a `Ballast.PoolPolicy` and populates managed pool's `NodePool`s data.
  """
  @spec from_resource(map) :: {:ok, t} | {:error, Tesla.Env.t()}
  def from_resource(%{"metadata" => %{"name" => name}} = resource) do
    pool = NodePool.new(resource)

    with {:ok, conn} <- Ballast.conn(),
         {:ok, pool} <- NodePool.get(pool, conn),
         pool <- NodePool.set_pressure_status(pool) do
      managed_pools = make_managed_pools(resource)
      cooldown_seconds = get_in(resource, ["spec", "cooldownSeconds"]) || @default_cooldown_seconds

      policy = %PoolPolicy{
        pool: pool,
        managed_pools: managed_pools,
        name: name,
        cooldown_seconds: cooldown_seconds
      }

      {:ok, policy}
    end
  end

  @doc """
  Applies all changesets. Returns a tuple of two lists: `{succeeded, failed}`
  """
  @spec apply(t) :: {list, list}
  def apply(%__MODULE__{} = policy) do
    {:ok, conn} = Ballast.conn()

    Enum.split_with(policy.changesets, fn changeset ->
      :ok == NodePool.scale(changeset, conn)
    end)
  end

  @doc """
  Generates changesets for managed pools.
  """
  @spec changesets(t) :: {:ok, t} | {:error, any()}
  def changesets(%PoolPolicy{managed_pools: managed_pools} = policy) do
    changesets = Enum.map(managed_pools, fn mp -> Changeset.new(mp, policy) end)

    {:ok, %PoolPolicy{policy | changesets: changesets}}
  end

  # make_managed_pools/1 removes managed_pools that encountered errors in `Ballast.NodePool.Adapter/g2`
  @spec make_managed_pools(map) :: list(PoolPolicy.ManagedPool.t())
  defp make_managed_pools(%{"spec" => %{"managedPools" => managed_pools}} = resource) do
    %{"spec" => %{"projectId" => project, "clusterName" => cluster}} = resource

    managed_pools
    |> Enum.map(fn managed_pool -> PoolPolicy.ManagedPool.new(managed_pool, project, cluster) end)
    |> Enum.reject(fn {status, _} -> status == :error end)
    |> Enum.map(fn {:ok, managed_pool} -> managed_pool end)
  end

  defp make_managed_pools(_), do: []
end
