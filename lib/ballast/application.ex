defmodule Ballast.Application do
  @moduledoc false

  use Application

  @spec start(any(), any()) :: {:error, any()} | {:ok, pid()}
  def start(_type, _args) do
    metrics = Ballast.Sys.Metrics.setup()
    TelemetryMetricsPrometheus.init(metrics, port: Ballast.Config.metrics_port())

    enable_debugging = Ballast.Config.debugging_enabled?()
    Ballast.Sys.Logger.attach(enable_debugging)

    children = [
      {Ballast.PoolPolicy.CooldownCache, []}
      # {Telemetry.Metrics.ConsoleReporter, metrics: metrics}
    ]

    opts = [strategy: :one_for_one, name: Ballast.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
