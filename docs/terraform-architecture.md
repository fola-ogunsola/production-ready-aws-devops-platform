# Terraform Architecture

## Status and scope

This repository now contains reusable VPC and networking modules plus dev/prod
root wiring in `eu-west-1`. The modules implement DNS-enabled VPCs, public and
private subnets across multiple availability zones, internet and NAT gateways,
explicit route tables, private NAT routes, an S3 gateway endpoint, VPC flow
logs with a customer-managed encrypted CloudWatch destination, and restricted
default security groups.

The bootstrap and environment configurations have **not been applied**. No
AWS resources have been created and no live AWS credentials or plans are used
by local validation or mocked module tests. Workload security groups, ALB, and
ECR, ECS, IAM, RDS and externally populated Secrets Manager metadata are
implemented locally. Monitoring remains a subsequent implementation stage.

Do not run `terraform apply` or `terraform destroy` as part of validation.

## Directory structure

```text
terraform/
├── bootstrap/                 # Local-state configuration for remote-state bucket
│   ├── main.tf
│   ├── outputs.tf
│   ├── providers.tf
│   ├── variables.tf
│   ├── terraform.tfvars.example
│   ├── .terraform.lock.hcl
│   └── versions.tf
├── environments/
│   ├── dev/                   # Independent dev state and root configuration
│   │   ├── backend.tf
│   │   ├── main.tf
│   │   ├── outputs.tf
│   │   ├── providers.tf
│   │   ├── terraform.tfvars.example
│   │   ├── variables.tf
│   │   ├── versions.tf
│   │   └── .terraform.lock.hcl
│   └── prod/                  # Independent production state and root configuration
│       ├── backend.tf
│       ├── main.tf
│       ├── outputs.tf
│       ├── providers.tf
│       ├── terraform.tfvars.example
│       ├── variables.tf
│       ├── versions.tf
│       └── .terraform.lock.hcl
└── modules/
    ├── alb/
    ├── ecr/
    ├── ecs/
    ├── iam/
    ├── monitoring/
    ├── rds/
    ├── security/               # Implemented workload ALB/ECS/RDS groups
    ├── vpc/
    └── networking/
```

Environment folders are independent Terraform roots. The VPC module owns the
VPC, internet gateway, and tiered subnets. The networking module owns NAT
gateways and Elastic IPs, route tables and associations, and the S3 gateway
endpoint. Dev uses one NAT gateway to reduce idle cost; production defaults to
one NAT gateway per availability zone.

## Versions, providers, credentials, and account safeguards

All roots require Terraform `>= 1.10.0, < 2.0.0`, needed for native S3
lockfiles, and the official `hashicorp/aws` provider `~> 6.0`. Each root has a
generated `.terraform.lock.hcl`, currently selecting AWS provider `6.73.0`.
Use `terraform init -upgrade` only as a deliberate, reviewed provider update.

Authentication uses the normal AWS SDK credential chain: an AWS CLI profile,
environment-based short-lived credentials, IAM Identity Center, or an
assumed-role session. Configure `aws_profile` only when a named local profile
is needed. No account IDs or credentials are embedded in Terraform source.
`expected_account_id` is required in each local, ignored `terraform.tfvars`
file or as an input; the AWS provider's `allowed_account_ids` rejects
operations against a different account. Confirm the active identity with
`aws sts get-caller-identity` before any future plan or apply.

Provider `default_tags` applies `Project`, `Environment`, `ManagedBy`, and
`Repository` tags consistently. User-provided tags are merged, while reserved
identity tags remain authoritative. Do not store passwords, JWT signing keys,
or other application secrets in `.tf` or `.tfvars` files. Future secret
resources should receive values through an approved secret-management process
and must not expose secret values in outputs or plans.

## State backend and bootstrap

The bootstrap root has no remote backend block. Its state remains local so it
can create the S3 bucket that the dev/prod roots later use; this avoids the
circular dependency of needing the bucket to create the bucket. The generated
bucket name includes a sanitized project name, the caller's AWS account ID,
and region. Bootstrap configures:

- S3 Block Public Access and bucket-owner-enforced object ownership.
- S3 versioning for recovery from accidental state overwrite or deletion.
- Default SSE-S3 encryption (`AES256`).
- A bucket policy denying non-TLS requests.
- `prevent_destroy` and `force_destroy = false`.
- Cleanup of incomplete multipart uploads, without expiring state versions.

