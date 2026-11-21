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
