variable "vpc_cidr" {
  description = "CIDR block for the project VPC"
  type        = string
}

variable "admin_cidr" {
  description = "Admin IP/CIDR allowed for direct PostgreSQL access"
  type        = string
}

variable "availability_zones" {
  description = "Availability zones used for Kubernetes public/private subnets"
  type        = list(string)
}

variable "subnet_newbits" {
  description = "Additional prefix bits used by cidrsubnet when deriving subnet CIDRs from vpc_cidr"
  type        = number
  default     = 8
}

# Kubernetes-first network layout:
# - public subnets host internet-facing entry points such as an AWS Load Balancer
#   or ingress controller load balancer, and also host NAT Gateway placement.
# - private subnets host EKS worker nodes and private AWS dependencies such as RDS.
# The defaults derive /24s from the project VPC when subnet_newbits = 8.
variable "public_subnet_netnums" {
  description = "Netnum indexes for public subnet CIDR derivation"
  type        = list(number)
  default     = [10, 11]
}

variable "private_subnet_netnums" {
  description = "Netnum indexes for private subnet CIDR derivation"
  type        = list(number)
  default     = [20, 21]
}

# Private EKS nodes need outbound access for image pulls and AWS/API calls.
# NAT Gateway provides that while keeping nodes out of public subnets.
variable "enable_nat_gateway" {
  description = "Whether to create NAT Gateway routing for private subnets"
  type        = bool
  default     = true
}

variable "name_prefix" {
  description = "Prefix used to namespace networking resource names"
  type        = string
}

variable "environment" {
  description = "Environment label for tagging"
  type        = string
}

variable "common_tags" {
  description = "Base tags applied to networking resources"
  type        = map(string)
  default     = {}
}