mock_provider "aws" {
  mock_data "aws_caller_identity" {
    defaults = {
      account_id = "123456789012"
    }
  }

  mock_data "aws_partition" {
    defaults = {
      partition = "aws"
    }
  }

  override_resource {
    target = aws_sns_topic.alarms
    values = {
      arn = "arn:aws:sns:eu-west-1:123456789012:test-prod-alarms"
    }
  }
}

run "disabled_without_prerequisites" {
  command = plan

  variables {
    enabled     = false
    name_prefix = "test-dev"
    aws_region  = "eu-west-1"
  }

  assert {
    condition     = length(aws_cloudwatch_metric_alarm.this) == 0
    error_message = "Monitoring alarms must be absent unless explicitly enabled."
  }

  assert {
    condition     = length(aws_cloudwatch_dashboard.operations) == 0
    error_message = "The monitoring dashboard must be absent unless monitoring is enabled."
  }

  assert {
    condition     = length(aws_sns_topic.alarms) == 0
    error_message = "No SNS topic may be created by default."
  }
}

run "dev_and_prod_thresholds_and_metric_dimensions" {
  command = plan

  variables {
    enabled     = true
    name_prefix = "test-prod"
    aws_region  = "eu-west-1"
    tags = {
      Environment = "prod"
      ManagedBy   = "Terraform"
    }
    ecs_cluster_name                           = "test-prod-ecs"
    ecs_service_name                           = "test-prod-api"
    ecs_service_deployed                       = true
    container_insights_enabled                 = true
    ecs_min_running_tasks                      = 2
    ecs_cpu_threshold_percent                  = 75
    ecs_memory_threshold_percent               = 75
    load_balancer_arn                          = "arn:aws:elasticloadbalancing:eu-west-1:123456789012:loadbalancer/app/test-prod-alb/0123456789abcdef"
    target_group_arn                           = "arn:aws:elasticloadbalancing:eu-west-1:123456789012:targetgroup/test-prod-tg/0123456789abcdef"
    alb_unhealthy_targets_threshold            = 0
    alb_target_5xx_threshold                   = 5
    alb_load_balancer_5xx_threshold            = 5
    alb_target_response_time_threshold_seconds = 1
    rds_instance_identifier                    = "test-prod-postgres"
    rds_cpu_threshold_percent                  = 75
    rds_free_storage_threshold_bytes           = 16106127360
    rds_connection_threshold                   = 160
    rds_freeable_memory_threshold_bytes        = 536870912
    alarm_period_seconds                       = 300
    evaluation_periods                         = 3
    datapoints_to_alarm                        = 2
    application_log_group_name                 = "/ecs/test-prod-api"
  }

  assert {
    condition     = aws_cloudwatch_metric_alarm.this["ecs_cpu"].namespace == "AWS/ECS" && aws_cloudwatch_metric_alarm.this["ecs_cpu"].metric_name == "CPUUtilization"
    error_message = "ECS CPU alarms must use the service metric namespace and name."
  }

  assert {
    condition     = aws_cloudwatch_metric_alarm.this["ecs_cpu"].dimensions["ClusterName"] == "test-prod-ecs" && aws_cloudwatch_metric_alarm.this["ecs_cpu"].dimensions["ServiceName"] == "test-prod-api"
    error_message = "ECS alarms must be dimensioned by cluster and service."
  }

  assert {
    condition     = aws_cloudwatch_metric_alarm.this["ecs_cpu"].threshold == 75 && aws_cloudwatch_metric_alarm.this["ecs_memory"].threshold == 75
    error_message = "Production ECS thresholds must be configurable to 75 percent."
  }

  assert {
    condition     = aws_cloudwatch_metric_alarm.this["ecs_running_tasks"].namespace == "ECS/ContainerInsights" && aws_cloudwatch_metric_alarm.this["ecs_running_tasks"].threshold == 2
    error_message = "RunningTaskCount must use the Container Insights namespace and configured minimum."
  }

  assert {
    condition     = aws_cloudwatch_metric_alarm.this["alb_unhealthy_targets"].dimensions["LoadBalancer"] == "app/test-prod-alb/0123456789abcdef" && aws_cloudwatch_metric_alarm.this["alb_unhealthy_targets"].dimensions["TargetGroup"] == "test-prod-tg/0123456789abcdef"
    error_message = "ALB alarm dimensions must use ARN suffixes without their resource-type prefixes."
  }

  assert {
    condition     = aws_cloudwatch_metric_alarm.this["alb_target_5xx"].statistic == "Sum" && aws_cloudwatch_metric_alarm.this["alb_target_5xx"].metric_name == "HTTPCode_Target_5XX_Count"
    error_message = "Target-generated HTTP 5xx alarms must sum target errors."
  }

  assert {
    condition     = aws_cloudwatch_metric_alarm.this["alb_load_balancer_5xx"].dimensions["LoadBalancer"] == "app/test-prod-alb/0123456789abcdef" && length(aws_cloudwatch_metric_alarm.this["alb_load_balancer_5xx"].dimensions) == 1
    error_message = "ALB-generated error alarms must use only the LoadBalancer dimension."
  }

  assert {
    condition     = aws_cloudwatch_metric_alarm.this["rds_free_storage"].namespace == "AWS/RDS" && aws_cloudwatch_metric_alarm.this["rds_free_storage"].unit == "Bytes" && aws_cloudwatch_metric_alarm.this["rds_free_storage"].threshold == 16106127360
    error_message = "RDS storage alarms must use the RDS namespace and byte-based thresholds."
  }

  assert {
    condition     = aws_cloudwatch_metric_alarm.this["rds_connections"].metric_name == "DatabaseConnections" && aws_cloudwatch_metric_alarm.this["rds_connections"].dimensions["DBInstanceIdentifier"] == "test-prod-postgres" && aws_cloudwatch_metric_alarm.this["rds_connections"].threshold == 160
    error_message = "RDS connection alarms must use the instance identifier and explicit configured threshold."
  }

  assert {
    condition     = aws_cloudwatch_metric_alarm.this["rds_freeable_memory"].unit == "Bytes" && aws_cloudwatch_metric_alarm.this["rds_freeable_memory"].threshold == 536870912
    error_message = "RDS freeable-memory alarms must use byte-based thresholds."
  }

  assert {
    condition     = aws_cloudwatch_metric_alarm.this["rds_cpu"].evaluation_periods == 3 && aws_cloudwatch_metric_alarm.this["rds_cpu"].datapoints_to_alarm == 2 && aws_cloudwatch_metric_alarm.this["rds_cpu"].treat_missing_data == "notBreaching"
    error_message = "Alarms must use configurable evaluation periods and treat absent metrics as non-breaching."
  }

  assert {
    condition     = anytrue([for widget in jsondecode(aws_cloudwatch_dashboard.operations[0].dashboard_body).widgets : widget.properties.title == "ALB target health"])
    error_message = "The environment dashboard must include ALB health metrics."
  }

  assert {
    condition     = anytrue([for widget in jsondecode(aws_cloudwatch_dashboard.operations[0].dashboard_body).widgets : widget.properties.title == "Application HTTP 5xx and slow requests"])
    error_message = "The dashboard must include a Logs Insights widget for application errors and latency."
  }

  assert {
    condition     = aws_cloudwatch_metric_alarm.this["ecs_cpu"].tags["Environment"] == "prod"
    error_message = "Alarm resources must inherit environment tags."
  }
}

