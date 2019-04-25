defmodule Ballast.Controller.V1.ReservePoolPolicy do
  @moduledoc """
  Ballast: ReservePoolPolicy CRD.
  """

  use Bonny.Controller
  require Logger
  alias Ballast.PoolPolicy

  @scope :cluster
  @names %{
    plural: "reservepoolpolicies",
    singular: "reservepoolpolicy",
    kind: "ReservePoolPolicy",
    shortNames: ["rpp"]
  }

  @rule {"", ["nodes"], ["list"]}

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

  @spec log(map, atom) :: :ok
  defp log(%{"metadata" => %{"name" => name}}, action) do
    Logger.debug("[#{action}] PoolPolicy: #{name}")
  end

  @spec do_apply(map) :: :ok | :error
  defp do_apply(payload) do
    policy = PoolPolicy.from_resource(payload)

    #  |> PoolPolicy.changesets()

    Logger.info("FOO: #{inspect(policy)}")
    :ok
  end
end
