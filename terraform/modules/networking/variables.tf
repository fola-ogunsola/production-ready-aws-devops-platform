variable "name_prefix" {
  description = "Environment-scoped prefix used for networking resource names."
  type        = string
}

variable "vpc_id" {
  description = "ID of the VPC to configure."
  type        = string
}

variable "internet_gateway_id" {
  description = "ID of the VPC internet gateway."
  type        = string
}

variable "availability_zones" {
  description = "Availability zones represented by the subnet maps."
  type        = list(string)
}

variable "public_subnet_ids" {
  description = "Public subnet IDs keyed by availability zone."
  type        = map(string)
}

variable "private_subnet_ids" {
  description = "Private subnet IDs keyed by availability zone."
  type        = map(string)
}

variable "database_subnet_ids" {
  description = "Dedicated database subnet IDs keyed by availability zone."
  type        = map(string)
  default     = {}
}

variable "enable_nat_gateway" {
  description = "Create NAT gateways for private subnet internet egress."
  type        = bool
  default     = true
}

variable "single_nat_gateway" {
  description = "Use one NAT gateway for all private subnets. Use false for production multi-AZ egress."
  type        = bool
  default     = false
}

variable "enable_s3_gateway_endpoint" {
  description = "Create a gateway VPC endpoint for Amazon S3."
  type        = bool
  default     = true
}

variable "tags" {
  description = "Additional tags applied to networking resources."
  type        = map(string)
  default     = {}
}
