output "enabled" {
  description = "Whether monitoring resources are enabled."
  value       = var.enabled
}

output "alarm_names" {
  description = "Names of CloudWatch alarms created by this module."
  value       = [for alarm in aws_cloudwatch_metric_alarm.this : alarm.alarm_name]
}

output "dashboard_name" {
  description = "Operations dashboard name, or null when monitoring is disabled or no dashboard metrics are configured."
  value       = try(aws_cloudwatch_dashboard.operations[0].dashboard_name, null)
}

output "sns_topic_arn" {
  description = "Created or caller-supplied SNS topic ARN used for alarm actions, or null when notifications are unavailable/disabled."
  value       = local.notification_topic_arn
}

output "ecs_running_task_alarm_enabled" {
  description = "Whether the Container Insights task-count alarm is enabled."
  value       = contains(keys(local.alarm_specs), "ecs_running_tasks")
}
