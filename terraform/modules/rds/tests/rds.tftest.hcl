mock_provider "aws" {
  override_resource {
    target = aws_db_instance.this
    values = {
      arn     = "arn:aws:rds:eu-west-1:123456789012:db:test-prod-postgres"
      id      = "test-prod-postgres"
      address = "test-prod-postgres.123456789012.eu-west-1.rds.amazonaws.com"
      port    = 5432
      db_name = "task_api"
      master_user_secret = [{
        secret_arn = "arn:aws:secretsmanager:eu-west-1:123456789012:secret:rds!db-placeholder"
      }]
    }
  }
}

run "production_private_postgresql" {
  command = plan
  variables {
    name_prefix           = "test-prod"
    database_subnet_ids   = ["subnet-db-a", "subnet-db-b", "subnet-db-c"]
    rds_security_group_id = "sg-0123456789abcdef0"
    database_name         = "task_api"
    master_username       = "platform_admin"
    engine_version        = "17.4"
    instance_class        = "db.t4g.small"
    allocated_storage     = 100
    max_allocated_storage = 500
    multi_az              = true
    backup_retention_days = 14
    deletion_protection   = true
    skip_final_snapshot   = false
  }
  assert {
    condition     = aws_db_instance.this.publicly_accessible == false
    error_message = "RDS must not be publicly accessible."
  }
  assert {
    condition     = aws_db_instance.this.storage_encrypted == true
    error_message = "RDS storage must be encrypted."
  }
  assert {
    condition     = aws_db_instance.this.manage_master_user_password == true
    error_message = "RDS must manage the master credential secret."
  }
  assert {
    condition     = aws_db_instance.this.multi_az == true
    error_message = "Production RDS must use Multi-AZ."
  }
  assert {
    condition     = aws_db_instance.this.backup_retention_period == 14
    error_message = "Production backup retention must be configurable and at least 14."
  }
  assert {
    condition     = aws_db_instance.this.deletion_protection == true
    error_message = "Production RDS deletion protection must be enabled."
  }
  assert {
    condition     = aws_db_instance.this.skip_final_snapshot == false
    error_message = "Production RDS must require a final snapshot."
  }
  assert {
    condition     = contains(aws_db_instance.this.vpc_security_group_ids, "sg-0123456789abcdef0")
    error_message = "RDS must attach the existing RDS security group."
  }
}

run "development_single_az" {
  command = plan
  variables {
    name_prefix           = "test-dev"
    database_subnet_ids   = ["subnet-db-a", "subnet-db-b"]
    rds_security_group_id = "sg-0123456789abcdef1"
    database_name         = "task_api"
    master_username       = "platform_admin"
    multi_az              = false
    backup_retention_days = 7
  }
  assert {
    condition     = aws_db_instance.this.multi_az == false
    error_message = "Development RDS must use a single-AZ configuration."
  }
  assert {
    condition     = aws_db_instance.this.backup_retention_period == 7
    error_message = "Development backup retention must be seven days."
  }
}
