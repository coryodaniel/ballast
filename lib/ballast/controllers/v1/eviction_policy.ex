defmodule Ballast.Controller.V1.EvictionPolicy do
  @moduledoc """
  Ballast: EvictionPolicy CRD.
  """

  use Bonny.Controller

  @scope :cluster
  @group "ballast.bonny.run"

  @names %{
    plural: "evictionpolicies",
    singular: "evictionpolicy",
    kind: "EvictionPolicy",
    shortNames: ["evp"]
  }

  @rule {"", ["nodes"], ["list"]}
  @rule {"", ["pods"], ["list"]}
  @rule {"", ["pods/eviction"], ["create"]}

  @doc """
  Handles an `ADDED` event
  """
  @spec add(map()) :: :ok | :error
  @impl Bonny.Controller
  def add(payload), do: reconcile(payload)

  @doc """
  Handles a `MODIFIED` event
  """
  @spec modify(map()) :: :ok | :error
  @impl Bonny.Controller
  def modify(payload), do: reconcile(payload)

  @doc """
  Handles a `DELETED` event
  """
  @spec delete(map()) :: :ok | :error
  @impl Bonny.Controller
  def delete(_), do: :ok

  @doc """
  Called periodically for each existing CustomResource to allow for reconciliation.
  """
  @spec reconcile(map()) :: :ok | :error
  @impl Bonny.Controller
  def reconcile(payload) do
    handle_eviction(payload)
    :ok
  end

  @spec handle_eviction(map()) :: :ok
  defp handle_eviction(%{} = policy) do
    with {:ok, pods} <- Ballast.Evictor.evictable(policy) do
      Enum.each(pods, &Ballast.Kube.Eviction.create/1)
    end

    :ok
  end

  defp handle_eviction(_) do
    :ok
  end
end
