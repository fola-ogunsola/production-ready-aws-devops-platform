variable "name_prefix" {
  description = "Environment-scoped prefix for ECS resources."
  type        = string

  validation {
    condition     = length(trimspace(var.name_prefix)) > 0
    error_message = "name_prefix must not be empty."
  }
}

variable "private_subnet_ids" {
  description = "Private subnet IDs used for ECS awsvpc tasks."
  type        = list(string)

  validation {
    condition     = length(var.private_subnet_ids) >= 2
    error_message = "At least two private subnet IDs are required."
  }
}

variable "ecs_security_group_id" {
  description = "Existing ECS task security group."
  type        = string

  validation {
    condition     = can(regex("^sg-[0-9a-f]+$", var.ecs_security_group_id))
    error_message = "ecs_security_group_id must be a valid security-group ID."
  }
}

variable "target_group_arn" {
  description = "Existing ALB IP target group ARN."
  type        = string
  default     = null
  nullable    = true
}

variable "https_listener_arn" {
  description = "Existing ALB HTTPS listener ARN. Required before service deployment."
  type        = string
  default     = null
  nullable    = true
}

variable "image_reference" {
  description = "Full ECR image reference. Use sha-<Git SHA> or a digest; latest is forbidden."
  type        = string
  default     = null
  nullable    = true

  validation {
    condition = (
      var.image_reference == null ||
      (
        !can(regex("(^|:)latest$", var.image_reference)) &&
        (
          can(regex("@sha256:[0-9a-f]{64}$", var.image_reference)) ||
          can(regex(":sha-[0-9a-f]{7,64}$", var.image_reference)) ||
          can(regex(":v?[0-9][0-9a-zA-Z._-]*$", var.image_reference))
        )
      )
    )
    error_message = "image_reference must use a SHA/digest or immutable release tag; latest is forbidden."
  }
}

variable "enable_service" {
  description = "Create the ECS task definition and service only after real deployment prerequisites exist."
  type        = bool
  default     = false
}

variable "task_cpu" {
  description = "Fargate task CPU units."
  type        = number
  default     = 256

  validation {
    condition     = contains([256, 512, 1024, 2048, 4096], var.task_cpu)
    error_message = "task_cpu must be a supported Fargate CPU value."
  }
}

variable "task_memory" {
  description = "Fargate task memory in MiB."
  type        = number
  default     = 512

  validation {
    condition     = contains([512, 1024, 2048, 3072, 4096, 5120, 6144, 7168, 8192, 16384, 20480, 30720], var.task_memory)
    error_message = "task_memory must be a supported Fargate memory value."
  }
}

variable "desired_count" {
  description = "Desired ECS task count."
  type        = number
  default     = 1

  validation {
    condition     = var.desired_count >= 1 && var.desired_count <= 20
    error_message = "desired_count must be between 1 and 20."
  }
}

variable "deployment_minimum_healthy_percent" {
  description = "Minimum healthy tasks during deployment."
  type        = number
  default     = 100
}

variable "deployment_maximum_percent" {
  description = "Maximum tasks during deployment."
  type        = number
  default     = 200
}

variable "health_check_grace_period" {
  description = "Seconds before ALB unhealthy threshold begins."
  type        = number
  default     = 60

  validation {
    condition     = var.health_check_grace_period >= 0 && var.health_check_grace_period <= 3600
    error_message = "health_check_grace_period must be between 0 and 3600 seconds."
  }
}

variable "enable_container_insights" {
  description = "Enable ECS Container Insights for the cluster."
  type        = bool
  default     = false
}

variable "execution_role_arn" {
  description = "Existing ECS task execution role ARN."
  type        = string
}

variable "task_role_arn" {
  description = "Existing ECS application task role ARN."
  type        = string
}

variable "database_host" {
  description = "PostgreSQL endpoint hostname."
  type        = string
  default     = null
  nullable    = true
}

variable "database_name" {
  description = "PostgreSQL database name."
  type        = string
  default     = null
  nullable    = true
}

variable "database_user" {
  description = "Restricted PostgreSQL application username."
  type        = string
  default     = null
  nullable    = true
}

variable "database_port" {
  description = "PostgreSQL port."
  type        = number
  default     = 5432
}

variable "secret_environment_variables" {
  description = "Existing Secrets Manager ARN references keyed by DATABASE_PASSWORD and JWT_SECRET_BASE64."
  type        = map(string)
  default     = {}

  validation {
    condition = alltrue([
      for arn in values(var.secret_environment_variables) :
      can(regex("^arn:[^:]+:secretsmanager:[^:]+:[0-9]{12}:secret:.+$", arn))
    ])
    error_message = "Every secret reference must be an existing Secrets Manager secret ARN."
  }
}

variable "jwt_issuer" {
  description = "JWT issuer URL."
  type        = string
  default     = null
  nullable    = true
}

variable "jwt_audience" {
  description = "JWT audience."
  type        = string
  default     = null
  nullable    = true
}

variable "cors_origins" {
  description = "Comma-separated exact HTTPS/HTTP origins."
  type        = string
  default     = ""
}

variable "log_retention_days" {
  description = "CloudWatch Logs retention for ECS application logs."
  type        = number
  default     = 30

  validation {
    condition     = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288, 3653], var.log_retention_days)
    error_message = "log_retention_days must be a supported CloudWatch retention period."
  }
}

variable "log_kms_key_arn" {
  description = "Optional existing KMS key ARN for ECS application logs."
  type        = string
  default     = null
  nullable    = true
}

variable "database_ssl" {
  description = "Enable verified TLS connections to PostgreSQL."
  type        = bool
  default     = false
}

variable "database_ssl_ca" {
  description = "Optional PEM RDS CA bundle content or public CA path configuration."
  type        = string
  default     = null
  nullable    = true
  sensitive   = false
}

variable "tags" {
  description = "Tags applied to ECS resources."
  type        = map(string)
  default     = {}
}
