defmodule Ballast.Instrumentation do
  use Notion, name: :ballast, metadata: %{}
  require Logger

  defevent([:pod, :eviction, :succeeded])
  defevent([:pod, :eviction, :failed])

  defevent([:provider, :scale_pool, :succeeded])
  defevent([:provider, :scale_pool, :failed])

  defevent([:provider, :get_pool_size, :succeeded])
  defevent([:provider, :get_pool_size, :failed])

  defevent([:provider, :get_pool, :succeeded])
  defevent([:provider, :get_pool, :failed])

  defevent([:get_eviction_candidates, :succeeded])
  defevent([:get_eviction_candidates, :failed])

  @doc "A new PoolPolicy resource was added"
  defevent([:pool_policy, :added])

  @doc "A PoolPolicy was modified"
  defevent([:pool_policy, :modified])

  @doc "A PoolPolicy was deleted"
  defevent([:pool_policy, :deleted])

  @doc "A PoolPolicy was reconciled"
  defevent([:pool_policy, :reconciled])

  @doc "A PoolPolicy was applied successfully"
  defevent([:pool_policy, :applied])

  @doc "A PoolPolicy was in cooldown and backed off"
  defevent([:pool_policy, :backed_off])

  @spec attach_logger(atom) :: :ok
  @doc "Logs all dispatched events at the given log level"
  def attach_logger(level \\ :info) do
    log_handler = fn event, _measurements, metadata, _config ->
      msg = "Dispatched: #{inspect(event)} #{inspect(metadata)}"
      Logger.log(level, msg)
    end

    :telemetry.attach_many("ballast-instrumentation-logger", events(), log_handler, nil)
  end
end
