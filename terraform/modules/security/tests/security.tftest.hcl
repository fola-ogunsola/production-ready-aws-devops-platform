mock_provider "aws" {
  override_resource {
    target = aws_security_group.alb
    values = {
      id = "sg-0123456789abcdef0"
    }
  }

  override_resource {
    target = aws_security_group.ecs
    values = {
      id = "sg-0123456789abcdef1"
    }
  }

  override_resource {
    target = aws_security_group.rds
    values = {
      id = "sg-0123456789abcdef2"
    }
  }
}

run "restricted_workload_security_groups" {
  command = plan

  variables {
    name_prefix                      = "test-prod"
    vpc_id                           = "vpc-0123456789abcdef0"
    vpc_cidr                         = "10.30.0.0/16"
    application_port                 = 3000
    database_port                    = 5432
    alb_ingress_cidrs                = ["203.0.113.0/24"]
    enable_alb_http_ingress          = false
    ecs_https_egress_cidrs           = ["151.101.0.0/16"]
    ecs_https_egress_prefix_list_ids = []
    tags = {
      Project     = "test-project"
      Environment = "test"
      ManagedBy   = "Terraform"
    }
  }

  assert {
    condition     = aws_vpc_security_group_ingress_rule.alb_https["203.0.113.0/24"].from_port == 443
    error_message = "The ALB must permit HTTPS on TCP 443."
  }

  assert {
    condition     = aws_vpc_security_group_ingress_rule.alb_https["203.0.113.0/24"].cidr_ipv4 == "203.0.113.0/24"
    error_message = "ALB HTTPS ingress must use the approved CIDR."
  }

  assert {
    condition     = length(aws_vpc_security_group_ingress_rule.alb_http) == 0
    error_message = "HTTP ingress must remain disabled by default."
  }

  assert {
    condition     = aws_vpc_security_group_ingress_rule.ecs_from_alb.from_port == 3000
    error_message = "ECS application ingress must use the configured application port."
  }

  assert {
    condition     = aws_vpc_security_group_ingress_rule.rds_from_ecs.from_port == 5432
    error_message = "RDS PostgreSQL ingress must use TCP 5432."
  }

  assert {
    condition     = aws_vpc_security_group_ingress_rule.rds_from_ecs.cidr_ipv4 == null
    error_message = "RDS must not accept a public CIDR-based database rule."
  }

  assert {
    condition     = aws_security_group.alb.tags["Project"] == "test-project"
    error_message = "The ALB security group must receive consistent tags."
  }

  assert {
    condition     = aws_security_group.ecs.tags["Environment"] == "test"
    error_message = "The ECS security group must receive consistent tags."
  }

  assert {
    condition     = aws_security_group.rds.tags["ManagedBy"] == "Terraform"
    error_message = "The RDS security group must receive consistent tags."
  }

}

run "optional_http_ingress_enabled" {
  command = plan

  variables {
    name_prefix                      = "test-dev"
    vpc_id                           = "vpc-0123456789abcdef0"
    vpc_cidr                         = "10.20.0.0/16"
    application_port                 = 3000
    database_port                    = 5432
    alb_ingress_cidrs                = ["198.51.100.0/24"]
    enable_alb_http_ingress          = true
    ecs_https_egress_cidrs           = []
    ecs_https_egress_prefix_list_ids = ["pl-1234567890abcdef0"]
  }

  assert {
    condition     = length(aws_vpc_security_group_ingress_rule.alb_http) == 1
    error_message = "HTTP ingress must create exactly one rule for the approved CIDR."
  }

  assert {
    condition     = aws_vpc_security_group_ingress_rule.alb_http["198.51.100.0/24"].from_port == 80
    error_message = "Optional HTTP ingress must use TCP 80."
  }

  assert {
    condition     = length(aws_vpc_security_group_egress_rule.ecs_https_prefix_lists) == 1
    error_message = "ECS HTTPS connectivity must support managed prefix lists."
  }
}

run "rejects_non_postgresql_port" {
  command = plan

  variables {
    name_prefix             = "test-prod"
    vpc_id                  = "vpc-0123456789abcdef0"
    vpc_cidr                = "10.30.0.0/16"
    application_port        = 3000
    database_port           = 5433
    alb_ingress_cidrs       = ["203.0.113.0/24"]
    enable_alb_http_ingress = false
  }

  expect_failures = [
    var.database_port,
  ]
}

run "rejects_invalid_application_port" {
  command = plan

  variables {
    name_prefix       = "test-dev"
    vpc_id            = "vpc-0123456789abcdef0"
    vpc_cidr          = "10.20.0.0/16"
    application_port  = 70000
    database_port     = 5432
    alb_ingress_cidrs = ["203.0.113.0/24"]
  }

  expect_failures = [
    var.application_port,
  ]
}
