provider "google" {
  version     = "~> 2.4.1"
  region      = "${var.gcp_region}"
  project     = "${var.gcp_project}"
  credentials = "${file(var.gcp_credentials_path)}"
}

locals {
  location   = "${var.gcp_region}-a"
  node_group = "ballast-example-group"
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
  name               = "${var.gke_cluster_name}-preemptible"
  location           = "${local.location}"
  cluster            = "${google_container_cluster.main.name}"
  initial_node_count = 1

  autoscaling {
    min_node_count = 1
    max_node_count = 50
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }

  node_config {
    preemptible  = true
    machine_type = "n1-standard-1"

    metadata = {
      disable-legacy-endpoints = "true"
    }

    labels {
      node-group = "${local.node_group}"
      node-type  = "preemptible"
    }
  }
}

resource "google_container_node_pool" "on_demand_nodes_autoscaling" {
  name               = "${var.gke_cluster_name}-autoscaling-pool"
  location           = "${local.location}"
  cluster            = "${google_container_cluster.main.name}"
  initial_node_count = 1

  autoscaling {
    min_node_count = 1
    max_node_count = 50
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }

  node_config {
    preemptible  = false
    machine_type = "n1-standard-1"

    metadata = {
      disable-legacy-endpoints = "true"
    }

    labels {
      node-group = "${local.node_group}"
    }
  }
}

resource "google_container_node_pool" "on_demand_nodes_fixed" {
  name               = "${var.gke_cluster_name}-fixed-pool"
  location           = "${local.location}"
  cluster            = "${google_container_cluster.main.name}"
  initial_node_count = 1

  management {
    auto_repair  = true
    auto_upgrade = true
  }

  node_config {
    preemptible  = false
    machine_type = "n1-standard-1"

    metadata = {
      disable-legacy-endpoints = "true"
    }

    labels {
      node-group = "${local.node_group}"
    }
  }
}

resource "google_container_node_pool" "other" {
  name               = "${var.gke_cluster_name}-other"
  location           = "${local.location}"
  cluster            = "${google_container_cluster.main.name}"
  initial_node_count = 1

  autoscaling {
    min_node_count = 1
    max_node_count = 3
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }

  node_config {
    machine_type = "n1-standard-1"

    metadata = {
      disable-legacy-endpoints = "true"
    }
  }
}

data "template_file" "poolpolicy-yaml" {
  template = "${file("${path.module}/ballast-poolpolicy.tpl.yaml")}"

  vars = {
    project                 = "${var.gcp_project}"
    location                = "${local.location}"
    cluster                 = "${google_container_cluster.main.name}"
    source_pool             = "${google_container_node_pool.preemptible_nodes.name}"
    target_autoscaling_pool = "${google_container_node_pool.on_demand_nodes_autoscaling.name}"
    target_fixed_pool       = "${google_container_node_pool.on_demand_nodes_fixed.name}"
  }
}

resource "local_file" "poolpolicy-yaml" {
  content  = "${data.template_file.poolpolicy-yaml.rendered}"
  filename = "${path.module}/ballast-poolpolicy.yaml"
}
