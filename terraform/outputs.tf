output "vpc_id" {
  value = module.networking.vpc_id
}

output "frontend_public_ip" {
  value = module.ec2.frontend_public_ip
}

output "backend_private_ip" {
  value = module.ec2.backend_private_ip
}

output "backend_public_ip" {
  value = module.ec2.backend_public_ip
}

output "worker_private_ip" {
  value = module.ec2.worker_private_ip
}

output "worker_public_ip" {
  value = module.ec2.worker_public_ip
}

output "rds_endpoint" {
  value = module.rds_postgresql.endpoint
}

output "s3_bucket_name" {
  value = module.s3_bucket.bucket_name
}

output "sns_topic_arn" {
  value = module.sns_topic.topic_arn
}

output "worker_launch_template_id" {
  value = module.ec2.worker_launch_template_id
}