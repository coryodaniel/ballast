{:ok, cluster} = K8s.Cluster.conf(:default)
IO.puts("Using cluster: #{inspect(cluster)}")

# {:ok, pods} = Ballast.Evictor.evictable(match: "ballast-od-n1-2")
# # IO.puts("Found #{length(pods)} pods to evict")
# Enum.each(pods, &Ballast.Resources.Eviction.create/1)

# {:ok, pods} = Ballast.Evictor.evictable(match: "ballast-od-n1-1")
# # IO.puts("Found #{length(pods)} pods to evict")
# Enum.each(pods, &Ballast.Resources.Eviction.create/1)
