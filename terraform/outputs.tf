output "vpc_id" {
  value = module.networking.vpc_id
}

output "rds_endpoint" {
  value = module.rds_postgresql.endpoint
}

output "rds_hostname" {
  value = split(":", module.rds_postgresql.endpoint)[0]
}

output "db_name" {
  value = var.db_name
}

output "db_username" {
  value     = var.db_username
  sensitive = true
}

output "db_port" {
  value = 5432
}

output "s3_bucket_name" {
  description = "Terraform-owned private application content and catalog bucket"
  value       = module.s3_bucket.bucket_name
}

output "sns_topic_arn" {
  value = module.sns_topic.topic_arn
}

output "db_password_secret_name" {
  value = var.db_password_secret_name
}

output "aws_region" {
  value = var.aws_region
}

output "eks_cluster_name" {
  value = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "eks_oidc_provider_arn" {
  value = module.eks.oidc_provider_arn
}

output "worker_role_arn" {
  value = module.iam.worker_role_arn
}

output "public_alb_dns_name" {
  description = "AWS-generated DNS name for the Terraform-owned shared public ALB"
  value       = module.public_alb.dns_name
}

output "public_url" {
  description = "Canonical HTTPS URL for the public frontend"
  value       = module.public_alb.public_url
}

output "jenkins_webhook_url" {
  description = "GitHub webhook URL restricted by the shared ALB listener rules"
  value       = module.public_alb.jenkins_webhook_url
}

output "public_tls_mode" {
  description = "Selected certificate mode for downstream lifecycle orchestration"
  value       = var.public_tls_mode
}

output "self_signed_certificate_arn" {
  description = "Ansible-owned imported certificate ARN used only for dependency-ordered self-signed teardown"
  value       = module.public_alb.self_signed_certificate_arn
}
