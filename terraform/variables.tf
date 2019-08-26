variable "gcp_location" {
  description = "GCP Region or Zone"
  default     = "us-central1"
  #default     = "us-central1-a"
}

variable "gcp_project" {
  description = "GCP Project ID"
}

variable "gke_cluster_name" {
  description = "GKE Cluster Name"
  default     = "ballast"
}

variable "gcp_credentials_path" {
  description = "Path to GCP credentials JSON"
}

variable "gcp_on_demand_max_nodes" {
  default = 5
}

variable "gcp_preemptible_max_nodes" {
  default = 5
}
