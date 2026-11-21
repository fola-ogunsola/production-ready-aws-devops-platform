data "aws_caller_identity" "current" {}

locals {
  state_bucket_name = format(
    "tfstate-%s-%s-%s",
    replace(var.project_name, "-platform", ""),
    data.aws_caller_identity.current.account_id,
    var.aws_region
  )

  common_tags = merge(var.additional_tags, {
    Project     = var.project_name
    Environment = "bootstrap"
    ManagedBy   = "Terraform"
    Repository  = "production-ready-aws-devops-platform"
  })
}

provider "aws" {
  region              = var.aws_region
  profile             = var.aws_profile
  allowed_account_ids = [var.expected_account_id]

  default_tags {
    tags = local.common_tags
  }
}
