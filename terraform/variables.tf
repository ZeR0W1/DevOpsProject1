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
  description = "Availability zones used for app/db subnet placement (index 0 = app, index 1 = db)"
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

variable "bucket_name" {
  description = "S3 bucket name for machine catalog synchronization"
  type        = string
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

variable "db_storage_type" {
  description = "RDS storage type"
  type        = string
}

variable "db_publicly_accessible" {
  description = "Whether the RDS instance is publicly accessible"
  type        = bool
}

variable "db_skip_final_snapshot" {
  description = "Whether to skip the final snapshot when destroying the DB"
  type        = bool
}

variable "db_backup_retention_period" {
  description = "RDS backup retention period"
  type        = number
}

variable "db_password_secret_name" {
  description = "AWS Secrets Manager secret name used to store the PostgreSQL master password"
  type        = string
}

variable "db_creds_secret_name" {
  description = "AWS Secrets Manager secret name for the existing db_creds secret"
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

variable "enable_ssh_ingress" {
  description = "Enable a shared SSH admin security group and attach it to app instances"
  type        = bool
  default     = false
}