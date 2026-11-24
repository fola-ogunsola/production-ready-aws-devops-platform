mock_provider "aws" {
  override_resource {
    target = aws_ecr_repository.this
    values = {
      name           = "test-prod-api"
      arn            = "arn:aws:ecr:eu-west-1:123456789012:repository/test-prod-api"
      repository_url = "123456789012.dkr.ecr.eu-west-1.amazonaws.com/test-prod-api"
      registry_id    = "123456789012"
    }
  }
}

run "private_immutable_repository" {
  command = plan

  variables {
    name_prefix                = "test-prod"
    repository_name            = "test-prod-api"
    image_tag_mutability       = "IMMUTABLE"
    encryption_type            = "AES256"
    scan_on_push               = true
    force_delete               = false
    lifecycle_policy_enabled   = true
    production_image_retention = 30
    rollback_image_retention   = 10
    sha_image_retention        = 50
    untagged_image_retention   = 2
    tags = {
      Project     = "test-project"
      Environment = "prod"
      ManagedBy   = "Terraform"
    }
  }

  assert {
    condition     = aws_ecr_repository.this.name == "test-prod-api"
    error_message = "The repository name must match the configurable name."
  }

  assert {
    condition     = aws_ecr_repository.this.image_tag_mutability == "IMMUTABLE"
    error_message = "Production repository tags must be immutable by default."
  }

  assert {
    condition     = aws_ecr_repository.this.encryption_configuration[0].encryption_type == "AES256"
    error_message = "The repository must use AWS-supported AES256 encryption."
  }

  assert {
    condition     = aws_ecr_repository.this.image_scanning_configuration[0].scan_on_push == true
    error_message = "Basic scan-on-push must be configurable and enabled in this test."
  }

  assert {
    condition     = aws_ecr_repository.this.force_delete == false
    error_message = "Accidental deletion protection must default to false for force_delete."
  }

  assert {
    condition     = aws_ecr_repository.this.tags["Environment"] == "prod"
    error_message = "The repository must receive the environment tag."
  }

  assert {
    condition     = length(aws_ecr_lifecycle_policy.this) == 1
    error_message = "The lifecycle policy must be attached when enabled."
  }

  assert {
    condition     = can(regex("prod-", aws_ecr_lifecycle_policy.this[0].policy))
    error_message = "The lifecycle policy must retain production-tagged images."
  }

  assert {
    condition     = can(regex("rollback-", aws_ecr_lifecycle_policy.this[0].policy))
    error_message = "The lifecycle policy must retain rollback-tagged images."
  }

  assert {
    condition     = can(regex("sha-", aws_ecr_lifecycle_policy.this[0].policy))
    error_message = "The lifecycle policy must retain immutable SHA-tagged images."
  }

}

run "kms_encryption_and_dev_retention" {
  command = plan

  variables {
    name_prefix                = "test-dev"
    repository_name            = "test-dev-api"
    image_tag_mutability       = "IMMUTABLE"
    encryption_type            = "KMS"
    kms_key_arn                = "arn:aws:kms:eu-west-1:123456789012:key/12345678-abcd-1234-abcd-123456789012"
    scan_on_push               = false
    lifecycle_policy_enabled   = true
    production_image_retention = 10
    rollback_image_retention   = 5
    sha_image_retention        = 20
  }

  assert {
    condition     = aws_ecr_repository.this.encryption_configuration[0].encryption_type == "KMS"
    error_message = "The repository must support account-managed KMS encryption."
  }

  assert {
    condition     = aws_ecr_repository.this.image_scanning_configuration[0].scan_on_push == false
    error_message = "Basic scan-on-push must be configurable for development."
  }
}

run "lifecycle_disabled" {
  command = plan

  variables {
    name_prefix              = "test-dev"
    repository_name          = "test-dev-api"
    lifecycle_policy_enabled = false
  }

  assert {
    condition     = length(aws_ecr_lifecycle_policy.this) == 0
    error_message = "Lifecycle policy resources must be omitted when disabled."
  }
}

run "reject_invalid_kms_configuration" {
  command = plan

  variables {
    name_prefix     = "test-prod"
    repository_name = "test-prod-api"
    encryption_type = "KMS"
    kms_key_arn     = null
  }

  expect_failures = [
    var.kms_key_arn,
  ]
}

run "reject_invalid_repository_name" {
  command = plan

  variables {
    name_prefix     = "test-prod"
    repository_name = "INVALID Repository"
  }

  expect_failures = [
    var.repository_name,
  ]
}
