variable "project_id" {
  description = "GCP project id (e.g., fin45-483402)"
  type        = string
}

variable "region" {
  description = "Primary region for Cloud Run and storage"
  type        = string
  default     = "us-west1"
}

variable "service_name" {
  description = "Cloud Run service name"
  type        = string
  default     = "openclaw-gateway"
}

variable "image" {
  description = "Container image URI (Artifact Registry)"
  type        = string
}

variable "min_instances" {
  description = "Minimum Cloud Run instances (WhatsApp requires >= 1)"
  type        = number
  default     = 1
}

variable "max_instances" {
  description = "Maximum Cloud Run instances"
  type        = number
  default     = 2
}

variable "cpu" {
  description = "CPU limit"
  type        = string
  default     = "2"
}

variable "memory" {
  description = "Memory limit"
  type        = string
  default     = "2Gi"
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
