locals {
  name_prefix = "${var.project_name}-${var.environment}"

  common_tags = merge(var.additional_tags, {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
    Repository  = "production-ready-aws-devops-platform"
  })
}

module "vpc" {
  source = "../../modules/vpc"

  name_prefix          = local.name_prefix
  vpc_cidr             = var.vpc_cidr
  availability_zones   = var.availability_zones
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  tags                 = local.common_tags
}

module "networking" {
  source = "../../modules/networking"

  name_prefix                = local.name_prefix
  vpc_id                     = module.vpc.vpc_id
  internet_gateway_id        = module.vpc.internet_gateway_id
  availability_zones         = var.availability_zones
  public_subnet_ids          = module.vpc.public_subnet_ids
  private_subnet_ids         = module.vpc.private_subnet_ids
  enable_nat_gateway         = var.enable_nat_gateway
  single_nat_gateway         = var.single_nat_gateway
  enable_s3_gateway_endpoint = var.enable_s3_gateway_endpoint
  tags                       = local.common_tags
}
