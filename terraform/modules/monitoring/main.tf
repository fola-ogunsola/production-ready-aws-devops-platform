locals {
  ecs_service_available = (
    var.enabled &&
    var.ecs_service_deployed &&
    var.ecs_cluster_name != null &&
    var.ecs_service_name != null
  )

  alb_available = (
    var.enabled &&
    var.load_balancer_arn != null &&
    var.target_group_arn != null
  )

  rds_available = var.enabled && var.rds_instance_identifier != null

  load_balancer_dimension = var.load_balancer_arn == null ? null : trimprefix(split(":", var.load_balancer_arn)[5], "loadbalancer/")
  target_group_dimension  = var.target_group_arn == null ? null : trimprefix(split(":", var.target_group_arn)[5], "targetgroup/")

  alarm_specs = merge(
    local.ecs_service_available ? {
      ecs_cpu = {
        alarm_name          = "${var.name_prefix}-ecs-cpu-high"
        alarm_description   = "ECS service average CPU utilization is at or above the configured threshold."
        namespace           = "AWS/ECS"
        metric_name         = "CPUUtilization"
        dimensions          = { ClusterName = var.ecs_cluster_name, ServiceName = var.ecs_service_name }
        statistic           = "Average"
        comparison_operator = "GreaterThanOrEqualToThreshold"
        threshold           = var.ecs_cpu_threshold_percent
        unit                = "Percent"
      }
      ecs_memory = {
        alarm_name          = "${var.name_prefix}-ecs-memory-high"
        alarm_description   = "ECS service average memory utilization is at or above the configured threshold."
        namespace           = "AWS/ECS"
        metric_name         = "MemoryUtilization"
        dimensions          = { ClusterName = var.ecs_cluster_name, ServiceName = var.ecs_service_name }
        statistic           = "Average"
        comparison_operator = "GreaterThanOrEqualToThreshold"
        threshold           = var.ecs_memory_threshold_percent
        unit                = "Percent"
      }
    } : {},
    local.ecs_service_available && var.container_insights_enabled ? {
      ecs_running_tasks = {
        alarm_name          = "${var.name_prefix}-ecs-running-tasks-low"
        alarm_description   = "ECS Container Insights RunningTaskCount is below the configured minimum."
        namespace           = "ECS/ContainerInsights"
        metric_name         = "RunningTaskCount"
        dimensions          = { ClusterName = var.ecs_cluster_name, ServiceName = var.ecs_service_name }
        statistic           = "Minimum"
        comparison_operator = "LessThanThreshold"
        threshold           = var.ecs_min_running_tasks
        unit                = "Count"
      }
    } : {},
    local.alb_available ? {
      alb_unhealthy_targets = {
        alarm_name          = "${var.name_prefix}-alb-unhealthy-targets"
        alarm_description   = "The maximum unhealthy target count is above the configured threshold."
        namespace           = "AWS/ApplicationELB"
        metric_name         = "UnHealthyHostCount"
        dimensions          = { LoadBalancer = local.load_balancer_dimension, TargetGroup = local.target_group_dimension }
        statistic           = "Maximum"
        comparison_operator = "GreaterThanThreshold"
        threshold           = var.alb_unhealthy_targets_threshold
        unit                = "Count"
      }
      alb_target_5xx = {
        alarm_name          = "${var.name_prefix}-alb-target-5xx"
        alarm_description   = "Target-generated HTTP 5xx responses exceed the configured count per period."
        namespace           = "AWS/ApplicationELB"
        metric_name         = "HTTPCode_Target_5XX_Count"
        dimensions          = { LoadBalancer = local.load_balancer_dimension, TargetGroup = local.target_group_dimension }
        statistic           = "Sum"
        comparison_operator = "GreaterThanOrEqualToThreshold"
        threshold           = var.alb_target_5xx_threshold
        unit                = "Count"
      }
      alb_load_balancer_5xx = {
        alarm_name          = "${var.name_prefix}-alb-load-balancer-5xx"
        alarm_description   = "ALB-generated HTTP 5xx responses exceed the configured count per period."
        namespace           = "AWS/ApplicationELB"
        metric_name         = "HTTPCode_ELB_5XX_Count"
        dimensions          = { LoadBalancer = local.load_balancer_dimension }
        statistic           = "Sum"
        comparison_operator = "GreaterThanOrEqualToThreshold"
        threshold           = var.alb_load_balancer_5xx_threshold
        unit                = "Count"
      }
      alb_target_response_time = {
        alarm_name          = "${var.name_prefix}-alb-target-response-time-high"
        alarm_description   = "Average target response time exceeds the configured threshold in seconds."
        namespace           = "AWS/ApplicationELB"
        metric_name         = "TargetResponseTime"
        dimensions          = { LoadBalancer = local.load_balancer_dimension, TargetGroup = local.target_group_dimension }
        statistic           = "Average"
        comparison_operator = "GreaterThanOrEqualToThreshold"
        threshold           = var.alb_target_response_time_threshold_seconds
        unit                = "Seconds"
      }
    } : {},
    local.rds_available ? merge(
      {
        rds_cpu = {
          alarm_name          = "${var.name_prefix}-rds-cpu-high"
          alarm_description   = "RDS average CPU utilization is at or above the configured threshold."
          namespace           = "AWS/RDS"
          metric_name         = "CPUUtilization"
          dimensions          = { DBInstanceIdentifier = var.rds_instance_identifier }
          statistic           = "Average"
          comparison_operator = "GreaterThanOrEqualToThreshold"
          threshold           = var.rds_cpu_threshold_percent
          unit                = "Percent"
        }
        rds_free_storage = {
          alarm_name          = "${var.name_prefix}-rds-free-storage-low"
          alarm_description   = "RDS FreeStorageSpace is below the configured byte threshold."
          namespace           = "AWS/RDS"
          metric_name         = "FreeStorageSpace"
          dimensions          = { DBInstanceIdentifier = var.rds_instance_identifier }
          statistic           = "Minimum"
          comparison_operator = "LessThanThreshold"
          threshold           = var.rds_free_storage_threshold_bytes
          unit                = "Bytes"
        }
        rds_freeable_memory = {
          alarm_name          = "${var.name_prefix}-rds-freeable-memory-low"
          alarm_description   = "RDS FreeableMemory is below the configured byte threshold."
          namespace           = "AWS/RDS"
          metric_name         = "FreeableMemory"
          dimensions          = { DBInstanceIdentifier = var.rds_instance_identifier }
          statistic           = "Minimum"
          comparison_operator = "LessThanThreshold"
          threshold           = var.rds_freeable_memory_threshold_bytes
          unit                = "Bytes"
        }
      },
      var.rds_connection_threshold == null ? {} : {
        rds_connections = {
          alarm_name          = "${var.name_prefix}-rds-connections-high"
          alarm_description   = "Maximum RDS database connections exceed the explicitly configured capacity-derived threshold."
          namespace           = "AWS/RDS"
          metric_name         = "DatabaseConnections"
          dimensions          = { DBInstanceIdentifier = var.rds_instance_identifier }
          statistic           = "Maximum"
          comparison_operator = "GreaterThanOrEqualToThreshold"
          threshold           = var.rds_connection_threshold
          unit                = "Count"
        }
      }
    ) : {}
  )

  notification_topic_arn = (
    var.enabled && var.alarm_actions_enabled
    ? (var.existing_sns_topic_arn != null ? var.existing_sns_topic_arn : try(aws_sns_topic.alarms[0].arn, null))
    : null
  )

  dashboard_widgets = [
    for candidate in [
      {
        enabled = local.ecs_service_available
        widget = jsonencode({
          type   = "metric"
          x      = 0
          y      = 0
          width  = 12
          height = 6
          properties = {
            title  = "ECS service CPU and memory utilization"
            region = var.aws_region
            stat   = "Average"
            period = var.alarm_period_seconds
            metrics = [
              ["AWS/ECS", "CPUUtilization", "ClusterName", var.ecs_cluster_name, "ServiceName", var.ecs_service_name, { label = "CPU (%)" }],
              [".", "MemoryUtilization", ".", ".", ".", ".", { label = "Memory (%)" }]
            ]
            yAxis = { left = { min = 0, max = 100 } }
          }
        })
      },
      {
        enabled = local.ecs_service_available && var.container_insights_enabled
        widget = jsonencode({
          type   = "metric"
          x      = 12
          y      = 0
          width  = 6
          height = 6
          properties = {
            title  = "ECS running tasks (Container Insights)"
            region = var.aws_region
            stat   = "Minimum"
            period = var.alarm_period_seconds
            metrics = [
              ["ECS/ContainerInsights", "RunningTaskCount", "ClusterName", var.ecs_cluster_name, "ServiceName", var.ecs_service_name]
            ]
          }
        })
      },
      {
        enabled = local.alb_available
        widget = jsonencode({
          type   = "metric"
          x      = 0
          y      = 6
          width  = 12
          height = 6
          properties = {
            title  = "ALB target health"
            region = var.aws_region
            stat   = "Minimum"
            period = var.alarm_period_seconds
            metrics = [
              ["AWS/ApplicationELB", "HealthyHostCount", "LoadBalancer", local.load_balancer_dimension, "TargetGroup", local.target_group_dimension],
              [".", "UnHealthyHostCount", ".", ".", ".", ".", { stat = "Maximum" }]
            ]
          }
        })
      },
      {
        enabled = local.alb_available
        widget = jsonencode({
          type   = "metric"
          x      = 12
          y      = 6
          width  = 12
          height = 6
          properties = {
            title  = "ALB requests and HTTP 5xx"
            region = var.aws_region
            stat   = "Sum"
            period = var.alarm_period_seconds
            metrics = [
              ["AWS/ApplicationELB", "RequestCount", "LoadBalancer", local.load_balancer_dimension, { yAxis = "left", label = "Requests" }],
              [".", "HTTPCode_Target_5XX_Count", ".", ".", "TargetGroup", local.target_group_dimension, { yAxis = "right", label = "Target 5xx" }],
              [".", "HTTPCode_ELB_5XX_Count", ".", ".", { yAxis = "right", label = "ALB 5xx" }]
            ]
          }
        })
      },
      {
        enabled = local.alb_available
        widget = jsonencode({
          type   = "metric"
          x      = 0
          y      = 12
          width  = 12
          height = 6
          properties = {
            title  = "ALB target response time"
            region = var.aws_region
            stat   = "Average"
            period = var.alarm_period_seconds
            metrics = [
              ["AWS/ApplicationELB", "TargetResponseTime", "LoadBalancer", local.load_balancer_dimension, "TargetGroup", local.target_group_dimension]
            ]
            yAxis = { left = { min = 0 } }
          }
        })
      },
      {
        enabled = local.rds_available
        widget = jsonencode({
          type   = "metric"
          x      = 12
          y      = 12
          width  = 12
          height = 6
          properties = {
            title  = "RDS CPU and database connections"
            region = var.aws_region
            period = var.alarm_period_seconds
            metrics = [
              ["AWS/RDS", "CPUUtilization", "DBInstanceIdentifier", var.rds_instance_identifier, { stat = "Average", yAxis = "left" }],
              [".", "DatabaseConnections", ".", ".", { stat = "Maximum", yAxis = "right" }]
            ]
          }
        })
      },
      {
        enabled = local.rds_available
        widget = jsonencode({
          type   = "metric"
          x      = 0
          y      = 18
          width  = 12
          height = 6
          properties = {
            title  = "RDS free storage and freeable memory (bytes)"
            region = var.aws_region
            period = var.alarm_period_seconds
            metrics = [
              ["AWS/RDS", "FreeStorageSpace", "DBInstanceIdentifier", var.rds_instance_identifier, { stat = "Minimum", yAxis = "left" }],
              [".", "FreeableMemory", ".", ".", { stat = "Minimum", yAxis = "right" }]
            ]
          }
        })
      },
      {
        enabled = var.enabled && var.application_log_group_name != null
        widget = jsonencode({
          type   = "log"
          x      = 12
          y      = 18
          width  = 12
          height = 8
          properties = {
            title  = "Application HTTP 5xx and slow requests"
            region = var.aws_region
            view   = "table"
            query  = "SOURCE '${var.application_log_group_name == null ? "" : var.application_log_group_name}' | fields @timestamp, level, requestId, req.method, req.path, res.statusCode, responseTime, msg | filter res.statusCode >= 500 or responseTime >= 1000 | sort @timestamp desc | limit 100"
          }
        })
      },
      {
        enabled = var.enabled && var.application_log_group_name != null
        widget = jsonencode({
          type   = "log"
          x      = 0
          y      = 24
          width  = 12
          height = 8
          properties = {
            title  = "Application authentication and database errors"
            region = var.aws_region
            view   = "table"
            query  = "SOURCE '${var.application_log_group_name == null ? "" : var.application_log_group_name}' | fields @timestamp, level, requestId, req.method, req.path, res.statusCode, err.type, err.message, msg | filter level >= 40 and (req.path like /auth/ or err.type like /Database|Error/) | sort @timestamp desc | limit 100"
          }
        })
      }
    ] : jsondecode(candidate.widget) if candidate.enabled
  ]
}
