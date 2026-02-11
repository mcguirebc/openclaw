# Static external IP for the gateway (Telegram webhook, HTTPS)
resource "google_compute_address" "openclaw" {
  name   = "openclaw-gateway-ip"
  region = var.region
}

# Firewall: allow HTTPS, HTTP (for Let's Encrypt), and SSH
resource "google_compute_firewall" "openclaw" {
  name    = "openclaw-gateway"
  network = "default"

  allow {
    protocol = "tcp"
    ports    = ["22", "80", "443"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["openclaw-gateway"]
}

# Persistent disk for session data (survives VM restarts)
resource "google_compute_disk" "openclaw_data" {
  name = "openclaw-gateway-data"
  type = "pd-standard"
  zone = var.zone
  size = var.disk_size_gb

  labels = {
    role = "openclaw-sessions"
  }
}

# GCE VM for the OpenClaw gateway
resource "google_compute_instance" "openclaw" {
  name         = var.vm_name
  machine_type = var.machine_type
  zone         = var.zone
  tags         = ["openclaw-gateway"]

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12"
      size  = 20
    }
  }

  attached_disk {
    source      = google_compute_disk.openclaw_data.id
    device_name = "openclaw-data"
  }

  network_interface {
    network = "default"
    access_config {
      nat_ip = google_compute_address.openclaw.address
    }
  }

  service_account {
    email  = google_service_account.openclaw.email
    scopes = ["cloud-platform"]
  }

  metadata_startup_script = templatefile("${path.module}/startup.sh.tpl", {
    project_id                  = var.project_id
    openclaw_config_secret      = var.openclaw_config_secret
    openclaw_config_secret_ver  = var.openclaw_config_secret_version
    domain                      = var.domain
    brain_bucket                = google_storage_bucket.brain.name
    sessions_bucket             = google_storage_bucket.sessions.name
    image                       = var.image
    openclaw_config_placeholder = join("", ["$", "{", "OPENCLAW_CONFIG", "}"])
  })
}
