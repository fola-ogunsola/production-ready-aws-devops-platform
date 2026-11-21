output "project_name" {
  description = "Configured project name."
  value       = var.project_name
}

output "environment" {
  description = "Configured environment name."
  value       = var.environment
}

output "aws_region" {
  description = "Configured AWS region."
  value       = var.aws_region
}

output "resource_name_prefix" {
  description = "Environment-scoped prefix for future infrastructure resources."
  value       = local.name_prefix
}

output "common_tags" {
  description = "Standard tags that future modules should apply to resources."
  value       = local.common_tags
}

output "vpc_id" {
  description = "ID of the development VPC."
  value       = module.vpc.vpc_id
}

output "public_subnet_ids" {
  description = "Development public subnet IDs keyed by availability zone."
  value       = module.vpc.public_subnet_ids
}

output "private_subnet_ids" {
  description = "Development private subnet IDs keyed by availability zone."
  value       = module.vpc.private_subnet_ids
}

output "nat_gateway_ids" {
  description = "Development NAT gateway IDs keyed by availability zone."
  value       = module.networking.nat_gateway_ids
}

output "s3_vpc_endpoint_id" {
  description = "ID of the development S3 gateway endpoint, when enabled."
  value       = module.networking.s3_vpc_endpoint_id
}
