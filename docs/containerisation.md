# Application Containerisation

The API is packaged as a non-root Node.js container for local verification and
future deployment. This container does not create or configure AWS resources;
ECS, ECR, Terraform, and CI/CD remain separate, unimplemented work.

## Docker architecture

[`app/Dockerfile`](../app/Dockerfile) uses separate dependency-install,
integration-test, and runtime stages:

1. `production-dependencies` copies the npm manifest and committed lockfile,
   then runs `npm ci --omit=dev` on a digest-pinned official Node 24 Debian
   Trixie image. Keeping this layer separate from source allows Docker to reuse
   the dependency layer when only application files change.
2. `integration-test` uses the same pinned Node 24 builder image and includes
   test-only dependencies and test source; it is not used as a runtime image.
3. `runtime` copies only production `node_modules`, package metadata, and
   application source into a digest-pinned Distroless Node.js 24 Debian 13
   image. The minimal runtime does not include npm, Corepack, Yarn, a shell, or
   build tools. It runs as UID/GID 65532, the Distroless non-root account.

The official Node 24 Trixie image is used for reproducible dependency
installation and tests. The final runtime uses Distroless Node.js 24 on Debian
13, retaining glibc compatibility for the Argon2 native addon while
substantially reducing the runtime package surface. Both multi-platform base
image indexes are pinned by digest and support Linux/AMD64 and Linux/ARM64.
Refresh these digests through a reviewed dependency-update process and rerun
tests and image scans.

## Build commands

From the repository root, build a native image for local testing:

```sh
docker build -t production-ready-aws-devops-platform-api:local ./app
```

For ECS Fargate configured for Linux/AMD64, build the deployment architecture
explicitly. On Apple Silicon this may use emulation and take longer:

```sh
docker buildx build \
  --platform linux/amd64 \
  --load \
  -t production-ready-aws-devops-platform-api:local-amd64 \
  ./app
```

The Dockerfile does not upgrade dependencies during image creation; it installs
the lockfile-resolved packages with `npm ci --omit=dev`.

## Local container execution

The API now requires PostgreSQL and a valid JWT signing key, so use the
repository Compose configuration rather than running the image without its
runtime dependencies:

```sh
cp app/.env.example app/.env
# Replace all secret placeholders with local-only random values.
docker compose --env-file app/.env up -d postgres
docker compose --env-file app/.env build api
docker compose --env-file app/.env run --rm api src/db/migrate-cli.js
docker compose --env-file app/.env run --rm -it api src/cli/provision-account.js admin
docker compose --env-file app/.env up -d api
```

The container binds to `0.0.0.0` inside its network namespace so Docker's
port-forwarding can reach it. The published host port is explicitly bound to
`127.0.0.1`; PostgreSQL is private to the Compose network and its port is not
published to the host. Task routes require JWT authentication and user-scoped
authorization. This local setup is not a public deployment: TLS termination,
token revocation, distributed rate limiting, and production secret management
are not implemented.

The repository-root [`compose.yaml`](../compose.yaml) runs the API, PostgreSQL,
and an optional isolated PostgreSQL integration-test service:

```sh
docker compose --env-file app/.env ps
docker compose --env-file app/.env logs -f api
docker compose --env-file app/.env stop
```

Set `HOST_PORT` in the ignored `app/.env` to change the host-side port. Keep
development credentials out of source control and never reuse them in
production. Removing the Compose `postgres-data` volume deletes all local
database data; `docker compose down --volumes` is destructive.

## Health checks

The image and Compose configuration use Node's built-in `fetch` to probe
`/health/live`; neither curl nor wget is installed in the runtime image. The
check has a 2-second request timeout, a 30-second interval, a 3-second check
timeout, a 5-second start period, and three retries. Liveness is independent
of PostgreSQL. `/health/ready` performs a bounded database query and returns
503 when the database is unavailable or shutdown has started.

Verify health and application routes:

```sh
curl --fail http://127.0.0.1:3000/health/live
curl --fail http://127.0.0.1:3000/health/ready
curl --fail http://127.0.0.1:3000/api/v1/info
docker inspect --format '{{.State.Health.Status}}' \
  "$(docker compose --env-file app/.env ps -q api)"
```

## Logging

The application writes structured Pino JSON logs to stdout. Docker's default
logging path makes these available through `docker logs` and the Compose
`logs` command. Compose bounds local JSON log-file usage to three 10 MiB files.
Future ECS task definitions can route container stdout/stderr to CloudWatch;
that AWS configuration is not included here.

