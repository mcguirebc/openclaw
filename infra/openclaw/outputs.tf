output "vm_external_ip" {
  description = "External IP of the OpenClaw gateway VM"
  value       = google_compute_address.openclaw.address
}

output "gateway_url" {
  description = "HTTPS URL for the gateway (point DNS A record to vm_external_ip)"
  value       = "https://${var.domain}"
}

output "brain_bucket" {
  description = "GCS bucket for prompts/memory"
  value       = google_storage_bucket.brain.name
}

output "sessions_bucket" {
  description = "GCS bucket for WhatsApp sessions"
  value       = google_storage_bucket.sessions.name
}
