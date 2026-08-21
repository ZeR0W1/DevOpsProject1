variable "aws_region" {
  description = "AWS region for the project infrastructure"
  type        = string
  default     = "us-east-1"
}

variable "vpc_cidr" {
  description = "CIDR block for the Terraform-managed project VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "Availability zones used for Kubernetes public/private subnet placement"
  type        = list(string)
}

variable "subnet_newbits" {
  description = "Additional prefix bits used by cidrsubnet when deriving subnet CIDRs from vpc_cidr"
  type        = number
  default     = 8
}

variable "public_subnet_netnums" {
  description = "Netnum indexes for public subnet CIDR derivation. Public subnets support the temporary frontend LoadBalancer and NAT Gateway placement."
  type        = list(number)
  default     = [10, 11]
}

variable "private_subnet_netnums" {
  description = "Netnum indexes for private subnet CIDR derivation. Private subnets are intended for EKS worker nodes and RDS."
  type        = list(number)
  default     = [20, 21]
}

variable "enable_nat_gateway" {
  description = "Enable NAT Gateway routing so private EKS nodes can reach image registries and AWS APIs without public IPs"
  type        = bool
  default     = true
}

variable "eks_cluster_name" {
  description = "Name of the Terraform-managed EKS cluster"
  type        = string
  default     = ""
}

variable "eks_cluster_version" {
  description = "Kubernetes version for the EKS control plane"
  type        = string
  default     = "1.34"
}

variable "eks_node_instance_types" {
  description = "EC2 instance types for the EKS managed node group"
  type        = list(string)
  default     = ["t3.medium"]
}

variable "eks_node_desired_size" {
  description = "Desired number of EKS worker nodes"
  type        = number
  default     = 3
}

variable "eks_node_min_size" {
  description = "Minimum number of EKS worker nodes"
  type        = number
  default     = 3
}

variable "eks_node_max_size" {
  description = "Maximum number of EKS worker nodes"
  type        = number
  default     = 4
}

variable "public_tls_mode" {
  description = "TLS certificate mode for the shared public ALB: Route 53-validated ACM certificate or an Ansible-imported self-signed certificate"
  type        = string
  default     = "self_signed"

  validation {
    condition     = contains(["route53", "self_signed"], var.public_tls_mode)
    error_message = "public_tls_mode must be either route53 or self_signed."
  }
}

variable "public_hostname" {
  description = "Public DNS hostname for the shared ALB; required only when public_tls_mode is route53"
  type        = string
  default     = null
  nullable    = true

  validation {
    condition = var.public_hostname == null || (
      length(var.public_hostname) <= 253 &&
      can(regex(
        "^(?:[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\\.)+[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\\.?$",
        var.public_hostname
      ))
    )
    error_message = "public_hostname must be null or a valid lowercase fully qualified DNS hostname."
  }
}

variable "public_route53_zone_id" {
  description = "Existing Route 53 public hosted zone ID used for ACM validation and the shared ALB alias; required only when public_tls_mode is route53"
  type        = string
  default     = null
  nullable    = true

  validation {
    condition     = var.public_route53_zone_id == null || can(regex("^Z[A-Z0-9]+$", var.public_route53_zone_id))
    error_message = "public_route53_zone_id must be null or a valid Route 53 hosted zone ID beginning with Z."
  }
}

variable "public_imported_certificate_arn" {
  description = "ARN of the self-signed ACM certificate imported by Ansible; required only when public_tls_mode is self_signed"
  type        = string
  default     = null
  nullable    = true

  validation {
    condition = var.public_imported_certificate_arn == null || can(regex(
      "^arn:aws:acm:[a-z0-9-]+:[0-9]{12}:certificate/[0-9a-f-]+$",
      var.public_imported_certificate_arn
    ))
    error_message = "public_imported_certificate_arn must be null or a valid ACM certificate ARN."
  }
}

variable "github_hooks_ipv4_cidrs" {
  description = "Current GitHub hooks IPv4 CIDRs allowed to reach the exact Jenkins webhook listener rule; refreshed by Ansible before Terraform runs"
  type        = list(string)

  validation {
    condition = (
      length(var.github_hooks_ipv4_cidrs) > 0 &&
      alltrue([
        for cidr in var.github_hooks_ipv4_cidrs :
        can(cidrhost(cidr, 0)) && !strcontains(cidr, ":")
      ])
    )
    error_message = "github_hooks_ipv4_cidrs must contain at least one valid IPv4 CIDR."
  }
}