The bootstrap state file is initially stored locally and must be protected,
backed up, and retained by the operator. It does not contain application
credentials. Do not configure bootstrap to use the bucket it manages.

After review and explicit authorization to create backend infrastructure, the
operator can initialize and apply **only the bootstrap root**. No AWS bootstrap
plan or apply was run by this foundation task; validation initialization used
`-backend=false`:

```sh
cd terraform/bootstrap
cp terraform.tfvars.example terraform.tfvars
terraform init
terraform plan -out=bootstrap.tfplan
# Review identity, bucket name, tags, and the complete plan before any apply.
```

The copied `terraform.tfvars` is ignored by Git. Replace the empty
`expected_account_id` placeholder and set `aws_profile` if needed before
planning. Confirm the AWS identity first. The eventual apply is intentionally
not shown as an executed step.

Once the bucket exists and its output has been verified, initialize each
environment from its own directory, supplying only the bucket name as an
uncommitted backend setting:

```sh
cd terraform/environments/dev
terraform init -backend-config="bucket=<verified-bootstrap-output>"

cd ../prod
terraform init -backend-config="bucket=<verified-bootstrap-output>"
```

The checked-in backends already define distinct state keys,
`production-ready-aws-devops-platform/dev/terraform.tfstate` and
`production-ready-aws-devops-platform/prod/terraform.tfstate`, with
`use_lockfile = true`. The bucket name is deliberately absent from source
because it does not exist yet. Terraform S3 native locking uses a `.tflock`
object next to each state file; DynamoDB locking is not used.

The operator/CI role needs narrowly scoped S3 access to the relevant state key
and lock object: `s3:ListBucket` restricted by prefix, `s3:GetObject` and
`s3:PutObject` on the state object, and `s3:GetObject`, `s3:PutObject`, and
`s3:DeleteObject` on that environment's `.tflock` object. Bootstrap permissions
to create/configure the bucket should be separate from routine environment
permissions. Use IAM policy conditions for TLS and encryption where
appropriate, and do not grant broad account-wide S3 access.

### State recovery

Versioning permits recovery of a prior state object version, but state recovery
must be coordinated with the corresponding infrastructure and lock state.
Stop concurrent Terraform operations, identify the correct state version,
preserve a copy of the current object, then restore/re-upload only after review.
Do not manually delete a lock file while an operation may still be active.
Protect bucket deletion and version cleanup; state contains sensitive
infrastructure metadata even when application secrets are excluded.

## Dev/prod separation and tradeoffs

The environment roots have separate backend keys and environment-specific
defaults; resource names use `<project>-<environment>`. The dev example is
tagged for development cost attribution. The prod example carries a distinct
environment and cost-centre tag. Both default to `eu-west-1`, use the same
provider and tagging conventions, and can be configured independently.

The directory/foundation layer does not yet configure actual capacity,
Availability Zones, NAT, backups, scaling, or deletion protection for
application resources. The intended follow-on tradeoff is:

- **Dev:** minimize idle cost with reduced capacity and carefully chosen
  shared/single-AZ options where acceptable, while retaining private workloads,
  least-privilege access, encryption, and recoverable state.
- **Prod:** prioritize multi-AZ availability, isolated private workloads,
  stronger backup/restore objectives, health-based deployment, controlled
  scaling, and explicit deletion protection. This increases recurring cost
  and operational complexity.

These are design intentions, not deployed behavior or current Terraform
variables. Each should be made an explicit, reviewed module input when the
relevant module is implemented.

## Validation and code quality

Run formatting and validation without contacting AWS:

```sh
terraform fmt -recursive
terraform -chdir=terraform/bootstrap init -backend=false
terraform -chdir=terraform/bootstrap validate
terraform -chdir=terraform/environments/dev init -backend=false
terraform -chdir=terraform/environments/dev validate
terraform -chdir=terraform/environments/prod init -backend=false
terraform -chdir=terraform/environments/prod validate
```

Formatting and validation were verified with Terraform `1.10.5`. The host's
preinstalled Terraform `1.5.7` is below the declared minimum and cannot
initialize these roots. `init -backend=false` does not configure or access
remote state. Do not run
`plan` against the real backend as a substitute for validation until the
backend bucket and AWS account have been deliberately set up and verified.
Terraform `validate` checks syntax and internal consistency, not IAM access,
AWS quotas, or whether a future plan is safe.

## Proposed infrastructure sequence

