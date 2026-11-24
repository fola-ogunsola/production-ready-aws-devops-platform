# Database and Authentication

This document describes the API's PostgreSQL persistence, database migration
process, administrator-provisioned accounts, and per-user authorization. Local
Compose configuration is for development and verification only; it is not an
AWS deployment or a production database design.

## Database schema

The versioned migration [`001_users_and_tasks.sql`](../app/migrations/001_users_and_tasks.sql)
creates two application tables:

| Table | Columns and constraints |
|---|---|
| `users` | UUID primary key; normalized unique email; Argon2id password hash; `user` or `admin` role; creation and update timestamps. |
| `tasks` | UUID primary key; required owner UUID foreign key to `users` with `ON DELETE CASCADE`; constrained title, description, and status; creation and update timestamps. |

`tasks_user_created_idx` supports owner-scoped listing by creation time.
Database constraints enforce valid roles, task statuses, normalized email,
nonblank task titles, required ownership, and field limits in addition to
request-layer Zod validation.

The application connects as a restricted role created by the PostgreSQL
container initialization script. The Compose PostgreSQL superuser password is
separate from the application-role password and is not passed to the API
container. The application role can connect to its database and create objects
in the `public` schema for explicit migrations; it is not a PostgreSQL
superuser.

## Migration strategy

SQL migrations are stored under `app/migrations/` and are not run during API
startup. The migrator:

1. Obtains a PostgreSQL advisory lock to serialize concurrent migration
   commands.
2. Records each migration filename and SHA-256 checksum in
   `schema_migrations`.
3. Applies each migration and its ledger entry in a transaction.
4. Rejects a previously applied migration if its contents have changed.

Apply migrations as a reviewed operator action after the database is healthy:

```sh
docker compose --env-file app/.env up -d postgres
docker compose --env-file app/.env build api
docker compose --env-file app/.env run --rm api src/db/migrate-cli.js
```

Never edit a migration that has already been applied; add a new, forward-only
migration. Take and verify backups before production schema changes.

## Connection pooling and database errors

The Node `pg` connection pool is configured by `DATABASE_POOL_MAX`,
`DATABASE_IDLE_TIMEOUT_MS`, `DATABASE_CONNECTION_TIMEOUT_MS`, and
`DATABASE_QUERY_TIMEOUT_MS`. Query and statement deadlines are applied to avoid
unbounded work. Readiness performs a bounded `SELECT 1`; database credentials
and raw connection details are not included in health responses or error logs.
SIGTERM/SIGINT drain HTTP work and close the pool within the configured
shutdown deadline.

The Compose database stores data in the named `postgres-data` volume. Removing
the volume **deletes all local database data**:

```sh
docker compose --env-file app/.env down
# Destructive to local PostgreSQL data: only use when that is intended.
docker compose --env-file app/.env down --volumes
```

Back up production PostgreSQL using managed, encrypted, tested backup
procedures, and regularly exercise restore and point-in-time recovery. No
backup automation, RDS configuration, encryption, or disaster-recovery
procedure is implemented in this repository.

## Authentication and account provisioning

There is no public registration endpoint. Operators provision users through a
terminal-only CLI. The initial administrator command is:

```sh
docker compose --env-file app/.env run --rm -it api \
  src/cli/provision-account.js admin
```

Additional standard accounts can be provisioned by an authorized operator:

```sh
docker compose --env-file app/.env run --rm -it api \
  src/cli/provision-account.js user
```

The CLI prompts for the email, password, and confirmation. Password input is
read in terminal raw mode with echo disabled; passwords are not accepted as
arguments, printed, or logged. A password must be 15-128 characters.
Passwords are hashed with Argon2id before a single parameterized `INSERT`.
Provisioning requires that the schema migration has already been applied.
Duplicate addresses and database failures are reported without exposing SQL or
connection details.

The login flow is:

1. Validate and normalize the submitted email and validate the password shape.
2. Look up the normalized email and verify the submitted password against the
   Argon2id hash. Unknown accounts perform a dummy hash verification to reduce
   account-existence timing differences.
3. Return a generic failure for unknown accounts and incorrect passwords.
4. On success, issue a signed bearer access token.

No password, password hash, email, database credential, or signing key is
included in JWT claims. The token subject is the user's UUID. Tokens use HS256
and are verified against a configured 256-bit-or-stronger key, issuer,
audience, and expiration. Token lifetime defaults to 15 minutes. There is no
refresh token or immediate revocation mechanism; an issued token remains
valid until expiration.

Authenticated requests resolve the subject against the user table. The current
role is loaded from PostgreSQL, so role changes take effect on the next
request. `requireRole()` is available for future administrative operations;
administrators receive no special access to task data.

## Per-user authorization

The task router requires a valid bearer token for every supported task method.
Controllers pass only the authenticated UUID from `request.auth` to the service.
PostgreSQL task queries bind both task ID and owner ID as parameters:

```sql
SELECT ... FROM tasks WHERE id = $1 AND user_id = $2;
```

List, insert, update, and delete queries also scope the operation to the
authenticated owner. A task owned by another user is indistinguishable from a
missing task and returns `404`. The API does not accept or trust client-supplied
owner IDs.

## Secrets and local configuration

Copy `app/.env.example` to the ignored `app/.env` and replace all placeholder
secrets. Generate separate database passwords and a JWT key:

```sh
openssl rand -hex 32
openssl rand -hex 32
openssl rand -base64 32
```

The first database password is for the restricted API role; the second is for
the local PostgreSQL administrative account; the Base64 value is the JWT
signing key. Keep the file owner-readable only and never commit or bake it into
an image. Compose interpolation uses:

```sh
docker compose --env-file app/.env ...
```

Production should use a managed secret store, distinct per-environment
credentials, key rotation, database TLS, and an appropriately restricted
database role. Terraform models a private RDS PostgreSQL instance and
Secrets Manager metadata/secret references, but these resources and secret
values have not been created or tested in AWS.

## Local testing

Unit tests use isolated fake repositories:

```sh
npm --prefix app test
npm --prefix app run coverage
```

PostgreSQL integration tests use a separate ephemeral Compose PostgreSQL
container and the fixed `task_api_test` database. They refuse to run against a
database with any other name and never connect to the development volume:

```sh
docker compose --env-file app/.env --profile integration \
  run --build --rm integration-test
```

## Security limitations

- The local Compose PostgreSQL service is not configured for TLS or encrypted
  storage; use production-grade managed database controls before deployment.
- Access tokens cannot be revoked before their expiration time.
- Login rate limiting is process-local and is not shared across instances.
- User provisioning is a trusted-operator CLI workflow; there is no public
  registration or self-service password recovery.
- The role middleware is provided for future administrative endpoints; no
  administrative task access or user-management API exists.
- Authentication does not remove the need for TLS, network restrictions,
  monitoring, secret rotation, or abuse controls at the deployment boundary.
