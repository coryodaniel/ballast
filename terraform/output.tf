output "gke_auth_command" {
  value = "gcloud container clusters get-credentials ${google_container_cluster.main.name} --zone ${google_container_cluster.main.zone}"
}

output "gke_cluster_name" {
  value = "${google_container_cluster.main.name}"
}

output "gke_preemptible_pool" {
  value = "${google_container_node_pool.preemptible_nodes.name}"
}

output "gke_on_demand_pool_autoscaling" {
  value = "${google_container_node_pool.on_demand_nodes_autoscaling.name}"
}

output "gke_on_demand_pool_fixed" {
  value = "${google_container_node_pool.on_demand_nodes_fixed.name}"
}
