locals {
  repository_name = var.repository_name != null ? var.repository_name : "${var.name_prefix}-api"

  lifecycle_policy = {
    rules = [
      {
        rulePriority = 1
        description  = "Retain production release images"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["prod-"]
          countType     = "imageCountMoreThan"
          countNumber   = var.production_image_retention
        }
        action = {
          type = "expire"
        }
      },
      {
        rulePriority = 2
        description  = "Retain rollback release images"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["rollback-"]
          countType     = "imageCountMoreThan"
          countNumber   = var.rollback_image_retention
        }
        action = {
          type = "expire"
        }
      },
      {
        rulePriority = 3
        description  = "Retain immutable Git SHA images"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["sha-"]
          countType     = "imageCountMoreThan"
          countNumber   = var.sha_image_retention
        }
        action = {
          type = "expire"
        }
      },
      {
        rulePriority = 4
        description  = "Remove surplus untagged manifests"
        selection = {
          tagStatus   = "untagged"
          countType   = "imageCountMoreThan"
          countNumber = var.untagged_image_retention
        }
        action = {
          type = "expire"
        }
      }
    ]
  }
}

resource "aws_ecr_repository" "this" {
  name                 = local.repository_name
  image_tag_mutability = var.image_tag_mutability
  force_delete         = var.force_delete

  image_scanning_configuration {
    scan_on_push = var.scan_on_push
  }

  encryption_configuration {
    encryption_type = var.encryption_type
    kms_key         = var.encryption_type == "AES256" ? null : var.kms_key_arn
  }

  tags = merge(var.tags, {
    Name = local.repository_name
  })
}

resource "aws_ecr_lifecycle_policy" "this" {
  count = var.lifecycle_policy_enabled ? 1 : 0

  repository = aws_ecr_repository.this.name
  policy     = jsonencode(local.lifecycle_policy)
}
