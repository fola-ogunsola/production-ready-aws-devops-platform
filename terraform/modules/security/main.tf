resource "aws_security_group" "alb" {
  name        = "${var.name_prefix}-alb"
  description = "ALB ingress and ECS application egress"
  vpc_id      = var.vpc_id

  ingress = []
  egress  = []

  revoke_rules_on_delete = true

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-alb"
    Tier = "public"
  })
}

resource "aws_security_group" "ecs" {
  name        = "${var.name_prefix}-ecs"
  description = "ECS tasks with ALB-only application ingress"
  vpc_id      = var.vpc_id

  ingress = []
  egress  = []

  revoke_rules_on_delete = true

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-ecs"
    Tier = "private"
  })
}

resource "aws_security_group" "rds" {
  name        = "${var.name_prefix}-rds"
  description = "PostgreSQL access restricted to ECS tasks"
  vpc_id      = var.vpc_id

  ingress = []
  egress  = []

  revoke_rules_on_delete = true

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-rds"
    Tier = "private"
  })
}

resource "aws_vpc_security_group_ingress_rule" "alb_https" {
  for_each = toset(var.alb_ingress_cidrs)

  security_group_id = aws_security_group.alb.id
  description       = "Approved HTTPS ingress"
  cidr_ipv4         = each.value
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"

  tags = var.tags
}

resource "aws_vpc_security_group_ingress_rule" "alb_http" {
  for_each = var.enable_alb_http_ingress ? toset(var.alb_ingress_cidrs) : toset([])

  security_group_id = aws_security_group.alb.id
  description       = "Optional HTTP-to-HTTPS redirect ingress"
  cidr_ipv4         = each.value
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"

  tags = var.tags
}

resource "aws_vpc_security_group_egress_rule" "alb_to_ecs" {
  security_group_id            = aws_security_group.alb.id
  description                  = "ALB to ECS application port"
  referenced_security_group_id = aws_security_group.ecs.id
  from_port                    = var.application_port
  to_port                      = var.application_port
  ip_protocol                  = "tcp"

  tags = var.tags
}

resource "aws_vpc_security_group_ingress_rule" "ecs_from_alb" {
  security_group_id            = aws_security_group.ecs.id
  description                  = "ALB application ingress"
  referenced_security_group_id = aws_security_group.alb.id
  from_port                    = var.application_port
  to_port                      = var.application_port
  ip_protocol                  = "tcp"

  tags = var.tags
}

resource "aws_vpc_security_group_egress_rule" "ecs_to_rds" {
  security_group_id            = aws_security_group.ecs.id
  description                  = "ECS to PostgreSQL"
  referenced_security_group_id = aws_security_group.rds.id
  from_port                    = var.database_port
  to_port                      = var.database_port
  ip_protocol                  = "tcp"

  tags = var.tags
}

resource "aws_vpc_security_group_egress_rule" "ecs_https_cidrs" {
  for_each = toset(var.ecs_https_egress_cidrs)

  security_group_id = aws_security_group.ecs.id
  description       = "ECS HTTPS service connectivity"
  cidr_ipv4         = each.value
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"

  tags = var.tags
}

resource "aws_vpc_security_group_egress_rule" "ecs_https_prefix_lists" {
  for_each = toset(var.ecs_https_egress_prefix_list_ids)

  security_group_id = aws_security_group.ecs.id
  description       = "ECS HTTPS connectivity to AWS managed service prefix list"
  prefix_list_id    = each.value
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"

  tags = var.tags
}

resource "aws_vpc_security_group_egress_rule" "ecs_dns_tcp" {
  security_group_id = aws_security_group.ecs.id
  description       = "ECS DNS resolution over TCP"
  cidr_ipv4         = var.vpc_cidr
  from_port         = 53
  to_port           = 53
  ip_protocol       = "tcp"

  tags = var.tags
}

resource "aws_vpc_security_group_egress_rule" "ecs_dns_udp" {
  security_group_id = aws_security_group.ecs.id
  description       = "ECS DNS resolution over UDP"
  cidr_ipv4         = var.vpc_cidr
  from_port         = 53
  to_port           = 53
  ip_protocol       = "udp"

  tags = var.tags
}

resource "aws_vpc_security_group_ingress_rule" "rds_from_ecs" {
  security_group_id            = aws_security_group.rds.id
  description                  = "PostgreSQL ingress from ECS tasks"
  referenced_security_group_id = aws_security_group.ecs.id
  from_port                    = var.database_port
  to_port                      = var.database_port
  ip_protocol                  = "tcp"

  tags = var.tags
}
