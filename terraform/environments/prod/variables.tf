variable "project_name" {
  description = "Lowercase project identifier used in resource names and tags."
  type        = string
  default     = "production-ready-aws-devops-platform"

  validation {
    condition     = can(regex("^[a-z0-9]([a-z0-9-]*[a-z0-9])?$", var.project_name))
    error_message = "project_name must contain only lowercase letters, digits, and internal hyphens."
  }
}

variable "environment" {
  description = "Environment name used to namespace future resources."
  type        = string
  default     = "prod"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{0,15}$", var.environment))
    error_message = "environment must start with a lowercase letter and contain only lowercase letters, digits, and hyphens (maximum 16 characters)."
  }
}

variable "aws_region" {
  description = "AWS region for production infrastructure."
  type        = string
  default     = "eu-west-1"
}

variable "aws_profile" {
  description = "Optional AWS CLI profile. Leave null to use the standard AWS credential chain."
  type        = string
  default     = null
  nullable    = true
}

variable "expected_account_id" {
  description = "Required 12-digit account guard. Set this before any plan or apply."
  type        = string

  validation {
    condition     = can(regex("^[0-9]{12}$", var.expected_account_id))
    error_message = "expected_account_id must be the intended 12-digit AWS account ID."
  }
}

variable "additional_tags" {
  description = "Additional non-sensitive resource tags."
  type        = map(string)
  default     = {}
}

variable "vpc_cidr" {
  description = "IPv4 CIDR block for the production VPC."
  type        = string
  default     = "10.30.0.0/16"

  validation {
    condition     = can(cidrnetmask(var.vpc_cidr))
    error_message = "vpc_cidr must be a valid IPv4 CIDR block."
  }
}

variable "availability_zones" {
  description = "Availability zones used by the production VPC."
  type        = list(string)
  default     = ["eu-west-1a", "eu-west-1b", "eu-west-1c"]
}

