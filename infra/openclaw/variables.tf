variable "project_id" {
  description = "GCP project id (e.g., fin45-483402)"
  type        = string
}

variable "region" {
  description = "Primary region for GCE and storage"
  type        = string
  default     = "us-west1"
}

variable "zone" {
  description = "GCE zone for the VM"
  type        = string
  default     = "us-west1-b"
}

variable "vm_name" {
  description = "GCE instance name"
  type        = string
  default     = "openclaw-gateway"
}

variable "machine_type" {
  description = "GCE machine type"
  type        = string
  default     = "e2-medium"
}

variable "disk_size_gb" {
  description = "Size in GB for persistent data disk"
  type        = number
  default     = 20
}

variable "domain" {
  description = "FQDN for the gateway (Caddy TLS, e.g. gateway.openclaw.ai)"
  type        = string
}

variable "image" {
  description = "Container image URI (e.g. ghcr.io/openclaw/openclaw:deploy or Artifact Registry)"
  type        = string
}

variable "openclaw_config_secret" {
  description = "Secret Manager secret name containing unified JSON config"
  type        = string
  default     = "openclaw-config"
}

variable "openclaw_config_secret_version" {
  description = "Secret Manager version for unified JSON config"
  type        = string
  default     = "latest"
}
