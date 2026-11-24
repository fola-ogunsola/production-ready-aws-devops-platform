variable "name_prefix" {
  description = "Environment-scoped prefix for ECS IAM roles."
  type        = string

  validation {
    condition     = length(trimspace(var.name_prefix)) > 0
    error_message = "name_prefix must not be empty."
  }
}

variable "ecr_repository_arn" {
  description = "ECR repository ARN used for task image pulls."
  type        = string

  validation {
    condition     = can(regex("^arn:[^:]+:ecr:[^:]+:[0-9]{12}:repository/.+$", var.ecr_repository_arn))
    error_message = "ecr_repository_arn must be a valid repository ARN."
  }
}

variable "log_group_name" {
  description = "CloudWatch log group name used by ECS application containers."
  type        = string

  validation {
    condition     = length(trimspace(var.log_group_name)) > 0
    error_message = "log_group_name must not be empty."
  }
}

variable "secret_arns" {
  description = "Explicit Secrets Manager ARNs authorized for ECS task execution."
  type        = map(string)
  default     = {}

  validation {
    condition = alltrue([
      for arn in values(var.secret_arns) :
      can(regex("^arn:[^:]+:secretsmanager:[^:]+:[0-9]{12}:secret:.+$", arn))
    ])
    error_message = "Every secret ARN must be a Secrets Manager secret ARN."
  }
}

variable "kms_key_arns" {
  description = "Explicit KMS key ARNs authorized for approved secrets."
  type        = map(string)
  default     = {}

  validation {
    condition = alltrue([
      for arn in values(var.kms_key_arns) :
      can(regex("^arn:[^:]+:kms:[^:]+:[0-9]{12}:key/.+$", arn))
    ])
    error_message = "Every KMS key ARN must be a customer key ARN."
  }
}

variable "tags" {
  description = "Tags applied to IAM roles."
  type        = map(string)
  default     = {}
}
