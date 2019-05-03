defmodule Ballast.PoolPolicy do
  @moduledoc """
  Internal representation of `Ballast.Controller.V1.PoolPolicy` custom resource.
  """

  alias Ballast.{NodePool, PoolPolicy}
  require Logger

  defstruct pool: nil, targets: [], changesets: []

  @typedoc "PoolPolicy"
  @type t :: %__MODULE__{
          pool: NodePool.t(),
          targets: list(PoolPolicy.Target.t()),
          changesets: list(PoolPolicy.Changeset.t())
        }

  @doc """
  Converts a `Ballast.Controller.V1.PoolPolicy` resource to a `Ballast.PoolPolicy` and populates target `NodePool`s data.
  """
  @spec from_resource(map) :: {:ok, t} | {:error, Tesla.Env.t()}
  def from_resource(resource) do
    pool = NodePool.new(resource)

    with {:ok, conn} <- Ballast.conn(), {:ok, pool} <- NodePool.get(pool, conn) do
      targets = make_targets(resource)
      {:ok, %PoolPolicy{pool: pool, targets: targets}}
    else
      {:error, %Tesla.Env{status: status} = error} ->
        Logger.error("Could not GET source pool #{NodePool.id(pool)}. HTTP Status: #{status}")
        {:error, error}
    end
  end

  # TODO: doc, spec
  def apply(%__MODULE__{} = policy) do
    {:ok, conn} = Ballast.conn()
    Enum.map(policy.changesets, &(NodePool.scale(&1, conn)))
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
    else
      {:error, %Tesla.Env{status: status} = error} ->
        Logger.error("Could not get source pool size #{NodePool.id(policy.pool)}. HTTP Status: #{status}")
        {:error, error}
    end
  end

  # make_targets/1 removes targets that encountered errors in `Ballast.NodePool.Adapter/g2`
  @spec make_targets(map) :: list(PoolPolicy.Target.t())
  defp make_targets(%{"spec" => %{"targetPools" => targets}} = resource) do
    {project, cluster} = get_project_and_cluster(resource)

    targets
    |> Enum.map(fn target -> PoolPolicy.Target.new(target, project, cluster) end)
    |> Enum.reject(&is_nil/1)
  end

  @spec get_project_and_cluster(map) :: {String.t(), String.t()}
  defp get_project_and_cluster(%{"spec" => %{"projectId" => p, "clusterName" => c}}), do: {p, c}
end
