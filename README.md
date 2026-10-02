# databricks-aws-terraform-lab

Hands-on lab provisioning a Databricks workspace on AWS using Terraform, with CI/CD via GitHub Actions. Built to practice production-grade MLOps/data-platform requirements: Databricks on AWS, Delta Lake, Unity Catalog, and infrastructure as code with homologation/production environments.

## Project structure

```
infra/
  bootstrap/           # creates the S3 bucket for remote state — local state, applied once by hand
  modules/
    network/           # VPC, subnets, security groups
    iam-databricks/    # cross-account role, root bucket, Unity Catalog bucket/role
    workspace/         # Databricks workspace resources
    unity-catalog/     # metastore, catalogs, schemas, grants
  environments/
    homol/
    prod/
.github/
  workflows/
```

## 1. AWS IAM setup

This project uses a two-identity pattern: a low-privilege IAM user that can only assume a role, and a role that holds the actual permissions. The user never has direct access to AWS resources.

### 1.1 Create the IAM user

**User:** `terraform-cli-user`
No console access, no permissions attached directly — this user only gets the ability to assume a role (step 1.4).

### 1.2 Create the permissions policy (attached to the role, not the user)

**Policy:** `terraform-bootstrap-s3-policy`

> Note: the action list below includes the read (`Get*`) actions required for the Terraform AWS provider to confirm resource state after creation. Missing any of these causes the provider to mark the resource as `tainted` after a partial failure.

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "TerraformBootstrapS3",
      "Effect": "Allow",
      "Action": [
        "s3:CreateBucket",
        "s3:PutBucketVersioning",
        "s3:PutBucketPublicAccessBlock",
        "s3:GetBucketPublicAccessBlock",
        "s3:PutEncryptionConfiguration",
        "s3:GetBucketLocation",
        "s3:GetBucketVersioning",
        "s3:GetBucketPolicy",
        "s3:GetBucketAcl",
        "s3:GetBucketCors",
        "s3:GetBucketWebsite",
        "s3:GetBucketLogging",
        "s3:GetBucketObjectLockConfiguration",
        "s3:GetBucketRequestPayment",
        "s3:GetBucketTagging",
        "s3:GetAccelerateConfiguration",
        "s3:GetLifecycleConfiguration",
        "s3:GetReplicationConfiguration",
        "s3:GetEncryptionConfiguration",
        "s3:ListBucket",
        "s3:PutObject",
        "s3:GetObject",
        "s3:DeleteObject"
      ],
      "Resource": [
        "arn:aws:s3:::terraform-state-*",
        "arn:aws:s3:::terraform-state-*/*"
      ]
    }
  ]
}
```

### 1.3 Create the role, with a custom trust policy

**Role:** `terraform-deployer-role`

Trust policy (custom trust policy — requires `terraform-cli-user` to already exist):

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::{your-account-number}:user/terraform-cli-user"
      },
      "Action": "sts:AssumeRole",
      "Condition": {}
    }
  ]
}
```

Attach the permissions policy from step 1.2 (`terraform-bootstrap-s3-policy`) to this role.

### 1.4 Create the assume-role policy (attached to the user)

**Policy:** `assume-terraform-deployer-role-via-policy`

> Created after the role, since it references the role's ARN.

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "sts:AssumeRole",
      "Resource": "arn:aws:iam::{your-account-number}:role/terraform-deployer-role"
    }
  ]
}
```

Attach this policy to `terraform-cli-user`.

### 1.5 Generate an access key

On `terraform-cli-user` → Security credentials → Create access key → Command Line Interface (CLI). Save the Access Key ID and Secret Access Key immediately — the secret is shown only once.

**Final structure:**
```
terraform-cli-user (user)
  └─ attached: assume-terraform-deployer-role-via-policy

terraform-deployer-role (role)
  ├─ trust policy → trusts terraform-cli-user
  └─ attached: terraform-bootstrap-s3-policy
```

## 2. Configure and test the local connection

### 2.1 Configure the base profile (real identity)

```bash
aws configure --profile terraform-cli-user
```

### 2.2 Add the assume-role profile

```bash
cat >> ~/.aws/config << 'EOF'

[profile terraform-deployer]
role_arn = arn:aws:iam::{your-account-number}:role/terraform-deployer-role
source_profile = terraform-cli-user
region = us-east-1
EOF
```

```bash
aws configure list-profiles
```

### 2.3 Test Layer 1 — base user identity

```bash
aws sts get-caller-identity --profile terraform-cli-user
```

Expected output:

```json
{
    "UserId": "AIDA4YJLUZ326HXKMXARG",
    "Account": "{your-account-number}",
    "Arn": "arn:aws:iam::{your-account-number}:user/terraform-cli-user"
}
```

### 2.4 Test Layer 2 — assumed role

```bash
aws sts get-caller-identity --profile terraform-deployer
```

Expected output:

```json
{
    "UserId": "AROA4YJLUZ32VHM7BJUHV:botocore-session-...",
    "Account": "{your-account-number}",
    "Arn": "arn:aws:sts::{your-account-number}:assumed-role/terraform-deployer-role/botocore-session-..."
}
```

The `assumed-role/...` ARN confirms the trust policy and assume-role policy are working together correctly.

## 3. Execution

### 3.1 Bootstrap — create the remote state bucket (run once, by hand)

The state bucket can't be managed by the backend that will use it (chicken-and-egg problem). `infra/bootstrap` uses **local state** and is applied manually, a single time.

```bash
cd infra/bootstrap
terraform init
terraform plan
terraform apply
```

```bash
terraform output
```

Should return `bucket_name` and `bucket_arn`. From this point on, `infra/environments/homol` and `infra/environments/prod` use this bucket as their remote backend — `infra/bootstrap` is never re-applied.

## Troubleshooting notes

- **Resource marked as `tainted`:** happens when a create/update call is partially accepted by AWS but Terraform can't confirm the final state (often a missing `Get*` IAM permission right after a `Put*`/`Create*` call). Fix the underlying permission, confirm the resource is correct outside Terraform (console or `aws s3api ...`), then run `terraform untaint <resource>` — never force a destroy/recreate on a resource you haven't verified.
- Managed policy searches in the IAM console (e.g. searching `sts:AssumeRole` or `CreateBucket`) only match **predefined policy names**, not individual actions. Use **Create inline policy → JSON**, or create a standalone managed policy via JSON, to grant a specific action.