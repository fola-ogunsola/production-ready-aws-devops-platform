output "cluster_arn" {
  description = "ARN of the ECS cluster."
  value       = aws_ecs_cluster.this.arn
}

output "cluster_name" {
  description = "Name of the ECS cluster."
  value       = aws_ecs_cluster.this.name
}

output "service_name" {
  description = "Stable ECS service name; the service resource is still deployment-gated."
  value       = local.service_name
}

output "log_group_name" {
  description = "CloudWatch Logs group name used by ECS tasks."
  value       = aws_cloudwatch_log_group.ecs.name
}

output "log_group_arn" {
  description = "CloudWatch Logs group ARN used by ECS tasks."
  value       = aws_cloudwatch_log_group.ecs.arn
}

output "task_definition_arn" {
  description = "Task definition ARN, or null while deployment is gated."
  value       = local.deployment_ready ? aws_ecs_task_definition.api[0].arn : null
}

output "service_arn" {
  description = "ECS service ARN, or null while deployment is gated."
  value       = local.deployment_ready ? aws_ecs_service.api[0].id : null
}

output "deployment_ready" {
  description = "Whether all explicit ECS deployment prerequisites are configured."
  value       = local.deployment_ready
}
