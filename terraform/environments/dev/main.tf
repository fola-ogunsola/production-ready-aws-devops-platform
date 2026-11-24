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

  name_prefix           = local.name_prefix
  vpc_cidr              = var.vpc_cidr
  availability_zones    = var.availability_zones
  public_subnet_cidrs   = var.public_subnet_cidrs
  private_subnet_cidrs  = var.private_subnet_cidrs
  database_subnet_cidrs = var.database_subnet_cidrs
  tags                  = local.common_tags
}

module "networking" {
  source = "../../modules/networking"

  name_prefix                = local.name_prefix
  vpc_id                     = module.vpc.vpc_id
  internet_gateway_id        = module.vpc.internet_gateway_id
  availability_zones         = var.availability_zones
  public_subnet_ids          = module.vpc.public_subnet_ids
  private_subnet_ids         = module.vpc.private_subnet_ids
  database_subnet_ids        = module.vpc.database_subnet_ids
  enable_nat_gateway         = var.enable_nat_gateway
  single_nat_gateway         = var.single_nat_gateway
  enable_s3_gateway_endpoint = var.enable_s3_gateway_endpoint
  tags                       = local.common_tags
}

module "security" {
  source = "../../modules/security"

  name_prefix                      = local.name_prefix
  vpc_id                           = module.vpc.vpc_id
  vpc_cidr                         = var.vpc_cidr
  application_port                 = var.application_port
  database_port                    = var.database_port
  alb_ingress_cidrs                = var.alb_ingress_cidrs
  enable_alb_http_ingress          = var.enable_alb_http_ingress
  ecs_https_egress_cidrs           = var.ecs_https_egress_cidrs
  ecs_https_egress_prefix_list_ids = []
  tags                             = local.common_tags
}

module "alb" {
  source = "../../modules/alb"

  name_prefix                = local.name_prefix
  vpc_id                     = module.vpc.vpc_id
  subnet_ids                 = values(module.vpc.public_subnet_ids)
  alb_security_group_id      = module.security.alb_security_group_id
  application_port           = var.application_port
  alb_scheme                 = var.alb_scheme
  enable_deletion_protection = var.enable_alb_deletion_protection
  https_listener_enabled     = var.enable_alb_https_listener
  acm_certificate_arn        = var.alb_acm_certificate_arn
  enable_http_listener       = var.enable_alb_http_listener
  enable_access_logs         = var.enable_alb_access_logs
  access_logs_bucket_id      = var.alb_access_logs_bucket_id
  waf_web_acl_arn            = var.alb_waf_web_acl_arn
  tags                       = local.common_tags
}

module "ecr" {
  source = "../../modules/ecr"

  name_prefix                = local.name_prefix
  repository_name            = var.ecr_repository_name
  image_tag_mutability       = "IMMUTABLE"
  encryption_type            = "AES256"
  scan_on_push               = var.ecr_scan_on_push
  force_delete               = var.ecr_force_delete
  lifecycle_policy_enabled   = var.ecr_lifecycle_policy_enabled
  production_image_retention = var.ecr_production_image_retention
  rollback_image_retention   = var.ecr_rollback_image_retention
  sha_image_retention        = var.ecr_sha_image_retention
  untagged_image_retention   = 2
  tags                       = local.common_tags
}

module "iam" {
  source = "../../modules/iam"

  name_prefix        = local.name_prefix
  ecr_repository_arn = module.ecr.repository_arn
  log_group_name     = "/ecs/${local.name_prefix}-api"
  secret_arns        = merge(var.ecs_secret_environment_variables, module.secrets.secret_arns)
  kms_key_arns       = var.ecs_kms_key_arns
  tags               = local.common_tags
}

module "ecs" {
  source = "../../modules/ecs"

