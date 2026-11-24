variable "enabled" {
  description = "Create monitoring resources only after the environment is explicitly enabled."
  type        = bool
  default     = false
}

variable "name_prefix" {
  description = "Environment-scoped prefix for dashboard, alarms, and optional SNS topic."
  type        = string

  validation {
    condition     = length(trimspace(var.name_prefix)) > 0
    error_message = "name_prefix must not be empty."
  }
}

variable "aws_region" {
  description = "AWS region containing the monitored resources."
  type        = string
}

variable "tags" {
  description = "Tags applied to alarms and a created SNS topic."
  type        = map(string)
  default     = {}
}

variable "alarm_period_seconds" {
  description = "CloudWatch metric period used by alarms."
  type        = number
  default     = 300

  validation {
    condition     = var.alarm_period_seconds >= 60 && var.alarm_period_seconds <= 86400 && var.alarm_period_seconds % 60 == 0
    error_message = "alarm_period_seconds must be a whole-minute period between 60 and 86400 seconds."
  }
}

variable "evaluation_periods" {
  description = "Number of consecutive metric periods evaluated by each alarm."
  type        = number
  default     = 2

  validation {
    condition     = var.evaluation_periods >= 1 && var.evaluation_periods <= 100
    error_message = "evaluation_periods must be between 1 and 100."
  }
}

variable "datapoints_to_alarm" {
  description = "Number of breaching datapoints required to alarm."
  type        = number
  default     = 2

  validation {
    condition     = var.datapoints_to_alarm >= 1 && var.datapoints_to_alarm <= var.evaluation_periods
    error_message = "datapoints_to_alarm must be between 1 and evaluation_periods."
  }
}

variable "alarm_actions_enabled" {
  description = "Attach the configured notification topic to alarm actions."
  type        = bool
  default     = true
}

variable "existing_sns_topic_arn" {
  description = "Optional existing SNS topic ARN; its encryption and publish policy remain caller-managed."
  type        = string
  default     = null
  nullable    = true

  validation {
    condition = (
      var.existing_sns_topic_arn == null ||
      can(regex("^arn:[^:]+:sns:[^:]+:[0-9]{12}:[A-Za-z0-9_-]+$", var.existing_sns_topic_arn))
    )
    error_message = "existing_sns_topic_arn must be a valid SNS topic ARN."
  }
}

variable "create_sns_topic" {
  description = "Create an environment-scoped, AWS-managed-key-encrypted SNS topic when no existing topic ARN is supplied."
  type        = bool
  default     = false
}

variable "ecs_cluster_name" {
  description = "ECS cluster name for service-level metrics; null when not configured."
  type        = string
  default     = null
  nullable    = true
}

variable "ecs_service_name" {
  description = "ECS service name; null until an ECS service is deployed."
  type        = string
  default     = null
  nullable    = true
}

variable "ecs_service_deployed" {
  description = "Whether deployment prerequisites have enabled the ECS service."
  type        = bool
  default     = false
}

variable "container_insights_enabled" {
  description = "Whether ECS Container Insights is enabled for task-count metrics."
  type        = bool
  default     = false
}

variable "ecs_min_running_tasks" {
  description = "Minimum RunningTaskCount before the Container Insights alarm enters ALARM."
  type        = number
  default     = 1

  validation {
    condition     = var.ecs_min_running_tasks >= 0
    error_message = "ecs_min_running_tasks must be non-negative."
  }
}

variable "ecs_cpu_threshold_percent" {
  description = "ECS service CPUUtilization alarm threshold in percent."
  type        = number
  default     = 85

  validation {
    condition     = var.ecs_cpu_threshold_percent > 0 && var.ecs_cpu_threshold_percent <= 100
    error_message = "ecs_cpu_threshold_percent must be greater than 0 and no more than 100."
  }
}

variable "ecs_memory_threshold_percent" {
  description = "ECS service MemoryUtilization alarm threshold in percent."
  type        = number
  default     = 85

  validation {
    condition     = var.ecs_memory_threshold_percent > 0 && var.ecs_memory_threshold_percent <= 100
    error_message = "ecs_memory_threshold_percent must be greater than 0 and no more than 100."
  }
}

