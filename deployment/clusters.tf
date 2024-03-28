resource "google_container_cluster" "tejas_cpu_ray" {
  name     = "tejas-cpu-ray"
  project  = "supercomputer-testing"
  location = "us-central1"

  release_channel {
    channel = "RAPID"
  }

  # We can't create a cluster with no node pool defined, but we want to only use
  # separately managed node pools. So we create the smallest possible default
  # node pool and immediately delete it.
  remove_default_node_pool = true
  initial_node_count       = 1
}

resource "google_container_node_pool" "primary" {
  name       = "tejas-nodepool"
  project  = google_container_cluster.tejas_cpu_ray.project
  location   = google_container_cluster.tejas_cpu_ray.location
  cluster    = google_container_cluster.tejas_cpu_ray.name
  node_count = 1

  management {
    auto_repair = true
    auto_upgrade = true
  }

  node_config {
    preemptible  = true
    machine_type = "e2-medium"

    oauth_scopes    = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]
  }
}


resource "google_container_node_pool" "nvidia-v100x2" {
  name       = "nvidia-v100x2-pool"
  project  = google_container_cluster.tejas_cpu_ray.project
  location   = google_container_cluster.tejas_cpu_ray.location
  cluster    = google_container_cluster.tejas_cpu_ray.name

  autoscaling {
    min_node_count = 2
    max_node_count = 6
  }

  node_locations = [
    "us-central1-b"
  ]

  management {
    auto_repair = true
    auto_upgrade = true
  }

  node_config {
    preemptible  = true
    machine_type = "n1-highmem-16"

    oauth_scopes    = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]
    guest_accelerator {
      type  = "nvidia-tesla-v100"
      count = 2
      gpu_driver_installation_config {
        gpu_driver_version = "LATEST"
      }
    }
  }
}

data "google_client_config" "provider" {}

provider "kubernetes" {
  host  = "https://${google_container_cluster.tejas_cpu_ray.endpoint}"
  token = data.google_client_config.provider.access_token
  cluster_ca_certificate = base64decode(
    google_container_cluster.tejas_cpu_ray.master_auth[0].cluster_ca_certificate,
  )
}

// Headless service required for service discovery within a Job.
// Pods will be addressable as `hostname.headless-svc`
resource "kubernetes_service" "example" {
  metadata {
    name = "headless-svc"
  }
  spec {
    selector = {
      headless-svc = "true"
    }
    cluster_ip = "None"
  }
}
