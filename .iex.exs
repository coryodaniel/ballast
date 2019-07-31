{:ok, cluster} = K8s.Cluster.conf(:default)
IO.puts("Using cluster: #{inspect(cluster)}")

alias GoogleApi.Container.V1.Api.Projects, as: Container
alias GoogleApi.Compute.V1.Api.InstanceGroups

{:ok, conn} = Ballast.conn
project = "odanielc-70641"
location = "us-central1-a"
cluster = "ballast"
name = "ballast-od-n1-1"

parent = "projects/#{project}/locations/#{location}/clusters/#{cluster}"
id = "#{parent}/nodePools/#{name}"

Container.container_projects_zones_clusters_node_pools_get(conn, project, location, cluster, name)

Container.container_projects_locations_clusters_node_pools_list(conn, parent)

Ballast.NodePool.Adapters.GKE.container_projects_locations_clusters_node_pools_get(conn, id)

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