run "dev_thresholds_and_container_insights_prerequisite" {
  command = plan

  variables {
    enabled                      = true
    name_prefix                  = "test-dev"
    aws_region                   = "eu-west-1"
    ecs_cluster_name             = "test-dev-ecs"
    ecs_service_name             = "test-dev-api"
    ecs_service_deployed         = true
    container_insights_enabled   = false
    ecs_cpu_threshold_percent    = 85
    ecs_memory_threshold_percent = 85
  }

  assert {
    condition     = aws_cloudwatch_metric_alarm.this["ecs_cpu"].threshold == 85 && aws_cloudwatch_metric_alarm.this["ecs_memory"].threshold == 85
    error_message = "Development ECS CPU and memory thresholds must support 85 percent."
  }

  assert {
    condition     = length([for alarm in aws_cloudwatch_metric_alarm.this : alarm if alarm.metric_name == "RunningTaskCount"]) == 0
    error_message = "RunningTaskCount alarms must be omitted when Container Insights is disabled."
  }
}

run "skip_ecs_alarms_until_service_is_deployed" {
  command = plan

  variables {
    enabled              = true
    name_prefix          = "test-dev"
    aws_region           = "eu-west-1"
    ecs_cluster_name     = "test-dev-ecs"
    ecs_service_name     = null
    ecs_service_deployed = false
  }

  assert {
    condition     = length(aws_cloudwatch_metric_alarm.this) == 0
    error_message = "ECS alarms must not be created for an intentionally gated service."
  }

  assert {
    condition     = length(aws_cloudwatch_dashboard.operations) == 0
    error_message = "No empty dashboard should be created without monitored resources."
  }
}

run "optional_encrypted_sns_notifications" {
  command = apply

  variables {
    enabled                 = true
    name_prefix             = "test-prod"
    aws_region              = "eu-west-1"
    create_sns_topic        = true
    alarm_actions_enabled   = true
    rds_instance_identifier = "test-prod-postgres"
  }

  assert {
    condition     = aws_sns_topic.alarms[0].kms_master_key_id == "alias/aws/sns"
    error_message = "An optional notification topic must use SNS-managed encryption."
  }

  assert {
    condition     = jsondecode(aws_sns_topic_policy.alarms[0].policy).Statement[0].Principal.Service == "cloudwatch.amazonaws.com"
    error_message = "The notification topic policy must grant publishing to CloudWatch only."
  }

  assert {
    condition     = alltrue([for alarm in aws_cloudwatch_metric_alarm.this : contains(alarm.alarm_actions, output.sns_topic_arn)])
    error_message = "Alarm actions must use the configured notification topic."
  }
}

run "existing_sns_topic_is_reused_without_creation" {
  command = apply

  variables {
    enabled                 = true
    name_prefix             = "test-prod"
    aws_region              = "eu-west-1"
    existing_sns_topic_arn  = "arn:aws:sns:eu-west-1:123456789012:existing-alarms"
    create_sns_topic        = true
    rds_instance_identifier = "test-prod-postgres"
  }

  assert {
    condition     = length(aws_sns_topic.alarms) == 0
    error_message = "A caller-supplied SNS topic must be reused instead of creating another topic."
  }

  assert {
    condition     = alltrue([for alarm in aws_cloudwatch_metric_alarm.this : contains(alarm.alarm_actions, var.existing_sns_topic_arn)])
    error_message = "Alarm actions must use the caller-supplied topic."
  }
}

run "reject_invalid_threshold" {
  command = plan

  variables {
    enabled                      = true
    name_prefix                  = "test-dev"
    aws_region                   = "eu-west-1"
    ecs_memory_threshold_percent = 101
  }

  expect_failures = [
    var.ecs_memory_threshold_percent,
  ]
}

run "reject_datapoints_greater_than_evaluation_periods" {
  command = plan

  variables {
    enabled             = true
    name_prefix         = "test-dev"
    aws_region          = "eu-west-1"
    evaluation_periods  = 2
    datapoints_to_alarm = 3
  }

  expect_failures = [
    var.datapoints_to_alarm,
  ]
}
