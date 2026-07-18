terraform {
  required_version = ">= 1.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }

  backend "local" {}
}

provider "google" {
  project = var.project_id
  region  = var.region
}

variable "project_id" {
  type    = string
  default = "yok-ai-2026"
}

variable "region" {
  type    = string
  default = "asia-northeast1"
}

variable "service_name" {
  type    = string
  default = "bubblevoice"
}

variable "db_url" {
  type      = string
  sensitive = true
}

variable "secret_key_base" {
  type      = string
  sensitive = true
}

variable "gcs_bucket_name" {
  type    = string
  default = "bubblevoice-uploads"
}

# Artifact Registry for Docker images
resource "google_artifact_registry_repository" "app" {
  location      = var.region
  repository_id = var.service_name
  description   = "Docker images for ${var.service_name}"
  format        = "DOCKER"
}

# Cloud Run service
resource "google_cloud_run_v2_service" "app" {
  name     = var.service_name
  location = var.region

  template {
    scaling {
      min_instance_count = 0
      max_instance_count = 2
    }

    containers {
      image = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.app.repository_id}/${var.service_name}:latest"

      ports {
        container_port = 4000
      }

      resources {
        limits = {
          cpu    = "1"
          memory = "512Mi"
        }
      }

      env {
        name  = "DATABASE_URL"
        value = var.db_url
      }

      env {
        name  = "SECRET_KEY_BASE"
        value = var.secret_key_base
      }

      env {
        name  = "PHX_HOST"
        value = "${google_cloud_run_v2_service.app.name}-${google_cloud_run_v2_service.app.location}.run.app"
      }

      env {
        name  = "PHX_SERVER"
        value = "true"
      }

      env {
        name  = "GCS_BUCKET"
        value = google_storage_bucket.uploads.name
      }

      env {
        name  = "PORT"
        value = "4000"
      }
    }

    service_account = google_service_account.cloudrun.email
  }

  traffic {
    type    = "TRAFFIC_TARGET_ALLOCATION_TYPE_LATEST"
    percent = 100
  }

  depends_on = [google_project_iam_member.cloudrun_sa]
}

# Service account for Cloud Run
resource "google_service_account" "cloudrun" {
  account_id   = "${var.service_name}-sa"
  display_name = "Cloud Run service account for ${var.service_name}"
}

# Grant Cloud Run SA access to GCS
resource "google_project_iam_member" "cloudrun_sa" {
  project = var.project_id
  role    = "roles/storage.objectAdmin"
  member  = "serviceAccount:${google_service_account.cloudrun.email}"
}

# Allow unauthenticated access
resource "google_cloud_run_v2_service_iam_member" "public" {
  project  = var.project_id
  location = var.region
  name     = google_cloud_run_v2_service.app.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}

# GCS bucket for voice uploads
resource "google_storage_bucket" "uploads" {
  name          = var.gcs_bucket_name
  location      = var.region
  storage_class = "STANDARD"
  uniform_bucket_level_access = true

  versioning {
    enabled = false
  }

  lifecycle_rule {
    condition {
      age = 365
    }
    action {
      type = "Delete"
    }
  }
}

# Public read access for GCS bucket
resource "google_storage_bucket_iam_member" "public_read" {
  bucket = google_storage_bucket.uploads.name
  role   = "roles/storage.objectViewer"
  member = "allUsers"
}

output "service_url" {
  value = google_cloud_run_v2_service.app.uri
}

output "gcs_bucket" {
  value = google_storage_bucket.uploads.name
}

output "service_account" {
  value = google_service_account.cloudrun.email
}
