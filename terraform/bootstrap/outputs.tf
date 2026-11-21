output "state_bucket_name" {
  description = "S3 bucket name to supply when initializing dev and prod backends."
  value       = aws_s3_bucket.terraform_state.bucket
}

output "state_bucket_region" {
  description = "AWS region containing the remote state bucket."
  value       = var.aws_region
}

output "development_state_key" {
  description = "Remote state key configured by the development root."
  value       = "production-ready-aws-devops-platform/dev/terraform.tfstate"
}

output "production_state_key" {
  description = "Remote state key configured by the production root."
  value       = "production-ready-aws-devops-platform/prod/terraform.tfstate"
}
