# Production-Ready AWS DevOps Platform

## 1. Project Overview

The Production-Ready AWS DevOps Platform is an infrastructure engineering
project for designing and implementing an automated, secure, scalable, and
highly available application deployment architecture on AWS. It brings
infrastructure as code, container delivery, CI/CD, security controls, and
operational observability into one version-controlled platform.

The repository is intended to make the platform's architecture and delivery
approach reviewable: reusable Terraform modules and development/production
configuration define the infrastructure design, while GitHub Actions validates
application, container, and Terraform changes. These configurations have not
been applied to AWS. Workflows do not deploy, publish images, or create AWS
resources.

The application layer now includes a versioned Express REST API for operational
tasks, PostgreSQL persistence, administrator-provisioned accounts, short-lived
JWT authentication, per-user task authorization, structured request logging,
input validation, health checks, graceful shutdown, automated tests, and an
OpenAPI contract. PostgreSQL is a required runtime dependency; a reusable RDS
Terraform module is implemented but has not been deployed.

The API is also packaged in a multi-stage Node.js 24 Docker image. A local
Compose configuration uses a non-root runtime, read-only root filesystem,
restricted Linux capabilities, PostgreSQL with a named data volume, container
health checks, and loopback-only API host port publishing.

## 2. Architecture Overview

The target request path places an Application Load Balancer (ALB) in public
subnets and an Amazon ECS service using Fargate in private subnets. The service
will retrieve container images from Amazon ECR, use IAM roles for scoped AWS
access, and integrate with CloudWatch for logs and metrics and Secrets Manager
for application secrets. The VPC and service are intended to span multiple
Availability Zones.

This separation is modeled in Terraform, including private task networking,
scoped IAM roles, Secrets Manager references, and a gated ECS deployment.
CloudWatch logs, alarms, dashboard widgets, and optional SNS alerting are also
modeled as reusable Terraform; monitoring remains disabled in both
environments until explicitly enabled.

Task-management routes now require a valid access token and enforce database-
scoped user ownership. The API still lacks token revocation, distributed
rate-limiting, TLS termination, and a production secret-management integration;
it must not be exposed publicly until those deployment controls are designed
and implemented.

> **Architecture diagram placeholder:** A reviewed deployment diagram remains
> future work; the Terraform design is implemented locally but has not been
> applied to AWS or verified against live services.

### Local container workflow

Configure local-only credentials and start the database and API from the
repository root:

```sh
cp app/.env.example app/.env
# Replace all secret placeholders in app/.env before running.
docker compose --env-file app/.env up -d postgres
docker compose --env-file app/.env build api
docker compose --env-file app/.env run --rm api src/db/migrate-cli.js
docker compose --env-file app/.env run --rm -it api src/cli/provision-account.js admin
docker compose --env-file app/.env up -d api
```

Compose binds the API to `127.0.0.1:3000`. Container build details, health
checks, runtime hardening, AMD64 build instructions, and verification evidence
are documented in [`docs/containerisation.md`](./docs/containerisation.md).
The baseline and post-remediation Docker Scout results for AMD64 and ARM64 are
recorded in
[`docs/container-security-assessment.md`](./docs/container-security-assessment.md).
Database schema, account provisioning, authentication, and integration-test
details are documented in
[`docs/database-and-authentication.md`](./docs/database-and-authentication.md).

## 3. Technology Stack