  name_prefix                  = local.name_prefix
  private_subnet_ids           = values(module.vpc.private_subnet_ids)
  ecs_security_group_id        = module.security.ecs_security_group_id
  target_group_arn             = module.alb.target_group_arn
  https_listener_arn           = module.alb.https_listener_arn
  image_reference              = var.ecs_image_reference
  enable_service               = var.enable_ecs_service
  task_cpu                     = var.ecs_task_cpu
  task_memory                  = var.ecs_task_memory
  desired_count                = var.ecs_desired_count
  health_check_grace_period    = var.ecs_health_check_grace_period
  enable_container_insights    = var.ecs_enable_container_insights
  execution_role_arn           = module.iam.task_execution_role_arn
  task_role_arn                = module.iam.task_role_arn
  database_host                = var.ecs_database_host != null ? var.ecs_database_host : module.rds.db_endpoint
  database_name                = var.ecs_database_name != null ? var.ecs_database_name : module.rds.db_name
  database_user                = var.ecs_database_user
  database_ssl                 = true
  database_ssl_ca              = null
  secret_environment_variables = merge(var.ecs_secret_environment_variables, module.secrets.secret_arns)
  jwt_issuer                   = var.ecs_jwt_issuer
  jwt_audience                 = var.ecs_jwt_audience
  log_retention_days           = var.ecs_log_retention_days
  tags                         = local.common_tags
}

module "rds" {
  source = "../../modules/rds"

  name_prefix           = local.name_prefix
  database_subnet_ids   = values(module.vpc.database_subnet_ids)
  rds_security_group_id = module.security.rds_security_group_id
  database_name         = "task_api"
  master_username       = "platform_admin"
  instance_class        = var.rds_instance_class
  allocated_storage     = var.rds_allocated_storage
  max_allocated_storage = var.rds_max_allocated_storage
  multi_az              = false
  backup_retention_days = var.rds_backup_retention_days
  deletion_protection   = var.rds_deletion_protection
  skip_final_snapshot   = true
  tags                  = local.common_tags
}

module "secrets" {
  source = "../../modules/secrets"

  name_prefix                     = local.name_prefix
  create_database_password_secret = true
  create_jwt_secret               = true
  tags                            = local.common_tags
}

module "monitoring" {
  source = "../../modules/monitoring"

  enabled                                    = var.monitoring_enabled
  name_prefix                                = local.name_prefix
  aws_region                                 = var.aws_region
  tags                                       = local.common_tags
  existing_sns_topic_arn                     = var.monitoring_sns_topic_arn
  create_sns_topic                           = var.monitoring_create_sns_topic
  alarm_actions_enabled                      = var.monitoring_alarm_actions_enabled
  alarm_period_seconds                       = var.monitoring_alarm_period_seconds
  evaluation_periods                         = var.monitoring_evaluation_periods
  datapoints_to_alarm                        = var.monitoring_datapoints_to_alarm
  ecs_cluster_name                           = module.ecs.cluster_name
  ecs_service_name                           = module.ecs.deployment_ready ? module.ecs.service_name : null
  ecs_service_deployed                       = module.ecs.deployment_ready
  container_insights_enabled                 = var.ecs_enable_container_insights
  ecs_min_running_tasks                      = var.monitoring_ecs_min_running_tasks
  ecs_cpu_threshold_percent                  = var.monitoring_ecs_cpu_threshold_percent
  ecs_memory_threshold_percent               = var.monitoring_ecs_memory_threshold_percent
  load_balancer_arn                          = module.alb.alb_arn
  target_group_arn                           = module.alb.target_group_arn
  alb_unhealthy_targets_threshold            = var.monitoring_alb_unhealthy_targets_threshold
  alb_target_5xx_threshold                   = var.monitoring_alb_target_5xx_threshold
  alb_load_balancer_5xx_threshold            = var.monitoring_alb_lb_5xx_threshold
  alb_target_response_time_threshold_seconds = var.monitoring_alb_response_time_seconds
  rds_instance_identifier                    = module.rds.db_instance_id
  rds_cpu_threshold_percent                  = var.monitoring_rds_cpu_threshold_percent
  rds_free_storage_threshold_bytes           = var.monitoring_rds_free_storage_threshold_bytes
  rds_connection_threshold                   = var.monitoring_rds_connection_threshold
  rds_freeable_memory_threshold_bytes        = var.monitoring_rds_freeable_memory_threshold_bytes
  application_log_group_name                 = module.ecs.log_group_name
}
