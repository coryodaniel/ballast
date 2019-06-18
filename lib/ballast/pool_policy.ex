defmodule Ballast.PoolPolicy do
  @moduledoc """
  Internal representation of `Ballast.Controller.V1.PoolPolicy` custom resource.
  """
  @default_cooldown_seconds 300

  alias Ballast.{NodePool, PoolPolicy}

  defstruct name: nil, pool: nil, targets: [], changesets: [], cooldown_seconds: nil, enable_auto_eviction: false

  @typedoc "PoolPolicy"
  @type t :: %__MODULE__{
          name: nil | String.t(),
          pool: NodePool.t(),
          cooldown_seconds: pos_integer,
          enable_auto_eviction: boolean,
          targets: list(PoolPolicy.Target.t()),
          changesets: list(PoolPolicy.Changeset.t())
        }

  @doc """
  Converts a `Ballast.Controller.V1.PoolPolicy` resource to a `Ballast.PoolPolicy` and populates target `NodePool`s data.
  """
  @spec from_resource(map) :: {:ok, t} | {:error, Tesla.Env.t()}
  def from_resource(%{"metadata" => %{"name" => name}} = resource) do
    pool = NodePool.new(resource)

    with {:ok, conn} <- Ballast.conn(), {:ok, pool} <- NodePool.get(pool, conn) do
      targets = make_targets(resource)
      cooldown_seconds = get_in(resource, ["spec", "cooldownSeconds"]) || @default_cooldown_seconds
      enable_auto_eviction = get_in(resource, ["spec", "enableAutoEviction"]) || false

      policy = %PoolPolicy{
        pool: pool,
        targets: targets,
        name: name,
        cooldown_seconds: cooldown_seconds,
        enable_auto_eviction: enable_auto_eviction
      }

      {:ok, policy}
    end
  end

  @doc """
  Applies all changesets
  """
  @spec apply(t) :: :ok
  def apply(%__MODULE__{} = policy) do
    {:ok, conn} = Ballast.conn()
    Enum.each(policy.changesets, &NodePool.scale(&1, conn))
    :ok
  end

  @doc """
  Generates changesets for target pools.
  """
  @spec changesets(t) :: {:ok, t} | {:error, any()}
  def changesets(%PoolPolicy{targets: targets} = policy) do
    with {:ok, conn} <- Ballast.conn(),
         {:ok, pool} <- NodePool.size(policy.pool, conn) do
      changesets =
        Enum.map(targets, fn target ->
          PoolPolicy.Changeset.new(target, pool.instance_count)
        end)

      {:ok, %PoolPolicy{policy | changesets: changesets}}
    end
  end

  # make_targets/1 removes targets that encountered errors in `Ballast.NodePool.Adapter/g2`
  @spec make_targets(map) :: list(PoolPolicy.Target.t())
  defp make_targets(%{"spec" => %{"targetPools" => targets}} = resource) do
    %{"spec" => %{"projectId" => project, "clusterName" => cluster}} = resource

    targets
    |> Enum.map(fn target -> PoolPolicy.Target.new(target, project, cluster) end)
    |> Enum.reject(fn {status, _} -> status == :error end)
    |> Enum.map(fn {:ok, target} -> target end)
  end
end
