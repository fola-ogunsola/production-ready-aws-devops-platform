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
by local validation or mocked module tests. Security groups for application
workloads, ALB, ECR, ECS, RDS, IAM application roles, Secrets Manager, and
monitoring remain subsequent implementation stages.

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
    ├── security/
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

The next implementation stage will add the workload security-group module and
its callers before proceeding to ALB, ECS, RDS, ECR, IAM, Secrets Manager, or
monitoring resources.

## Safe teardown

There are no infrastructure resources to tear down from this foundation.
Future environments should be destroyed only through an explicitly reviewed
Terraform plan in the correct account, region, and environment. Back up
application data and state first, and preserve the backend bucket until all
dependent states are intentionally retired. `prevent_destroy` on the state
bucket is a deliberate guard; removing it or deleting state versions requires
separate review and recovery planning. Never use `terraform destroy` as a
cleanup shortcut.
