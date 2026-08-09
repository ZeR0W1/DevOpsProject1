// Define the subnet group and managed PostgreSQL instance for the application database.
resource "aws_db_subnet_group" "project" {
  # RDS uses this subnet group to place the instance inside the selected DB subnets.
  name       = "${var.name_prefix}-${var.environment}-${var.db_subnet_group_name}"
  subnet_ids = var.subnet_ids

  tags = merge(var.common_tags, {
    Name        = "${var.name_prefix}-${var.environment}-${var.db_subnet_group_name}"
    Environment = var.environment
    Role        = "database"
    ManagedBy   = "Terraform"
  })
}

resource "aws_db_instance" "postgres" {
  # The master password is passed through Terraform's write-only ephemeral flow.
  identifier              = "${var.name_prefix}-${var.environment}-${var.db_identifier}"
  engine                  = "postgres"
  engine_version          = var.db_engine_version
  instance_class          = var.db_instance_class
  allocated_storage       = var.allocated_storage
  storage_type            = "gp3"
  storage_encrypted       = true
  db_name                 = var.db_name
  username                = var.db_username
  password_wo             = var.db_password_wo
  password_wo_version     = 1
  publicly_accessible     = false
  db_subnet_group_name    = aws_db_subnet_group.project.name
  vpc_security_group_ids  = var.security_group_ids
  skip_final_snapshot     = true
  backup_retention_period = 0
  deletion_protection     = false

  tags = merge(var.common_tags, {
    Name        = "${var.name_prefix}-${var.environment}-${var.db_identifier}"
    Environment = var.environment
    Role        = "database"
    ManagedBy   = "Terraform"
  })
}