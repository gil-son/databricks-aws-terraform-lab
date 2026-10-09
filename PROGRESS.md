# PROGRESS.md

Step-by-step plan for `databricks-aws-terraform-lab` (Project 1). Legend: `[x]` done, `[ ]` pending.

## Phase 0 - AWS access and local setup
- [x] Create IAM user `terraform-cli-user` (no direct permissions, access key for CLI)
- [x] Create `terraform-deployer-role` with trust policy for the user
- [x] Create and attach `assume-terraform-deployer-role-via-policy` to the user
- [x] Create `terraform-bootstrap-s3-policy` and `terraform-network-policy`, attach to the role
- [x] Configure AWS CLI profiles (`terraform-cli-user`, `terraform-deployer`) and test both identities
- [x] Create `terraform-iam-databricks-policy` and attach to the role
- [x] Create Databricks service principal `terraform-deployer` with Account admin and OAuth secret
- [ ] Add `ec2:AssociateAddress` and `ec2:DisassociateAddress` to `terraform-network-policy` (by hand, IAM admin) and re-run `apply -var enable_nat=false` to release the Elastic IP
- [ ] Configure AWS Budgets alert on the AWS account
- [x] Databricks 14-day trial activated early (platform requirements changed); pre-trial gate no longer blocking
- [x] Trial status: 13 days remaining as of 2026-10-08 (expires about 2026-10-21)

## Phase 1 - Bootstrap (remote state)
- [x] Write `infra/bootstrap` (S3 bucket, versioning, public access block, encryption)
- [x] Apply bootstrap once with local state; outputs `bucket_name` / `bucket_arn`
- [x] Configure remote backend in `infra/environments/homol/backend.tf`
- [x] State locking: S3 native lockfile (`use_lockfile = true`), no DynamoDB
- [ ] Configure `infra/environments/prod/backend.tf` (currently empty), key `prod/terraform.tfstate`

## Phase 2 - Network module
- [x] VPC, 2 private subnets in different AZs, route tables
- [x] `enable_nat` variable (NAT, IGW, EIP, public subnet)
- [x] Databricks security group rules validated against the customer-managed VPC docs
- [x] Module outputs (`vpc_id`, `private_subnet_ids`, `security_group_id`, `nat_enabled`)
- [x] Apply in homol with `enable_nat = false` and document (README 3.2)
- [ ] Optional: VPC endpoints (S3 gateway, STS/Kinesis interface) behind a flag
- [x] `enable_nat = true` applied for the workspace (NAT `nat-052076b3fa0e2d29f`). Turn off at the end of each session with `terraform apply -var enable_nat=false`. **Current state (end of session 2026-10-08): NAT gateway deleted, but `apply -var enable_nat=false` failed on `ec2:DisassociateAddress`; Elastic IP may still exist until the policy is fixed and the apply re-run**; turn it on again with `-var enable_nat=true` before running any cluster

