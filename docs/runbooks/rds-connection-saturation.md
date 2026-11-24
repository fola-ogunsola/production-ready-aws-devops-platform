# RDS Connection Saturation Runbook

## 1. Incident description

RDS `DatabaseConnections` approaches the explicitly configured capacity
threshold. Connection pressure may cause application timeouts even while the
database is otherwise available.

## 2. Detection signals and alarms

- `AWS/RDS` `DatabaseConnections`, statistic `Maximum`, dimension
  `DBInstanceIdentifier`.
- Default alarm threshold is environment-configured (80 for the example
  development `db.t4g.micro`, 160 for production `db.t4g.small`) and must be
  revalidated against the deployed engine's `max_connections`.
- Correlate `CPUUtilization`, `FreeableMemory`, application readiness, pool
  errors, and RDS events. The threshold is not a universal safe limit.

## 3. Possible causes

- Connection leak, excessive ECS task count or per-task pool size, slow
  queries, retry storm, or a client that failed to close connections.
- Increased workload or reduced database capacity.
- Reserved PostgreSQL connections and administrative headroom were not
  considered when selecting the threshold.

## 4. Investigation steps

1. Confirm RDS status and collect the exact `SHOW max_connections` value.
2. Compare active/idle/waiting sessions and application pool configuration.
3. Identify session age and application name; avoid collecting SQL literals or
   user data unless approved.
4. Correlate with ECS desired/running tasks and deployment changes.
5. Determine if connection count is growing, stable, or falling.

## 5. AWS CLI commands

**Read-only diagnostics**:

```sh
aws cloudwatch describe-alarms --region <REGION> \
  --alarm-names <ENVIRONMENT>-rds-connections-high
aws rds describe-db-instances --region <REGION> \
  --db-instance-identifier <DB_INSTANCE_IDENTIFIER>
aws rds describe-events --region <REGION> \
  --source-type db-instance --source-identifier <DB_INSTANCE_IDENTIFIER> \
  --duration 180
aws cloudwatch get-metric-statistics --region <REGION> \
  --namespace AWS/RDS --metric-name DatabaseConnections \
  --dimensions Name=DBInstanceIdentifier,Value=<DB_INSTANCE_IDENTIFIER> \
  --start-time <UTC_START_ISO8601> --end-time <UTC_END_ISO8601> \
  --period 300 --statistics Maximum Average
```

Use an approved PostgreSQL client/role for read-only SQL:

```sql
SHOW max_connections;
SELECT state, count(*) FROM pg_stat_activity GROUP BY state ORDER BY state;
```

Do not pass database passwords on a command line or store them in shell
history.

## 6. Application-log investigation

Search the ECS log group for database connection timeouts/errors and readiness
failures. Correlate `requestId` and timestamps. Do not log DSNs, SQL
credentials, access tokens, or query parameter values.

## 7. Safe mitigation steps

- **Read-only:** calculate the effective connection budget across tasks and
  pools; compare against `max_connections` minus reserved/admin headroom.
- **State-changing (approval required):** reduce application concurrency or
  pool size through a reviewed release, scale database capacity, or terminate
  a specifically identified runaway session only with database-owner
  approval. Avoid blanket termination and abrupt parameter-group changes.
- Confirm backup/recovery posture before database-class or parameter changes.

## 8. Recovery verification

Confirm connection count remains below the reviewed threshold with headroom,
new API requests succeed, readiness returns 200, and connection timeout
errors stop. Observe at least one full alarm window.

## 9. Escalation guidance

Escalate pool/leak symptoms to the application owner, instance capacity and
PostgreSQL tuning to the database owner, and task count/network issues to the
platform owner. Escalate immediately if connections block administrative
access or cause broad production errors.

## 10. Post-incident review checklist

- Record `max_connections`, configured threshold, and reserved headroom.
- Document pool size multiplied by maximum task count and observed sessions.
- Identify leak, retry, capacity, or query cause and assign follow-up owner.
- Recalculate the alarm threshold after any instance class or task-scaling
  change.