variable "frontend_node_port" {
  description = "Fixed Kubernetes NodePort targeted by the shared ALB default frontend route"
  type        = number
  default     = 32081

  validation {
    condition     = var.frontend_node_port >= 30000 && var.frontend_node_port <= 32767
    error_message = "frontend_node_port must be within the Kubernetes NodePort range 30000-32767."
  }
}

variable "jenkins_webhook_node_port" {
  description = "Fixed Kubernetes NodePort targeted only by the shared ALB Jenkins webhook rule"
  type        = number
  default     = 32080

  validation {
    condition     = var.jenkins_webhook_node_port >= 30000 && var.jenkins_webhook_node_port <= 32767
    error_message = "jenkins_webhook_node_port must be within the Kubernetes NodePort range 30000-32767."
  }
}

check "public_tls_inputs" {
  assert {
    condition = (
      var.public_tls_mode == "route53"
      ? var.public_hostname != null && var.public_route53_zone_id != null && var.public_imported_certificate_arn == null
      : var.public_hostname == null && var.public_route53_zone_id == null && var.public_imported_certificate_arn != null
    )
    error_message = "Route 53 mode requires public_hostname and public_route53_zone_id only; self-signed mode requires public_imported_certificate_arn only."
  }
}

check "distinct_public_node_ports" {
  assert {
    condition     = var.frontend_node_port != var.jenkins_webhook_node_port
    error_message = "frontend_node_port and jenkins_webhook_node_port must be different."
  }
}

variable "bucket_name" {
  description = "Optional application S3 bucket name override; when null, Terraform derives a deterministic name from prefix, environment, AWS account ID, and region"
  type        = string
  default     = null
  nullable    = true

  validation {
    condition = var.bucket_name == null || (
      length(var.bucket_name) >= 3 &&
      length(var.bucket_name) <= 63 &&
      can(regex("^[a-z0-9][a-z0-9.-]*[a-z0-9]$", var.bucket_name)) &&
      !can(regex("\\.\\.", var.bucket_name)) &&
      !can(regex("^[0-9]+\\.[0-9]+\\.[0-9]+\\.[0-9]+$", var.bucket_name))
    )
    error_message = "bucket_name must be null or a valid 3-63 character lowercase S3 bucket name that is not formatted as an IPv4 address."
  }
}

variable "worker_topic_name" {
  description = "SNS topic name used by the worker"
  type        = string
}

variable "billing_alarm_name" {
  description = "CloudWatch billing alarm name"
  type        = string
}

variable "db_subnet_group_name" {
  description = "DB subnet group name"
  type        = string
}

variable "db_identifier" {
  description = "RDS instance identifier"
  type        = string
}

variable "db_name" {
  description = "PostgreSQL database name"
  type        = string
}

variable "db_engine_version" {
  description = "PostgreSQL engine version"
  type        = string
}

variable "db_instance_class" {
  description = "RDS instance class"
  type        = string
}

variable "db_allocated_storage" {
  description = "Allocated RDS storage in GB"
  type        = number
}

variable "db_password_secret_name" {
  description = "AWS Secrets Manager secret name used to store the PostgreSQL master password"
  type        = string
}

variable "admin_cidr" {
  description = "Administrator IPv4 CIDR allowed to reach controlled administrative endpoints and the EKS public API"
  type        = string

  sensitive = true

  validation {
    condition     = can(cidrhost(var.admin_cidr, 0)) && can(regex("/32$", var.admin_cidr))
    error_message = "admin_cidr must be a valid IPv4 /32 CIDR."
  }
}

variable "admin_email" {
  description = "Administrator email used for SNS notifications"
  type        = string
  sensitive   = true

  validation {
    condition     = can(regex("^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$", var.admin_email))
    error_message = "admin_email must be a valid email address."
  }
}

variable "db_username" {
  description = "Deterministic PostgreSQL administrator username derived from name_prefix and environment by Ansible"
  type        = string
  sensitive   = true

  validation {
    condition     = can(regex("^[a-z][a-z0-9_]{0,62}$", var.db_username)) && !startswith(var.db_username, "pg_")
    error_message = "db_username must be a valid PostgreSQL identifier up to 63 characters and must not start with pg_."
  }
}

variable "name_prefix" {
  description = "Prefix used in AWS resource names to avoid collisions across environments"
  type        = string
}

variable "environment" {
  description = "Environment label (e.g. dev/staging/prod)"
  type        = string
}

variable "common_tags" {
  description = "Base tags applied to managed resources"
  type        = map(string)
  default     = {}
}