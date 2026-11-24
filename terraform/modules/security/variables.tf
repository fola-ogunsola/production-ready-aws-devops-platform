variable "name_prefix" {
  description = "Environment-scoped prefix used for security-group names."
  type        = string

  validation {
    condition     = length(trimspace(var.name_prefix)) > 0
    error_message = "name_prefix must not be empty."
  }
}

variable "vpc_id" {
  description = "ID of the VPC in which workload security groups are created."
  type        = string

  validation {
    condition     = can(regex("^vpc-[0-9a-f]+$", var.vpc_id))
    error_message = "vpc_id must be a valid VPC resource ID."
  }
}

variable "vpc_cidr" {
  description = "IPv4 CIDR block of the VPC, used to restrict DNS egress."
  type        = string

  validation {
    condition     = can(cidrnetmask(var.vpc_cidr))
    error_message = "vpc_cidr must be a valid IPv4 CIDR block."
  }
}

variable "application_port" {
  description = "TCP port exposed by the ECS application."
  type        = number
  default     = 3000

  validation {
    condition     = var.application_port >= 1 && var.application_port <= 65535
    error_message = "application_port must be between 1 and 65535."
  }
}

variable "database_port" {
  description = "TCP port exposed by RDS PostgreSQL."
  type        = number
  default     = 5432

  validation {
    condition     = var.database_port == 5432
    error_message = "database_port must be 5432 for PostgreSQL."
  }
}

variable "alb_ingress_cidrs" {
  description = "Approved IPv4 CIDR ranges permitted to reach the public ALB over HTTPS."
  type        = list(string)
  default     = ["0.0.0.0/0"]

  validation {
    condition     = length(var.alb_ingress_cidrs) > 0
    error_message = "alb_ingress_cidrs must contain at least one CIDR."
  }

  validation {
    condition = alltrue([
      for cidr in var.alb_ingress_cidrs : can(cidrnetmask(cidr))
    ])
    error_message = "Every alb_ingress_cidrs entry must be a valid IPv4 CIDR."
  }
}

variable "enable_alb_http_ingress" {
  description = "Allow TCP 80 on the ALB for HTTP-to-HTTPS redirection."
  type        = bool
  default     = false
}

variable "ecs_https_egress_cidrs" {
  description = "Approved IPv4 destinations for ECS TCP 443 service connectivity. Prefer VPC endpoints or narrow CIDRs over internet ranges."
  type        = list(string)
  default     = ["0.0.0.0/0"]

  validation {
    condition = alltrue([
      for cidr in var.ecs_https_egress_cidrs : can(cidrnetmask(cidr))
    ])
    error_message = "Every ecs_https_egress_cidrs entry must be a valid IPv4 CIDR."
  }
}

variable "ecs_https_egress_prefix_list_ids" {
  description = "Optional managed or gateway prefix lists for ECS HTTPS connectivity."
  type        = list(string)
  default     = []

  validation {
    condition = alltrue([
      for prefix_list_id in var.ecs_https_egress_prefix_list_ids :
      can(regex("^pl-[0-9a-f]+$", prefix_list_id))
    ])
    error_message = "Every entry must be a valid prefix-list ID."
  }
}

variable "tags" {
  description = "Additional tags applied to workload security groups."
  type        = map(string)
  default     = {}
}
