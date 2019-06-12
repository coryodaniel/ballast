defmodule Ballast.Controller.V1.PoolPolicy do
  @moduledoc """
  Ballast: PoolPolicy CRD.
  """

  use Bonny.Controller
  require Logger
  alias Ballast.{PoolPolicy}

  @scope :cluster
  @group "ballast.bonny.run"

  @names %{
    plural: "poolpolicies",
    singular: "poolpolicy",
    kind: "PoolPolicy",
    shortNames: ["pp"]
  }

  @rule {"", ["nodes"], ["list"]}
  @rule {"", ["pods/eviction"], ["create"]}

  @doc """
  Handles an `ADDED` event
  """
  @spec add(map()) :: :ok | :error
  @impl Bonny.Controller
  def add(payload) do
    log(payload, :add)
    do_apply(payload)
  end

  @doc """
  Handles a `MODIFIED` event
  """
  @spec modify(map()) :: :ok | :error
  @impl Bonny.Controller
  def modify(payload) do
    log(payload, :modify)
    do_apply(payload)
  end

  @doc """
  Handles a `DELETED` event. This handler is a *no-op*.
  """
  @spec delete(map()) :: :ok | :error
  @impl Bonny.Controller
  def delete(payload) do
    log(payload, :delete)
  end

  @doc """
  Called periodically for each existing CustomResource to allow for reconciliation.
  """
  @spec reconcile(map()) :: :ok | :error
  @impl Bonny.Controller
  def reconcile(payload) do
    log(payload, :reconcile)
    do_apply(payload)
  end

  @spec log(binary | map, atom) :: :ok
  defp log(%{"metadata" => %{"name" => name}}, action), do: log(name, action)
  defp log(name, action), do: Logger.info("[#{action}] PoolPolicy: #{name}")

  @spec do_apply(map) :: :ok | :error
  defp do_apply(payload) do
    with {:ok, policy} <- PoolPolicy.from_resource(payload) do
      handle_policy(policy)
    end
  end

  @spec handle_policy(Ballast.PoolPolicy.t()) :: :ok | :error
  defp handle_policy(%Ballast.PoolPolicy{} = policy) do
    Enum.each(policy.targets, &evict_from_target/1)

    with :ok <- PoolPolicy.Store.ready?(policy),
         {:ok, policy} <- PoolPolicy.changesets(policy),
         :ok <- PoolPolicy.apply(policy) do
      PoolPolicy.Store.ran(policy)
      log(policy.name, :completed)
      :ok
    else
      {:error, :cooling_down} ->
        log(policy.name, :cooldown)
        :ok

      :error ->
        :error
    end
  end

  @spec evict_from_target(Ballast.PoolPolicy.Target.t()) :: :ok
  defp evict_from_target(%Ballast.PoolPolicy.Target{} = target) do
    {:ok, pods} = Ballast.Evictor.evictable(match: target.pool.name)
    Enum.each(pods, &Ballast.Evictor.evict/1)
    :ok
  end
end
