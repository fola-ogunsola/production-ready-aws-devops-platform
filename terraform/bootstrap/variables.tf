variable "project_name" {
  description = "Lowercase project identifier used in backend resource names and tags."
  type        = string
  default     = "production-ready-aws-devops-platform"

  validation {
    condition     = can(regex("^[a-z0-9]([a-z0-9-]*[a-z0-9])?$", var.project_name))
    error_message = "project_name must contain only lowercase letters, digits, and internal hyphens."
  }

  validation {
    condition = length(format(
      "tfstate-%s--%s",
      replace(var.project_name, "-platform", ""),
      var.aws_region
    )) + 12 <= 63
    error_message = "project_name and aws_region produce an S3 bucket name longer than 63 characters."
  }
}

variable "aws_region" {
  description = "AWS region in which to create the state bucket."
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
  description = "Required 12-digit account guard. Provider operations are restricted to this account."
  type        = string

  validation {
    condition     = can(regex("^[0-9]{12}$", var.expected_account_id))
    error_message = "expected_account_id must be the intended 12-digit AWS account ID."
  }
}

variable "additional_tags" {
  description = "Additional non-sensitive tags to apply to bootstrap resources."
  type        = map(string)
  default     = {}
}
