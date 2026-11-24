output "project_name" {
  description = "Configured project name."
  value       = var.project_name
}

output "environment" {
  description = "Configured environment name."
  value       = var.environment
}

output "aws_region" {
  description = "Configured AWS region."
  value       = var.aws_region
}

output "resource_name_prefix" {
  description = "Environment-scoped prefix for future infrastructure resources."
  value       = local.name_prefix
}

output "common_tags" {
  description = "Standard tags that future modules should apply to resources."
  value       = local.common_tags
}

output "vpc_id" {
  description = "ID of the production VPC."
  value       = module.vpc.vpc_id
}

output "public_subnet_ids" {
  description = "Production public subnet IDs keyed by availability zone."
  value       = module.vpc.public_subnet_ids
}

output "private_subnet_ids" {
  description = "Production private subnet IDs keyed by availability zone."
  value       = module.vpc.private_subnet_ids
}

output "nat_gateway_ids" {
  description = "Production NAT gateway IDs keyed by availability zone."
  value       = module.networking.nat_gateway_ids
}

output "s3_vpc_endpoint_id" {
  description = "ID of the production S3 gateway endpoint, when enabled."
  value       = module.networking.s3_vpc_endpoint_id
}

output "alb_security_group_id" {
  description = "ID of the production ALB security group."
  value       = module.security.alb_security_group_id
}

output "ecs_security_group_id" {
  description = "ID of the production ECS security group."
  value       = module.security.ecs_security_group_id
}

output "rds_security_group_id" {
  description = "ID of the production RDS security group."
  value       = module.security.rds_security_group_id
}

output "alb_arn" {
  description = "ARN of the production Application Load Balancer."
  value       = module.alb.alb_arn
}

output "alb_dns_name" {
  description = "DNS name of the production Application Load Balancer."
  value       = module.alb.alb_dns_name
}

output "target_group_arn" {
  description = "ARN of the production ECS target group."
  value       = module.alb.target_group_arn
}

output "https_listener_arn" {
  description = "Production HTTPS listener ARN, or null when disabled."
  value       = module.alb.https_listener_arn
}

output "http_listener_arn" {
  description = "Production HTTP redirect listener ARN, or null when disabled."
  value       = module.alb.http_listener_arn
}

output "ecr_repository_name" {
  description = "Name of the production private ECR repository."
  value       = module.ecr.repository_name
}

output "ecr_repository_arn" {
  description = "ARN of the production private ECR repository."
  value       = module.ecr.repository_arn
}

output "ecr_repository_url" {
  description = "Registry URL of the production private ECR repository."
  value       = module.ecr.repository_url
}

output "ecs_cluster_name" {
  description = "Name of the production ECS cluster."
  value       = module.ecs.cluster_name
}

output "ecs_log_group_name" {
  description = "Production ECS application log-group name."
  value       = module.ecs.log_group_name
}

output "ecs_task_execution_role_arn" {
  description = "Production ECS task execution role ARN."
  value       = module.iam.task_execution_role_arn
}

output "ecs_task_role_arn" {
  description = "Production ECS application task role ARN."
  value       = module.iam.task_role_arn
}

output "ecs_deployment_ready" {
  description = "Whether production ECS deployment prerequisites are complete."
  value       = module.ecs.deployment_ready
}

output "rds_endpoint" {
  value = module.rds.db_endpoint
}

output "rds_managed_master_secret_arn" {
  value = module.rds.managed_master_secret_arn
}

output "database_password_secret_arn" {
  value = module.secrets.database_password_secret_arn
}

output "jwt_secret_arn" {
  value = module.secrets.jwt_secret_arn
}
