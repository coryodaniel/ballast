# if Mix.env() == :dev do
#   Bonny.Telemetry.DebugLogger.attach()
# end

{:ok, cluster} = K8s.Cluster.conf(:default)
IO.puts("Using cluster: #{inspect(cluster)}")

{:ok, pods} = Ballast.Evictor.evictable(match: "ballast-fixed-pool")
IO.puts("Found #{length(pods)} pods to evict")
Enum.each(pods, &Ballast.Evictor.evict/1)

{:ok, pods} = Ballast.Evictor.evictable(match: "ballast-autoscaling-pool")
IO.puts("Found #{length(pods)} pods to evict")
Enum.each(pods, &Ballast.Evictor.evict/1)