| Area | Technology | Status / intended use |
|---|---|---|
| Cloud platform | AWS | Hosting, networking, identity, registry, secrets, and observability |
| Network | Amazon VPC | Public and private subnet topology across Availability Zones |
| Compute | Amazon ECS with AWS Fargate | Run container workloads without managing EC2 hosts |
| Ingress | Application Load Balancer | Route external requests to healthy service tasks |
| Image registry | Amazon ECR | Store versioned application container images |
| Infrastructure as code | Terraform | Provision reusable infrastructure and environment-specific deployments |
| CI/CD | GitHub Actions | Application, Docker, and Terraform validation workflows; no deployment or registry publishing |
| Application | Node.js 24, Express 5, JavaScript | Implemented versioned REST API with PostgreSQL-backed tasks and users |
| Database | PostgreSQL 17, `pg` | Local Compose database, explicit SQL migrations, and integration tests implemented; reusable managed RDS configuration exists but is not deployed |
| Authentication | Argon2id, JWT (`jose`) | Administrator-provisioned local accounts, short-lived access tokens, and per-user authorization implemented |
| Containerisation | Docker, Docker Compose | Multi-stage Node.js 24 image and hardened local Compose configuration with PostgreSQL implemented |
| Identity and secrets | IAM, AWS Secrets Manager | Scoped ECS execution/application roles and secret references are modeled; live credentials are not configured |
| Monitoring | Amazon CloudWatch, SNS | Reusable alarms, dashboard, and optional encrypted SNS topic are implemented offline; disabled by default and not deployed |

## 4. Repository Structure

The application, reusable Terraform infrastructure modules, CI validation
workflows, and operational documentation are implemented. AWS deployment
automation is intentionally absent. `.gitkeep` files retain otherwise-empty
directories and are not infrastructure or workflow implementations.

```text
.
├── .github/
│   └── workflows/                 # Application, Docker, and Terraform validation
├── app/
│   ├── Dockerfile                  # Multi-stage production API image
│   ├── .dockerignore
│   ├── src/                       # Express API, services, repository, middleware
│   ├── tests/                     # Unit and PostgreSQL integration tests
│   ├── migrations/                # Versioned SQL schema migrations
│   ├── docs/                      # API setup, security notes, OpenAPI contract
│   ├── .env.example
│   ├── package.json
│   └── package-lock.json
├── terraform/
│   ├── bootstrap/              # S3 state-backend bootstrap (not applied)
│   ├── environments/
│   │   ├── dev/                 # Development root, backend key, and provider lock
│   │   └── prod/                # Production root, backend key, and provider lock
│   └── modules/
│       ├── alb/                   # ALB, target group, listeners, optional access logs
│       ├── ecr/                   # Private image registry and lifecycle policy
│       ├── ecs/                   # Deployment-gated ECS Fargate service
│       ├── iam/                   # Scoped task execution and application roles
│       ├── monitoring/            # Disabled-by-default alarms, dashboard, optional SNS
│       ├── rds/                   # Private PostgreSQL and managed master credentials
│       ├── security/              # Implemented workload security-group module
│       ├── vpc/                   # Implemented VPC and flow-log module
│       └── networking/            # Implemented routing, NAT, and S3 endpoint module
├── scripts/                       # Repository utility scripts
├── docs/
│   ├── containerisation.md        # Container build, runtime, security, and verification
│   ├── database-and-authentication.md
│   ├── terraform-architecture.md  # State, environment, security, and validation design
│   ├── ecr-architecture.md        # Repository, scanning, retention, and IAM design
│   ├── ecs-architecture.md        # ECS, task roles, secrets, logs, and deployment gating
│   ├── monitoring-and-observability.md
│   ├── runbooks/                  # ECS, ALB, RDS, outage, and rollback procedures
│   ├── rds-and-secrets-architecture.md
│   └── ci-cd-architecture.md      # GitHub Actions CI, scanning, artifacts, and local reproduction
├── compose.yaml                   # Hardened local API, PostgreSQL, and isolated test services
├── .gitignore
└── README.md
```

## 5. Infrastructure Design

Terraform now has separate dev/prod roots, consistent AWS provider and
version constraints, common tagging and naming inputs, and a separate
not-yet-applied bootstrap configuration for the S3 state bucket. Environment
state keys are distinct and use native S3 lockfiles. The backend bucket name is
intentionally not committed because it has not been created.