1. Review and separately approve/apply the backend bootstrap; secure its local
   state and verify bucket settings.
2. Configure and verify dev/prod S3 backends and account guards.
3. Implement and review the VPC network module and its security-group
   boundaries, including CIDR, AZ/subnet layout, egress, and endpoint tradeoffs.
4. Add ECR, then RDS with private connectivity, encryption, backups, and
   carefully managed credentials.
5. Add ECS task/execution roles and Fargate service, then ALB and health-based
   routing; ensure only the ALB can reach the application port.
6. Add logging, metrics, alarms, scaling, deployment protections, and
   environment-specific operational controls.
7. Validate plans and security posture in dev before reviewing a production
   plan separately.

## VPC and networking implementation stage

Implemented and locally validated:

1. Reusable VPC inputs and outputs, CIDR validation, two-or-more-AZ subnet maps,
   DNS support, an internet gateway, and private/public subnet definitions.
2. Public/private route tables, public and private subnet associations,
   default-internet routing, configurable NAT egress, and per-AZ NAT production
   behavior.
3. An optional S3 gateway endpoint and stable subnet/route/NAT outputs.
4. VPC flow logs to an encrypted, retained CloudWatch log destination, an
   isolated delivery IAM role, and a customer-managed KMS key with rotation.
5. Terraform native mocked tests for VPC topology and both dev single-NAT and
   prod per-AZ NAT behavior.

Not yet validated in AWS:

- Live AZ availability and CIDR fit for the target account.
- NAT gateway billing, routing behavior, and reachability.
- S3 endpoint and private DNS behavior.
- CloudWatch Logs delivery and KMS key policy behavior.
- Real security-group-to-workload connectivity.

## Workload security-group stage

The reusable security module creates three independent security groups:

- `alb`: HTTPS 443 ingress from caller-approved CIDRs. TCP 80 may be enabled
  explicitly for HTTP-to-HTTPS redirection. Its only application egress is TCP
  3000 or the configured application port to the ECS security group.
- `ecs`: application ingress from the ALB security group only. It can reach RDS
  on TCP 5432 through the RDS security-group reference, resolve DNS within the
  VPC, and use TCP 443 for approved CIDR or prefix-list destinations.
- `rds`: PostgreSQL TCP 5432 ingress from the ECS security group only. It has
  no application CIDR ingress and no unrestricted outbound rules.

Rules use `aws_vpc_security_group_ingress_rule` and
`aws_vpc_security_group_egress_rule`; security-group bodies have empty
`ingress` and `egress` collections. This avoids circular dependencies because
the groups are created first and cross-references are attached by dedicated
rules. No SSH rule exists.

ECS service connectivity includes ECR API and Docker-registry access, Secrets
Manager, CloudWatch Logs and metrics, SSM, and ECS/Fargate control-plane
dependencies. The correct implementation depends on private subnet design:
interface VPC endpoints and an S3 gateway endpoint reduce internet exposure,
while a NAT gateway requires carefully controlled HTTPS egress. This stage
provides configurable HTTPS CIDRs and managed prefix-list IDs but does not
create the endpoints or claims that all AWS-service traffic has been tested.

Dev and prod use the same module and default ports. Dev can use one NAT
gateway and approved test CIDRs; production should use per-AZ NAT or VPC
endpoints and replace broad CIDRs with approved ranges before deployment.
Neither environment enables ALB HTTP ingress by default. No AWS workload
resources are created by this module.

Remaining limitations:

- ALB and ECS/RDS resources are not implemented.
- ALB approved-CIDR defaults can be widened when public internet ingress is
  intended; production should use an explicit allowlist.
- ECS HTTPS egress defaults to `0.0.0.0/0` unless a caller narrows it. This
  preserves NAT-based AWS connectivity but is not an implied AWS deployment.
- The module does not yet create VPC endpoints for ECR, Secrets Manager,
  CloudWatch, SSM, or ECS. It also does not validate live endpoint service names.

## Security scan findings

Checkov passed 50 checks and reported three CKV2_AWS_5 findings for the
security module: each new security group is not yet attached to a live ALB,
ECS service, or RDS instance. This is an expected stage-boundary limitation
because those resources intentionally have not been implemented or deployed.
The findings will be rechecked when the ALB, ECS, and RDS modules attach the
groups. They are not suppressed. Environment scans repeat the same findings
because they reuse the security module.

