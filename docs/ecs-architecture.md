# ECS Fargate Architecture

## Cluster and deployment model

The ECS module creates one ECS cluster per environment and a private Fargate
service for the Node.js API. Tasks use `awsvpc` networking, Linux/X86_64,
the existing ECS security group, and private subnet IDs. Public IP assignment
is disabled.

The ECS service is intentionally disabled by default. Terraform creates the
cluster and CloudWatch log group, but task-definition and service resources are
created only when all deployment prerequisites are supplied:

- ECS deployment explicitly enabled
- Existing target-group ARN
- Existing HTTPS listener ARN
- Full ECR image reference
- PostgreSQL host, database name and application user
- PostgreSQL password secret ARN
- JWT secret-base64 secret ARN
- JWT issuer and audience

This prevents a service with an unattached target group or HTTP-only listener
from appearing deployable. No HTTPS listener is created by this module.

## Task definition

The API container uses:

- Container name `api`
- Port 3000
- Linux/X86_64 runtime
- Non-root UID/GID `65532:65532`
- Read-only root filesystem
- `NODE_ENV=production`
- Fargate CPU and memory limits
- SIGTERM graceful shutdown

The container health check calls `/health/live` from inside the container.
The ALB uses `/health/ready`, which depends on PostgreSQL. A 503 readiness
response removes the target from healthy routing.

## ALB integration

The service dynamically registers task IP addresses in the existing IP target
group. It associates port 3000 with the ECS `api` container. No task receives
a public IP, and ECS inbound traffic is restricted by the existing ECS security
group to the ALB security-group reference.

## IAM roles

The IAM module creates separate execution and application task roles.

The execution role can:

- Authenticate to ECR
- Pull from the selected ECR repository
- Create/write approved CloudWatch log streams
- Read explicitly supplied Secrets Manager secret ARNs
- Decrypt explicitly supplied KMS key ARNs

`ecr:GetAuthorizationToken` requires account/registry scope and is the narrow
AWS exception to repository-only image resource restrictions.

The application task role has ECS task trust but no application AWS actions.
It does not receive administrator, blanket Secrets Manager, or database access.
Application permissions must be added explicitly after the application requires
an AWS API.

## Secrets

Secret values are never stored in Terraform variables or task-definition plain
environment fields. The task definition uses ECS secret references for:

- `DATABASE_PASSWORD`
- `JWT_SECRET_BASE64`

PostgreSQL host, database name, and application user are non-secret environment
values. JWT issuer and audience are also non-secret values. Reusable RDS and
Secrets Manager integration modules are implemented in Terraform, but their
resources have not been created in AWS.

Secret rotation requires a new ECS deployment or force-new-deployment unless
the application and ECS execution environment support a separate refresh
process. ECS task definitions should point to secret ARNs, not secret values.

PostgreSQL TLS is configured with `DATABASE_SSL=true` and certificate
verification enabled. `DATABASE_SSL_CA` is a public CA-bundle input and must
contain or point to the appropriate AWS RDS CA bundle before deployment.
`rejectUnauthorized` is never disabled.

## CloudWatch logging

The ECS module creates `/ecs/<environment>-api` application log groups. It
supports optional customer-managed KMS encryption and environment-specific
retention:

- Development: 30 days
- Production: 365 days

The task-execution role receives `CreateLogStream` and `PutLogEvents` only for
the matching log-group ARN pattern.

The separate monitoring module reuses this log group for documented Logs
Insights queries and defines optional ECS, ALB, and RDS metric alarms and a
dashboard. Monitoring is disabled by default in both environments. It creates
no duplicate application log group, and no dashboard or alarm has been
deployed or verified against live CloudWatch metrics.

## Deployment behavior

The service uses the ECS deployment controller and enables the ECS deployment
circuit breaker with rollback. Development defaults to one task and 256 CPU /
512 MiB. Production defaults to two tasks and 512 CPU / 1024 MiB. Container
Insights is disabled in development and enabled in production.

Tasks use private subnets across the configured availability zones and
`assign_public_ip = false`.

## Missing deployment dependencies

The repository does not contain deployed RDS, real Secrets Manager secrets,
or an ACM certificate. Reusable RDS and secret-reference configuration exists,
but no AWS resources or secret values are present. No placeholder secret
values or fake database endpoints are used. ECS infrastructure is modelled
and tested, but task definitions and services remain gated until:

- The HTTPS listener ARN is available
- An immutable ECR image exists
- RDS connectivity is configured
- Secrets Manager ARNs exist
- Deployment is explicitly enabled

## Cost considerations

ECS Fargate pricing is based on task CPU, memory, runtime, and desired task
count. Development uses a single small task and short log retention. Production
uses more tasks, larger resources, Container Insights, and longer log retention.
Container Insights, CloudWatch alarms/dashboards, SNS, and NAT access may
create additional operational cost. Monitoring is disabled by default;
enabling it should follow a review of the thresholds, selected metrics, and
expected charges.

## Deployment prerequisites

1. Create RDS PostgreSQL and restricted application credentials.
2. Create Secrets Manager secrets and optional KMS keys.
3. Create or import a valid ACM certificate.
4. Enable the ALB HTTPS listener.
5. Push an immutable AMD64 image to ECR.
6. Supply image, secret, database, JWT, and listener values.
7. Explicitly enable ECS deployment.
8. Review the task definition and service plan before any future apply.

## Validation and security findings

Native mocked tests cover cluster, Fargate launch, awsvpc networking, Linux
X86_64, private subnets, public-IP disablement, security-group attachment,
ALB target registration, task-role separation, secret references, circuit
breaker rollback, deployment gating, and mutable latest-tag rejection.

Checkov reports development-cost tradeoffs for the 30-day log retention and
disabled Container Insights. Production retains logs for 365 days and enables
Container Insights. These settings are configurable and were not reported as
automatic deployed resources. IAM test secret values are synthetic placeholders
and contain no real credentials.