variable "public_subnet_cidrs" {
  description = "Public subnet CIDRs for production, one per availability zone."
  type        = list(string)
  default     = ["10.30.0.0/24", "10.30.1.0/24", "10.30.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "Private subnet CIDRs for production, one per availability zone."
  type        = list(string)
  default     = ["10.30.10.0/24", "10.30.11.0/24", "10.30.12.0/24"]
}

variable "enable_nat_gateway" {
  description = "Create NAT gateway egress for production private subnets."
  type        = bool
  default     = true
}

variable "single_nat_gateway" {
  description = "Use a separate production NAT gateway per availability zone."
  type        = bool
  default     = false
}

variable "enable_s3_gateway_endpoint" {
  description = "Create the S3 gateway endpoint for production private subnets."
  type        = bool
  default     = true
}

variable "application_port" {
  description = "TCP port exposed by the ECS application."
  type        = number
  default     = 3000
}

variable "database_port" {
  description = "TCP port exposed by RDS PostgreSQL."
  type        = number
  default     = 5432
}

variable "alb_ingress_cidrs" {
  description = "Approved IPv4 CIDR ranges allowed to reach the production ALB."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "enable_alb_http_ingress" {
  description = "Allow HTTP ingress on the production ALB."
  type        = bool
  default     = false
}

variable "ecs_https_egress_cidrs" {
  description = "IPv4 destinations for production ECS HTTPS connectivity."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "alb_scheme" {
  description = "Placement scheme for the production ALB."
  type        = string
  default     = "internet-facing"
}

variable "enable_alb_deletion_protection" {
  description = "Enable deletion protection on the production ALB."
  type        = bool
  default     = true
}

variable "enable_alb_access_logs" {
  description = "Enable production ALB access logs to S3."
  type        = bool
  default     = false
}

variable "alb_access_logs_bucket_id" {
  description = "Optional existing S3 bucket ID for production ALB access logs."
  type        = string
  default     = null
  nullable    = true
}

variable "alb_acm_certificate_arn" {
  description = "Existing ACM certificate ARN for production HTTPS. Null disables HTTPS."
  type        = string
  default     = null
  nullable    = true
}

variable "enable_alb_https_listener" {
  description = "Create the production ALB HTTPS listener."
  type        = bool
  default     = false
}

variable "enable_alb_http_listener" {
  description = "Create production HTTP-to-HTTPS redirect ingress."
  type        = bool
  default     = false
}

variable "alb_waf_web_acl_arn" {
  description = "Optional existing WAFv2 Web ACL ARN to associate with the production ALB."
  type        = string
  default     = null
  nullable    = true
}

variable "enable_ecs_service" {
  description = "Enable ECS deployment only after all real external prerequisites exist."
  type        = bool
  default     = false
}

variable "ecs_image_reference" {
  description = "Existing ECR image reference with SHA or immutable tag."
  type        = string
  default     = null
  nullable    = true
}

variable "ecs_task_cpu" {
  description = "Production ECS Fargate CPU units."
  type        = number
  default     = 512
}

variable "ecs_task_memory" {
  description = "Production ECS Fargate memory in MiB."
  type        = number
  default     = 1024
}

variable "ecs_desired_count" {
  description = "Production ECS desired task count."
  type        = number
  default     = 2
}

variable "ecs_health_check_grace_period" {
  description = "Production ECS ALB health-check grace period."
  type        = number
  default     = 60
}

variable "ecs_enable_container_insights" {
  description = "Enable ECS Container Insights in production."
  type        = bool
  default     = true
}

variable "ecs_log_retention_days" {
  description = "Production ECS application log retention."
  type        = number
  default     = 365
}

variable "ecs_database_host" {
  description = "Existing RDS or PostgreSQL endpoint for production."
  type        = string
  default     = null
  nullable    = true
}

variable "ecs_database_name" {
  description = "Existing production PostgreSQL database name."
  type        = string
  default     = null
  nullable    = true
}

variable "ecs_database_user" {
  description = "Existing restricted production PostgreSQL username."
  type        = string
  default     = null
  nullable    = true
}

variable "ecs_secret_environment_variables" {
  description = "Existing Secrets Manager ARNs for ECS DATABASE_PASSWORD and JWT_SECRET_BASE64."
  type        = map(string)
  default     = {}
}

variable "ecs_kms_key_arns" {
  description = "Existing KMS key ARNs needed to decrypt ECS secrets."
  type        = map(string)
  default     = {}
}

variable "ecs_jwt_issuer" {
  description = "Production JWT issuer URL."
  type        = string
  default     = null
  nullable    = true
}

variable "ecs_jwt_audience" {
  description = "Production JWT audience."
  type        = string
  default     = null
  nullable    = true
}

variable "rds_instance_class" {
  type    = string
  default = "db.t4g.small"
}

variable "rds_allocated_storage" {
  type    = number
  default = 100
}

variable "rds_max_allocated_storage" {
  type    = number
  default = 500
}

variable "rds_backup_retention_days" {
  type    = number
  default = 14
}

variable "rds_deletion_protection" {
  type    = bool
  default = true
}

variable "monitoring_enabled" {
  description = "Explicitly enable production CloudWatch dashboards, alarms, and optional SNS resources."
  type        = bool
  default     = false
}

variable "monitoring_sns_topic_arn" {
  description = "Optional existing SNS topic ARN for monitoring alarms."
  type        = string
  default     = null
  nullable    = true
}

variable "monitoring_create_sns_topic" {
  description = "Create an encrypted production SNS topic when monitoring is enabled."
  type        = bool
  default     = false
}

variable "monitoring_alarm_actions_enabled" {
  description = "Attach notification actions when a topic is configured."
  type        = bool
  default     = true
}

variable "monitoring_alarm_period_seconds" {
  description = "CloudWatch alarm period in seconds."
  type        = number
  default     = 300
}

variable "monitoring_evaluation_periods" {
  description = "Number of alarm periods evaluated."
  type        = number
  default     = 2
}

variable "monitoring_datapoints_to_alarm" {
  description = "Breaching datapoints required to alarm."
  type        = number
  default     = 2
}

variable "monitoring_ecs_min_running_tasks" {
  description = "Minimum ECS RunningTaskCount when Container Insights task alarms are enabled."
  type        = number
  default     = 1
}

variable "monitoring_ecs_cpu_threshold_percent" {
  description = "Production ECS service CPU alarm threshold."
  type        = number
  default     = 75
}

variable "monitoring_ecs_memory_threshold_percent" {
  description = "Production ECS service memory alarm threshold."
  type        = number
  default     = 75
}

variable "monitoring_alb_unhealthy_targets_threshold" {
  description = "Production ALB unhealthy-target count threshold."
  type        = number
  default     = 0
}

variable "monitoring_alb_target_5xx_threshold" {
  description = "Production target-generated HTTP 5xx count per alarm period."
  type        = number
  default     = 5
}

variable "monitoring_alb_lb_5xx_threshold" {
  description = "Production ALB-generated HTTP 5xx count per alarm period."
  type        = number
  default     = 5
}

variable "monitoring_alb_response_time_seconds" {
  description = "Production average target response-time threshold."
  type        = number
  default     = 1
}

variable "monitoring_rds_cpu_threshold_percent" {
  description = "Production RDS CPU alarm threshold."
  type        = number
  default     = 75
}

variable "monitoring_rds_free_storage_threshold_bytes" {
  description = "Production RDS free-storage alarm threshold in bytes."
  type        = number
  default     = 16106127360
}

variable "monitoring_rds_connection_threshold" {
  description = "Capacity-derived production PostgreSQL connection alarm threshold; recalculate if the instance class changes."
  type        = number
  default     = 160
}

variable "monitoring_rds_freeable_memory_threshold_bytes" {
  description = "Production RDS freeable-memory alarm threshold in bytes."
  type        = number
  default     = 536870912
}

variable "database_subnet_cidrs" {
  description = "Dedicated private database subnet CIDRs for production."
  type        = list(string)
  default     = ["10.30.20.0/24", "10.30.21.0/24", "10.30.22.0/24"]
}

variable "ecr_repository_name" {
  description = "Private production ECR repository name."
  type        = string
  default     = "production-ready-aws-devops-platform-prod-api"
}

variable "ecr_scan_on_push" {
  description = "Enable basic ECR scan-on-push for the production repository."
  type        = bool
  default     = true
}

variable "ecr_force_delete" {
  description = "Allow forced repository deletion in production."
  type        = bool
  default     = false
}

variable "ecr_lifecycle_policy_enabled" {
  description = "Attach the production ECR lifecycle policy."
  type        = bool
  default     = true
}

variable "ecr_production_image_retention" {
  description = "Production production-tagged image retention count."
  type        = number
  default     = 30
}

variable "ecr_rollback_image_retention" {
  description = "Production rollback-tagged image retention count."
  type        = number
  default     = 10
}

variable "ecr_sha_image_retention" {
  description = "Production SHA-tagged image retention count."
  type        = number
  default     = 50
}
