defmodule Ballast.Sys.Metrics do
  @moduledoc """
  Prometheus Telemetry integration
  """

  import Telemetry.Metrics

  @doc false
  @spec setup() :: list(Telemetry.Metrics.t())
  def setup() do
    [
      counter("ballast.pool_policy.backed_off.count", description: nil),
      counter("ballast.pool_policy.applied.count", description: nil),
      counter("ballast.pool_policy.reconciled.count", description: nil),
      counter("ballast.pool_policy.deleted.count", description: nil),
      counter("ballast.pool_policy.modified.count", description: nil),
      counter("ballast.pool_policy.added.count", description: nil),
      counter("ballast.nodes.list.succeeded.count", description: nil),
      counter("ballast.nodes.list.failed.count", description: nil),
      counter("ballast.pod.eviction.failed.count", description: nil),
      counter("ballast.pod.eviction.succeeded.count", description: nil),
      counter("ballast.get_eviction_candidates.failed.count", description: nil),
      counter("ballast.get_eviction_candidates.succeeded.count", description: nil),
      counter("ballast.provider.get_pool.failed.count", description: nil),
      counter("ballast.provider.get_pool.succeeded.count", description: nil),
      counter("ballast.provider.get_pool_size.failed.count", description: nil),
      counter("ballast.provider.get_pool_size.succeeded.count", description: nil),
      counter("ballast.provider.scale_pool.failed.count", description: nil),
      counter("ballast.provider.scale_pool.succeeded.count", description: nil)
    ]
  end
end
