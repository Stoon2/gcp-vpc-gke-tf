provider "google" {
  project = "aqueous-freedom-348421"
  region  = "us-central1"
  zone    = "us-central1-c"
}

module "vpc" {
  source  = "terraform-google-modules/network/google"
  version = "~> 4.0"

  project_id   = "aqueous-freedom-348421"
  network_name = "final-task-vpc"
  routing_mode = "REGIONAL"

  # delete_default_internet_gateway_routes = true

  subnets = [
    {
      subnet_name           = "public-sn"
      subnet_ip             = "10.0.0.0/24"
      subnet_region         = "us-central1"
      subnet_private_access = "false"
      subnet_flow_logs      = "false"
      description           = "This subnet is public"
    },
    {
      subnet_name           = "private-sn"
      subnet_ip             = "10.0.1.0/24"
      subnet_region         = "us-central1"
      subnet_private_access = "true"
      subnet_flow_logs      = "false"
      description           = "This subnet is private"
    }
  ]

  routes = [
    {
      name              = "egress-internet"
      description       = "route through IGW to access internet"
      destination_range = "0.0.0.0/0"
      tags              = "egress-inet"
      next_hop_internet = "true"
    }
  ]
}

module "cloud_router" {
  source  = "terraform-google-modules/cloud-router/google"
  version = "~> 0.4"

  name    = "nat-router"
  project = "aqueous-freedom-348421"
  region  = "us-central1"
  network = module.vpc.network_name
  nats = [
    {
      name                               = "nat-gateway"
      nat_ip_allocate_option             = "AUTO_ONLY"
      source_subnetwork_ip_ranges_to_nat = "LIST_OF_SUBNETWORKS"
      subnetworks = [
        {
          name                    = "private-sn"
          source_ip_ranges_to_nat = ["ALL_IP_RANGES"]
        },
        {
          name                    = "public-sn"
          source_ip_ranges_to_nat = ["ALL_IP_RANGES"]
        }
      ]
    }
  ]
}

resource "google_compute_instance" "vm_instance" {
  name         = "terraform-public-instance"
  machine_type = "e2-micro"

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2204-lts"
    }
  }

  network_interface {
    # A default network is created for all GCP projects
    network    = module.vpc.network_name
    subnetwork = "public-sn"
    # Remove public IP by hashing 'access_config'
    # access_config {
    # }
  }

  service_account {
    email  = google_service_account.final-cluster-admin.email
    scopes = ["cloud-platform"]
  }

  depends_on = [
    module.vpc
  ]
}

# firewall resource
resource "google_compute_firewall" "ssh-rule-final" {
  name    = "ssh-rule-final"
  network = "final-task-vpc"

  allow {
    protocol = "tcp"
    # Allow all ports on tcp
    # ports    = ["22"]
  }

  source_ranges = ["0.0.0.0/0"]

  depends_on = [
    module.vpc
  ]
}

# first service account & bindings
resource "google_service_account" "final-cluster-admin" {
  account_id   = "cluster-admin"
  display_name = "final-k8s-admin"
}
resource "google_project_iam_member" "final-admin-binding" {
  project = "aqueous-freedom-348421"
  role    = "roles/container.admin"
  member  = "serviceAccount:${google_service_account.final-cluster-admin.email}"
}

# second service account & bindings
resource "google_service_account" "final-node-accounts" {
  account_id   = "node-acc"
  display_name = "node-acc"
}
resource "google_project_iam_member" "final-node-binding" {
  project = "aqueous-freedom-348421"
  role    = "roles/storage.objectViewer"
  member  = "serviceAccount:${google_service_account.final-node-accounts.email}"
}

# Moi un clusters
resource "google_container_cluster" "cluster" {
  name                     = "final-cluster"
  location                 = "us-central1"
  remove_default_node_pool = true
  initial_node_count       = 1
  network                  = "final-task-vpc"
  subnetwork               = "private-sn"

  node_locations = [
    "us-central1-b"
  ]
  master_authorized_networks_config {
    cidr_blocks {
      cidr_block   = "10.0.0.0/24"
      display_name = "managment-cidr"
    }
  }

  ip_allocation_policy {

  }

  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = true
    master_ipv4_cidr_block  = "192.168.1.0/28"
  }

  depends_on = [
    module.vpc
  ]
}

resource "google_container_node_pool" "nodePool" {
  name       = "final-node-pool"
  location   = "us-central1"
  cluster    = google_container_cluster.cluster.name
  node_count = 3

  node_config {
    preemptible  = true
    machine_type = "e2-medium"

    service_account = google_service_account.final-node-accounts.email
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]
  }
  depends_on = [
    module.vpc
  ]
}

# resource "google_compute_instance" "vm_private_instance" {
#   name         = "terraform-private-instance"
#   machine_type = "e2-micro"
#   tags = ["allow-rules-final"]
#   boot_disk {
#     initialize_params {
#       image = "debian-cloud/debian-9"
#     }
#   }

#   network_interface {
#     # A default network is created for all GCP projects
#     network = module.vpc.network_name
#     subnetwork  = "private-sn"
#   }
# }
