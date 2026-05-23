variable "ami_id" {
  description = "AMI ID used by the EC2 instances"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
}

variable "key_name" {
  description = "EC2 key pair name"
  type        = string
}

variable "subnet_id" {
  description = "Subnet ID used by the EC2 instances"
  type        = string
}

variable "frontend_security_group_id" {
  description = "Security group ID for the frontend instance"
  type        = string
}

variable "backend_security_group_id" {
  description = "Security group ID for the backend instance"
  type        = string
}

variable "worker_security_group_id" {
  description = "Security group ID for the worker instance"
  type        = string
}

variable "instance_profile_name" {
  description = "IAM instance profile name for the EC2 instances"
  type        = string
}

variable "frontend_name" {
  description = "Name tag for the frontend instance"
  type        = string
}

variable "backend_name" {
  description = "Name tag for the backend instance"
  type        = string
}

variable "worker_name" {
  description = "Name tag for the worker instance"
  type        = string
}

variable "public_availability_zone" {
  description = "Availability zone for the worker launch template placement"
  type        = string
}

variable "name_prefix" {
  description = "Prefix used to namespace EC2-related resource names"
  type        = string
}

variable "environment" {
  description = "Environment label for tagging"
  type        = string
}

variable "common_tags" {
  description = "Base tags applied to EC2 resources"
  type        = map(string)
  default     = {}
}