Reusable VPC, networking, workload security-group, ALB, ECR, ECS, IAM, RDS,
Secrets Manager, and CloudWatch monitoring modules are implemented for dev and
prod. ECS service and monitoring resources are deployment-gated; the
environment examples keep monitoring disabled. See
[`docs/terraform-architecture.md`](./docs/terraform-architecture.md) for
backend setup, authentication, environment tradeoffs, recovery, validation,
and deployment boundaries.

The target network places the ALB in public subnets and ECS tasks in private
subnets across multiple Availability Zones. The Terraform modules model scoped
security groups and ECS task roles, ECR image references, and Secrets Manager
runtime secret references.

These are IaC configurations and local mocked-test results, not deployed AWS
resources. No VPC, RDS instance, ECS service, SNS topic, or other AWS resource
has been provisioned.

## 6. CI/CD Architecture

The repository contains three GitHub Actions CI workflows:

- `application-ci.yml`: Node.js 24 unit, coverage, PostgreSQL integration, and
  dependency audit checks.
- `docker-ci.yml`: Linux/AMD64 image build, hardened runtime checks, and Trivy
  vulnerability scanning. It does not publish images.
- `terraform-ci.yml`: Terraform formatting, validation, mocked tests, and
  Checkov scanning for both environments.

All workflows use least-privilege read-only GitHub permissions, require no AWS
credentials, and do not run `terraform apply`, `terraform destroy`, or
deployment commands. Docker CI currently fails its intentional CRITICAL/HIGH
gate on two OpenSSL QUIC findings; see the
[`container security assessment`](./docs/container-security-assessment.md).
The workflows have not been claimed as passing on GitHub.

> **Deployment diagram placeholder:** A separate future deployment design
> should show image publication, environment promotion, AWS authentication,
> ECS deployment, and rollback. Current workflows validate and scan only.

## 7. Security Architecture

Security objectives for the platform include:

- Application HTTP headers, explicit CORS origin allowlisting, bounded JSON
  request bodies, request-rate limiting, and schema validation are implemented.
- Argon2id password hashing, required JWT configuration, issuer/audience/
  expiration verification, generic login errors, and a stricter login rate
  limit are implemented.
- Task routes require authentication; SQL operations scope ownership to the
  authenticated UUID, and foreign-owned tasks return `404`.
- Database and JWT secrets are supplied through runtime configuration locally;
  no real credentials are committed. Terraform models Secrets Manager
  references and distinct least-privilege ECS task execution/application roles.
- GitHub Actions use read-only repository permissions and require no AWS
  credentials; OIDC deployment federation is not configured.
- Private subnets for application tasks and security groups limited to
  required communication paths are modeled in Terraform.
- Runtime secret references are modeled without storing secret values in
  Terraform source, plain environment fields, or image layers.
- Container vulnerability scanning and dependency checks as part of delivery.
- Reviewable, version-controlled Terraform changes and environment separation.

Immediate token revocation and distributed login rate-limiting are not
implemented. Terraform, CI, and monitoring policies are locally modeled and
validated; no AWS resources have been created.

## 8. Monitoring and Observability

The reusable CloudWatch monitoring module defines ECS service CPU/memory and
optional Container Insights task-count alarms, ALB target health/error/latency
alarms, RDS saturation/storage alarms, a per-environment operations dashboard,
and optional SNS alert delivery. Development and production thresholds,
prerequisites, cost considerations, Logs Insights queries, and validation are
documented in
[`docs/monitoring-and-observability.md`](./docs/monitoring-and-observability.md).
Monitoring is disabled by default; no live dashboard, alarm, subscription, or
notification has been created or tested.

## 9. Deployment Strategy

The intended deployment model uses immutable images and environment-specific
Terraform. Current GitHub workflows validate, build locally on the runner, and
scan but do not publish to ECR or deploy to ECS. Production approvals,
promotion, and AWS identity federation remain future work.

