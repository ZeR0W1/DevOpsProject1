variable "bucket_name" {
  description = "S3 bucket name for the machine catalog"
  type        = string
}

variable "sns_topic_arn" {
  description = "SNS topic ARN used by the worker"
  type        = string
}

variable "eks_cluster_arn" {
  description = "EKS cluster ARN that the Jenkins deployer may describe"
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
