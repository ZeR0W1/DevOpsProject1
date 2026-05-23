variable "billing_alarm_name" {
  description = "CloudWatch billing alarm name"
  type        = string
}

variable "sns_topic_arn" {
  description = "SNS topic ARN used for billing notifications"
  type        = string
}

variable "name_prefix" {
  description = "Prefix used to namespace service resource names"
  type        = string
}

variable "environment" {
  description = "Environment label for tagging"
  type        = string
}

variable "common_tags" {
  description = "Base tags applied to service resources"
  type        = map(string)
  default     = {}
}
