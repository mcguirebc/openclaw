resource "google_cloud_run_v2_service" "openclaw" {
  name     = var.service_name
  location = var.region

  template {
    service_account = google_service_account.openclaw.email

    scaling {
      min_instance_count = var.min_instances
      max_instance_count = var.max_instances
    }

    containers {
      image = var.image

      resources {
        limits = {
          cpu    = var.cpu
          memory = var.memory
        }
      }

      env {
        name  = "PORT"
        value = "8080"
      }

      env {
        name  = "OPENCLAW_STATE_DIR"
        value = "/data/openclaw"
      }

      env {
        name  = "OPENCLAW_CONFIG_PATH"
        value = "/data/openclaw/openclaw.json"
      }

      env {
        name  = "OPENCLAW_CONFIG_TEMPLATE"
        value = "/app/infra/openclaw/openclaw.json"
      }

      env {
        name  = "OPENCLAW_BRAIN_BUCKET"
        value = google_storage_bucket.brain.name
      }

      env {
        name  = "OPENCLAW_SESSIONS_BUCKET"
        value = google_storage_bucket.sessions.name
      }

      env {
        name = "OPENCLAW_CONFIG"
        value_source {
          secret_key_ref {
            secret  = var.openclaw_config_secret
            version = var.openclaw_config_secret_version
          }
        }
      }

      volume_mounts {
        name       = "sessions"
        mount_path = "/data/openclaw"
      }
    }

    volumes {
      name = "sessions"
      gcs {
        bucket    = google_storage_bucket.sessions.name
        read_only = false
      }
    }
  }

  traffic {
    type    = "TRAFFIC_TARGET_ALLOCATION_TYPE_LATEST"
    percent = 100
  }
}
