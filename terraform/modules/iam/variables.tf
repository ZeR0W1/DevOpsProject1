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

variable "eks_oidc_provider_arn" {
  description = "OIDC provider ARN for the EKS cluster, used for IRSA trust relationships"
  type        = string
  default     = ""
}

variable "eks_oidc_issuer_url" {
  description = "OIDC issuer URL for the EKS cluster, used when building IRSA trust conditions"
  type        = string
  default     = ""
}

variable "worker_irsa_namespace" {
  description = "Kubernetes namespace of the worker service account for IRSA"
  type        = string
  default     = "devops-app"
}

variable "worker_irsa_service_account_name" {
  description = "Kubernetes service account name used by the worker for IRSA"
  type        = string
  default     = "worker-sa"
}
