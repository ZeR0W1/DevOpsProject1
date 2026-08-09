variable "aws_region" {
  description = "AWS region for the Terraform state bucket"
  type        = string
  default     = "us-east-1"
}

variable "state_bucket_name" {
  description = "Globally unique name for the Terraform state bucket"
  type        = string

  validation {
    condition = (
      length(var.state_bucket_name) >= 3 &&
      length(var.state_bucket_name) <= 63 &&
      can(regex("^[a-z0-9][a-z0-9.-]*[a-z0-9]$", var.state_bucket_name)) &&
      !can(regex("\\.\\.", var.state_bucket_name))
    )
    error_message = "state_bucket_name must be a valid 3-63 character lowercase S3 bucket name."
  }
}

variable "project_name" {
  description = "Project tag applied to remote-state resources"
  type        = string
  default     = "devops-project1"
}

variable "environment" {
  description = "Environment tag applied to remote-state resources"
  type        = string
  default     = "shared"
}

variable "common_tags" {
  description = "Additional tags applied to remote-state resources"
  type        = map(string)
  default     = {}
}