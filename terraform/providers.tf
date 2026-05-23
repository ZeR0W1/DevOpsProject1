terraform {
  # Pin Terraform and provider versions to keep deployments reproducible
  # across local machines and CI environments.
  required_version = "> 1.11.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }

    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

provider "aws" {
  # All resources in this stack are created in the configured AWS region.
  region = var.aws_region
}