No public RDS CIDR rule or SSH rule is present. ECS and RDS inbound rules
use security-group references rather than public CIDRs. RDS has no outbound
application rules. The ALB public HTTPS and optional HTTP rules are CIDR-based
because internet ingress is their purpose. ECS HTTPS CIDRs are caller-
configurable and should be narrowed or replaced with interface/gateway VPC
endpoints before AWS deployment.

## ALB Checkov findings

The final ALB module scan found 4 remaining findings after SSE-S3 lifecycle,
ACL, multipart-abort, and deletion-protection controls were added:

- Event notifications are not enabled. This access-log bucket is not an
  application event bus; a separate notification/SIEM integration is a future
  operational decision.
- Server access logging is not enabled on the access-log bucket. Recursive
  bucket logging was not configured, and no central audit bucket destination
  has yet been approved.
- Cross-region replication is not enabled. Replication is a deployment-specific
  recovery requirement and should be implemented with a separately approved
  destination, KMS key, and cost model.
- A public ALB can remain without WAF unless `waf_web_acl_arn` is supplied.
  The module accepts an existing WAFv2 Web ACL ARN and avoids deploying or
  assuming an unspecified WAF policy.
- WAF policy coverage for an AMR/Log4j managed rule set is not asserted.
  Deployment should attach an independently reviewed WAFv2 Web ACL containing
  the account-approved rule set.
- Checkov CKV_AWS_145 is not satisfied with KMS encryption because current
  standard ALB access-log delivery explicitly requires SSE-S3. This finding is
  an encryption-method compatibility false positive, not a blanket suppression.

These findings are recorded rather than suppressed. Production should supply
both an approved WAFv2 Web ACL and access-log destination after AWS account
controls are reviewed.

## Application Load Balancer stage

The reusable ALB module creates:

- An Application Load Balancer in caller-selected public or internal subnets.
- An ECS IP-type target group using HTTP on the configured application port.
- A readiness health check at `/health/ready`, matching HTTP 200.
- Optional HTTPS TCP 443 listener forwarding to the target group.
- Optional HTTP TCP 80 listener that redirects to HTTPS with HTTP 301.
- Optional private S3 access-log storage, or an existing protected bucket ID.

The target group performs no static registration. ECS Fargate task IP addresses
will be dynamically registered during a later ECS service implementation.
Readiness is intentionally used instead of a liveness-only endpoint because
database availability affects whether the API can safely accept traffic.

Health defaults use a 30-second interval, 5-second timeout, two healthy
consecutive responses, three unhealthy responses, and a 30-second
deregistration delay. These values can be tuned, but the timeout must remain
shorter than the interval.

TLS is disabled by default. Enabling HTTPS requires a real existing ACM
certificate ARN; this repository does not create certificates or DNS records.
HTTP can be enabled only alongside HTTPS and never forwards directly to ECS.
The default TLS policy is `ELBSecurityPolicy-TLS13-1-2-2021-06`.

The ALB uses the existing ALB security-group output. It forwards application
traffic to ECS on TCP 3000, and ECS accepts that traffic only from the ALB
security group. ECS remains in private subnets and has no public CIDR ingress.
RDS accepts PostgreSQL traffic only from the ECS security group.

Development defaults to an internet-facing ALB, no deletion protection, no
access logs, and no public listeners. Production defaults to an internet-facing
multi-AZ ALB, deletion protection enabled, no access logs until an approved
bucket is supplied, and no listener until a genuine ACM certificate is configured.
Both environments provide public subnet placement and the existing approved
client-CIDR allowlist for future security controls.

Deployment prerequisites include:

1. Create or import a valid ACM certificate for the intended hostname.
2. Set `alb_acm_certificate_arn` and enable the HTTPS listener.
3. Optionally enable HTTP for HTTP-301-to-HTTPS behavior.
4. Supply a protected S3 bucket ID or allow the module to create one.
5. Create DNS records outside this module once the deployed ALB DNS name exists.

These resources are Terraform configuration only. They have not been planned
against AWS, created, or verified with live routing or TLS behavior.

The module supports associating an existing WAFv2 Web ACL through
`waf_web_acl_arn`; neither environment supplies an ARN until WAF is separately
designed and deployed. Access-log buckets use SSE-S3 encryption, bucket-owner
enforced ACLs, versioning, public-access blocks, lifecycle expiration after 365
days, and abort incomplete multipart uploads after seven days. Standard ALB
access-log delivery supports SSE-S3 rather than SSE-KMS. The bucket policy grants
the `logdelivery.elasticloadbalancing.amazonaws.com` service principal access
to the account-specific `AWSLogs/<account-id>/*` object path.

