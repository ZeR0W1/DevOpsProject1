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
