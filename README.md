# Production-Ready AWS DevOps Platform

## 1. Project Overview

The Production-Ready AWS DevOps Platform is an infrastructure engineering
project for designing and implementing an automated, secure, scalable, and
highly available application deployment architecture on AWS. It brings
infrastructure as code, container delivery, CI/CD, security controls, and
operational observability into one version-controlled platform.

The repository is intended to make the platform's architecture and delivery
approach reviewable: reusable Terraform modules define infrastructure,
environment-specific configuration separates deployment concerns, and
GitHub Actions is planned to validate and deliver application and infrastructure
changes. Architectural capabilities described below are targets unless marked
as delivered in the implementation status.

The application layer now includes a versioned Express REST API for operational
tasks, PostgreSQL persistence, administrator-provisioned accounts, short-lived
JWT authentication, per-user task authorization, structured request logging,
input validation, health checks, graceful shutdown, automated tests, and an
OpenAPI contract. PostgreSQL is a required runtime dependency; AWS RDS is not
implemented.

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

This separation keeps application tasks off direct public ingress while
providing a managed entry point, and uses managed AWS services to reduce
operational overhead. The exact network egress, endpoint, scaling, and
monitoring configurations will be documented as they are implemented.

Task-management routes now require a valid access token and enforce database-
scoped user ownership. The API still lacks token revocation, distributed
rate-limiting, TLS termination, and a production secret-management integration;
it must not be exposed publicly until those deployment controls are designed
and implemented.

> **Architecture diagram placeholder:** Add a reviewed diagram here once the
> Terraform network, service, and AWS integrations are implemented and verified.

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
| CI/CD | GitHub Actions | Validate, test, scan, build, and deploy changes |
| Application | Node.js 24, Express 5, JavaScript | Implemented versioned REST API with PostgreSQL-backed tasks and users |
| Database | PostgreSQL 17, `pg` | Local Compose database, explicit SQL migrations, and integration tests implemented; managed AWS database planned |
| Authentication | Argon2id, JWT (`jose`) | Administrator-provisioned local accounts, short-lived access tokens, and per-user authorization implemented |
| Containerisation | Docker, Docker Compose | Multi-stage Node.js 24 image and hardened local Compose configuration with PostgreSQL implemented |
| Identity and secrets | IAM, GitHub Actions OIDC, AWS Secrets Manager | Planned scoped access, keyless CI authentication, and runtime secrets |
| Monitoring | Amazon CloudWatch | Centralise application logs, infrastructure metrics, dashboards, and alerts |

## 4. Repository Structure

The application layer is implemented; infrastructure, deployment automation,
and top-level operational documentation remain scaffolded. The `.gitkeep` files
retain otherwise-empty directories and are not infrastructure or workflow
implementations.

