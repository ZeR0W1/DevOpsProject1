variable "topic_name" {
  description = "SNS topic name used by the worker"
  type        = string
}

variable "subscription_email" {
  description = "Email subscription endpoint for SNS notifications"
  type        = string
}

variable "name_prefix" {
  description = "Prefix used to namespace SNS resource names"
  type        = string
}

variable "environment" {
  description = "Environment label for tagging"
  type        = string
}

variable "common_tags" {
  description = "Base tags applied to SNS resources"
  type        = map(string)
  default     = {}
}