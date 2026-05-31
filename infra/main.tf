terraform {
  required_version = ">= 1.6"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }

  # Backend local por padrão. Antes de mais de uma pessoa rodar `terraform
  # apply`, migrar pra GCS pra evitar corrupção de state concorrente:
  #
  #   backend "gcs" {
  #     bucket = "runnin-494520-tfstate"
  #     prefix = "infra"
  #   }
  #
  # Criar o bucket uma vez:
  #   gsutil mb -p runnin-494520 -l southamerica-east1 \
  #     gs://runnin-494520-tfstate
  #   gsutil versioning set on gs://runnin-494520-tfstate
}

provider "google" {
  project = var.project_id
  region  = var.region
}
