output "db_instance_arn" {
  value = aws_db_instance.this.arn
}

output "db_instance_id" {
  value = aws_db_instance.this.id
}

output "db_endpoint" {
  value = aws_db_instance.this.address
}

output "db_port" {
  value = aws_db_instance.this.port
}

output "db_name" {
  value = aws_db_instance.this.db_name
}

output "managed_master_secret_arn" {
  description = "ARN of the AWS-managed RDS master credential secret."
  value       = try(aws_db_instance.this.master_user_secret[0].secret_arn, null)
}

output "db_subnet_group_name" {
  value = aws_db_subnet_group.this.name
}
