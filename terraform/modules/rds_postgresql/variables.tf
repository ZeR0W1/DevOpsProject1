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

variable "db_username" {
  description = "PostgreSQL master username"
  type        = string
}

variable "db_password_wo" {
  description = "Ephemeral PostgreSQL master password passed to the RDS write-only password argument"
  type        = string
  sensitive   = true
  ephemeral   = true
}

variable "db_engine_version" {
  description = "PostgreSQL engine version"
  type        = string
}

variable "db_instance_class" {
  description = "RDS instance class"
  type        = string
}

variable "allocated_storage" {
  description = "Allocated RDS storage in GB"
  type        = number
}

variable "subnet_ids" {
  description = "Subnet IDs used by the DB subnet group"
  type        = list(string)
}

variable "security_group_ids" {
  description = "Security group IDs attached to the RDS instance"
  type        = list(string)
}

variable "name_prefix" {
  description = "Prefix used to namespace RDS resource names"
  type        = string
}

variable "environment" {
  description = "Environment label for tagging"
  type        = string
}

variable "common_tags" {
  description = "Base tags applied to RDS resources"
  type        = map(string)
  default     = {}
}