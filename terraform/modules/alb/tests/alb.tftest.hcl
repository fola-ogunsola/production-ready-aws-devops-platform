mock_provider "aws" {
  override_resource {
    target = aws_lb.this
    values = {
      arn      = "arn:aws:elasticloadbalancing:eu-west-1:123456789012:loadbalancer/app/test-prod-alb/0123456789abcdef"
      dns_name = "test-prod-alb.eu-west-1.elb.amazonaws.com"
      zone_id  = "Z35SXDOTRQ7X7K"
      id       = "arn:aws:elasticloadbalancing:eu-west-1:123456789012:loadbalancer/app/test-prod-alb/0123456789abcdef"
    }
  }

  override_resource {
    target = aws_lb_target_group.this
    values = {
      arn = "arn:aws:elasticloadbalancing:eu-west-1:123456789012:targetgroup/test-prod-tg/0123456789abcdef"
    }
  }
}

run "internet_facing_https_alb" {
  command = plan

  variables {
    name_prefix                = "test-prod"
    vpc_id                     = "vpc-0123456789abcdef0"
    subnet_ids                 = ["subnet-0123456789abcdef0", "subnet-0123456789abcdef1"]
    alb_security_group_id      = "sg-0123456789abcdef0"
    application_port           = 3000
    alb_scheme                 = "internet-facing"
    enable_deletion_protection = true
    https_listener_enabled     = true
    acm_certificate_arn        = "arn:aws:acm:eu-west-1:123456789012:certificate/12345678-abcd-1234-abcd-123456789012"
    enable_http_listener       = true
    enable_access_logs         = false
    tags = {
      Project     = "test-project"
      Environment = "prod"
      ManagedBy   = "Terraform"
    }
  }

  assert {
    condition     = aws_lb.this.internal == false
    error_message = "The production ALB must be internet-facing."
  }

  assert {
    condition     = length(aws_lb.this.subnets) == 2
    error_message = "The ALB must span at least two subnets."
  }

  assert {
    condition     = contains(aws_lb.this.security_groups, "sg-0123456789abcdef0")
    error_message = "The ALB must attach the existing ALB security group."
  }

  assert {
    condition     = aws_lb.this.enable_deletion_protection == true
    error_message = "Deletion protection must be enabled for the production test."
  }

  assert {
    condition     = aws_lb_target_group.this.target_type == "ip"
    error_message = "The target group must use IP targets for ECS tasks."
  }

  assert {
    condition     = aws_lb_target_group.this.port == 3000
    error_message = "The target group must use application port 3000."
  }

  assert {
    condition     = aws_lb_target_group.this.health_check[0].path == "/health/ready"
    error_message = "The target group must check the PostgreSQL-aware readiness endpoint."
  }

  assert {
    condition     = aws_lb_target_group.this.health_check[0].matcher == "200"
    error_message = "Readiness health checks must require HTTP 200."
  }

  assert {
    condition     = aws_lb_listener.https[0].ssl_policy == "ELBSecurityPolicy-TLS13-1-2-2021-06"
    error_message = "HTTPS must use the modern TLS 1.3 policy."
  }

  assert {
    condition     = aws_lb_listener.https[0].certificate_arn == "arn:aws:acm:eu-west-1:123456789012:certificate/12345678-abcd-1234-abcd-123456789012"
    error_message = "HTTPS must use the configured existing certificate."
  }

  assert {
    condition     = aws_lb_listener.http[0].default_action[0].redirect[0].protocol == "HTTPS"
    error_message = "HTTP must redirect to HTTPS and must not forward to ECS."
  }

  assert {
    condition     = aws_lb_listener.http[0].default_action[0].redirect[0].status_code == "HTTP_301"
    error_message = "HTTP redirection must use a permanent redirect."
  }

  assert {
    condition     = aws_lb.this.tags["Environment"] == "prod"
    error_message = "The ALB must receive the environment tag."
  }

  assert {
    condition     = aws_lb_target_group.this.tags["ManagedBy"] == "Terraform"
    error_message = "The target group must receive the Terraform tag."
  }
}

