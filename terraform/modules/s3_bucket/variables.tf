variable "bucket_name" {
  description = "S3 bucket name for machine catalog synchronization"
  type        = string
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