defmodule Ballast.Logger do
  @moduledoc """
  Attaches telemetry events to the Elixir Logger
  """

  require Logger

  @spec attach(boolean) :: :ok
  @doc """
  Attaches telemetry events to the Elixir Logger

  Set `BALLAST_DEBUG=true` to enable debug logging.
  """
  def attach(enable_debugging)

  def attach(true) do
    attach_ballast()
    attach_bonny()
  end

  def attach(_) do
    attach_ballast()
  end

  @doc false
  @spec log_handler(keyword, map | integer, map, atom) :: :ok
  def log_handler(event, measurements, metadata, preferred_level) do
    event_name = Enum.join(event, ".")

    level =
      case Regex.match?(~r/fail|error/, event_name) do
        true -> :error
        _ -> preferred_level
      end

    Logger.log(level, "[#{event_name}] #{inspect(measurements)} #{inspect(metadata)}")
  end

  @spec attach_bonny() :: :ok
  defp attach_bonny() do
    events = Bonny.Telemetry.events()
    :telemetry.attach_many("bonny-instrumentation-logger", events, &log_handler/4, :debug)
  end

  @spec attach_ballast() :: :ok
  defp attach_ballast() do
    events = Ballast.Instrumentation.events()
    :telemetry.attach_many("ballast-instrumentation-logger", events, &log_handler/4, :info)
  end
end
