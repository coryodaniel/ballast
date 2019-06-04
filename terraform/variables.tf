variable "gcp_region" {
  description = "GCP Region"
  default     = "us-central1"
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
