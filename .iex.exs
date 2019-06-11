if Mix.env() == :dev do
  Bonny.Telemetry.DebugLogger.attach()
end

{:ok, cluster} = K8s.Cluster.conf(:default)
IO.puts("Using cluster: #{inspect(cluster)}")