variable "load_balancer_arn" {
  description = "Application Load Balancer ARN; null disables ALB alarms and widgets."
  type        = string
  default     = null
  nullable    = true

  validation {
    condition = (
      var.load_balancer_arn == null ||
      can(regex("^arn:[^:]+:elasticloadbalancing:[^:]+:[0-9]{12}:loadbalancer/app/.+$", var.load_balancer_arn))
    )
    error_message = "load_balancer_arn must be an Application Load Balancer ARN."
  }
}

variable "target_group_arn" {
  description = "ALB target group ARN; null disables ALB alarms and widgets."
  type        = string
  default     = null
  nullable    = true

  validation {
    condition = (
      var.target_group_arn == null ||
      can(regex("^arn:[^:]+:elasticloadbalancing:[^:]+:[0-9]{12}:targetgroup/.+$", var.target_group_arn))
    )
    error_message = "target_group_arn must be an ALB target group ARN."
  }
}

variable "alb_unhealthy_targets_threshold" {
  description = "ALB unhealthy-host count that triggers an alarm."
  type        = number
  default     = 0

  validation {
    condition     = var.alb_unhealthy_targets_threshold >= 0
    error_message = "alb_unhealthy_targets_threshold must be non-negative."
  }
}

variable "alb_target_5xx_threshold" {
  description = "Target-generated HTTP 5xx count per alarm period that triggers an alarm."
  type        = number
  default     = 5

  validation {
    condition     = var.alb_target_5xx_threshold >= 1
    error_message = "alb_target_5xx_threshold must be at least 1."
  }
}

variable "alb_load_balancer_5xx_threshold" {
  description = "ALB-generated HTTP 5xx count per alarm period that triggers an alarm."
  type        = number
  default     = 5

  validation {
    condition     = var.alb_load_balancer_5xx_threshold >= 1
    error_message = "alb_load_balancer_5xx_threshold must be at least 1."
  }
}

variable "alb_target_response_time_threshold_seconds" {
  description = "Average target response-time threshold in seconds."
  type        = number
  default     = 1

  validation {
    condition     = var.alb_target_response_time_threshold_seconds > 0
    error_message = "alb_target_response_time_threshold_seconds must be greater than 0."
  }
}

variable "rds_instance_identifier" {
  description = "RDS DB instance identifier; null disables RDS alarms and widgets."
  type        = string
  default     = null
  nullable    = true

  validation {
    condition = (
      var.rds_instance_identifier == null ||
      can(regex("^[A-Za-z][A-Za-z0-9-]{0,62}$", var.rds_instance_identifier))
    )
    error_message = "rds_instance_identifier must be a valid RDS DB instance identifier."
  }
}

variable "rds_cpu_threshold_percent" {
  description = "RDS CPUUtilization alarm threshold in percent."
  type        = number
  default     = 80

  validation {
    condition     = var.rds_cpu_threshold_percent > 0 && var.rds_cpu_threshold_percent <= 100
    error_message = "rds_cpu_threshold_percent must be greater than 0 and no more than 100."
  }
}

variable "rds_free_storage_threshold_bytes" {
  description = "Alarm when FreeStorageSpace drops below this byte value."
  type        = number
  default     = 5368709120

  validation {
    condition     = var.rds_free_storage_threshold_bytes > 0
    error_message = "rds_free_storage_threshold_bytes must be greater than 0."
  }
}

variable "rds_connection_threshold" {
  description = "Capacity-derived DatabaseConnections alarm threshold; null disables this alarm until the operator configures a safe value."
  type        = number
  default     = null
  nullable    = true

  validation {
    condition     = var.rds_connection_threshold == null || var.rds_connection_threshold >= 1
    error_message = "rds_connection_threshold must be null or at least 1."
  }
}

variable "rds_freeable_memory_threshold_bytes" {
  description = "Alarm when FreeableMemory drops below this byte value."
  type        = number
  default     = 268435456

  validation {
    condition     = var.rds_freeable_memory_threshold_bytes > 0
    error_message = "rds_freeable_memory_threshold_bytes must be greater than 0."
  }
}

variable "application_log_group_name" {
  description = "Existing ECS application log group name; null omits the Logs Insights dashboard widget."
  type        = string
  default     = null
  nullable    = true
}
