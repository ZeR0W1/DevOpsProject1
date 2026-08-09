variable "bucket_name" {
  description = "Globally unique private S3 bucket name for application content and machine catalog synchronization"
  type        = string

  validation {
    condition = (
      length(var.bucket_name) >= 3 &&
      length(var.bucket_name) <= 63 &&
      can(regex("^[a-z0-9][a-z0-9.-]*[a-z0-9]$", var.bucket_name)) &&
      !can(regex("\\.\\.", var.bucket_name)) &&
      !can(regex("^[0-9]+\\.[0-9]+\\.[0-9]+\\.[0-9]+$", var.bucket_name))
    )
    error_message = "bucket_name must be a valid 3-63 character lowercase S3 bucket name and must not be formatted as an IPv4 address."
  }
}

variable "name_prefix" {
  description = "Prefix used to namespace S3-related resource names"
  type        = string
}

variable "environment" {
  description = "Environment label for tagging"
  type        = string
}

variable "common_tags" {
  description = "Base tags applied to S3 resources"
  type        = map(string)
  default     = {}
}