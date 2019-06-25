defmodule Ballast.Controller.V1.PoolPolicy do
  @moduledoc """
  Ballast: PoolPolicy CRD.
  """

  use Bonny.Controller
  alias Ballast.{PoolPolicy}
  alias Ballast.Sys.Instrumentation, as: Inst

  @scope :cluster
  @group "ballast.bonny.run"

  @names %{
    plural: "poolpolicies",
    singular: "poolpolicy",
    kind: "PoolPolicy",
    shortNames: ["pp"]
  }

  @rule {"", ["nodes"], ["list"]}
  @rule {"", ["pods"], ["list"]}
  @rule {"", ["pods/eviction"], ["create"]}

  @doc """
  Handles an `ADDED` event
  """
  @spec add(map()) :: :ok | :error
  @impl Bonny.Controller
  def add(payload) do
    inst(payload, :added)
    do_apply(payload)
  end

  @spec inst(map | binary, atom, map | nil) :: :ok
  def inst(policy_or_name, action, measurements \\ %{})
  def inst(%{"metadata" => %{"name" => name}}, event, measurements), do: inst(name, event, measurements)

  def inst(name, event, measurements) do
    metadata = %{name: name}

    case event do
      :added -> Inst.pool_policy_added(measurements, metadata)
      :deleted -> Inst.pool_policy_deleted(measurements, metadata)
      :modified -> Inst.pool_policy_modified(measurements, metadata)
      :reconciled -> Inst.pool_policy_reconciled(measurements, metadata)
      :applied -> Inst.pool_policy_applied(measurements, metadata)
      :backed_off -> Inst.pool_policy_backed_off(measurements, metadata)
    end
  end

  @doc """
  Handles a `MODIFIED` event
  """
  @spec modify(map()) :: :ok | :error
  @impl Bonny.Controller
  def modify(payload) do
    inst(payload, :modified)
    do_apply(payload)
  end

  @doc """
  Handles a `DELETED` event. This handler is a *no-op*.
  """
  @spec delete(map()) :: :ok | :error
  @impl Bonny.Controller
  def delete(payload) do
    inst(payload, :deleted)
  end

  @doc """
  Called periodically for each existing CustomResource to allow for reconciliation.
  """
  @spec reconcile(map()) :: :ok | :error
  @impl Bonny.Controller
  def reconcile(payload) do
    inst(payload, :reconciled)
    do_apply(payload)
  end

  @spec do_apply(map) :: :ok | :error
  defp do_apply(payload) do
    with {:ok, policy} <- PoolPolicy.from_resource(payload) do
      handle_policy(policy)
    end
  end

  @spec handle_policy(Ballast.PoolPolicy.t()) :: :ok | :error
  defp handle_policy(%Ballast.PoolPolicy{} = policy) do
    handle_eviction(policy)

    with :ok <- PoolPolicy.CooldownCache.ready?(policy),
         {:ok, policy} <- PoolPolicy.changesets(policy),
         {succeeded, failed} <- PoolPolicy.apply(policy) do
      PoolPolicy.CooldownCache.ran(policy)
      inst(policy.name, :applied, %{succeeded: succeeded, failed: failed})
      :ok
    else
      {:error, :cooling_down} ->
        inst(policy.name, :backed_off)
        :ok

      :error ->
        :error
    end
  end

  @spec handle_eviction(Ballast.PoolPolicy.t()) :: :ok
  defp handle_eviction(%Ballast.PoolPolicy{enable_auto_eviction: true} = policy) do
    Enum.each(policy.managed_pools, fn managed_pool ->
      {:ok, pods} = Ballast.Evictor.evictable(match: managed_pool.pool.name)
      Enum.each(pods, &Ballast.Kube.Eviction.create/1)
    end)

    :ok
  end

  defp handle_eviction(_) do
    :ok
  end
end
