mock_provider "aws" {}

run "metadata_only_application_secrets" {
  command = plan
  variables {
    name_prefix                     = "test-prod"
    create_database_password_secret = true
    create_jwt_secret               = true
  }
  assert {
    condition     = length(aws_secretsmanager_secret.database_password) == 1
    error_message = "Database password secret metadata must be created."
  }
  assert {
    condition     = length(aws_secretsmanager_secret.jwt_secret) == 1
    error_message = "JWT signing secret metadata must be created."
  }
  assert {
    condition     = contains(keys(output.secret_arns), "DATABASE_PASSWORD")
    error_message = "The database password secret must map to its ECS environment name."
  }
  assert {
    condition     = contains(keys(output.secret_arns), "JWT_SECRET_BASE64")
    error_message = "The JWT secret must map to its ECS environment name."
  }
}

run "no_secret_versions_created" {
  command = plan
  variables {
    name_prefix = "test-dev"
  }
  assert {
    condition     = length(aws_secretsmanager_secret.database_password) == 1
    error_message = "Database secret metadata should exist independently of secret values."
  }
}
