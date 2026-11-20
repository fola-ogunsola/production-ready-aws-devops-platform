# Application API

The application is a Node.js 24 / Express 5 API with PostgreSQL persistence,
administrator-provisioned accounts, short-lived JWT access tokens, and
per-user task ownership. The database is a required runtime dependency.

## Local installation and configuration

Install Node.js 24 and npm, then from the repository root:

```sh
npm --prefix app ci
cp app/.env.example app/.env
```

Replace the placeholder database passwords and signing key in `app/.env` with
independently generated values. For example:

```sh
openssl rand -hex 32
openssl rand -base64 32
```

Do not commit `app/.env`, use example values in production, or bake credentials
into an image. The full environment contract and local Compose workflow are
documented in [`../../docs/database-and-authentication.md`](../../docs/database-and-authentication.md).

## Start the database and API

From the repository root:

```sh
docker compose --env-file app/.env up -d postgres
docker compose --env-file app/.env build api
docker compose --env-file app/.env run --rm api src/db/migrate-cli.js
docker compose --env-file app/.env run --rm -it api src/cli/provision-account.js admin
docker compose --env-file app/.env up -d api
```

The provisioning command prompts for the administrator email and hidden,
confirmed password; do not pass passwords as command-line arguments. The API
listens on `http://127.0.0.1:3000` by default. Change the host port with
`HOST_PORT` in `app/.env`.

The database schema is not changed automatically on API startup. Apply reviewed
SQL migrations explicitly with `npm run db:migrate` (inside the API container
use the command above). Administrator accounts are also provisioned explicitly.

## Environment configuration

| Variable | Default | Description |
|---|---|---|
| `NODE_ENV` | `development` | Runtime environment. |
| `HOST` | `0.0.0.0` | HTTP bind address inside the container. |
| `PORT` | `3000` | HTTP port inside the container. |
| `HOST_PORT` | `3000` | Loopback-only host port published by Compose. |
| `LOG_LEVEL` | `info` | Pino log level. |
| `CORS_ORIGINS` | empty | Comma-separated exact HTTP(S) browser origins. |
| `RATE_LIMIT_WINDOW_MS` / `RATE_LIMIT_MAX` | `60000` / `100` | General API request limit. |
| `LOGIN_RATE_LIMIT_WINDOW_MS` / `LOGIN_RATE_LIMIT_MAX` | `900000` / `5` | Per-IP login attempt limit. |
| `TRUST_PROXY_HOPS` | `0` | Trusted proxy count; keep zero unless direct ingress is restricted. |
| `SHUTDOWN_TIMEOUT_MS` | `10000` | Grace period before forced termination. |
| `DATABASE_HOST` / `DATABASE_PORT` | required / `5432` | PostgreSQL endpoint. |
| `DATABASE_NAME` / `DATABASE_USER` / `DATABASE_PASSWORD` | required | Database and restricted application-role credentials. |
| `DATABASE_POOL_MAX` | `10` | Maximum pooled connections, 1-50. |
| `DATABASE_IDLE_TIMEOUT_MS` | `30000` | Idle connection retirement time. |
| `DATABASE_CONNECTION_TIMEOUT_MS` | `3000` | Maximum time to establish a connection. |
| `DATABASE_QUERY_TIMEOUT_MS` | `5000` | Client and PostgreSQL statement timeout. |
| `JWT_SECRET_BASE64` | required | Canonical Base64 encoding of at least 32 random bytes. |
| `JWT_ISSUER` / `JWT_AUDIENCE` | required | Expected JWT issuer and audience. |
| `JWT_EXPIRES_IN_SECONDS` | `900` | Token lifetime; constrained to 60-3600 seconds. |

Configuration is validated at startup. There is no fallback signing secret or
database password. Compose requires values from `app/.env` for interpolation;
the `.env.example` contains placeholders, not usable secrets.

## API endpoints

Successful responses use a `data` property. Errors contain a stable code, safe
message, and request ID. Task endpoints and `/api/v1/auth/me` require a bearer
access token; health routes and login are unauthenticated.

