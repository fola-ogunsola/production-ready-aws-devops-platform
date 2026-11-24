# RDS Low Storage Runbook

## 1. Incident description

RDS `FreeStorageSpace` is below the configured byte threshold or is declining
rapidly. This is a storage-capacity warning, not proof the database is
unavailable.

## 2. Detection signals and alarms

- `AWS/RDS` `FreeStorageSpace`, statistic `Minimum`, unit `Bytes`, dimension
  `DBInstanceIdentifier`.
- Example thresholds: 5 GiB development and 15 GiB production.
- Correlate with allocated/max storage, storage autoscaling events, write
  workload, and PostgreSQL log volume. Autoscaling has a configured maximum
  and may take time; do not rely on it as the only response.

## 3. Possible causes

- Data/index growth, large transactions, temporary files, WAL/log accumulation,
  unbounded audit data, or storage autoscaling reaching its cap.
- Unexpected batch/import workload or retention/cleanup failure.

## 4. Investigation steps

1. Check current free, allocated, and maximum allocated storage.
2. Review RDS events and storage growth trend over days, not only the current
   datapoint.
3. Identify large relations and retention policies using approved read-only
   database queries.
4. Check whether autoscaling is enabled and whether its configured maximum
   leaves sufficient forecast headroom.
5. Estimate time to exhaustion from recent growth and raise severity if
   exhaustion is imminent.

## 5. AWS CLI commands

**Read-only diagnostics**:

```sh
aws cloudwatch describe-alarms --region <REGION> \
  --alarm-names <ENVIRONMENT>-rds-free-storage-low
aws rds describe-db-instances --region <REGION> \
  --db-instance-identifier <DB_INSTANCE_IDENTIFIER> \
  --query 'DBInstances[0].[DBInstanceStatus,AllocatedStorage,MaxAllocatedStorage,StorageType,StorageEncrypted]'
aws rds describe-events --region <REGION> \
  --source-type db-instance --source-identifier <DB_INSTANCE_IDENTIFIER> \
  --duration 1440
aws cloudwatch get-metric-statistics --region <REGION> \
  --namespace AWS/RDS --metric-name FreeStorageSpace \
  --dimensions Name=DBInstanceIdentifier,Value=<DB_INSTANCE_IDENTIFIER> \
  --start-time <UTC_START_ISO8601> --end-time <UTC_END_ISO8601> \
  --period 3600 --statistics Minimum Average
```

Use an approved database role for read-only relation-size and retention
queries. Do not query or export row contents.

## 6. Application-log investigation

Look for PostgreSQL “no space”/write failures and migrations or batch tasks
around the growth period. Search sanitized error type/message and request IDs;
never include database credentials or application payloads.

## 7. Safe mitigation steps

- **Read-only:** calculate growth rate and time-to-cap; identify approved
  retention or temporary-file sources.
- **State-changing (approval required):** increase the RDS storage maximum or
  allocated storage through a reviewed change; pause a known batch workload;
  archive or purge data only under approved retention and backup procedures.
- Never delete production records, WAL, or logs ad hoc to clear an alarm.

## 8. Recovery verification

Verify free storage is above the threshold and stable, storage changes have
completed, database status is available, and the growth trend is understood.
Observe the next alarm period and confirm no application write errors.

## 9. Escalation guidance

Escalate to the database owner when projected time to storage exhaustion is
shorter than the change window, autoscaling approaches its maximum, or writes
fail. Involve data owners before retention or archival actions.

## 10. Post-incident review checklist

- Record free/allocated/max storage, growth rate, and estimated time to cap.
- Identify the growth source and whether autoscaling responded.
- Review retention, alert lead time, and storage headroom.
- Assign capacity or data-lifecycle actions with owners.
