{:ok, cluster} = K8s.Cluster.conf(:default)
IO.puts("Using cluster: #{inspect(cluster)}")

# pool = Ballast.NodePool.new("odanielc-70640", "us-central1-a", "ballast", "ballast-preemptible")
# {:ok, stream} = Ballast.NodePool.nodes(pool)
# Ballast.NodePool.under_pressure?(pool)

# {:ok, pods} = Ballast.Evictor.evictable(match: "ballast-od-n1-2")
# # IO.puts("Found #{length(pods)} pods to evict")
# Enum.each(pods, &Ballast.Kube.Eviction.create/1)

# {:ok, pods} = Ballast.Evictor.evictable(match: "ballast-od-n1-1")
# # IO.puts("Found #{length(pods)} pods to evict")
# Enum.each(pods, &Ballast.Kube.Eviction.create/1)
