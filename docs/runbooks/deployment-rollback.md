# ECS Deployment Rollback Runbook

## 1. Incident description

A new ECS task-definition revision or application image causes failed health
checks, elevated errors, task churn, or customer impact. The ECS deployment
circuit breaker is configured to roll back a failed deployment automatically.

## 2. Detection signals and alarms

- ECS service deployment state/events and task start/stop reasons.
- ALB unhealthy targets, target/ALB 5xx, response time, and application logs.
- ECS CPU/memory and RDS readiness/connection pressure.
- Confirm which immutable image and task-definition revision is actually
  serving traffic.

## 3. Possible causes

- Application regression, incompatible schema migration, invalid task
  configuration, inaccessible secret, or wrong image architecture.
- New task fails liveness/readiness or cannot connect to RDS.
- Resource sizing, IAM, subnet, or target-group configuration regression.

## 4. Investigation steps

1. Record deployment ID, start time, task-definition ARN, and image digest.
2. Check whether the circuit breaker has already restored the prior revision.
3. Compare task-definition revisions, container image, environment variable
   names, secret ARNs, health checks, and resource sizes.
4. Inspect target health, service events, stopped-task reasons, and sanitized
   application logs.
5. Consider schema compatibility and data migration safety before rollback.

## 5. AWS CLI commands

**Read-only diagnostics**:

```sh
aws ecs describe-services --region <REGION> --cluster <CLUSTER_NAME> \
  --services <SERVICE_NAME>
aws ecs list-task-definitions --region <REGION> \
  --family-prefix <TASK_FAMILY> --sort DESC
aws ecs describe-task-definition --region <REGION> \
  --task-definition <TASK_DEFINITION_ARN>
aws ecs describe-tasks --region <REGION> --cluster <CLUSTER_NAME> \
  --tasks <TASK_ARN>
aws elbv2 describe-target-health --region <REGION> \
  --target-group-arn <TARGET_GROUP_ARN>
```

Review returned task definitions for secret references and image digests;
never copy secret values into tickets.

## 6. Application-log investigation

Use request IDs and the time window to compare error rates and routes before
and after deployment. Search `res.statusCode`, `responseTime`, safe error
type/message, startup, and readiness logs. Exclude credentials and payloads.

## 7. Safe mitigation steps

- **Read-only:** verify rollback candidate, schema compatibility, image
  digest, and whether automatic rollback completed.
- **State-changing (approval required; do not run during investigation):**
  update the ECS service to a reviewed prior task-definition ARN. This example
  changes infrastructure and must only be executed by an authorized operator
  under the incident/change process:

```sh
aws ecs update-service --region <REGION> --cluster <CLUSTER_NAME> \
  --service <SERVICE_NAME> --task-definition <APPROVED_PREVIOUS_TASK_DEFINITION_ARN>
```

- Do not deploy a mutable `latest` tag. Do not roll back across an
  incompatible database migration without a reviewed recovery plan.

## 8. Recovery verification

Confirm the intended revision is stable, running tasks match desired count,
targets are healthy, error/latency metrics return to baseline, readiness
returns 200, and no new service events indicate rollback failure. Monitor for
at least one full alarm window.

## 9. Escalation guidance

The incident commander authorizes production rollback; application and
database owners assess code/schema compatibility; platform owners execute
approved ECS changes. Escalate immediately when the automatic circuit breaker
does not restore service.

## 10. Post-incident review checklist

- Record deployment and rollback revisions, image digests, and timeline.
- Assess customer impact and whether the circuit breaker behaved as designed.
- Review migration expand/contract compatibility and release validation.
- Assign code, test, deployment, or operational improvements.
