variable "name_prefix" {
  type = string
  validation {
    condition     = length(trimspace(var.name_prefix)) > 0
    error_message = "name_prefix must not be empty."
  }
}

variable "database_subnet_ids" {
  description = "Dedicated private database subnet IDs."
  type        = list(string)
  validation {
    condition     = length(var.database_subnet_ids) >= 2
    error_message = "At least two database subnet IDs are required."
  }
}

variable "rds_security_group_id" {
  type = string
  validation {
    condition     = can(regex("^sg-[0-9a-f]+$", var.rds_security_group_id))
    error_message = "rds_security_group_id must be a valid security-group ID."
  }
}

variable "database_name" {
  type = string
  validation {
    condition     = can(regex("^[A-Za-z][A-Za-z0-9_]{0,63}$", var.database_name))
    error_message = "database_name must be a valid PostgreSQL database identifier."
  }
}

variable "master_username" {
  type = string
  validation {
    condition     = can(regex("^[A-Za-z][A-Za-z0-9_]{0,63}$", var.master_username))
    error_message = "master_username must be a valid PostgreSQL role identifier."
  }
}

variable "engine_version" {
  type    = string
  default = "17.4"
  validation {
    condition     = can(regex("^1[67]\\.[0-9]+$", var.engine_version))
    error_message = "engine_version must be a PostgreSQL 16 or 17 supported major/minor version."
  }
}

variable "instance_class" {
  type    = string
  default = "db.t4g.micro"
}

variable "allocated_storage" {
  type    = number
  default = 20
  validation {
    condition     = var.allocated_storage >= 20 && var.allocated_storage <= 65536
    error_message = "allocated_storage must be between 20 and 65536 GiB."
  }
}

variable "max_allocated_storage" {
  type    = number
  default = 100
  validation {
    condition     = var.max_allocated_storage >= var.allocated_storage
    error_message = "max_allocated_storage must not be below allocated_storage."
  }
}

variable "multi_az" {
  type    = bool
  default = true
}

variable "backup_retention_days" {
  type    = number
  default = 7
  validation {
    condition     = var.backup_retention_days >= 7 && var.backup_retention_days <= 35
    error_message = "backup_retention_days must be between 7 and 35."
  }
}

variable "backup_window" {
  type    = string
  default = "03:00-04:00"
}

variable "maintenance_window" {
  type    = string
  default = "sun:04:00-sun:05:00"
}

variable "deletion_protection" {
  type    = bool
  default = true
}

variable "skip_final_snapshot" {
  type    = bool
  default = true
}

variable "kms_key_arn" {
  type     = string
  default  = null
  nullable = true
}

variable "enabled_cloudwatch_logs_exports" {
  type    = list(string)
  default = ["postgresql", "upgrade"]
  validation {
    condition = alltrue([
      for log in var.enabled_cloudwatch_logs_exports : contains(["postgresql", "upgrade"], log)
    ])
    error_message = "Only supported PostgreSQL exports may be selected."
  }
}

variable "iam_database_authentication_enabled" {
  type    = bool
  default = true
}

variable "performance_insights_enabled" {
  type    = bool
  default = true
}

variable "performance_insights_retention_period" {
  type    = number
  default = 7
  validation {
    condition     = contains([7, 31, 62, 93, 186, 372, 731], var.performance_insights_retention_period)
    error_message = "Performance Insights retention must be a supported RDS period."
  }
}

variable "monitoring_interval" {
  type    = number
  default = 60
  validation {
    condition     = contains([0, 1, 5, 10, 15, 30, 60], var.monitoring_interval)
    error_message = "monitoring_interval must be a supported RDS monitoring interval."
  }
}

variable "tags" {
  type    = map(string)
  default = {}
}
