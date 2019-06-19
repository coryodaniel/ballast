defmodule Ballast.Config do
  @moduledoc """
  Configuration interface
  """

  @sys_env_key_metrics "BALLAST_METRICS_PORT"
  @sys_env_key_debugging "BALLAST_DEBUG"

  @default_metrics_port 9323
  @default_minimum_percent 50
  @default_minimum_instances 1

  @doc "Is debugging enabled"
  @spec debugging_enabled?() :: boolean()
  def debugging_enabled?() do
    @sys_env_key_debugging |> System.get_env() |> parse_boolean
  end

  @doc "Prometheus metrics port"
  @spec metrics_port :: pos_integer
  def metrics_port do
    port =
      @sys_env_key_metrics
      |> System.get_env()
      |> string_to_integer()

    port || @default_metrics_port
  end

  @doc """
  Get the default minimum percent for managed pools.

  ## Example
      iex> Ballast.Config.default_minimum_percent()
      50
  """
  @spec default_minimum_percent() :: pos_integer
  def default_minimum_percent() do
    get_config_value(:default_minimum_percent, @default_minimum_percent)
  end

  @doc """
  Get the default minimum instances for managed pools.

  ## Example
      iex> Ballast.Config.default_minimum_instances()
      1
  """
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

  @doc """
  Parses an integer from a string

  ## Examples
      iex> Ballast.Config.string_to_integer("300")
      300

      iex> Ballast.Config.string_to_integer("nonsense")
      nil

      iex> Ballast.Config.string_to_integer(300)
      300

  """
  @spec string_to_integer(any) :: integer() | nil
  def string_to_integer(str) when is_binary(str), do: str |> Integer.parse() |> string_to_integer
  def string_to_integer({int, _}), do: int
  def string_to_integer(int) when is_number(int), do: int
  def string_to_integer(_), do: nil

  @doc false
  @spec parse_boolean(any) :: boolean()
  def parse_boolean("true"), do: true
  def parse_boolean(true), do: true
  def parse_boolean(_), do: false
end
