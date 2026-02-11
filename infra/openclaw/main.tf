terraform {
  required_version = ">= 1.5.0"

  backend "gcs" {
    bucket = "openclaw-tfstate-fin45-483402"
    prefix = "openclaw-gateway"
  }

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.10.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}
