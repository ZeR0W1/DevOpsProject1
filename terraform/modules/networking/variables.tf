variable "vpc_cidr" {
  description = "CIDR block for the project VPC"
  type        = string
}

variable "admin_cidr" {
  description = "Admin IP/CIDR allowed for direct PostgreSQL access"
  type        = string
}

variable "enable_ssh_ingress" {
  description = "Whether to allow SSH ingress (22/tcp) from admin_cidr to app instances"
  type        = bool
  default     = false
}

variable "availability_zones" {
  description = "Availability zones used for app and DB subnets (first = app, second = db)"
  type        = list(string)
}

variable "subnet_newbits" {
  description = "Additional prefix bits used by cidrsubnet when deriving subnet CIDRs from vpc_cidr"
  type        = number
  default     = 8
}

variable "app_subnet_netnum" {
  description = "Netnum index for app subnet CIDR derivation"
  type        = number
  default     = 1
}

variable "db_subnet_netnum" {
  description = "Netnum index for db subnet CIDR derivation"
  type        = number
  default     = 2
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