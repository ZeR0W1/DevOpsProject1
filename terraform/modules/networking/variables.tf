variable "vpc_id" {
  description = "VPC ID for the project security groups"
  type        = string
}

variable "admin_cidr" {
  description = "Admin IP/CIDR allowed for direct PostgreSQL access"
  type        = string
}

variable "public_subnet_id" {
  description = "Subnet ID used by the EC2 instances"
  type        = string
}

variable "db_subnet_id" {
  description = "Additional subnet used in the DB subnet group"
  type        = string
}

variable "public_availability_zone" {
  description = "Availability zone of the public subnet"
  type        = string
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