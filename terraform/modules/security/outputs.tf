output "alb_security_group_id" {
  description = "ID of the Application Load Balancer security group."
  value       = aws_security_group.alb.id
}

output "ecs_security_group_id" {
  description = "ID of the ECS Fargate security group."
  value       = aws_security_group.ecs.id
}

output "rds_security_group_id" {
  description = "ID of the RDS PostgreSQL security group."
  value       = aws_security_group.rds.id
}