```text
.
├── .github/
│   └── workflows/                 # Planned CI/CD workflow definitions
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
│       ├── alb/                   # Planned load balancer module
│       ├── ecr/                   # Planned container registry module
│       ├── ecs/                   # Planned ECS service module
│       ├── iam/                   # Planned IAM module
│       ├── monitoring/            # Planned observability module
│       ├── rds/                   # Planned database module
│       ├── security/              # Implemented workload security-group module
│       ├── vpc/                   # Implemented VPC and flow-log module
│       └── networking/            # Implemented routing, NAT, and S3 endpoint module
├── scripts/                       # Planned operational and development scripts
├── docs/
│   ├── containerisation.md        # Container build, runtime, security, and verification
│   ├── database-and-authentication.md
│   ├── terraform-architecture.md  # State, environment, security, and validation design
│   ├── ecr-architecture.md        # Repository, scanning, retention, and IAM design
│   ├── ecs-architecture.md        # ECS, task roles, secrets, logs, and deployment gating
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

Reusable VPC, networking, workload security-group, ALB, and ECR modules are implemented
for dev and prod; ECS, RDS, IAM, Secrets Manager, and monitoring modules remain to be
implemented. See
[`docs/terraform-architecture.md`](./docs/terraform-architecture.md) for
backend setup, authentication, environment tradeoffs, recovery, validation,
and the proposed implementation sequence.

The target network places the ALB in public subnets and ECS tasks in private
subnets across multiple Availability Zones. Security groups will constrain
traffic to required paths. ECS task execution and application permissions will
use appropriately scoped IAM roles. ECR will provide the image source, and
Secrets Manager will hold runtime secrets rather than embedding them in source
or container images.

Infrastructure modules, environment promotion controls, network egress, and
specific sizing and scaling values remain to be implemented; no AWS resources
have been provisioned.

## 6. CI/CD Architecture

GitHub Actions workflows are planned to provide automated checks and controlled
delivery. The intended pipeline will:

1. Run application tests and relevant code or configuration validation.
2. Build the Docker image using a multistage build.
3. Scan dependencies, source, and the built image for security issues.
4. Authenticate to AWS using GitHub Actions OIDC with narrowly scoped IAM
   permissions rather than stored long-lived AWS credentials.
5. Publish an identified image version to ECR and deploy it to the target ECS
   environment after the applicable checks and approvals.

Workflow triggers, promotion rules, approval gates, and rollback behavior will
be specified when the pipeline is implemented. No CI/CD workflows currently
exist in the repository.

> **Deployment diagram placeholder:** Add a pipeline diagram showing source
> change, validation and scanning, image publication, environment promotion,
> ECS deployment, and rollback after the workflow and release controls are
> implemented.

## 7. Security Architecture

Security objectives for the platform include:

- Application HTTP headers, explicit CORS origin allowlisting, bounded JSON
  request bodies, request-rate limiting, and schema validation are implemented.
- Argon2id password hashing, required JWT configuration, issuer/audience/
  expiration verification, generic login errors, and a stricter login rate
  limit are implemented.
- Task routes require authentication; SQL operations scope ownership to the
  authenticated UUID, and foreign-owned tasks return `404`.
- Database and JWT secrets are supplied by runtime environment configuration;
  no real credentials are committed. Production secret management and TLS are
  not implemented. Least-privilege IAM policies and distinct roles for CI, task execution, and
  application runtime access are planned.
- GitHub Actions OIDC federation to avoid persistent AWS access keys in
  repository secrets is planned.
- Private subnets for application tasks and security-group rules limited to
  required communication paths are planned.
- Runtime secret retrieval through Secrets Manager, with secrets excluded from
  source control, build artifacts, and image layers.
- Container vulnerability scanning and dependency checks as part of delivery.
- Reviewable, version-controlled Terraform changes and environment separation.

Immediate token revocation and distributed login rate-limiting are not
implemented. The AWS, IAM, OIDC, network, and CI controls remain planned; no
AWS resources or CI security policies are configured.

## 8. Monitoring and Observability

The target observability design uses CloudWatch for centralised application
logs, infrastructure and service metrics, dashboards, and alerting. Health
checks will inform traffic routing and service health; alerts will be designed
around actionable conditions and documented operational responses.

Log retention, metric selection, alert thresholds, dashboard content, and
notification destinations will be defined and validated with the implementation.
No monitoring resources or operational thresholds are currently present.

## 9. Deployment Strategy

The intended delivery model builds an immutable, versioned container image,
publishes it to ECR, and deploys that image to ECS through an automated,
environment-aware workflow. Development and production configurations are
separated so that changes can be validated before promotion. Production
approvals and release controls will be selected as part of the CI/CD
implementation.

Deployment health checks and rollback behavior are planned safeguards. Their
exact ECS deployment configuration and recovery procedure will be documented
and tested before being described as implemented.

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

Operational documentation will be maintained under `docs/` as the platform is
implemented. Planned runbooks and references include:

- Architecture and network-flow diagrams.
- Environment provisioning and teardown procedures.
- Deployment, promotion, and rollback steps.
- Monitoring dashboards, alert interpretation, and incident response guidance.
- Security and access-management decisions.
- Recovery and troubleshooting procedures.

Application API, containerisation, and database/authentication documentation
is present. AWS provisioning, deployment, backup/restore, and incident-response
runbooks are not yet implemented.

## 12. Implementation Status

Status reflects repository contents, not the target design. The Node.js API,
PostgreSQL persistence, JWT authentication, ownership controls, and local
container configuration are implemented. AWS infrastructure and CI/CD remain
unimplemented.

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
| Application and PostgreSQL verification | Delivered | 21 unit tests pass at 86.99% line coverage; the isolated PostgreSQL integration test passes and verifies scoped ownership, readiness failure, and persisted task data after reconnect. |
| Container verification | Delivered | Final image `:amd64` (167,597,275 bytes) and `:arm64` (174,666,942 bytes) passed Docker Scout scans, ran as UID/GID 65532, and loaded Argon2 successfully. Compose health, read-only-root, loopback publishing, graceful SIGTERM, and API-restart persistence checks passed. |
| Dependency and image scanning | Delivered | `npm audit` reported zero advisories. Docker Scout baseline was 79 findings (0 critical, 13 high, 24 medium, 42 low); final AMD64 and ARM64 images each report no vulnerable packages. |
| Container security assessment | Delivered | Baseline package/CVE findings, remediation rationale, final scan results, and ongoing scanning policy are recorded in `docs/container-security-assessment.md`. |
| Containerisation documentation | Delivered | Build, runtime, health, security, scanning, and platform guidance is in `docs/containerisation.md`. |
| Terraform foundation | Delivered | Terraform/provider constraints, dev/prod roots, provider lockfiles, tagging inputs, partial S3 backend configuration with native locking, and separate local-state bootstrap are present. No apply was run. |
| VPC and networking modules | Delivered (offline) | Reusable VPC/subnet/IGW and networking/NAT/route/S3 endpoint modules are implemented; dev uses a single NAT and prod defaults to per-AZ NAT. Native mocked tests and Checkov pass locally; no AWS deployment was performed. |
| Workload security-group module | Delivered (offline) | Reusable ALB, ECS, and RDS security groups use dedicated ingress/egress rule resources; ALB-only ECS ingress and ECS-only RDS ingress are enforced. Mocked tests and local validation pass; no AWS deployment was performed. |
| Application Load Balancer module | Delivered (offline) | Reusable internet-facing/internal ALB, IP target group, HTTPS listener, optional HTTP redirect, hardened access-log bucket support, deletion protection, and optional WAF association are implemented. Native mocked tests pass; no certificate, DNS, WAF, or AWS resource was created. |
| Amazon ECR module | Delivered (offline) | Private immutable-repository configuration, AES256 or optional KMS encryption, basic scan-on-push, lifecycle retention, and dev/prod integration are implemented. Native mocked tests pass; no image or AWS repository was created. |
| ECS and IAM modules | Delivered (offline) | ECS Fargate cluster, gated task-definition/service, private awsvpc networking, execution/task roles, CloudWatch logs, secret references, and deployment rollback configuration are implemented. Native mocked tests pass; no service or AWS resource was deployed. |
| RDS and Secrets Manager modules | Delivered (offline) | Private RDS subnet placement, PostgreSQL TLS parameter group, managed master credentials, external application secrets, and ECS secret references are implemented. Native mocked tests pass; no database or secret was created. |
| Terraform infrastructure modules | Partial | VPC, networking, workload security groups, ALB, ECR, ECS, IAM, RDS, and Secrets Manager configuration are implemented; monitoring remains planned. |
| Terraform validation | Delivered | `terraform fmt -recursive` and `terraform validate` passed for all implemented modules and dev/prod roots using Terraform v1.17.2 and AWS provider v6.73.0. Native mocked tests passed locally. |
| AWS workload infrastructure | Planned | VPC, RDS, ECS, ALB, ECR, IAM workload roles, and monitoring are not provisioned. ECS and IAM configuration is locally modelled with service creation gated; RDS, Secrets Manager and ACM deployment remain prerequisites. |
| GitHub Actions CI | Delivered (offline) | Application unit/coverage/integration, Docker build/runtime/Trivy, and Terraform/Checkov workflows are implemented. They have not yet been reported as passing on GitHub and perform no AWS deployment. |
| GitHub Actions deployment and AWS OIDC | Planned | No deployment workflow or AWS identity configuration exists. |
| CloudWatch logs, metrics, dashboards, and alerts | Planned | No monitoring configuration exists. |
| AWS runbooks and architecture diagrams | Planned | Platform-specific operations and AWS architecture diagrams remain to be added. |

Implementation claims will be updated as code and configuration are added and
verified.
