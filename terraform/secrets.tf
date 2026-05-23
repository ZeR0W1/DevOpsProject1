// Generate the database password ephemerally and store it in AWS Secrets Manager.
ephemeral "random_password" "db_password" {
  length           = 24
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

// Read the existing db_creds secret metadata for optional consumers.
data "aws_secretsmanager_secret" "db_creds" {
  name = var.db_creds_secret_name
}

// Read the current db_creds secret value from Secrets Manager.
data "aws_secretsmanager_secret_version" "db_creds" {
  secret_id = data.aws_secretsmanager_secret.db_creds.id
}

locals {
  db_creds_secret = jsondecode(data.aws_secretsmanager_secret_version.db_creds.secret_string)
}

resource "aws_secretsmanager_secret" "db_password" {
  # Stable secret container for the RDS master password value.
  name                    = var.db_password_secret_name
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "db_password" {
  # Write the ephemeral password without persisting the plaintext in Terraform state.
  secret_id                = aws_secretsmanager_secret.db_password.id
  secret_string_wo         = ephemeral.random_password.db_password.result
  secret_string_wo_version = 1
}