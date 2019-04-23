defmodule Ballast.Controller.V1.ReservePoolPolicy do
  @moduledoc """
  Ballast: ReservePoolPolicy CRD.
  """

  use Bonny.Controller
  require Logger

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
    :ok
  end

  @doc """
  Handles a `MODIFIED` event
  """
  @spec modify(map()) :: :ok | :error
  @impl Bonny.Controller
  def modify(payload) do
    log(payload, :modify)
    :ok
  end

  @doc """
  Handles a `DELETED` event
  """
  @spec delete(map()) :: :ok | :error
  @impl Bonny.Controller
  def delete(payload) do
    log(payload, :delete)
    :ok
  end

  @doc """
  Called periodically for each existing CustomResource to allow for reconciliation.
  """
  @spec reconcile(map()) :: :ok | :error
  @impl Bonny.Controller
  def reconcile(payload) do
    log(payload, :reconcile)
    :ok
  end

  defp log(payload, action) do
    Logger.debug("[#{action}]: #{inspect(payload)}")
  end
end
