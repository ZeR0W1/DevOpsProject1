variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
}

variable "cluster_version" {
  description = "Kubernetes version for the EKS control plane"
  type        = string
}

variable "endpoint_public_access_cidrs" {
  description = "CIDR blocks permitted to access the public EKS API endpoint"
  type        = list(string)

  validation {
    condition     = length(var.endpoint_public_access_cidrs) > 0 && alltrue([for cidr in var.endpoint_public_access_cidrs : can(cidrnetmask(cidr))])
    error_message = "endpoint_public_access_cidrs must contain at least one valid CIDR block."
  }
}

variable "enabled_cluster_log_types" {
  description = "Optional EKS control-plane log types sent to CloudWatch Logs; empty disables control-plane logging"
  type        = set(string)
  default     = []

  validation {
    condition = alltrue([
      for log_type in var.enabled_cluster_log_types : contains(
        ["api", "audit", "authenticator", "controllerManager", "scheduler"],
        log_type
      )
    ])
    error_message = "enabled_cluster_log_types contains an unsupported EKS control-plane log type."
  }
}

variable "private_subnet_ids" {
  description = "Private subnet IDs used by the managed node group"
  type        = list(string)

  validation {
    condition     = length(var.private_subnet_ids) >= 2 && alltrue([for subnet_id in var.private_subnet_ids : trimspace(subnet_id) != ""])
    error_message = "private_subnet_ids must contain at least two non-empty subnet IDs."
  }
}

variable "public_subnet_ids" {
  description = "Public subnet IDs included in the EKS control plane VPC config"
  type        = list(string)

  validation {
    condition     = length(var.public_subnet_ids) >= 2 && alltrue([for subnet_id in var.public_subnet_ids : trimspace(subnet_id) != ""])
    error_message = "public_subnet_ids must contain at least two non-empty subnet IDs."
  }
}

variable "vpc_id" {
  description = "VPC ID used for the managed-node load balancer security boundary"
  type        = string

  validation {
    condition     = can(regex("^vpc-[0-9a-f]+$", var.vpc_id))
    error_message = "vpc_id must be a valid VPC ID."
  }
}

variable "node_instance_types" {
  description = "Instance types for the EKS managed node group"
  type        = list(string)

  validation {
    condition     = length(var.node_instance_types) > 0 && alltrue([for instance_type in var.node_instance_types : trimspace(instance_type) != ""])
    error_message = "node_instance_types must contain at least one non-empty EC2 instance type."
  }
}

variable "node_desired_size" {
  description = "Desired EKS node count"
  type        = number

  validation {
    condition     = var.node_desired_size >= 1
    error_message = "node_desired_size must be at least 1."
  }
}

variable "node_min_size" {
  description = "Minimum EKS node count"
  type        = number

  validation {
    condition     = var.node_min_size >= 1
    error_message = "node_min_size must be at least 1."
  }
}

variable "node_max_size" {
  description = "Maximum EKS node count"
  type        = number

  validation {
    condition     = var.node_max_size >= 1
    error_message = "node_max_size must be at least 1."
  }
}

variable "name_prefix" {
  description = "Prefix used for AWS resource names"
  type        = string
}

variable "environment" {
  description = "Environment label for tagging"
  type        = string
}

variable "common_tags" {
  description = "Base tags applied to EKS resources"
  type        = map(string)
  default     = {}
}