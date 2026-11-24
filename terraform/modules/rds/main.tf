resource "aws_db_subnet_group" "this" {
  name       = "${var.name_prefix}-db"
  subnet_ids = var.database_subnet_ids
  tags       = merge(var.tags, { Name = "${var.name_prefix}-db" })
}

resource "aws_iam_role" "rds_enhanced_monitoring" {
  count = var.monitoring_interval > 0 ? 1 : 0

  name = "${var.name_prefix}-rds-enhanced-monitoring"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "monitoring.rds.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "rds_enhanced_monitoring" {
  count = var.monitoring_interval > 0 ? 1 : 0

  role       = aws_iam_role.rds_enhanced_monitoring[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

resource "aws_db_parameter_group" "this" {
  name   = "${var.name_prefix}-postgres17"
  family = "postgres17"

  parameter {
    name  = "rds.force_ssl"
    value = "1"
  }

  tags = var.tags

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_db_instance" "this" {
  identifier                            = "${var.name_prefix}-postgres"
  engine                                = "postgres"
  engine_version                        = var.engine_version
  instance_class                        = var.instance_class
  allocated_storage                     = var.allocated_storage
  max_allocated_storage                 = var.max_allocated_storage
  storage_type                          = "gp3"
  storage_encrypted                     = true
  kms_key_id                            = var.kms_key_arn
  db_name                               = var.database_name
  username                              = var.master_username
  manage_master_user_password           = true
  db_subnet_group_name                  = aws_db_subnet_group.this.name
  parameter_group_name                  = aws_db_parameter_group.this.name
  vpc_security_group_ids                = [var.rds_security_group_id]
  publicly_accessible                   = false
  multi_az                              = var.multi_az
  backup_retention_period               = var.backup_retention_days
  backup_window                         = var.backup_window
  maintenance_window                    = var.maintenance_window
  deletion_protection                   = var.deletion_protection
  skip_final_snapshot                   = var.skip_final_snapshot
  final_snapshot_identifier             = var.skip_final_snapshot ? null : "${var.name_prefix}-final"
  copy_tags_to_snapshot                 = true
  enabled_cloudwatch_logs_exports       = var.enabled_cloudwatch_logs_exports
  auto_minor_version_upgrade            = true
  iam_database_authentication_enabled   = var.iam_database_authentication_enabled
  performance_insights_enabled          = var.performance_insights_enabled
  performance_insights_kms_key_id       = var.kms_key_arn
  performance_insights_retention_period = var.performance_insights_retention_period
  monitoring_interval                   = var.monitoring_interval
  monitoring_role_arn                   = var.monitoring_interval > 0 ? aws_iam_role.rds_enhanced_monitoring[0].arn : null

  tags = merge(var.tags, { Name = "${var.name_prefix}-postgres" })

  lifecycle {
    precondition {
      condition     = var.deletion_protection == true || var.skip_final_snapshot == true
      error_message = "Deletion protection is recommended; when disabled, skip_final_snapshot must be explicitly true outside production."
    }
  }
}