ECS configuration includes ALB readiness checks, a deployment circuit breaker,
and rollback behavior. The rollback process is documented in
[`docs/runbooks/deployment-rollback.md`](./docs/runbooks/deployment-rollback.md);
it has not been exercised against AWS.

## 10. Reliability and High Availability

The target design aims to deploy the ALB and ECS service across multiple
Availability Zones, route traffic only to healthy tasks, and use service
autoscaling to respond to workload demand. Managed Fargate compute removes the
need to operate an application host fleet, while deployment health checks and
rollback controls are intended to reduce release risk.

Availability objectives, capacity limits, scaling signals, failure handling,
and recovery procedures have not yet been configured or measured. They will be
specified and validated during implementation; this README makes no SLA or
performance claim.

## 11. Operational Documentation

Operational documentation is maintained under `docs/`, including:

- Architecture documentation and the intended network flow.
- Environment provisioning and teardown procedures.
- Deployment, promotion, and rollback steps.
- Monitoring architecture, alert interpretation, and incident response guidance.
- Security and access-management decisions.
- Recovery and troubleshooting procedures.

Application API, containerisation, database/authentication, Terraform, CI,
monitoring, and seven operational runbooks are present. Architecture diagrams,
AWS provisioning, backup/restore, and live incident procedures remain
outstanding or untested.

## 12. Implementation Status

Status reflects repository contents, not deployment. Application code,
Terraform configuration, local automated tests, CI workflows, and offline
operational documentation are implemented. No AWS infrastructure is deployed.

