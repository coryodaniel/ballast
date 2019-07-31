{:ok, cluster} = K8s.Cluster.conf(:default)
IO.puts("Using cluster: #{inspect(cluster)}")

# wrong project/nodepool names below... 
# pool = Ballast.NodePool.new("odanielc-70640", "us-central1-a", "ballast", "pool-name")
# {:ok, stream} = Ballast.NodePool.nodes(pool)
# Ballast.NodePool.under_pressure?(pool)

# {:ok, pods} = Ballast.Evictor.evictable(match: "pool-name-2")
# # IO.puts("Found #{length(pods)} pods to evict")
# Enum.each(pods, &Ballast.Kube.Eviction.create/1)

# {:ok, pods} = Ballast.Evictor.evictable(match: "pool-name-3")
# # IO.puts("Found #{length(pods)} pods to evict")
# Enum.each(pods, &Ballast.Kube.Eviction.create/1)
