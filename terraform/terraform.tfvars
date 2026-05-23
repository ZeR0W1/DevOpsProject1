aws_region  = "us-east-1"
name_prefix = "doa"
environment = "staging"
common_tags = {
  Project   = "DevOpsProject1"
  ManagedBy = "Terraform"
}

vpc_id                     = "vpc-0661ad9886c7d135f"
public_subnet_id           = "subnet-02084b58d14d91ea7"
db_subnet_id               = "subnet-009f8ce8c5da4bd1c"
public_availability_zone   = "us-east-1b"
ami_id                     = "ami-02dfbd4ff395f2a1b"
instance_type              = "t3.micro"
key_name                   = "cetemPair"
bucket_name                = "quick-demo-058264247987-us-east-1-an"
worker_topic_name          = "DOAworker"
billing_alarm_name         = "Billing-Over-20-USD"
db_password_secret_name    = "project/postgresql/master-password"
db_creds_secret_name       = "db_creds"
db_subnet_group_name       = "db-group1"
db_identifier              = "dodb2"
db_name                    = "postgres"
db_engine_version          = "17.6"
db_instance_class          = "db.t4g.micro"
db_allocated_storage       = 20
db_storage_type            = "gp2"
db_publicly_accessible     = true
db_skip_final_snapshot     = true
db_backup_retention_period = 0
frontend_name              = "Front"
backend_name               = "Back"
worker_name                = "Worker"

# Sensitive value managed separately in terraform/secrets.tf.
# Set this before apply, or move it here if you prefer tfvars-based secret handling.
# db_password = "replace-me"