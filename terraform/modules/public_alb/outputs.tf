output "dns_name" {
  description = "AWS-generated DNS name of the shared public ALB"
  value       = aws_lb.public.dns_name
}

output "public_url" {
  description = "Canonical HTTPS URL for the public frontend and Jenkins webhook endpoint"
  value       = "https://${var.public_tls_mode == "route53" ? local.normalized_hostname : aws_lb.public.dns_name}"
}

output "jenkins_webhook_url" {
  description = "Restricted GitHub webhook URL routed by the shared ALB"
  value       = "https://${var.public_tls_mode == "route53" ? local.normalized_hostname : aws_lb.public.dns_name}/github-webhook/"
}

output "self_signed_certificate_arn" {
  description = "Ansible-owned imported certificate ARN returned only for dependency-ordered self-signed teardown"
  value       = var.public_tls_mode == "self_signed" ? var.public_imported_certificate_arn : null
}