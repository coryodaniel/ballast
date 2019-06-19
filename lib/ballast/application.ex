defmodule Ballast.Application do
  @moduledoc false

  use Application

  @spec start(any(), any()) :: {:error, any()} | {:ok, pid()}
  def start(_type, _args) do
    port = "BALLAST_METRICS_PORT" |> System.get_env() |> parse_port
    enable_debugging = "BALLAST_DEBUG" |> System.get_env() |> parse_enable_debugging

    metrics = Ballast.Metrics.setup()
    TelemetryMetricsPrometheus.init(metrics, port: port)
    Ballast.Logger.attach(enable_debugging)

    children = [
      {Ballast.PoolPolicy.CooldownCache, []}
      # {Telemetry.Metrics.ConsoleReporter, metrics: metrics}
    ]

    opts = [strategy: :one_for_one, name: Ballast.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @spec parse_port(any) :: pos_integer()
  defp parse_port(port) when is_binary(port), do: port |> Integer.parse() |> parse_port
  defp parse_port({port, _}), do: port
  defp parse_port(nil), do: 9323
  defp parse_port(port), do: port

  @spec parse_enable_debugging(any) :: boolean()
  defp parse_enable_debugging("true"), do: true
  defp parse_enable_debugging(_), do: false
end