run "http_disabled_by_default" {
  command = plan

  variables {
    name_prefix                = "test-dev"
    vpc_id                     = "vpc-0123456789abcdef0"
    subnet_ids                 = ["subnet-0123456789abcdef0", "subnet-0123456789abcdef1"]
    alb_security_group_id      = "sg-0123456789abcdef0"
    application_port           = 3000
    alb_scheme                 = "internet-facing"
    enable_deletion_protection = false
  }

  assert {
    condition     = length(aws_lb_listener.https) == 0
    error_message = "HTTPS must remain disabled without an explicit certificate."
  }

  assert {
    condition     = length(aws_lb_listener.http) == 0
    error_message = "HTTP must remain disabled by default."
  }

  assert {
    condition     = aws_lb.this.enable_deletion_protection == false
    error_message = "Development deletion protection must remain configurable and disabled by default."
  }
}

run "internal_alb" {
  command = plan

  variables {
    name_prefix           = "test-dev"
    vpc_id                = "vpc-0123456789abcdef0"
    subnet_ids            = ["subnet-private-a", "subnet-private-b"]
    alb_security_group_id = "sg-0123456789abcdef0"
    alb_scheme            = "internal"
  }

  assert {
    condition     = aws_lb.this.internal == true
    error_message = "The ALB must support internal scheme configuration."
  }
}

run "access_logs_bucket_is_private" {
  command = plan

  variables {
    name_prefix           = "test-prod"
    vpc_id                = "vpc-0123456789abcdef0"
    subnet_ids            = ["subnet-0123456789abcdef0", "subnet-0123456789abcdef1"]
    alb_security_group_id = "sg-0123456789abcdef0"
    enable_access_logs    = true
    waf_web_acl_arn       = "arn:aws:wafv2:eu-west-1:123456789012:regional/webacl/test/12345678-abcd-1234-abcd-123456789012"
  }

  assert {
    condition     = length(aws_s3_bucket.alb_logs) == 1
    error_message = "Access logging must create a private destination when no bucket is supplied."
  }

  assert {
    condition     = aws_s3_bucket_public_access_block.alb_logs[0].block_public_acls == true
    error_message = "The access-log bucket must block public ACLs."
  }

  assert {
    condition     = aws_s3_bucket_public_access_block.alb_logs[0].restrict_public_buckets == true
    error_message = "The access-log bucket must restrict public buckets."
  }

  assert {
    condition     = length(aws_wafv2_web_acl_association.this) == 1
    error_message = "An existing WAFv2 Web ACL must be associable with the ALB."
  }

  assert {
    condition     = length(aws_s3_bucket_server_side_encryption_configuration.alb_logs) == 1
    error_message = "ALB access logging must configure a server-side encryption resource."
  }
}

run "reject_https_without_certificate" {
  command = plan

  variables {
    name_prefix            = "test-prod"
    vpc_id                 = "vpc-0123456789abcdef0"
    subnet_ids             = ["subnet-0123456789abcdef0", "subnet-0123456789abcdef1"]
    alb_security_group_id  = "sg-0123456789abcdef0"
    https_listener_enabled = true
    acm_certificate_arn    = null
  }

  expect_failures = [
    var.https_listener_enabled,
  ]
}

run "reject_http_without_https" {
  command = plan

  variables {
    name_prefix            = "test-dev"
    vpc_id                 = "vpc-0123456789abcdef0"
    subnet_ids             = ["subnet-0123456789abcdef0", "subnet-0123456789abcdef1"]
    alb_security_group_id  = "sg-0123456789abcdef0"
    https_listener_enabled = false
    enable_http_listener   = true
  }

  expect_failures = [
    var.enable_http_listener,
  ]
}
