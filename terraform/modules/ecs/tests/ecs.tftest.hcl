mock_provider "aws" {
  override_resource {
    target = aws_ecs_cluster.this
    values = {
      id   = "arn:aws:ecs:eu-west-1:123456789012:cluster/test-prod-ecs"
      arn  = "arn:aws:ecs:eu-west-1:123456789012:cluster/test-prod-ecs"
      name = "test-prod-ecs"
    }
  }

  override_resource {
    target = aws_ecs_task_definition.api
    values = {
      arn = "arn:aws:ecs:eu-west-1:123456789012:task-definition/test-prod-api:1"
    }
  }

  override_resource {
    target = aws_ecs_service.api
    values = {
      id  = "arn:aws:ecs:eu-west-1:123456789012:service/test-prod-ecs/test-prod-api"
      arn = "arn:aws:ecs:eu-west-1:123456789012:service/test-prod-ecs/test-prod-api"
    }
  }
}

run "deployment_disabled_by_default" {
  command = plan

  variables {
    name_prefix           = "test-dev"
    private_subnet_ids    = ["subnet-0123456789abcdef0", "subnet-0123456789abcdef1"]
    ecs_security_group_id = "sg-0123456789abcdef0"
    execution_role_arn    = "arn:aws:iam::123456789012:role/test-dev-ecs-task-execution"
    task_role_arn         = "arn:aws:iam::123456789012:role/test-dev-ecs-task"
  }

  assert {
    condition     = output.deployment_ready == false
    error_message = "ECS deployment must remain gated without external prerequisites."
  }

  assert {
    condition     = length(aws_ecs_task_definition.api) == 0
    error_message = "No task definition should be created while deployment is gated."
  }

  assert {
    condition     = length(aws_ecs_service.api) == 0
    error_message = "No ECS service should be created while deployment is gated."
  }

  assert {
    condition     = aws_ecs_cluster.this.name == "test-dev-ecs"
    error_message = "The ECS cluster must still be modelled while deployment is gated."
  }
}

run "fargate_deployment_configuration" {
  command = plan

  variables {
    name_prefix               = "test-prod"
    private_subnet_ids        = ["subnet-private-a", "subnet-private-b"]
    ecs_security_group_id     = "sg-0123456789abcdef0"
    target_group_arn          = "arn:aws:elasticloadbalancing:eu-west-1:123456789012:targetgroup/test-prod-tg/0123456789abcdef"
    https_listener_arn        = "arn:aws:elasticloadbalancing:eu-west-1:123456789012:listener/app/test-prod-alb/0123456789abcdef/0123456789abcdef"
    image_reference           = "123456789012.dkr.ecr.eu-west-1.amazonaws.com/test-prod-api:sha-1234567"
    enable_service            = true
    task_cpu                  = 512
    task_memory               = 1024
    desired_count             = 2
    health_check_grace_period = 60
    enable_container_insights = true
    execution_role_arn        = "arn:aws:iam::123456789012:role/test-prod-ecs-task-execution"
    task_role_arn             = "arn:aws:iam::123456789012:role/test-prod-ecs-task"
    database_host             = "test-db.cluster-123456789012.eu-west-1.rds.amazonaws.com"
    database_name             = "task_api"
    database_user             = "task_api"
    jwt_issuer                = "https://api.example.com"
    jwt_audience              = "production-ready-aws-devops-platform-api"
    secret_environment_variables = {
      DATABASE_PASSWORD = "arn:aws:secretsmanager:eu-west-1:123456789012:secret:database-placeholder"
      JWT_SECRET_BASE64 = "arn:aws:secretsmanager:eu-west-1:123456789012:secret:jwt-placeholder"
    }
  }

  assert {
    condition     = output.deployment_ready == true
    error_message = "All ECS deployment prerequisites must produce a deployable gated configuration."
  }

  assert {
    condition     = contains(aws_ecs_task_definition.api[0].requires_compatibilities, "FARGATE")
    error_message = "The task definition must require Fargate."
  }

  assert {
    condition     = aws_ecs_task_definition.api[0].network_mode == "awsvpc"
    error_message = "The task definition must use awsvpc networking."
  }

  assert {
    condition     = aws_ecs_task_definition.api[0].runtime_platform[0].cpu_architecture == "X86_64"
    error_message = "The task definition must use Linux/X86_64."
  }

  assert {
    condition     = aws_ecs_service.api[0].launch_type == "FARGATE"
    error_message = "The ECS service must use the Fargate launch type."
  }

  assert {
    condition     = aws_ecs_service.api[0].network_configuration[0].assign_public_ip == false
    error_message = "Fargate tasks must not receive public IP addresses."
  }

  assert {
    condition     = contains(aws_ecs_service.api[0].network_configuration[0].security_groups, "sg-0123456789abcdef0")
    error_message = "The ECS service must attach the existing ECS security group."
  }

  assert {
    condition     = length(aws_ecs_service.api[0].load_balancer) == 1
    error_message = "The ECS service must contain exactly one ALB target registration."
  }

  assert {
    condition     = aws_ecs_service.api[0].deployment_circuit_breaker[0].enable == true
    error_message = "The ECS deployment circuit breaker must be enabled."
  }

  assert {
    condition     = aws_ecs_service.api[0].deployment_circuit_breaker[0].rollback == true
    error_message = "The ECS deployment circuit breaker must enable rollback."
  }
}

run "reject_latest_image" {
  command = plan

  variables {
    name_prefix           = "test-dev"
    private_subnet_ids    = ["subnet-0123456789abcdef0", "subnet-0123456789abcdef1"]
    ecs_security_group_id = "sg-0123456789abcdef0"
    execution_role_arn    = "arn:aws:iam::123456789012:role/test-dev-ecs-task-execution"
    task_role_arn         = "arn:aws:iam::123456789012:role/test-dev-ecs-task"
    image_reference       = "123456789012.dkr.ecr.eu-west-1.amazonaws.com/test-dev-api:latest"
  }

  expect_failures = [
    var.image_reference,
  ]
}
