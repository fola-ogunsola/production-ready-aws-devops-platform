# Database Unavailable Runbook

## 1. Incident description

The API cannot establish or maintain PostgreSQL connectivity, or RDS reports a
non-available state. ECS readiness depends on `SELECT 1`; liveness alone does
not prove database availability.

## 2. Detection signals and alarms

- `/health/live` failure indicates process/container trouble.
- `/health/ready` 503 indicates the API cannot confirm the database dependency.
- RDS instance state/events, ECS service events, database connection errors,
  and ALB `UnHealthyHostCount` provide complementary signals.
- RDS metrics may continue during some database failures; a missing metric is
  not a definitive availability alarm.

## 3. Possible causes

- RDS maintenance, failover, reboot, storage pressure, or engine issue.
- DNS/endpoint change, route/security-group error, TLS CA/configuration problem,
  credentials/secret rotation mismatch, or exhausted connections.
- Application pool startup failure or a database migration issue.

## 4. Investigation steps

1. Determine whether RDS is unavailable or only unreachable from the workload.
2. Inspect RDS events/status, ECS task events, secret ARN references, and
   security-group paths without exposing secret values.
3. Verify endpoint DNS and TCP reachability using an approved diagnostic
   workload in the same network; do not enable public access.
4. Confirm PostgreSQL TLS verification configuration and CA bundle version.
5. Check connection counts, storage, and failover/maintenance events.

## 5. AWS CLI commands

**Read-only diagnostics**:

```sh
aws rds describe-db-instances --region <REGION> \
  --db-instance-identifier <DB_INSTANCE_IDENTIFIER>
aws rds describe-events --region <REGION> \
  --source-type db-instance --source-identifier <DB_INSTANCE_IDENTIFIER> \
  --duration 180
aws ecs describe-services --region <REGION> --cluster <CLUSTER_NAME> \
  --services <SERVICE_NAME>
aws ecs describe-tasks --region <REGION> --cluster <CLUSTER_NAME> \
  --tasks <TASK_ARN>
aws secretsmanager describe-secret --region <REGION> \
  --secret-id <APPLICATION_SECRET_ARN>
aws ec2 describe-security-groups --region <REGION> \
  --group-ids <ECS_SECURITY_GROUP_ID> <RDS_SECURITY_GROUP_ID>
```

`describe-secret` returns metadata only. Never use `get-secret-value` in
shared terminal sessions or incident logs.

## 6. Application-log investigation

Search sanitized application logs for PostgreSQL connection errors, readiness
probes, TLS certificate errors, and `requestId`. Correlate with ECS task
start/stop time. Do not print connection strings, secret values, or
Authorization headers.

## 7. Safe mitigation steps

- **Read-only:** validate RDS state/events, DNS, network path, TLS, credentials
  metadata, and application pool behavior.
- **State-changing (approval required):** restore an approved security-group
  rule, rotate a credential using the approved secret process, or request an
  RDS failover/reboot only after database-owner review and impact assessment.
- Never make RDS publicly accessible or disable TLS verification as a
  workaround.

## 8. Recovery verification

From the authorized application network, verify DNS and an authenticated
TLS-verified database connection; confirm `/health/ready` returns 200, ECS
targets become healthy, and application errors stop. Validate failover or
credential changes against the approved change record.

## 9. Escalation guidance

Escalate RDS status, recovery, and data-integrity concerns to the database
owner. Escalate routing, security groups, task placement, and IAM to the
platform owner. Engage security for suspected credential exposure.

## 10. Post-incident review checklist

- Record RDS event timeline, API impact, failed dependency checks, and recovery.
- Verify whether the event was database, network, TLS, credential, or capacity
  related.
- Review backup/restore and failover readiness without performing recovery
  actions during the review.
- Create remediation tasks and update the status dashboard/runbook.