## Phase 3 - IAM Databricks module
- [x] Cross-account role + policy (Databricks data sources, `customer` policy type)
- [x] Workspace root bucket (private, SSE-S3, bucket policy)
- [x] Unity Catalog bucket and role (self-assuming trust)
- [x] `databricks_mws_credentials` and module outputs
- [x] Wire provider and module into `environments/homol/main.tf`; credentials via git-ignored tfvars
- [x] Document setup, verification and common errors (README 3.3)
- [x] Verified in homol; `feature/iam-databricks` merged into `main` (PR #1)

## Phase 4 - Workspace module (`infra/modules/workspace`)
- [x] `databricks_mws_storage_configurations` (root bucket)
- [x] `databricks_mws_networks` (VPC, subnets, security group from the network module)
- [x] `databricks_mws_workspaces` (credentials + storage + network; region `us-east-1`)
- [x] Expose outputs (`workspace_id`, `workspace_url`)
- [x] Wire into `environments/homol` (`enable_nat` is now an env variable); plan reviewed (9 to add, 1 to change)
- [x] `terraform apply -var enable_nat=true` done (9 added, 1 changed); NAT was ON during the session and was turned off afterwards
- [x] Workspace login confirmed (user assigned as Admin in account console); URL https://dbc-405a719f-a0d8.cloud.databricks.com (id 7474658903342069)
- [x] Workspace-level auth: second `databricks` provider (alias `workspace`) with the same OAuth service principal
- [x] Document in README (3.4)

## Phase 5 - Unity Catalog module (`infra/modules/unity-catalog`)
- [x] Metastore: not created by us; Databricks auto-created and attached `metastore_aws_us_east_1` to the workspace
- [x] Storage credential + external location applied; validated OK with the existing UC role trust (no change needed)
- [x] Catalog `homol_catalog` + schemas `bronze`, `silver`, `gold` applied in homol (4 added); `prod_catalog` will be created by the prod environment (own workspace, own state)
- [x] Explicit grants: service principal `databricks-homol-pipeline` + `databricks_grants` for catalog, schemas and data location (`grants.tf`, applied in homol)
- [x] Document in README (3.5)

## Phase 6 - Data bucket, cluster policies and validation (IN PROGRESS)
- [ ] Cluster policies (module/location TBD): job clusters by default, auto-termination 15-20 min, capped size/autoscaling
- [x] S3 data bucket `databricks-<env>-data-<account>` with `raw/creditcard/` and `export/gold/creditcard/` + UC role policy + external location written, plan 8 to add (branch `feature/data-bucket`)
- [x] Data bucket applied; both external locations visible in Catalog Explorer once the user became metastore admin / got visibility (objects are owned by the service principal, so other users see nothing until granted)
- [ ] Upload `creditcard.csv` (already in the repo root, now git-ignored via `*.csv`) to `raw/creditcard/`
- [x] **Test connection** on `databricks-homol-data-location`: all checks succeeded
- [ ] Validation job: read `creditcard.csv` from `raw/`, write Delta `homol_catalog.bronze.creditcard_raw`, confirm in Unity Catalog
- [x] Document data bucket in README (3.6)
- [x] Terraform grants applied: user (`admin_user_email` in git-ignored tfvars) has ALL_PRIVILEGES; pipeline SP has least privilege (README 3.5.2)
- [ ] Pipeline SP: OAuth secret for GitHub Actions, cluster policy `CAN_USE`, job permissions

## Phase 7 - Prod environment
- [ ] Fill `infra/environments/prod/main.tf` (reuse modules, `environment = "prod"`, prod catalog)
- [ ] Per-environment tfvars; parameterize hardcoded `"homol"` and AWS profile
- [x] Decision: prod gets its own workspace, VPC/NAT and `prod_catalog` (same account, separate state); shared metastore. Apply prod only when CI/CD is ready (duplicates NAT cost)

## Phase 8 - CI/CD (GitHub Actions) - required; NEXT PRIORITY candidate

Workflow files exist but are empty (structure sanity check only). Trial clock is running; needed to simulate homol -> prod (one AWS account, one workspace per environment).
- [ ] Create GitHub OIDC provider and `github-actions-terraform` role in AWS (add permissions to the deployer policy)
- [ ] Configure GitHub Environments: `homol` (no approval), `prod` (required reviewers)
- [ ] Store Databricks credentials as environment secrets (`TF_VAR_databricks_*`)
- [ ] Write `terraform-plan.yml` (PR, matrix homol/prod, fmt/init/validate/plan, PR comment) - file exists but is empty
- [ ] Write `terraform-apply-homol.yml` (push to main, concurrency group, environment homol) - empty
- [ ] Write `terraform-apply-prod.yml` (workflow_dispatch / release branch, environment prod) - empty
- [ ] Write `terraform-destroy-homol.yml` (workflow_dispatch, homol only) - empty
- [ ] Validate `terraform-plan.yml` with test PRs
- [ ] Commit `.github/` (currently untracked)

## Phase 9 - Quality checklist (trial already active; not a blocker)
- [ ] All modules pass `terraform fmt` / `validate`
- [ ] `terraform plan` reviewed line by line
- [ ] Remote backend tested for both environments
- [ ] Workflows written and plan workflow validated
- [ ] Service principal and credentials organized
- [ ] AWS Budgets alert active

## Phase 10 - Trial execution (trial ACTIVE, 13 days left on 2026-10-08, expires about 2026-10-21)
- [x] Network + IAM applied, homol workspace created and accessible
- [ ] Run `terraform-apply-homol.yml` end to end
- [x] Catalogs/schemas in homol
- [ ] Cluster policies, validation job, run Project 2 pipeline on the workspace, test homol -> prod promotion with manual approval
- [ ] Day 10-12: apply prod with approval; optional streaming test (Project 2 phase 3); document architecture decisions (screenshots, notes)
- [ ] Day 13-14: `terraform destroy` (or move to paid account); verify NAT, endpoints, EC2 removed; review AWS and Databricks billing; consolidate docs into README/post

## Phase 11 - Integration with Project 2 (SageMaker)
- [ ] Expose workspace URL, catalog/schema names and S3 prefixes as outputs/docs for Project 2
- [ ] Add IAM role/policy for SageMaker access to `export/gold/creditcard/` (and training/endpoint permissions for OIDC role)
- [ ] Reuse OIDC and environment secrets for Project 2 workflows (`databricks-pipeline-*`, `sagemaker-train-deploy`, `sagemaker-teardown`)
- [ ] Run Project 2 end to end: Delta bronze/silver/gold -> MLflow -> Parquet export -> SageMaker training -> endpoint -> delete endpoint

## Housekeeping
- [x] Initial README with IAM setup, bootstrap, network, iam-databricks docs and troubleshooting
- [ ] Add Terraform-state and tfvars entries to `.gitignore` check (verify `terraform.tfvars` and `.terraform/` ignored)
- [x] workspace + unity-catalog modules merged (PRs #1-#4 incl. diagrams)
- [x] `feature/data-bucket` merged (PR #5)
- [ ] Merge PR for `feature/uc-grants` (grants + docs)
- [ ] Keep this file and README updated after each module
