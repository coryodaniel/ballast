defmodule Ballast do
  @moduledoc """
  Documentation for Ballast.
  """

  @scopes [
    "https://www.googleapis.com/auth/compute",
    "https://www.googleapis.com/auth/cloud-platform"
  ]

  @scopes Enum.join(@scopes, " ")

  @spec conn() :: {:ok, Tesla.Client.t()} | {:error, any()}
  def conn() do
    case Goth.Token.for_scope(@scopes) do
      {:ok, tkn} ->
        {:ok, GoogleApi.Container.V1.Connection.new(tkn.token)}

      {:error, error} ->
        {:error, error}
    end
  end
end
