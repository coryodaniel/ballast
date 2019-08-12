output "gke_auth_command" {
  value = "gcloud container clusters get-credentials ${google_container_cluster.main.name} --location ${google_container_cluster.main.location}"
}

output "gke_cluster_name" {
  value = "${google_container_cluster.main.name}"
}

output "gke_preemptible_pool" {
  value = "${google_container_node_pool.pvm-n1-1.name}"
}

output "gke_on_demand_pool_autoscaling" {
  value = "${google_container_node_pool.od-n1-1.name}"
}

output "gke_on_demand_pool_fixed" {
  value = "${google_container_node_pool.pvm-n1-2.name}"
}

output "example_poolpolicy_yaml" {
  value = "${local_file.poolpolicy-yaml.filename}"
}