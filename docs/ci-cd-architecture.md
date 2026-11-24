# CI/CD Architecture

## Implemented CI workflows

The repository uses three GitHub Actions workflows. They provide validation and
diagnostics only; no workflow creates AWS resources or pushes images.

### Application CI

`.github/workflows/application-ci.yml` runs on pull requests to `main`, pushes
to `main`, and manual dispatch.

It:

- Uses Node.js 24 and `npm ci`
- Runs unit tests and coverage
- Verifies the package lock with a dry-run install
- Runs `npm audit --omit=dev --audit-level=high`
- Starts an isolated PostgreSQL 17 service
- Creates a temporary application role
- Applies migrations with `npm run db:migrate`
- Runs the PostgreSQL integration test
- Uploads coverage and JUnit-style test reports

PostgreSQL credentials are CI-only ephemeral environment values. The integration
database is `task_api_test`, isolated from development and production.

### Docker CI

`.github/workflows/docker-ci.yml` builds `app/Dockerfile` for Linux/AMD64 using
Buildx. It does not publish to Docker Hub or ECR.

The final image is checked for:

- `linux/amd64` architecture
- Non-root UID/GID `65532:65532`
- Read-only filesystem compatibility
- Live and ready endpoints
- Authentication rejection
- Graceful SIGTERM shutdown

The workflow uses an isolated PostgreSQL container, applies migrations using
the runtime image, and starts the API under a read-only root filesystem with
dropped Linux capabilities. Failure logs are uploaded as diagnostics.

OCI labels identify the repository, source revision and build context.

### Terraform CI

`.github/workflows/terraform-ci.yml` initializes modules with
`-backend=false`, validates both environment roots, runs Terraform native
mocked tests, verifies formatting and runs Checkov.

It does not configure remote state, AWS credentials or AWS providers for live
operations. It never runs `apply` or `destroy`.

## Security gates

- GitHub Actions use `permissions: contents: read`.
- Third-party actions are pinned to full commit SHAs.
- Pull-request and push workflows cannot deploy.
- `pull_request_target` is not used.
- Trivy scans fail on critical or high vulnerabilities without
  `ignore-unfixed`; the JSON and table reports are uploaded regardless.
- The table report is also printed in the Actions log after the gate runs, so
  findings remain visible when the scan step fails.
- Trivy image scans use `--scanners vuln` and `--skip-version-check` to avoid
  secret-scanner noise and version-update notices while retaining strict
  CRITICAL/HIGH vulnerability gates.
- Checkov findings are reported as workflow output and artifacts.
- A mutable `latest` tag is not used for deployment references.
- The Docker workflow uses build-time files and no repository secrets.

The Trivy gate is intentionally strict for critical and high findings. Existing
high findings do not make a newly failing scan a baseline exception. Remediation
must be reviewed for any introduction or removal of findings.

## Concurrency and cost controls

Each workflow has a per-ref concurrency group and cancellation of superseded
runs. Job timeouts bound runner usage. Standard Linux runners are used, with no
paid runner or build matrix.

Public repository usage is generally available under GitHub-hosted runner
allowances. Private repository usage or excessive runner usage may be charged
according to the repository or organization plan.

## Artifact retention

- Application coverage and test reports: 14 days
- Docker diagnostics: 14 days
- Trivy JSON and human-readable reports: 30 days
- Checkov report: 30 days

## Local reproduction

Application unit and coverage checks:

```sh
cd app
npm ci
npm test
npm run coverage
npm audit --omit=dev --audit-level=high
```

The application declares Node.js `>=24 <25`; run these commands under Node.js
24. For example, the Dockerfile's `integration-test` stage installs the test
dependencies and can run the unit suite without a local Node.js installation:

```sh
docker build --platform linux/amd64 --target integration-test \
  -f app/Dockerfile -t platform-node24-tests:local app
docker run --rm platform-node24-tests:local npm test
```

