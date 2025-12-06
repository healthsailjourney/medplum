terraform {
  required_version = ">= 1.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
}

# VPC Network
resource "google_compute_network" "medplum_vpc" {
  name                    = "medplum-dev-vpc"
  auto_create_subnetworks = false
}

# Subnet
resource "google_compute_subnetwork" "medplum_subnet" {
  name          = "medplum-dev-subnet"
  ip_cidr_range = "10.0.1.0/24"
  region        = var.region
  network       = google_compute_network.medplum_vpc.id
}

# Firewall Rules
resource "google_compute_firewall" "medplum_ssh" {
  name    = "medplum-dev-allow-ssh"
  network = google_compute_network.medplum_vpc.name

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = var.allowed_ssh_cidr
  target_tags   = ["medplum-dev"]
}

resource "google_compute_firewall" "medplum_apps" {
  name    = "medplum-dev-allow-apps"
  network = google_compute_network.medplum_vpc.name

  allow {
    protocol = "tcp"
    ports    = ["3000", "8080", "8103"]
  }

  source_ranges = var.allowed_app_cidr
  target_tags   = ["medplum-dev"]
}

# Static External IP
resource "google_compute_address" "medplum_static_ip" {
  name = "medplum-dev-static-ip"
}

# Compute Instance
resource "google_compute_instance" "medplum_dev" {
  name         = "medplum-dev-instance"
  machine_type = var.machine_type
  zone         = var.zone

  tags = ["medplum-dev"]

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2204-lts"
      size  = var.disk_size
      type  = "pd-ssd"
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.medplum_subnet.id

    access_config {
      nat_ip = google_compute_address.medplum_static_ip.address
    }
  }

  metadata = {
    ssh-keys = "${var.ssh_user}:${file(var.ssh_public_key_path)}"
  }

  metadata_startup_script = templatefile("${path.module}/startup_script.sh", {
    github_repo = var.github_repo
  })

  service_account {
    scopes = ["cloud-platform"]
  }

  labels = {
    environment = "development"
    project     = "medplum"
  }
}