## Amazon ECR stage

The reusable ECR module creates a private repository for the
`production-ready-aws-devops-platform-api` application. Repository names default
to environment-specific values in dev and prod. Tags are immutable by default;
images are identified by Git commit SHA tags such as `sha-<40-character-commit>`
and optional release tags such as `prod-<sha>` or `rollback-<sha>`.

Repository encryption defaults to AWS-managed AES256. A caller may instead use
KMS or KMS_DSSE with an account-specific existing key ARN. Basic ECR
scan-on-push is enabled by default and is part of repository configuration.
Enhanced Amazon Inspector scanning is separate, registry-aware, and not enabled
by this module because it can affect other repositories and incur charges.

The lifecycle policy is configured per repository and retains:

- `prod-*` production release images
- `rollback-*` rollback release images
- `sha-*` immutable commit images
- A small number of untagged manifests

Development retains 10 production, 5 rollback, and 20 SHA images. Production
retains 30 production, 10 rollback, and 50 SHA images. The policy does not expire
arbitrary deployed tags and does not remove the currently deployed digest unless
ECS/IAM deployment automation is separately configured to protect it.

No public repository policy is created. `force_delete` defaults to false.
Future push automation requires `ecr:GetAuthorizationToken`,
`ecr:BatchCheckLayerAvailability`, `ecr:CompleteLayerUpload`,
`ecr:InitiateLayerUpload`, `ecr:PutImage`, and `ecr:UploadLayerPart` on the
environment repository. ECS task-execution roles require authorization and image
pull permissions, typically `ecr:GetAuthorizationToken`,
`ecr:BatchCheckLayerAvailability`, `ecr:GetDownloadUrlForLayer`, and
`ecr:BatchGetImage`.

ECS Checkov findings:

- CKV_AWS_338 reports that development log retention is shorter than one year.
  The 30-day development default is intentionally cost-conscious and production
  uses 365 days; retention remains caller-configurable.
- CKV_AWS_65 reports that development Container Insights is disabled. The
  development default avoids monitoring overhead and cost, while production
  enables Container Insights.
- Secret scanning previously reported synthetic test ARN text as entropy. The
  test fixtures were replaced with clearly marked placeholder ARNs and contain
  no credentials.

Checkov reports CKV_AWS_136 for the default AES256 ECR encryption. AWS-managed
AES256 ECR encryption is valid and is kept as the default because no customer
key material or key-ARN is required. The module supports KMS and KMS_DSSE for
callers that need customer-managed key policy or compliance controls. This
finding is recorded, not suppressed.

## ECS Fargate and IAM stage

The ECS module creates an ECS cluster and an environment-specific application
log group locally. It models task definitions and Fargate services only when
explicit deployment prerequisites exist.

Task definitions use `awsvpc`, Linux/X86_64, UID/GID 65532, port 3000,
`NODE_ENV=production`, a read-only root filesystem, ECS structured logging,
and `/health/live` container health checks. The ALB continues to use
`/health/ready`, which verifies PostgreSQL availability.

The ECS service:

- Uses private subnets
- Disables public IP assignment
- Attaches the existing ECS security group
- Registers dynamically with the existing IP target group
- Uses deployment circuit-breaker rollback
- Requires the existing HTTPS listener ARN before creation

The IAM module separates ECS task-execution and application task roles.
Execution-role permissions are limited to the selected ECR repository,
matching CloudWatch log stream ARN, explicit Secrets Manager ARNs, and explicit
KMS key ARNs. The application task role has ECS task trust and no AWS
administrator or blanket application permissions.

Secret values are not represented in module variables or plain environment
values. ECS task-definition secret references require existing secret ARNs.
Database host, name and user remain non-secret task environment values; RDS
and Secrets Manager resources are not created in this stage.

## Safe teardown

There are no infrastructure resources to tear down from this foundation.
Future environments should be destroyed only through an explicitly reviewed
Terraform plan in the correct account, region, and environment. Back up
application data and state first, and preserve the backend bucket until all
dependent states are intentionally retired. `prevent_destroy` on the state
bucket is a deliberate guard; removing it or deleting state versions requires
separate review and recovery planning. Never use `terraform destroy` as a
cleanup shortcut.
