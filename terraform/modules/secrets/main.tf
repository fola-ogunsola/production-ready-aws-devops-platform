resource "aws_secretsmanager_secret" "database_password" {
  count = var.create_database_password_secret ? 1 : 0

  name                    = "${var.name_prefix}/database-password"
  description             = "Externally populated least-privilege application PostgreSQL password"
  kms_key_id              = var.kms_key_arn
  recovery_window_in_days = var.recovery_window_days

  tags = merge(var.tags, { Name = "${var.name_prefix}-database-password" })
}

resource "aws_secretsmanager_secret" "jwt_secret" {
  count = var.create_jwt_secret ? 1 : 0

  name                    = "${var.name_prefix}/jwt-secret-base64"
  description             = "Externally populated canonical Base64 JWT signing secret"
  kms_key_id              = var.kms_key_arn
  recovery_window_in_days = var.recovery_window_days

  tags = merge(var.tags, { Name = "${var.name_prefix}-jwt-secret-base64" })
}
