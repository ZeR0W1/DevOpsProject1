// Generate the database password ephemerally and store it in AWS Secrets Manager.
ephemeral "random_password" "db_password" {
  length           = 24
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "aws_secretsmanager_secret" "db_password" {
  # This secret follows the intentionally disposable application-data boundary.
  name                    = var.db_password_secret_name
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "db_password" {
  # Write the ephemeral password without persisting the plaintext in Terraform state.
  secret_id                = aws_secretsmanager_secret.db_password.id
  secret_string_wo         = ephemeral.random_password.db_password.result
  secret_string_wo_version = 1
}