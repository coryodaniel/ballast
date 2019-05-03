defmodule Ballast.Controller.V1.PoolPolicy do
  @moduledoc """
  Ballast: PoolPolicy CRD.
  """

  use Bonny.Controller
  require Logger
  alias Ballast.{PoolPolicy}

  @scope :cluster
  @names %{
    plural: "poolpolicies",
    singular: "poolpolicy",
    kind: "PoolPolicy",
    shortNames: ["pp"]
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
    with {:ok, policy} <- PoolPolicy.from_resource(payload),
         {:ok, policy} <- PoolPolicy.changesets(policy),
         :ok <- PoolPolicy.apply(policy) do

      # TODO: backoff
      :ok
    else
      error ->
        :error
    end
  end
end
