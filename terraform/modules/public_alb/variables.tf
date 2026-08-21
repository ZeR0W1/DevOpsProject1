variable "vpc_id" {
  description = "VPC hosting the shared public ALB and EKS nodes"
  type        = string
}

variable "public_subnet_ids" {
  description = "Public subnets used by the internet-facing ALB"
  type        = list(string)
}

variable "node_autoscaling_group_name" {
  description = "EKS managed-node Auto Scaling group attached to both ALB target groups"
  type        = string
}

variable "node_alb_security_group_id" {
  description = "Additional EKS node security group receiving ALB-only NodePort ingress"
  type        = string
}

variable "frontend_node_port" {
  description = "Fixed frontend Kubernetes NodePort"
  type        = number
}

variable "jenkins_webhook_node_port" {
  description = "Fixed Jenkins webhook Kubernetes NodePort"
  type        = number
}

variable "github_hooks_ipv4_cidrs" {
  description = "Current GitHub hooks IPv4 CIDRs allowed by the Jenkins webhook listener rules"
  type        = list(string)
}

variable "public_tls_mode" {
  description = "Shared ALB certificate mode: route53 or self_signed"
  type        = string
}

variable "public_hostname" {
  description = "Route 53 hostname used for the trusted public endpoint"
  type        = string
  default     = null
  nullable    = true
}

variable "public_route53_zone_id" {
  description = "Existing Route 53 public hosted zone used for trusted certificate validation and the ALB alias"
  type        = string
  default     = null
  nullable    = true
}

variable "public_imported_certificate_arn" {
  description = "Ansible-imported self-signed ACM certificate ARN"
  type        = string
  default     = null
  nullable    = true
}

variable "name_prefix" {
  description = "Prefix used for ALB resource names"
  type        = string
}

variable "environment" {
  description = "Environment label for naming and tags"
  type        = string
}

variable "common_tags" {
  description = "Base tags applied to shared ALB resources"
  type        = map(string)
  default     = {}
}