PostgreSQL integration test:

```sh
docker compose --profile integration up --abort-on-container-exit \
  --exit-code-from integration-test
```

Docker build and AMD64 verification:

```sh
docker build --platform linux/amd64 --target runtime -t api:ci ./app
docker inspect api:ci --format '{{.Os}}/{{.Architecture}}'
docker inspect api:ci --format '{{json .Config.User}}'
```

Terraform:

```sh
terraform fmt -check -recursive terraform
cd terraform/modules/vpc && terraform init -backend=false && terraform validate && terraform test
# Repeat for networking, security, alb, ecr, ecs, iam, rds, secrets and monitoring.
cd terraform/environments/dev && terraform init -backend=false && terraform validate
cd terraform/environments/prod && terraform init -backend=false && terraform validate
```

Checkov:

```sh
python3 -m checkov.main -d terraform
```

Trivy:

```sh
trivy image --severity CRITICAL,HIGH api:ci
trivy image --format json --output trivy-results.json api:ci
```

## Troubleshooting

- Unit failures: inspect JUnit and coverage artifacts.
- PostgreSQL failures: verify the dedicated `task_api_test` database and role.
- Docker runtime failures: inspect Docker logs uploaded for the failed run.
- Trivy failures: review the JSON and table reports; remediate CRITICAL/HIGH
  findings rather than widening the gate.
- Terraform failures: run the exact module locally with `-backend=false`.
- Checkov findings: distinguish AWS-compatible requirements from unresolved
  controls and document the technical reason rather than silently suppressing.

## Local verification results

The following checks were executed locally:

- Node.js 24 unit and repository suite: 21 passed, 0 failed.
- PostgreSQL 17 integration test: 1 passed, 0 failed.
- Docker final runtime image: Linux/AMD64, UID/GID 65532, read-only root,
  `no-new-privileges`, and `CAP_ALL` dropped.
- Runtime: liveness and readiness returned 200, unauthenticated tasks returned
  401, invalid login returned 400, and SIGTERM shutdown returned exit code 0.
- Terraform `fmt -check -recursive`, monitoring-module validation, and dev/prod
  root validation passed locally.
- All 35 native Terraform mocked tests passed across the ten modules, including
  eight monitoring tests. Mocked test results do not represent AWS deployment.
- Checkov 3.4.3 reported 198 passed and 19 failed checks. The findings include
  environment-specific availability/encryption defaults, S3 audit/replication
  controls, optional WAF/secret rotation, and unattached (not live) security
  groups; they remain reported and are documented in
  `terraform-architecture.md`. The scan did not identify findings in the new
  monitoring module.
- Actionlint passed after two shell-loop scripts were corrected.
- Trivy reported 0 CRITICAL and 2 HIGH findings for
  `libssl3t64`: CVE-2026-107494 and CVE-2026-124709. Both currently report no
  fixed version, so no package downgrade or suppression is applied. The strict
  gate remains enabled.

The host Node.js v16 test command timed out. Node v16 is outside the package's
declared Node.js `>=24 <25` engine range. The same 21-test suite passed under
Node.js 24 in the Docker `integration-test` stage; no test timeout was
increased and no test was weakened. This confirms the suite passes under its
supported runtime, but does not establish a more specific cause for the
unsupported-runtime hang.

The Docker runtime verification uses an isolated PostgreSQL 17 container and
temporary credentials. It does not connect to development or production data.

These local results do not prove that GitHub-hosted runners have passed. The
workflows must be executed by GitHub to verify runner-specific behavior.

## Future deployment design

A future deployment workflow should be separate and explicitly approved. It
should authenticate to AWS through GitHub OIDC, require environment approvals,
use immutable image digests or SHA tags, plan Terraform, and deploy to ECS only
after RDS, Secrets Manager, ACM and listener prerequisites exist.

No current workflow deploys infrastructure or publishes a container image.
