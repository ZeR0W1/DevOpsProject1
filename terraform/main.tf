// Root composition file that wires shared inputs into reusable infrastructure modules.
module "networking" {
  source = "./modules/networking"

  # Create project networking primitives directly in Terraform.
  vpc_cidr           = var.vpc_cidr
  admin_cidr         = local.db_creds_secret.admin_cidr
  enable_ssh_ingress = var.enable_ssh_ingress
  availability_zones = var.availability_zones
  subnet_newbits     = var.subnet_newbits
  app_subnet_netnum  = var.app_subnet_netnum
  db_subnet_netnum   = var.db_subnet_netnum
  name_prefix        = var.name_prefix
  environment        = var.environment
  common_tags        = var.common_tags
}

module "s3_bucket" {
  source = "./modules/s3_bucket"

  # Shared bucket used by the application workflow.
  bucket_name = var.bucket_name
  name_prefix = var.name_prefix
  environment = var.environment
  common_tags = var.common_tags
}

module "sns_topic" {
  source = "./modules/sns_topic"

  # Notification topic used for worker and operational alerts.
  topic_name         = var.worker_topic_name
  subscription_email = local.db_creds_secret.admin_email
  name_prefix        = var.name_prefix
  environment        = var.environment
  common_tags        = var.common_tags
}

module "services" {
  source = "./modules/services"

  # Operational monitoring resources such as billing alarms.
  billing_alarm_name = var.billing_alarm_name
  sns_topic_arn      = module.sns_topic.topic_arn
  name_prefix        = var.name_prefix
  environment        = var.environment
  common_tags        = var.common_tags
}

module "iam" {
  source = "./modules/iam"

  # Instance profile permissions for EC2 access to S3 and SNS.
  bucket_name             = module.s3_bucket.bucket_name
  sns_topic_arn           = module.sns_topic.topic_arn
  db_password_secret_name = var.db_password_secret_name
  name_prefix             = var.name_prefix
  environment             = var.environment
  common_tags             = var.common_tags
}

module "rds_postgresql" {
  source = "./modules/rds_postgresql"

  # Ensure the generated password has been written to Secrets Manager
  # before provisioning the database that uses the same ephemeral value.
  depends_on = [aws_secretsmanager_secret_version.db_password]

  # Database is placed in the networking module subnets and protected by its DB SG.
  db_subnet_group_name = var.db_subnet_group_name
  db_identifier        = var.db_identifier
  db_name              = var.db_name
  db_username          = local.db_creds_secret.db_username
  # Use the ephemeral password value so Terraform does not persist the plaintext in state.
  db_password_wo          = ephemeral.random_password.db_password.result
  db_engine_version       = var.db_engine_version
  db_instance_class       = var.db_instance_class
  allocated_storage       = var.db_allocated_storage
  storage_type            = var.db_storage_type
  publicly_accessible     = var.db_publicly_accessible
  skip_final_snapshot     = var.db_skip_final_snapshot
  backup_retention_period = var.db_backup_retention_period
  subnet_ids              = module.networking.db_subnet_ids
  security_group_ids      = module.networking.db_security_group_ids
  name_prefix             = var.name_prefix
  environment             = var.environment
  common_tags             = var.common_tags
}

module "ec2" {
  source = "./modules/ec2"

  # Application tier instances share networking outputs and IAM profile from other modules.
  ami_id                      = var.ami_id
  instance_type               = var.instance_type
  key_name                    = var.key_name
  subnet_id                   = module.networking.app_subnet_id
  frontend_security_group_id  = module.networking.frontend_security_group_id
  backend_security_group_id   = module.networking.backend_security_group_id
  worker_security_group_id    = module.networking.worker_security_group_id
  ssh_admin_security_group_id = module.networking.ssh_admin_security_group_id
  instance_profile_name       = module.iam.instance_profile_name
  frontend_name               = var.frontend_name
  backend_name                = var.backend_name
  worker_name                 = var.worker_name
  public_availability_zone    = module.networking.app_availability_zone
  name_prefix                 = var.name_prefix
  environment                 = var.environment
  common_tags                 = var.common_tags
}