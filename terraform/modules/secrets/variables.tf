variable "name_prefix" {
  type = string
  validation {
    condition     = length(trimspace(var.name_prefix)) > 0
    error_message = "name_prefix must not be empty."
  }
}

variable "kms_key_arn" {
  type     = string
  default  = null
  nullable = true
}

variable "recovery_window_days" {
  type    = number
  default = 30
  validation {
    condition     = var.recovery_window_days >= 7 && var.recovery_window_days <= 30
    error_message = "recovery_window_days must be between 7 and 30."
  }
}

variable "create_database_password_secret" {
  type    = bool
  default = true
}

variable "create_jwt_secret" {
  type    = bool
  default = true
}

variable "tags" {
  type    = map(string)
  default = {}
}