| Component | Status | Evidence / notes |
|---|---|---|
| Repository structure | Delivered | Initial directories and `.gitkeep` placeholders are present. |
| README and project description | Delivered | This document records intended design and current status. |
| `.gitignore` | Delivered | Ignores common Node.js, Terraform, AWS tooling, and local editor artifacts. |
| Node.js REST API and automated tests | Delivered | Express 5 API, validation, structured logging, health checks, lifecycle handling, authentication, authorization, and tests are implemented under `app/`. |
| PostgreSQL persistence and migrations | Delivered | Owner-scoped PostgreSQL repositories, versioned SQL migrations, pool lifecycle, and a separate integration test database are implemented. AWS RDS and automated backup/restore are not. |
| Authentication and authorization | Delivered | Argon2id, operator-provisioned accounts, configured short-lived JWTs, and database-enforced per-user task ownership are implemented. Token revocation and distributed rate limiting are not. |
| Application and database documentation | Delivered | API setup, OpenAPI, containerisation, database schema, authentication, and local testing guidance are documented. |
| Docker image and local container hardening | Delivered | Multi-stage Node 24 image; Compose runs non-root with read-only root filesystem, PostgreSQL, and loopback-only API publishing. |
| Application and PostgreSQL verification | Delivered | 21 unit tests pass at 86.91% line coverage under Node.js 24; the isolated PostgreSQL integration test passes and verifies scoped ownership, readiness failure, and persisted task data after reconnect. |
| Container verification | Delivered | Earlier AMD64 and ARM64 Docker runtime checks covered UID/GID 65532, Argon2, health, read-only root, graceful SIGTERM, and persistence. The current AMD64 Trivy scan reports two HIGH OpenSSL QUIC CVEs; see the container security assessment. |
| Dependency and image scanning | Delivered with open findings | `npm audit` previously reported zero advisories. Trivy 0.70.0 reports two HIGH Debian OpenSSL findings in the pinned AMD64 runtime; Docker CI fails the strict gate as intended. |
| Container security assessment | Delivered | Historical Docker Scout findings and current Trivy CVEs, reachability analysis, supported-image comparison, and deployment decision are recorded in `docs/container-security-assessment.md`. |
| Containerisation documentation | Delivered | Build, runtime, health, security, scanning, and platform guidance is in `docs/containerisation.md`. |
| Terraform foundation | Delivered | Terraform/provider constraints, dev/prod roots, provider lockfiles, tagging inputs, partial S3 backend configuration with native locking, and separate local-state bootstrap are present. No apply was run. |
| VPC and networking modules | Delivered (offline) | Reusable VPC/subnet/IGW and networking/NAT/route/S3 endpoint modules are implemented; dev uses a single NAT and prod defaults to per-AZ NAT. Native mocked tests pass; the repository-wide Checkov scan has outstanding findings documented in `docs/terraform-architecture.md`. No AWS deployment was performed. |
| Workload security-group module | Delivered (offline) | Reusable ALB, ECS, and RDS security groups use dedicated ingress/egress rule resources; ALB-only ECS ingress and ECS-only RDS ingress are enforced. Mocked tests and local validation pass; no AWS deployment was performed. |
| Application Load Balancer module | Delivered (offline) | Reusable internet-facing/internal ALB, IP target group, HTTPS listener, optional HTTP redirect, hardened access-log bucket support, deletion protection, and optional WAF association are implemented. Native mocked tests pass; no certificate, DNS, WAF, or AWS resource was created. |
| Amazon ECR module | Delivered (offline) | Private immutable-repository configuration, AES256 or optional KMS encryption, basic scan-on-push, lifecycle retention, and dev/prod integration are implemented. Native mocked tests pass; no image or AWS repository was created. |
| ECS and IAM modules | Delivered (offline) | ECS Fargate cluster, gated task-definition/service, private awsvpc networking, execution/task roles, CloudWatch logs, secret references, and deployment rollback configuration are implemented. Native mocked tests pass; no service or AWS resource was deployed. |
| RDS and Secrets Manager modules | Delivered (offline) | Private RDS subnet placement, PostgreSQL TLS parameter group, managed master credentials, external application secrets, and ECS secret references are implemented. Native mocked tests pass; no database or secret was created. |
| CloudWatch monitoring module | Delivered (offline) | Reusable ECS, ALB, and RDS alarms, JSON dashboard, optional encrypted SNS topic, environment thresholds, deployment gating, and eight native mocked tests are implemented. Monitoring is disabled by default; no AWS resources or subscriptions were created. |
| Operational runbooks | Delivered (offline) | Seven ECS, ALB, RDS, database outage, and deployment rollback runbooks distinguish read-only investigation from approval-gated changes. No operational commands were executed. |
| Terraform infrastructure modules | Delivered (offline) | VPC, networking, security groups, ALB, ECR, ECS, IAM, RDS, Secrets Manager, and monitoring configuration are implemented. Nothing has been applied to AWS. |
| Terraform validation | Delivered locally with open scan findings | Recursive formatting, both environment validations, monitoring module validation, and all 35 native mocked tests passed locally. Checkov reports 198 passed and 19 failed checks; details and decisions are documented in `docs/terraform-architecture.md`. |
| AWS workload infrastructure | Not deployed | VPC, RDS, ECS, ALB, ECR, IAM workload roles, and monitoring are not provisioned. ECS service creation is gated; RDS, Secrets Manager values, and ACM deployment remain live prerequisites. |
| GitHub Actions CI | Delivered (offline) | Application unit/coverage/integration, Docker build/runtime/Trivy, and Terraform/Checkov workflows are implemented. They perform no AWS deployment; Docker's strict Trivy gate currently reports two HIGH findings. |
| GitHub Actions deployment and AWS OIDC | Planned | No deployment workflow or AWS identity configuration exists. |
| CloudWatch logs, metrics, dashboards, and alerts | Delivered (offline) | Existing ECS logs are reused; metric alarms and dashboards are configured but disabled by default and not deployed. SNS subscriptions are not created. |
| AWS runbooks and architecture diagrams | Partial | Seven operational runbooks and architecture documentation are present; live AWS validation and architecture diagrams remain outstanding. |
