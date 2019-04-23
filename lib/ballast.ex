defmodule Ballast do
  @moduledoc """
  Documentation for Ballast.
  """

  @scopes [
    "https://www.googleapis.com/auth/compute",
    "https://www.googleapis.com/auth/cloud-platform"
  ]

  @scopes Enum.join(@scopes, " ")

  @default_target_capacity_percent 50
  @default_minimum_instances 1

  @spec token() :: {:ok, Goth.Token.t()}
  def token() do
    Goth.Token.for_scope(@scopes)
  end

  @spec conn() :: {:ok, Tesla.Client.t()} | {:error, any()}
  def conn() do
    {:ok, tkn} = token()
    {:ok, GoogleApi.Container.V1.Connection.new(tkn.token)}
  end

  @spec default_target_capacity_percent() :: pos_integer
  def default_target_capacity_percent() do
    get_config_value(:default_target_capacity_percent, @default_target_capacity_percent)
  end

  @spec default_minimum_instances() :: pos_integer
  def default_minimum_instances() do
    get_config_value(:default_minimum_instances, @default_minimum_instances)
  end

  @spec get_config_value(atom, any()) :: any()
  defp get_config_value(name, default) do
    env_var_name = name |> Atom.to_string() |> String.upcase()
    from_env = System.get_env(env_var_name)
    from_app = Application.get_env(:ballast, name, default)

    from_env || from_app
  end
end
