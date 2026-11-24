output "database_password_secret_arn" {
  description = "ARN of externally populated application database password secret."
  value       = var.create_database_password_secret ? aws_secretsmanager_secret.database_password[0].arn : null
}

output "jwt_secret_arn" {
  description = "ARN of externally populated JWT signing secret."
  value       = var.create_jwt_secret ? aws_secretsmanager_secret.jwt_secret[0].arn : null
}

output "secret_arns" {
  description = "Secret ARNs keyed by ECS secret environment variable name."
  value = merge(
    var.create_database_password_secret ? { DATABASE_PASSWORD = aws_secretsmanager_secret.database_password[0].arn } : {},
    var.create_jwt_secret ? { JWT_SECRET_BASE64 = aws_secretsmanager_secret.jwt_secret[0].arn } : {}
  )
}
