defmodule Ballast do
  @moduledoc """
  Documentation for Ballast.
  """

  @scopes [
    "https://www.googleapis.com/auth/compute",
    "https://www.googleapis.com/auth/cloud-platform"
  ]

  @scopes Enum.join(@scopes, " ")
  alias Ballast.Sys.Instrumentation, as: Inst

  @spec conn() :: {:ok, Tesla.Client.t()} | {:error, any()}
  @doc false
  def conn() do
    {duration, response} = :timer.tc(Goth.Token, :for_scope, [@scopes])
    measurements = %{duration: duration}
    metadata = %{provider: "gke"}

    case response do
      {:ok, tkn} ->
        Inst.provider_authentication_succeeded(measurements, metadata)
        {:ok, GoogleApi.Container.V1.Connection.new(tkn.token)}

      {:error, error} ->
        Inst.provider_authentication_failed(measurements, metadata)
        {:error, error}
    end
  end
end
