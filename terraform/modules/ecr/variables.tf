variable "name_prefix" {
  description = "Environment-scoped prefix used for ECR resource naming."
  type        = string

  validation {
    condition     = length(trimspace(var.name_prefix)) > 0
    error_message = "name_prefix must not be empty."
  }
}

variable "repository_name" {
  description = "Private ECR repository name."
  type        = string
  default     = null
  nullable    = true

  validation {
    condition = (
      var.repository_name == null ||
      can(regex("^(?:[a-z0-9]+(?:[._/-][a-z0-9]+)*)$", var.repository_name))
    )
    error_message = "repository_name must be a valid private ECR repository name."
  }
}

variable "image_tag_mutability" {
  description = "ECR tag mutability setting."
  type        = string
  default     = "IMMUTABLE"

  validation {
    condition     = contains(["IMMUTABLE", "MUTABLE"], var.image_tag_mutability)
    error_message = "image_tag_mutability must be IMMUTABLE or MUTABLE."
  }
}

variable "encryption_type" {
  description = "ECR encryption type."
  type        = string
  default     = "AES256"

  validation {
    condition     = contains(["AES256", "KMS", "KMS_DSSE"], var.encryption_type)
    error_message = "encryption_type must be AES256, KMS, or KMS_DSSE."
  }
}

variable "kms_key_arn" {
  description = "Existing KMS key ARN for ECR encryption when KMS or KMS_DSSE is selected."
  type        = string
  default     = null
  nullable    = true

  validation {
    condition = (
      var.encryption_type == "AES256" ||
      (
        var.kms_key_arn != null &&
        can(regex("^arn:[^:]+:kms:[^:]+:[0-9]{12}:key/.+$", var.kms_key_arn))
      )
    )
    error_message = "KMS or KMS_DSSE encryption requires a valid account-specific KMS key ARN."
  }
}

variable "scan_on_push" {
  description = "Enable basic ECR scan-on-push. Enhanced Inspector scanning is not enabled by this module."
  type        = bool
  default     = true
}

variable "force_delete" {
  description = "Allow deletion of the repository even when images remain. Defaults to false for rollback protection."
  type        = bool
  default     = false
}

variable "lifecycle_policy_enabled" {
  description = "Attach lifecycle rules that expire old images while retaining deployment and rollback tags."
  type        = bool
  default     = true
}

variable "production_image_retention" {
  description = "Maximum number of production-tagged images retained."
  type        = number
  default     = 30

  validation {
    condition     = var.production_image_retention >= 1 && var.production_image_retention <= 100
    error_message = "production_image_retention must be between 1 and 100."
  }
}

variable "rollback_image_retention" {
  description = "Maximum number of rollback-tagged images retained."
  type        = number
  default     = 10

  validation {
    condition     = var.rollback_image_retention >= 1 && var.rollback_image_retention <= 100
    error_message = "rollback_image_retention must be between 1 and 100."
  }
}

variable "sha_image_retention" {
  description = "Maximum number of immutable SHA-tagged images retained."
  type        = number
  default     = 50

  validation {
    condition     = var.sha_image_retention >= 1 && var.sha_image_retention <= 100
    error_message = "sha_image_retention must be between 1 and 100."
  }
}

variable "untagged_image_retention" {
  description = "Maximum number of untagged image manifests retained."
  type        = number
  default     = 2

  validation {
    condition     = var.untagged_image_retention >= 1 && var.untagged_image_retention <= 100
    error_message = "untagged_image_retention must be between 1 and 100."
  }
}

variable "tags" {
  description = "Additional tags applied to the ECR repository."
  type        = map(string)
  default     = {}
}
