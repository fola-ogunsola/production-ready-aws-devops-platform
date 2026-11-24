# Amazon ECR Architecture

## Repository design

The Terraform ECR module creates one private repository per environment. The
module is reusable and supports:

- Configurable repository names
- Immutable tags by default
- AWS-managed AES256 encryption
- Optional KMS or KMS_DSSE encryption with a caller-provided key ARN
- Basic ECR scan-on-push
- Configurable lifecycle retention
- Explicitly disabled forced deletion

The repository is private because no public repository or public repository
policy is created. Repository names avoid account IDs and are generated as
environment-specific names in the environment roots.

## Image tagging and releases

The application image is
`production-ready-aws-devops-platform-api`.

Future ECS deployments should use:

- `sha-<git-commit-sha>` for immutable, traceable releases
- `prod-<git-commit-sha>` for the promoted production image
- `rollback-<git-commit-sha>` for an explicitly retained rollback image

Production should reference an immutable tag or, preferably, a repository
digest. Mutable `latest` tags must not be used for ECS task definitions.

## Vulnerability scanning

Basic ECR scan-on-push is repository-scoped and can be enabled or disabled in
the module. It is implemented with
`aws_ecr_repository.image_scanning_configuration.scan_on_push`.

Enhanced scanning through Amazon Inspector is registry- or organization-wide
and can affect repositories outside this project. It is not enabled by the
Terraform module, and no enhanced scanning configuration or chargeable service
is created. Enhanced scanning and ECR scan findings require separate AWS
authorization and are not claimed in this repository.

Local Docker scanning remains separate. It may use Docker Scout or another
approved scanner against the locally built image; AWS ECR scanning does not
replace software dependency and container supply-chain controls.

## Encryption

AES256 is the default and requires no customer-managed KMS key. Callers that
require a customer-managed key can select `KMS` or `KMS_DSSE` and provide an
existing key ARN. The module validates that KMS selections receive a key.

## Lifecycle and rollback

The lifecycle policy retains images according to tag prefix:

- `prod-*`: 30 images in production, 10 in development
- `rollback-*`: 10 images in production, 5 in development
- `sha-*`: 50 images in production, 20 in development
- Untagged manifests: 2 in both environments

Older images beyond these counts are expired. The policy should not be changed
to broad `any`/older-than rules when deployed ECS task definitions may refer to
previously used tags or digests. ECS and rollback automation should retain a
tested image even if lifecycle counts change.

## GitHub Actions image push IAM

A future GitHub Actions OIDC role should receive repository-specific push
permissions rather than account-wide ECR permissions:

- `ecr:GetAuthorizationToken` for registry authentication
- `ecr:BatchCheckLayerAvailability`
- `ecr:CompleteLayerUpload`
- `ecr:InitiateLayerUpload`
- `ecr:PutImage`
- `ecr:UploadLayerPart`

The authorization token action has registry scope; image-layer actions should
be scoped to the environment repository ARN.

The role should also be federated by exact GitHub organization, repository,
branch or environment, and OIDC subject conditions. Long-lived AWS access keys
must not be stored in GitHub secrets.

## ECS image pull IAM

The ECS task-execution role requires:

- `ecr:GetAuthorizationToken`
- `ecr:BatchCheckLayerAvailability`
- `ecr:GetDownloadUrlForLayer`
- `ecr:BatchGetImage`

Repository resources should be scoped to the selected environment repository.
The role should not receive image push or lifecycle-policy permissions.

## Future build and publishing procedure

The future deployment procedure should build for Linux/AMD64 because ECS
Fargate is not guaranteed to execute ARM64 images:

```sh
docker build --platform linux/amd64 -t production-ready-aws-devops-platform-api:<git-sha> app
docker tag production-ready-aws-devops-platform-api:<git-sha> <ecr-url>:sha-<git-sha>
docker push <ecr-url>:sha-<git-sha>
```

Promotion should add or move an environment-specific tag only after validation:

```sh
docker pull <ecr-url>:sha-<git-sha>
docker tag <ecr-url>:sha-<git-sha> <ecr-url>:prod-<git-sha>
docker push <ecr-url>:prod-<git-sha>
```

The ECS task definition should reference the immutable digest or SHA tag,
not `latest`.

## Cost considerations

ECR storage, lifecycle count, and cross-region replication choices affect
recurring cost. Basic scanning behavior should be reviewed against account
policy and image push volume. Enhanced scanning and continuous scanning may
incur Amazon Inspector charges and are intentionally disabled.

Lifecycle retention increases storage and recovery capacity. Lower development
counts reduce cost; production counts preserve more rollback candidates.

## Security scanner findings

Checkov reports CKV_AWS_136 when the repository uses AWS-managed AES256
encryption. AWS-managed AES256 is an AWS-supported ECR encryption mode and is
the zero-key-management default for this module. KMS and KMS_DSSE are available
for deployments that require customer-managed keys. The finding is documented
rather than hidden or suppressed.

## Remaining prerequisites

- Create the AWS repositories through an explicitly reviewed apply.
- Configure repository authentication and IAM trust through OIDC.
- Validate basic scan findings on real images.
- Decide whether enhanced Inspector scanning is needed.
- Add ECS task-execution and image-pull permissions.
- Add CI build, AMD64 packaging, SHA tagging, push, and promotion workflows.
- Test digest and rollback deployment behavior in AWS.
