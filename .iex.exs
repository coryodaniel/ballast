if Mix.env() == :dev do
  Bonny.Telemetry.DebugLogger.attach()
  Ballast.Instrumentation.attach_logger(:info)
end

{:ok, cluster} = K8s.Cluster.conf(:default)
IO.puts("Using cluster: #{inspect(cluster)}")

{:ok, pods} = Ballast.Evictor.candidates()
IO.puts("Found #{length(pods)} candidates to evict")

{:ok, pods} = Ballast.Evictor.evictable(match: "ballast-od-n1-2")
IO.puts("Found #{length(pods)} pods to evict")
Enum.each(pods, &Ballast.Resources.Eviction.create/1)

{:ok, pods} = Ballast.Evictor.evictable(match: "ballast-od-n1-1")
IO.puts("Found #{length(pods)} pods to evict")
Enum.each(pods, &Ballast.Resources.Eviction.create/1)
