defmodule Ballast.Instrumentation do
  use Notion, name: :ballast, metadata: %{}
  require Logger

  @doc "Pod eviction succceeded"
  defevent([:pod, :eviction, :succeeded])

  @doc "Pod eviction failed"
  defevent([:pod, :eviction, :failed])

  @doc "Scaling pool minimum size from the provider API succeeded"
  defevent([:provider, :scale_pool, :succeeded])

  @doc "Scaling pool minimum size from the provider API failed"
  defevent([:provider, :scale_pool, :failed])

  @doc "Getting pool size from the provider API succeeded"
  defevent([:provider, :get_pool_size, :succeeded])

  @doc "Getting pool size from the provider API failed"
  defevent([:provider, :get_pool_size, :failed])

  @doc "Getting the pool from the provider API succeeded"
  defevent([:provider, :get_pool, :succeeded])

  @doc "Getting the pool from the provider API failed"
  defevent([:provider, :get_pool, :failed])

  @doc "Getting a list of eviction candidates from the k8s API succeeded"
  defevent([:get_eviction_candidates, :succeeded])

  @doc "Getting a list of eviction candidates from the k8s API failed"
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