## Security controls

- The runtime image executes as the Distroless non-root UID/GID `65532:65532`.
- The runtime filesystem has no shell or package manager; only the Node runtime
  and required application files are present.
- Only production npm dependencies and the files required to start the API are
  copied into the runtime stage.
- `.dockerignore` excludes environment files, npm configuration, local
  dependencies, tests, coverage, editor files, and temporary/log files from
  the build context.
- No credentials, secret files, or `.env` files are copied into the image.
- Compose enables `no-new-privileges`, drops all Linux capabilities, and mounts
  the root filesystem read-only. A small no-exec, no-setuid `/tmp` tmpfs is
  available for runtime compatibility; the application itself does not persist
  files there.
- Compose publishes the API only on host loopback and keeps PostgreSQL private.
- Task endpoints require JWT authentication and all task queries enforce owner
  scope in PostgreSQL. Administrators do not have implicit access to other
  users' tasks.
- Login uses Argon2id password hashes, generic failure responses, and a
  stricter per-IP rate limit. Access tokens cannot be revoked before expiry,
  and rate limits are not distributed across processes.
- Production TLS, managed secret delivery, database encryption/backups, and
  distributed abuse controls are not implemented.

The read-only root filesystem is compatible with the current API, which only
reads source and writes logs to stdout. If future features need writable state,
provide a narrowly scoped writable mount instead of making the whole root
filesystem writable.

## Runtime configuration

The image defaults to `NODE_ENV=production`, `HOST=0.0.0.0`, and `PORT=3000`.
The runtime also requires valid PostgreSQL and JWT configuration, supplied by
Compose from the ignored local `app/.env` file. No credentials are baked into
the image. PostgreSQL provides persistent local task data; managed AWS
PostgreSQL, backup/recovery, and production secret delivery remain unimplemented.

## Graceful shutdown

The exec-form command starts Node directly as the container process.
`STOPSIGNAL SIGTERM` makes the intended signal explicit. Docker delivers its
stop signal to Node when run directly; Compose's init shim forwards it to Node.
The server marks readiness false, stops accepting new connections, waits up to
`SHUTDOWN_TIMEOUT_MS` (10 seconds in Compose) for active requests, then closes
the PostgreSQL pool. Compose allows 15 seconds before forcefully stopping the
container.

Validate manually:

```sh
docker compose --env-file app/.env stop api
docker compose --env-file app/.env logs api
```

The shutdown log should include `Graceful shutdown started` with signal
`SIGTERM`, followed by `HTTP server closed`. Docker's health-check interval is
not a substitute for configuring a future ECS target group's health-check and
deregistration-drain settings.

## Image scanning

The vulnerable baseline image produced 79 findings across 23 packages. After
moving the runtime to a digest-pinned Distroless Node.js 24 Debian 13 image,
Docker Scout indexed both final architecture images and reported no vulnerable
packages. `npm audit` also reported zero vulnerabilities in the dependency
tree.

| Scanner / image | Result |
|---|---|
| `npm audit` | 0 dependency advisories |
| Docker Scout baseline (AMD64 and ARM64) | 79 findings: 0 critical, 13 high, 24 medium, and 42 low |
| Docker Scout final `:amd64` | No vulnerable package detected |
| Docker Scout final `:arm64` | No vulnerable package detected |

The detailed baseline package/CVE list, remediation rationale, final counts,
and ongoing scanning policy are in
[`container-security-assessment.md`](./container-security-assessment.md).
Scout results describe the scanner database at scan time, not a guarantee of
future safety. Trivy and Grype were unavailable during this validation. For
subsequent scans, use for example:

```sh
trivy image --severity HIGH,CRITICAL \
  production-ready-aws-devops-platform-api:local
```

This repository does not yet include automated image scanning.

## Platform compatibility and limitations

The digest-pinned Distroless Node.js 24 Debian 13 runtime supports Apple Silicon
(Linux/ARM64) and Linux/AMD64. A native local build uses the host architecture;
build with `--platform linux/amd64` for an AMD64 Fargate task definition.
Confirm that the selected ECS task architecture matches the image manifest.

The container has not been deployed to ECS and has not been pushed to a
registry. Linux/ARM64 and Linux/AMD64 images were built locally; Argon2 loaded
and hashed/verified in both final runtime images. No AWS infrastructure or
CI/CD implementation exists.
