mock_provider "aws" {
  override_resource {
    target = aws_iam_role.ecs_task_execution
    values = {
      arn  = "arn:aws:iam::123456789012:role/test-prod-ecs-task-execution"
      name = "test-prod-ecs-task-execution"
    }
  }

  override_resource {
    target = aws_iam_role.ecs_task
    values = {
      arn  = "arn:aws:iam::123456789012:role/test-prod-ecs-task"
      name = "test-prod-ecs-task"
    }
  }
}

run "separate_least_privilege_roles" {
  command = plan

  variables {
    name_prefix        = "test-prod"
    ecr_repository_arn = "arn:aws:ecr:eu-west-1:123456789012:repository/test-prod-api"
    log_group_name     = "/ecs/test-prod-api"
    secret_arns = {
      DATABASE_PASSWORD = "arn:aws:secretsmanager:eu-west-1:123456789012:secret:database-placeholder"
      JWT_SECRET_BASE64 = "arn:aws:secretsmanager:eu-west-1:123456789012:secret:jwt-placeholder"
    }
    kms_key_arns = {
      secrets = "arn:aws:kms:eu-west-1:123456789012:key/00000000-0000-0000-0000-000000000000"
    }
  }

  assert {
    condition     = length(aws_iam_role_policy.ecs_task_execution_secrets) == 1
    error_message = "Secret permissions must exist only for explicitly authorized secret ARNs."
  }

  assert {
    condition     = aws_iam_role_policy.ecs_task_execution.policy != null
    error_message = "The execution role must contain a dedicated policy."
  }

}

run "no_secret_permissions_by_default" {
  command = plan

  variables {
    name_prefix        = "test-dev"
    ecr_repository_arn = "arn:aws:ecr:eu-west-1:123456789012:repository/test-dev-api"
    log_group_name     = "/ecs/test-dev-api"
  }

  assert {
    condition     = length(aws_iam_role_policy.ecs_task_execution_secrets) == 0
    error_message = "No Secrets Manager permissions should be created without explicit secret ARNs."
  }
}
