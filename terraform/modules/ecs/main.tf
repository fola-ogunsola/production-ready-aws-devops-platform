locals {
  cluster_name   = "${var.name_prefix}-ecs"
  service_name   = "${var.name_prefix}-api"
  log_group_name = "/ecs/${var.name_prefix}-api"

  valid_cpu_memory = {
    256  = [512, 1024, 2048]
    512  = [1024, 2048, 3072, 4096]
    1024 = [2048, 3072, 4096, 5120, 6144, 7168, 8192]
    2048 = [4096, 5120, 6144, 7168, 8192, 16384]
    4096 = [8192, 9216, 10240, 11264, 12288, 13312, 14336, 16384, 20480, 30720]
  }

  deployment_ready = (
    var.enable_service &&
    var.target_group_arn != null &&
    var.https_listener_arn != null &&
    var.image_reference != null &&
    var.database_host != null &&
    var.database_name != null &&
    var.database_user != null &&
    (!var.database_ssl || var.database_ssl_ca != null) &&
    var.jwt_issuer != null &&
    var.jwt_audience != null &&
    contains(keys(var.secret_environment_variables), "DATABASE_PASSWORD") &&
    contains(keys(var.secret_environment_variables), "JWT_SECRET_BASE64")
  )

  container_secrets = [
    for name in ["DATABASE_PASSWORD", "JWT_SECRET_BASE64"] : {
      name      = name
      valueFrom = var.secret_environment_variables[name]
    }
    if contains(keys(var.secret_environment_variables), name)
  ]

  plain_environment = [
    { name = "NODE_ENV", value = "production" },
    { name = "HOST", value = "0.0.0.0" },
    { name = "PORT", value = "3000" },
    { name = "LOG_LEVEL", value = "info" },
    { name = "CORS_ORIGINS", value = var.cors_origins },
    { name = "DATABASE_HOST", value = var.database_host },
    { name = "DATABASE_PORT", value = tostring(var.database_port) },
    { name = "DATABASE_NAME", value = var.database_name },
    { name = "DATABASE_USER", value = var.database_user },
    { name = "DATABASE_POOL_MAX", value = "10" },
    { name = "DATABASE_IDLE_TIMEOUT_MS", value = "30000" },
    { name = "DATABASE_CONNECTION_TIMEOUT_MS", value = "3000" },
    { name = "DATABASE_QUERY_TIMEOUT_MS", value = "5000" },
    { name = "DATABASE_SSL", value = var.database_ssl ? "true" : "false" },
    { name = "DATABASE_SSL_CA", value = var.database_ssl_ca },
    { name = "JWT_ISSUER", value = var.jwt_issuer },
    { name = "JWT_AUDIENCE", value = var.jwt_audience },
    { name = "JWT_EXPIRES_IN_SECONDS", value = "900" }
  ]

  container_definitions = jsonencode([{
    name                   = "api"
    image                  = var.image_reference
    essential              = true
    user                   = "65532:65532"
    readonlyRootFilesystem = true
    portMappings = [{
      name          = "api-http"
      containerPort = 3000
      hostPort      = 3000
      protocol      = "tcp"
    }]
    environment = [for item in local.plain_environment : item if item.value != null]
    secrets     = local.container_secrets
    healthCheck = {
      command     = ["CMD", "/nodejs/bin/node", "-e", "fetch('http://127.0.0.1:3000/health/live',{signal:AbortSignal.timeout(2000)}).then(r=>process.exit(r.ok?0:1),()=>process.exit(1))"]
      interval    = 30
      timeout     = 5
      retries     = 3
      startPeriod = 10
    }
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = local.log_group_name
        "awslogs-region"        = data.aws_region.current.region
        "awslogs-stream-prefix" = "ecs"
      }
    }
  }])
}

data "aws_region" "current" {}

resource "aws_cloudwatch_log_group" "ecs" {
  name              = local.log_group_name
  retention_in_days = var.log_retention_days
  kms_key_id        = var.log_kms_key_arn

  tags = merge(var.tags, {
    Name = local.log_group_name
  })
}

resource "aws_ecs_cluster" "this" {
  name = local.cluster_name

  setting {
    name  = "containerInsights"
    value = var.enable_container_insights ? "enabled" : "disabled"
  }

  tags = merge(var.tags, {
    Name = local.cluster_name
  })
}

resource "aws_ecs_task_definition" "api" {
  count = local.deployment_ready ? 1 : 0

  family                   = local.service_name
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = tostring(var.task_cpu)
  memory                   = tostring(var.task_memory)
  execution_role_arn       = var.execution_role_arn
  task_role_arn            = var.task_role_arn
  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }
  container_definitions = local.container_definitions

  tags = var.tags

  lifecycle {
    precondition {
      condition     = contains(local.valid_cpu_memory[tostring(var.task_cpu)], var.task_memory)
      error_message = "The task CPU and memory values must form a valid Fargate combination."
    }
  }
}

resource "aws_ecs_service" "api" {
  count = local.deployment_ready ? 1 : 0

  name                               = local.service_name
  cluster                            = aws_ecs_cluster.this.id
  task_definition                    = aws_ecs_task_definition.api[0].arn
  desired_count                      = var.desired_count
  launch_type                        = "FARGATE"
  platform_version                   = "LATEST"
  health_check_grace_period_seconds  = var.health_check_grace_period
  enable_execute_command             = false
  propagate_tags                     = "SERVICE"
  enable_ecs_managed_tags            = true
  deployment_minimum_healthy_percent = var.deployment_minimum_healthy_percent
  deployment_maximum_percent         = var.deployment_maximum_percent

  network_configuration {
    assign_public_ip = false
    security_groups  = [var.ecs_security_group_id]
    subnets          = var.private_subnet_ids
  }

  load_balancer {
    target_group_arn = var.target_group_arn
    container_name   = "api"
    container_port   = 3000
  }

  deployment_controller {
    type = "ECS"
  }

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  lifecycle {
    ignore_changes = [desired_count]
  }

  tags = merge(var.tags, {
    Name = local.service_name
  })
}
