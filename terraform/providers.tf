terraform {
  # Pin Terraform and provider versions to keep deployments reproducible
  # across local machines and CI environments.
  required_version = "> 1.11.0"

  # Store Terraform's infrastructure state in a dedicated S3 bucket after the
  # automated state-bootstrap step. The generated remote-state settings stay out
  # of Git. Locking prevents two Terraform runs from changing state simultaneously.
  backend "s3" {
    use_lockfile = true
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }

    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }

    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}

provider "aws" {
  # All resources in this stack are created in the configured AWS region.
  region = var.aws_region
}

# Account identity is non-secret metadata used to make globally unique,
# deterministic resource names without requiring a manually copied account ID.
data "aws_caller_identity" "current" {}