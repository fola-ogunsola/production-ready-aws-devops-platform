# ECS High CPU Runbook

## 1. Incident description

The ECS service CPU alarm is above its environment threshold for the configured
number of periods. This signals sustained task CPU pressure; it does not by
itself establish user impact.

## 2. Detection signals and alarms

- Alarm: `<project>-<environment>-ecs-cpu-high`.
- Metric: `AWS/ECS` `CPUUtilization`, `Average`, dimensions `ClusterName` and
  `ServiceName`, normally 300-second periods and 2 of 2 datapoints.
- Threshold: 85% in development and 75% in production by default.
- Correlate with `MemoryUtilization`, `RunningTaskCount` when Container
  Insights is enabled, ALB target response time/5xx, and readiness failures.
- Missing metric data is treated as non-breaching. Confirm service deployment
  status before interpreting a gap.

## 3. Possible causes

- Traffic increase, a slow or expensive route, request bursts, or inefficient
  application code.
- Resource-heavy authentication/password hashing or repeated failed logins.
- CPU throttling due to task CPU sizing or an unexpected deployment.
- Downstream database latency causing request retries or work accumulation.

## 4. Investigation steps

1. Establish incident time, region, account, environment, and alarm state.
2. Compare CPU, task count, target response time, request count, and 5xx
   metrics over the same interval.
3. Check recent ECS deployments and service events; compare running and desired
   task counts.
4. Correlate request IDs and route/status/duration fields in application logs.
5. Check RDS connections, CPU, and storage before attributing pressure to the
   API.

## 5. AWS CLI commands

**Read-only diagnostics** (replace every `<PLACEHOLDER>`; use an authorized
read-only diagnostic role):

```sh
aws cloudwatch describe-alarms --region <REGION> \
  --alarm-names <ENVIRONMENT>-ecs-cpu-high
aws ecs describe-services --region <REGION> --cluster <CLUSTER_NAME> \
  --services <SERVICE_NAME>
aws ecs list-tasks --region <REGION> --cluster <CLUSTER_NAME> \
  --service-name <SERVICE_NAME> --desired-status RUNNING
aws cloudwatch get-metric-statistics --region <REGION> \
  --namespace AWS/ECS --metric-name CPUUtilization \
  --dimensions Name=ClusterName,Value=<CLUSTER_NAME> Name=ServiceName,Value=<SERVICE_NAME> \
  --start-time <UTC_START_ISO8601> --end-time <UTC_END_ISO8601> \
  --period 300 --statistics Average Maximum
```

## 6. Application-log investigation

Use the CloudWatch Logs Insights widget or query the configured ECS log group:

```text
fields @timestamp, requestId, req.method, req.path, res.statusCode, responseTime, msg
| filter @timestamp >= '<UTC_START>'
| sort responseTime desc
| limit 100
```

Avoid logging or copying request bodies, passwords, bearer tokens, or database
credentials. Follow `requestId` across related records.

## 7. Safe mitigation steps

- **Read-only:** verify service capacity, recent task failures, ALB health,
  database saturation, and the exact image revision.
- **State-changing (approval required; do not run as part of diagnosis):**
  change ECS desired count, update task CPU, or roll back to an approved
  immutable task definition. Confirm capacity, service limits, cost, and
  production change authorization first.
- Do not repeatedly restart tasks before preserving failure evidence.

## 8. Recovery verification

Confirm CPU falls below threshold for the full evaluation window, desired and
running task counts agree, ALB targets are healthy, readiness returns 200, and
latency/error rates return to baseline. Verify the resolution with a fresh
request and record the deployment revision.

## 9. Escalation guidance

Escalate to the application owner if one route dominates CPU; to the platform
owner for task capacity or deployment failures; and to the database owner if
RDS saturation correlates. Page the incident commander for sustained production
customer impact or exhaustion of service capacity.

## 10. Post-incident review checklist

- Record impact, timeline, triggering alarm, and recovery time.
- Preserve relevant metrics, deployment events, and redacted request IDs.
- Identify whether the threshold, task sizing, autoscaling, or test coverage
  needs revision.
- Track code, capacity, or operational follow-ups with an owner and due date.
