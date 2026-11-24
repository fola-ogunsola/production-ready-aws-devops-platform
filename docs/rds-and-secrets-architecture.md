# RDS PostgreSQL and Secrets Manager Architecture

## Database architecture

RDS PostgreSQL uses a dedicated private database subnet tier in at least two
availability zones. Database subnets have no internet-gateway route and use an
isolated route table. RDS has `publicly_accessible = false`.

The RDS security group accepts TCP 5432 only from the ECS security group.
The database is not accessible directly from public CIDRs or general ECS
egress.

Development uses a single-AZ instance, seven-day backup retention and
cost-conscious storage/logging defaults. Production uses Multi-AZ, at least
14-day retention, deletion protection and final snapshots.

## Encryption and TLS

RDS storage is encrypted. The module supports an existing customer-managed KMS
key and otherwise uses the AWS-managed encryption integration.

The PostgreSQL parameter group sets `rds.force_ssl = 1`. The Node.js `pg`
pool enables TLS when `DATABASE_SSL=true` and sets
`rejectUnauthorized: true`. The application supports an optional
`DATABASE_SSL_CA` value for an explicit RDS CA bundle. Certificate verification
must not be disabled.

Local Docker Compose keeps `DATABASE_SSL=false` and remains functional.

## Credentials

RDS uses `manage_master_user_password = true`. AWS Secrets Manager owns the
master credential; Terraform does not receive or output the master password.
The module exposes the AWS-managed secret ARN, not credential values.

The master account is administrative and must not be used by ECS application
tasks. A separate database bootstrap procedure creates a restricted role and
applies migrations using administrator credentials outside ECS.

Bootstrap responsibilities:

1. Connect as an administrator through an approved migration network path.
2. Create or rotate the least-privilege application role.
3. Grant schema and table privileges required by migrations and runtime SQL.
4. Apply migrations with the migration account.
5. Populate the external application password secret out of band.
6. Rotate application credentials and redeploy ECS tasks when required.

Terraform does not execute bootstrap or migration commands against AWS.

## Secrets Manager metadata

The secrets module creates secret metadata only:

- `<prefix>/database-password`
- `<prefix>/jwt-secret-base64`

It does not create secret versions or store plaintext values. Values are
populated by an approved CLI, automation, or secret-management process after
the secret metadata is created.

ECS receives exact environment names:

- `DATABASE_PASSWORD`
- `JWT_SECRET_BASE64`

The ECS execution role receives GetSecretValue and DescribeSecret permissions
only for supplied secret ARNs. KMS decrypt permissions are restricted to
supplied KMS key ARNs.

## Secret rotation

Secret rotation does not automatically replace environment variables in already
running ECS tasks. ECS can retrieve a referenced secret at task startup. After
application credential rotation or JWT signing-secret rotation, deploy a new
task definition or force a new ECS deployment.

JWT rotation can invalidate existing tokens; release procedures should set
issuer, audience and token lifetime consistently and handle overlap where
required.

## Backups and recovery

Automated backups retain 7 days in development and 14 or more days in production.
Production enables deletion protection and final snapshots. Production final
snapshots and state must be preserved independently during recovery planning.

Multi-AZ is a high-availability configuration, not a backup replacement.
Recovery requires testing RDS restore, migration state, application credentials,
DNS/endpoint changes and ECS redeployment.

## Monitoring

PostgreSQL and upgrade logs may be exported to CloudWatch. Recommended
operational monitoring includes:

- Free storage
- CPU and memory
- Database connections
- Read/write latency
- Replica or failover status
- Storage autoscaling
- Snapshot and backup status
- TLS and authentication failures

## Cost considerations

RDS cost varies by instance class, Multi-AZ, storage, IOPS, backup storage,
log exports and autoscaling. Development remains single-AZ and small.
Production has higher availability and retention cost. Final snapshots and
long backup retention can create additional storage charges.

## Deployment prerequisites

- Existing VPC, database subnets and RDS security group
- Reviewed database CIDRs and parameter settings
- Customer-managed KMS key when required
- AWS-managed RDS master secret
- External application database role and password secret
- External JWT signing secret
- Migration and bootstrap execution role
- RDS CA bundle and application TLS configuration
- Real database endpoint, name and application username
- ACM listener and ECS image before enabling ECS

No AWS database, secret, bootstrap command or ECS deployment was executed.

## Validation findings

Mocked RDS tests verify private placement, two-or-more-AZ subnet groups,
RDS-managed master credentials, SSL enforcement, encryption, backups,
Multi-AZ/Single-AZ behavior and snapshot/deletion settings.

Checkov passes 22 RDS/secrets controls and reports CKV_AWS_354 for optional
Performance Insights encryption because a customer KMS ARN is not supplied by
default. The module accepts `kms_key_arn` and assigns it to Performance
Insights and storage. Production should provide a reviewed customer key ARN
before deployment.
