variable "name_prefix" {
  description = "Environment-scoped prefix used for ALB resource names."
  type        = string

  validation {
    condition     = length(trimspace(var.name_prefix)) > 0
    error_message = "name_prefix must not be empty."
  }
}

variable "vpc_id" {
  description = "VPC containing the target group."
  type        = string

  validation {
    condition     = can(regex("^vpc-[0-9a-f]+$", var.vpc_id))
    error_message = "vpc_id must be a valid VPC resource ID."
  }
}

variable "subnet_ids" {
  description = "Subnets in at least two availability zones for ALB placement."
  type        = list(string)

  validation {
    condition     = length(var.subnet_ids) >= 2
    error_message = "At least two subnet IDs are required for the ALB."
  }
}

variable "alb_security_group_id" {
  description = "Existing ALB security-group ID."
  type        = string

  validation {
    condition     = can(regex("^sg-[0-9a-f]+$", var.alb_security_group_id))
    error_message = "alb_security_group_id must be a valid security-group ID."
  }
}

variable "application_port" {
  description = "TCP port used for ECS application traffic."
  type        = number
  default     = 3000

  validation {
    condition     = var.application_port >= 1 && var.application_port <= 65535
    error_message = "application_port must be between 1 and 65535."
  }
}

variable "alb_scheme" {
  description = "ALB placement scheme."
  type        = string
  default     = "internet-facing"

  validation {
    condition     = contains(["internet-facing", "internal"], var.alb_scheme)
    error_message = "alb_scheme must be either internet-facing or internal."
  }
}

variable "enable_deletion_protection" {
  description = "Prevent accidental ALB deletion."
  type        = bool
  default     = true
}

variable "https_listener_enabled" {
  description = "Create the HTTPS listener on TCP 443."
  type        = bool
  default     = false

  validation {
    condition = (
      !var.https_listener_enabled ||
      (
        var.acm_certificate_arn != null &&
        trimspace(var.acm_certificate_arn) != "" &&
        can(regex("^arn:[^:]+:acm:[^:]+:[0-9]{12}:certificate/.+$", var.acm_certificate_arn))
      )
    )
    error_message = "https_listener_enabled requires a valid existing ACM certificate ARN."
  }
}

variable "acm_certificate_arn" {
  description = "ARN of an existing ACM certificate; required only for the HTTPS listener."
  type        = string
  default     = null
  nullable    = true
}

variable "enable_http_listener" {
  description = "Create HTTP TCP 80 ingress that redirects to HTTPS."
  type        = bool
  default     = false

  validation {
    condition     = !var.enable_http_listener || var.https_listener_enabled
    error_message = "HTTP listener redirection requires the HTTPS listener to be enabled."
  }
}

variable "tls_policy" {
  description = "AWS-supported TLS security policy for HTTPS."
  type        = string
  default     = "ELBSecurityPolicy-TLS13-1-2-2021-06"
}

variable "health_check_path" {
  description = "Readiness endpoint used for ECS application health checks."
  type        = string
  default     = "/health/ready"

  validation {
    condition     = can(regex("^/", var.health_check_path))
    error_message = "health_check_path must begin with '/'."
  }
}

variable "health_check_interval" {
  description = "Seconds between application health checks."
  type        = number
  default     = 30

  validation {
    condition     = var.health_check_interval >= 5 && var.health_check_interval <= 300
    error_message = "health_check_interval must be between 5 and 300 seconds."
  }
}

variable "health_check_timeout" {
  description = "Seconds to wait for an application health response."
  type        = number
  default     = 5

  validation {
    condition     = var.health_check_timeout >= 2 && var.health_check_timeout <= 120 && var.health_check_timeout < var.health_check_interval
    error_message = "health_check_timeout must be between 2 and 120 seconds and shorter than the health-check interval."
  }
}

variable "healthy_threshold" {
  description = "Consecutive successful checks required for a healthy target."
  type        = number
  default     = 2

  validation {
    condition     = var.healthy_threshold >= 2 && var.healthy_threshold <= 10
    error_message = "healthy_threshold must be between 2 and 10."
  }
}

variable "unhealthy_threshold" {
  description = "Consecutive failed checks required for an unhealthy target."
  type        = number
  default     = 3

  validation {
    condition     = var.unhealthy_threshold >= 2 && var.unhealthy_threshold <= 10
    error_message = "unhealthy_threshold must be between 2 and 10."
  }
}

variable "deregistration_delay" {
  description = "Seconds to wait for in-flight requests during target deregistration."
  type        = number
  default     = 30

  validation {
    condition     = var.deregistration_delay >= 0 && var.deregistration_delay <= 3600
    error_message = "deregistration_delay must be between 0 and 3600 seconds."
  }
}

variable "enable_access_logs" {
  description = "Enable ALB access logging to S3."
  type        = bool
  default     = false
}

variable "access_logs_bucket_id" {
  description = "Existing S3 bucket ID for ALB access logs. A private bucket is created when null and access logs are enabled."
  type        = string
  default     = null
  nullable    = true
}

variable "access_logs_prefix" {
  description = "Optional object-prefix used for ALB access logs."
  type        = string
  default     = "alb"

  validation {
    condition     = !can(regex("^/|/$", var.access_logs_prefix))
    error_message = "access_logs_prefix must not begin or end with '/'."
  }
}

variable "waf_web_acl_arn" {
  description = "Optional existing WAFv2 Web ACL ARN to associate with the public ALB."
  type        = string
  default     = null
  nullable    = true

  validation {
    condition = (
      var.waf_web_acl_arn == null ||
      (
        trimspace(var.waf_web_acl_arn) != "" &&
        can(regex("^arn:[^:]+:wafv2:[^:]+:[0-9]{12}:.*", var.waf_web_acl_arn))
      )
    )
    error_message = "waf_web_acl_arn must be a valid WAFv2 ARN."
  }
}

variable "tags" {
  description = "Additional tags applied to ALB resources."
  type        = map(string)
  default     = {}
}