| Method | Path | Access | Success |
|---|---|---|---|
| `POST` | `/api/v1/auth/login` | Public, rate-limited | `200`, bearer access token |
| `GET` | `/api/v1/auth/me` | Authenticated | `200`, current user |
| `GET` | `/api/v1/tasks` | Authenticated owner | `200`, caller's tasks |
| `GET` | `/api/v1/tasks/{id}` | Authenticated owner | `200`, task |
| `POST` | `/api/v1/tasks` | Authenticated owner | `201`, created task |
| `PATCH` | `/api/v1/tasks/{id}` | Authenticated owner | `200`, updated task |
| `DELETE` | `/api/v1/tasks/{id}` | Authenticated owner | `204`, no body |
| `GET` | `/api/v1/info` | Public | `200`, application information |
| `GET` | `/health/live` | Public | `200` while the process can respond |
| `GET` | `/health/ready` | Public | `200` when PostgreSQL is reachable; otherwise `503` |

Task statuses are `pending`, `in_progress`, and `completed`. Titles are trimmed
and limited to 200 characters; descriptions are limited to 2,000 characters.
Client-supplied owner IDs and unknown input fields are rejected. A valid user
cannot distinguish a missing task from another user's task: both return `404`.

## Authenticate and call the API

The examples use shell variables for credentials and tokens rather than
hard-coded values. Avoid placing actual passwords or tokens directly in shell
commands or saved shell history.

```sh
read -r -p "Account email: " API_EMAIL
read -r -s -p "Account password: " API_PASSWORD
printf '\n'
export API_EMAIL API_PASSWORD
TOKEN=$(
  python3 -c 'import json, os; print(json.dumps({"email": os.environ["API_EMAIL"], "password": os.environ["API_PASSWORD"]}))' |
    curl --fail --silent --show-error \
      -H 'Content-Type: application/json' \
      --data-binary @- http://127.0.0.1:3000/api/v1/auth/login |
    jq -r '.data.accessToken'
)
unset API_PASSWORD API_EMAIL
```

Create and list the authenticated user's tasks:

```sh
curl --fail --silent --show-error \
  -H "Authorization: Bearer $TOKEN" \
  -H 'Content-Type: application/json' \
  -d '{"title":"Review deployment alarms","description":"Confirm actionable alerts"}' \
  http://127.0.0.1:3000/api/v1/tasks

curl --fail --silent --show-error \
  -H "Authorization: Bearer $TOKEN" \
  http://127.0.0.1:3000/api/v1/tasks
unset TOKEN
```

## Tests and coverage

Unit tests do not require PostgreSQL:

```sh
npm --prefix app test
npm --prefix app run coverage
```

PostgreSQL integration tests run in a separate, ephemeral Compose database
named `task_api_test`; they do not use the development database or volume:

```sh
docker compose --env-file app/.env --profile integration \
  run --build --rm integration-test
```

## Health checks and lifecycle

`/health/live` reports process responsiveness without querying PostgreSQL.
`/health/ready` runs a bounded `SELECT 1` and returns only `ready` or
`not_ready`, never connection details. On SIGTERM or SIGINT the server stops
accepting requests, drains active HTTP work, then closes the PostgreSQL pool.
A configured deadline prevents an unbounded graceful shutdown.

## Logging and security

Pino writes structured request logs to stdout without request bodies,
authorization headers, tokens, or database connection strings. Unexpected
database errors return a generic `500` response and logs contain only safe
error metadata.

Passwords are stored as Argon2id hashes. JWT access tokens use HS256 with a
minimum 256-bit configured key; verification enforces the algorithm, issuer,
audience, and expiration. Authentication failures use a generic message, and
login has a stricter per-IP rate limit. Task queries always include the
authenticated database user ID. Administrators do not receive implicit access
to other users' tasks.

Issued access tokens remain valid until expiry. Immediate token revocation,
refresh tokens, MFA, account lockout, and distributed rate limiting are not
implemented. Use TLS at any network boundary outside local development and
deliver production secrets through a future secret-management integration.

## Known limitations

- PostgreSQL and a JWT signing key are required at runtime.
- Local Compose credentials are development-only; never reuse them in production.
- The database is local PostgreSQL in Compose; RDS, managed backups, encryption,
  TLS configuration, and disaster recovery are not implemented.
- Access tokens cannot be revoked before expiry.
- Login rate limits use per-process memory and are not coordinated across
  multiple API instances.
- User provisioning is an operator CLI workflow; public registration and an
  administrative user-management API do not exist.
- Pagination, filtering, refresh tokens, and account recovery are not
  implemented.
