terraform {
  backend "s3" {
    key          = "production-ready-aws-devops-platform/prod/terraform.tfstate"
    region       = "eu-west-1"
    encrypt      = true
    use_lockfile = true
  }
}
