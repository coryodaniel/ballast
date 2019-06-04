provider "google" {
  version     = "~> 2.4.1"
  region      = "${var.gcp_region}"
  project     = "${var.gcp_project}"
  credentials = "${file(var.gcp_credentials_path)}"
}

locals {
  location = "${var.gcp_region}-a"
}

resource "google_container_cluster" "main" {
  name                     = "${var.gke_cluster_name}"
  location                 = "${local.location}"
  min_master_version       = "latest"
  remove_default_node_pool = true
  initial_node_count       = 1

  master_auth {
    username = ""
    password = ""

    client_certificate_config {
      issue_client_certificate = false
    }
  }
}

resource "google_container_node_pool" "preemptible_nodes" {
  name     = "${var.gke_cluster_name}-preemptible"
  location = "${local.location}"
  cluster  = "${google_container_cluster.main.name}"
  initial_node_count = 5

  autoscaling {
    min_node_count = 1
    max_node_count = 20
  }

  management {
    auto_repair = true
    auto_upgrade = true
  }

  node_config {
    preemptible  = true
    machine_type = "n1-standard-1"

    metadata = {
      disable-legacy-endpoints = "true"
    }
  }
}

resource "google_container_node_pool" "on_demand_nodes_autoscaling" {
  name     = "${var.gke_cluster_name}-on-demand-autoscaling"
  location = "${local.location}"
  cluster  = "${google_container_cluster.main.name}"
  initial_node_count = 1

  autoscaling {
    min_node_count = 1
    max_node_count = 10
  }

  management {
    auto_repair = true
    auto_upgrade = true
  }

  node_config {
    preemptible  = false
    machine_type = "n1-standard-1"

    metadata = {
      disable-legacy-endpoints = "true"
    }
  }
}

resource "google_container_node_pool" "on_demand_nodes_fixed" {
  name               = "${var.gke_cluster_name}-on-demand-fixed"
  location           = "${local.location}"
  cluster            = "${google_container_cluster.main.name}"
  initial_node_count = 1

  management {
    auto_repair = true
    auto_upgrade = true
  }

  node_config {
    preemptible  = false
    machine_type = "n1-standard-1"

    metadata = {
      disable-legacy-endpoints = "true"
    }
  }
}