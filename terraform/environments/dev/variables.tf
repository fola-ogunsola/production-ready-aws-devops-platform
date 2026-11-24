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
  default     = "dev"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{0,15}$", var.environment))
    error_message = "environment must start with a lowercase letter and contain only lowercase letters, digits, and hyphens (maximum 16 characters)."
  }
}

variable "aws_region" {
  description = "AWS region for development infrastructure."
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
  description = "IPv4 CIDR block for the development VPC."
  type        = string
  default     = "10.20.0.0/16"

  validation {
    condition     = can(cidrnetmask(var.vpc_cidr))
    error_message = "vpc_cidr must be a valid IPv4 CIDR block."
  }
}

variable "availability_zones" {
  description = "Availability zones used by the development VPC."
  type        = list(string)
  default     = ["eu-west-1a", "eu-west-1b"]
}

variable "public_subnet_cidrs" {
  description = "Public subnet CIDRs for development, one per availability zone."
  type        = list(string)
  default     = ["10.20.0.0/24", "10.20.1.0/24"]
}

variable "private_subnet_cidrs" {
  description = "Private subnet CIDRs for development, one per availability zone."
  type        = list(string)
  default     = ["10.20.10.0/24", "10.20.11.0/24"]
}

variable "enable_nat_gateway" {
  description = "Create NAT gateway egress for development private subnets."
  type        = bool
  default     = true
}

variable "single_nat_gateway" {
  description = "Use a single development NAT gateway to reduce idle cost."
  type        = bool
  default     = true
}

variable "enable_s3_gateway_endpoint" {
  description = "Create the S3 gateway endpoint for development private subnets."
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
  description = "Approved IPv4 CIDR ranges allowed to reach the development ALB."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "enable_alb_http_ingress" {
  description = "Allow HTTP ingress on the development ALB."
  type        = bool
  default     = false
}

variable "ecs_https_egress_cidrs" {
  description = "IPv4 destinations for development ECS HTTPS connectivity."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "alb_scheme" {
  description = "Placement scheme for the development ALB."
  type        = string
  default     = "internet-facing"
}

variable "enable_alb_deletion_protection" {
  description = "Enable deletion protection on the development ALB."
  type        = bool
  default     = false
}

variable "enable_alb_access_logs" {
  description = "Enable development ALB access logs to S3."
  type        = bool
  default     = false
}

variable "alb_access_logs_bucket_id" {
  description = "Optional existing S3 bucket ID for development ALB access logs."
  type        = string
  default     = null
  nullable    = true
}

variable "alb_acm_certificate_arn" {
  description = "Existing ACM certificate ARN for development HTTPS. Null disables HTTPS."
  type        = string
  default     = null
  nullable    = true
}

variable "enable_alb_https_listener" {
  description = "Create the development ALB HTTPS listener."
  type        = bool
  default     = false
}

variable "enable_alb_http_listener" {
  description = "Create development HTTP-to-HTTPS redirect ingress."
  type        = bool
  default     = false
}

variable "alb_waf_web_acl_arn" {
  description = "Optional existing WAFv2 Web ACL ARN to associate with the development ALB."
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
  description = "Development ECS Fargate CPU units."
  type        = number
  default     = 256
}

variable "ecs_task_memory" {
  description = "Development ECS Fargate memory in MiB."
  type        = number
  default     = 512
}

variable "ecs_desired_count" {
  description = "Development ECS desired task count."
  type        = number
  default     = 1
}

variable "ecs_health_check_grace_period" {
  description = "Development ECS ALB health-check grace period."
  type        = number
  default     = 60
}

variable "ecs_enable_container_insights" {
  description = "Enable ECS Container Insights in development."
  type        = bool
  default     = false
}

variable "ecs_log_retention_days" {
  description = "Development ECS application log retention."
  type        = number
  default     = 30
}

variable "ecs_database_host" {
  description = "Existing RDS or PostgreSQL endpoint for development."
  type        = string
  default     = null
  nullable    = true
}

variable "ecs_database_name" {
  description = "Existing development PostgreSQL database name."
  type        = string
  default     = null
  nullable    = true
}

variable "ecs_database_user" {
  description = "Existing restricted development PostgreSQL username."
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
  description = "Development JWT issuer URL."
  type        = string
  default     = null
  nullable    = true
}

variable "ecs_jwt_audience" {
  description = "Development JWT audience."
  type        = string
  default     = null
  nullable    = true
}

variable "rds_instance_class" {
  type    = string
  default = "db.t4g.micro"
}

variable "rds_allocated_storage" {
  type    = number
  default = 20
}

variable "rds_max_allocated_storage" {
  type    = number
  default = 100
}

variable "rds_backup_retention_days" {
  type    = number
  default = 7
}

variable "rds_deletion_protection" {
  type    = bool
  default = false
}

variable "monitoring_enabled" {
  description = "Explicitly enable development CloudWatch dashboards, alarms, and optional SNS resources."
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
  description = "Create an encrypted development SNS topic when monitoring is enabled."
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
  description = "Development ECS service CPU alarm threshold."
  type        = number
  default     = 85
}

variable "monitoring_ecs_memory_threshold_percent" {
  description = "Development ECS service memory alarm threshold."
  type        = number
  default     = 85
}

variable "monitoring_alb_unhealthy_targets_threshold" {
  description = "Development ALB unhealthy-target count threshold."
  type        = number
  default     = 0
}

variable "monitoring_alb_target_5xx_threshold" {
  description = "Development target-generated HTTP 5xx count per alarm period."
  type        = number
  default     = 10
}

variable "monitoring_alb_lb_5xx_threshold" {
  description = "Development ALB-generated HTTP 5xx count per alarm period."
  type        = number
  default     = 10
}

variable "monitoring_alb_response_time_seconds" {
  description = "Development average target response-time threshold."
  type        = number
  default     = 1.5
}

variable "monitoring_rds_cpu_threshold_percent" {
  description = "Development RDS CPU alarm threshold."
  type        = number
  default     = 80
}

variable "monitoring_rds_free_storage_threshold_bytes" {
  description = "Development RDS free-storage alarm threshold in bytes."
  type        = number
  default     = 5368709120
}

variable "monitoring_rds_connection_threshold" {
  description = "Capacity-derived development PostgreSQL connection alarm threshold; recalculate if the instance class changes."
  type        = number
  default     = 80
}

variable "monitoring_rds_freeable_memory_threshold_bytes" {
  description = "Development RDS freeable-memory alarm threshold in bytes."
  type        = number
  default     = 268435456
}

variable "database_subnet_cidrs" {
  description = "Dedicated private database subnet CIDRs for development."
  type        = list(string)
  default     = ["10.20.20.0/24", "10.20.21.0/24"]
}

variable "ecr_repository_name" {
  description = "Private development ECR repository name."
  type        = string
  default     = "production-ready-aws-devops-platform-dev-api"
}

variable "ecr_scan_on_push" {
  description = "Enable basic ECR scan-on-push for the development repository."
  type        = bool
  default     = true
}

variable "ecr_force_delete" {
  description = "Allow forced repository deletion in development."
  type        = bool
  default     = false
}

variable "ecr_lifecycle_policy_enabled" {
  description = "Attach the development ECR lifecycle policy."
  type        = bool
  default     = true
}

variable "ecr_production_image_retention" {
  description = "Development production-tagged image retention count."
  type        = number
  default     = 10
}

variable "ecr_rollback_image_retention" {
  description = "Development rollback-tagged image retention count."
  type        = number
  default     = 5
}

variable "ecr_sha_image_retention" {
  description = "Development SHA-tagged image retention count."
  type        = number
  default     = 20
}
