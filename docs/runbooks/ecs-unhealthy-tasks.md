# ECS Unhealthy Tasks Runbook

## 1. Incident description

Tasks are stopping, failing container checks, failing ALB readiness checks, or
the service has fewer running tasks than intended. This can cause reduced or
zero capacity.

## 2. Detection signals and alarms

- `AWS/ECS` CPU/memory, service events, desired/running task count.
- `ECS/ContainerInsights` `RunningTaskCount` only when Container Insights is
  enabled and the ECS service is actually deployed.
- `AWS/ApplicationELB` `UnHealthyHostCount` for the target group.
- `/health/live` is the container liveness check; `/health/ready` checks
  PostgreSQL readiness. A readiness failure removes an ALB target from service.
- Missing metrics are not treated as breaching; verify deployment and metric
  availability first.

## 3. Possible causes

- Invalid or incompatible image, failed startup, missing configuration or
  secret reference, or failed database connectivity.
- ECS/container health-check failures, memory pressure, or task exit.
- ALB security-group, listener, target registration, or health-check mismatch.
- Deployment circuit breaker rollback, subnet/IP exhaustion, or insufficient
  Fargate capacity.

## 4. Investigation steps

1. Check ECS service events and recent deployments.
2. Compare desired, pending, and running task counts.
3. Inspect stopped-task reason and container exit code; keep credentials out of
   notes and logs.
4. Check ALB target health reason codes and readiness responses.
5. Inspect application startup and database connectivity errors around the
   task start time.
6. Confirm the selected image reference is an approved immutable digest/tag.

## 5. AWS CLI commands

**Read-only diagnostics**:

```sh
aws ecs describe-services --region <REGION> --cluster <CLUSTER_NAME> \
  --services <SERVICE_NAME>
aws ecs list-tasks --region <REGION> --cluster <CLUSTER_NAME> \
  --service-name <SERVICE_NAME> --desired-status STOPPED
aws elbv2 describe-target-health --region <REGION> \
  --target-group-arn <TARGET_GROUP_ARN>
aws logs describe-log-streams --region <REGION> \
  --log-group-name <ECS_LOG_GROUP> --order-by LastEventTime --descending --limit 20
aws ecs describe-services --region <REGION> --cluster <CLUSTER_NAME> \
  --services <SERVICE_NAME> --query 'services[0].events[:20]'
```

For a stopped task, obtain its task ARN from `list-tasks`, then run:

```sh
aws ecs describe-tasks --region <REGION> --cluster <CLUSTER_NAME> \
  --tasks <TASK_ARN>
```

## 6. Application-log investigation

Inspect startup, migration, and readiness records in the ECS log group. Search
for Pino `level >= 50`, request ID, error type, and message. Do not copy secret
values or full environment dumps into incident tickets.

## 7. Safe mitigation steps

- **Read-only:** compare the active task definition and image digest, service
  events, ALB health reason, secret ARNs, and RDS status.
- **State-changing (approval required):** roll back to the last known-good
  immutable task definition or adjust desired count after capacity and cost
  review. The ECS circuit breaker is configured to roll back failed
  deployments automatically; verify whether it already did so.
- Do not enable ECS Exec; it is disabled in this service design.

## 8. Recovery verification

Confirm desired and running counts match, tasks pass container checks, ALB
targets are healthy, `/health/ready` returns 200 from the service network, and
the deployment is stable without new service events.

## 9. Escalation guidance

Escalate database symptoms to the database owner, task-definition/image
failures to application owners, and subnet, IAM, or Fargate capacity issues to
the platform owner. Escalate immediately if all production targets are
unhealthy.

## 10. Post-incident review checklist

- Record stopped-task reasons, deployment revision, and target-health reason.
- Capture relevant metrics and sanitized logs.
- Determine whether the failure was a release, configuration, dependency, or
  capacity issue.
- Assign corrective actions and evaluate circuit-breaker and readiness
  behavior.
