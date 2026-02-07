output "service_url" {
  description = "OpenClaw Cloud Run service URL"
  value       = google_cloud_run_v2_service.openclaw.uri
}

output "brain_bucket" {
  description = "GCS bucket for prompts/memory"
  value       = google_storage_bucket.brain.name
}

output "sessions_bucket" {
  description = "GCS bucket for WhatsApp sessions"
  value       = google_storage_bucket.sessions.name
}
