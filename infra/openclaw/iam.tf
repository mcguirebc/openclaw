resource "google_service_account" "openclaw" {
  account_id   = "openclaw-gateway"
  display_name = "OpenClaw Gateway"
}

resource "google_storage_bucket_iam_member" "brain_admin" {
  bucket = google_storage_bucket.brain.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.openclaw.email}"
}

resource "google_storage_bucket_iam_member" "sessions_admin" {
  bucket = google_storage_bucket.sessions.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.openclaw.email}"
}

data "google_secret_manager_secret" "openclaw_config" {
  secret_id = var.openclaw_config_secret
}

resource "google_secret_manager_secret_iam_member" "openclaw_config_access" {
  secret_id = data.google_secret_manager_secret.openclaw_config.id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.openclaw.email}"
}

# Cloud Logging and Monitoring for the GCE VM
resource "google_project_iam_member" "openclaw_logging" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.openclaw.email}"
}

resource "google_project_iam_member" "openclaw_monitoring" {
  project = var.project_id
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${google_service_account.openclaw.email}"
}
