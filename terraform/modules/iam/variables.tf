variable "bucket_name" {
  description = "S3 bucket name for the machine catalog"
  type        = string
}

variable "sns_topic_arn" {
  description = "SNS topic ARN used by the worker"
  type        = string
}

variable "db_password_secret_name" {
  description = "Secrets Manager secret name that stores the PostgreSQL master password"
  type        = string
}

variable "name_prefix" {
  description = "Prefix used to namespace IAM resource names"
  type        = string
}

variable "environment" {
  description = "Environment label for tagging"
  type        = string
}

variable "common_tags" {
  description = "Base tags applied to IAM resources"
  type        = map(string)
  default     = {}
}