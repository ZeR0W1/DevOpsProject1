// Root composition file that wires shared inputs into reusable infrastructure modules.
locals {
  application_bucket_name = coalesce(
    var.bucket_name,
    "${var.name_prefix}-${var.environment}-app-${data.aws_caller_identity.current.account_id}-${var.aws_region}"
  )
}

module "networking" {
  source = "./modules/networking"

  # Create project networking primitives directly in Terraform.
  vpc_cidr               = var.vpc_cidr
  admin_cidr             = var.admin_cidr
  availability_zones     = var.availability_zones
  subnet_newbits         = var.subnet_newbits
  public_subnet_netnums  = var.public_subnet_netnums
  private_subnet_netnums = var.private_subnet_netnums
  enable_nat_gateway     = var.enable_nat_gateway
  name_prefix            = var.name_prefix
  environment            = var.environment
  common_tags            = var.common_tags
}

module "s3_bucket" {
  source = "./modules/s3_bucket"

  # Terraform always owns the private application content/catalog bucket.
  bucket_name = local.application_bucket_name
  name_prefix = var.name_prefix
  environment = var.environment
  common_tags = var.common_tags
}

module "sns_topic" {
  source = "./modules/sns_topic"

  # Notification topic used for worker and operational alerts.
  topic_name         = var.worker_topic_name
  subscription_email = var.admin_email
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

  # Worker pod AWS permissions are exposed through EKS Pod Identity.
  bucket_name   = local.application_bucket_name
  sns_topic_arn = module.sns_topic.topic_arn
  name_prefix   = var.name_prefix
  environment   = var.environment
  common_tags   = var.common_tags
}

module "eks" {
  source = "./modules/eks"

  cluster_name                 = coalesce(var.eks_cluster_name, "${var.name_prefix}-${var.environment}-eks")
  cluster_version              = var.eks_cluster_version
  endpoint_public_access_cidrs = [var.admin_cidr]
  private_subnet_ids           = module.networking.eks_private_subnet_ids
  public_subnet_ids            = module.networking.eks_public_subnet_ids
  node_instance_types          = var.eks_node_instance_types
  node_desired_size            = var.eks_node_desired_size
  node_min_size                = var.eks_node_min_size
  node_max_size                = var.eks_node_max_size
  name_prefix                  = var.name_prefix
  environment                  = var.environment
  common_tags                  = var.common_tags
}

resource "aws_eks_pod_identity_association" "worker" {
  cluster_name    = module.eks.pod_identity_agent_cluster_name
  namespace       = "devops-app"
  service_account = "worker-sa"
  role_arn        = module.iam.worker_role_arn
}

resource "aws_security_group_rule" "eks_nodes_to_rds" {
  description              = "Allow EKS worker node traffic to PostgreSQL"
  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  security_group_id        = module.networking.db_security_group_ids[0]
  source_security_group_id = module.eks.cluster_security_group_id
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
  db_username          = var.db_username
  # Use the ephemeral password value so Terraform does not persist the plaintext in state.
  db_password_wo     = ephemeral.random_password.db_password.result
  db_engine_version  = var.db_engine_version
  db_instance_class  = var.db_instance_class
  allocated_storage  = var.db_allocated_storage
  subnet_ids         = module.networking.db_subnet_ids
  security_group_ids = module.networking.db_security_group_ids
  name_prefix        = var.name_prefix
  environment        = var.environment
  common_tags        = var.common_tags
}
