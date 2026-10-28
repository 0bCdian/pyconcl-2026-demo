terraform {
  required_version = ">= 1.8"
  required_providers {
    google = { source = "hashicorp/google", version = "~> 7.0" }
  }
}

provider "google" {
  region = var.region
}

# Budgets are billed to a quota project, which only exists after this root creates it.
provider "google" {
  alias                 = "in_project"
  region                = var.region
  user_project_override = true
  billing_project       = var.project_id
}
