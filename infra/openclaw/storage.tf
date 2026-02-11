resource "google_storage_bucket" "brain" {
  name     = "openclaw-brain-${var.project_id}"
  location = var.region

  versioning {
    enabled = true
  }

  lifecycle_rule {
    condition {
      num_newer_versions = 10
    }
    action {
      type = "Delete"
    }
  }

  uniform_bucket_level_access = true
}

resource "google_storage_bucket" "sessions" {
  name     = "openclaw-sessions-${var.project_id}"
  location = var.region

  uniform_bucket_level_access = true
}
