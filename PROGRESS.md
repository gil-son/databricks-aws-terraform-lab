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
- [ ] Configure AWS Budgets alert on the AWS account
- [x] Databricks 14-day trial activated early (platform requirements changed); pre-trial gate no longer blocking
- [ ] Record trial start date and expiry date here (ask user) and track days remaining

## Phase 1 - Bootstrap (remote state)
- [x] Write `infra/bootstrap` (S3 bucket, versioning, public access block, encryption)
- [x] Apply bootstrap once with local state; outputs `bucket_name` / `bucket_arn`
- [x] Configure remote backend in `infra/environments/homol/backend.tf`
- [ ] Decide on state locking (S3 native lockfile vs DynamoDB table) and apply it
- [ ] Configure `infra/environments/prod/backend.tf` (currently empty), key `prod/terraform.tfstate`

## Phase 2 - Network module
- [x] VPC, 2 private subnets in different AZs, route tables
- [x] `enable_nat` variable (NAT, IGW, EIP, public subnet)
- [x] Databricks security group rules validated against the customer-managed VPC docs
- [x] Module outputs (`vpc_id`, `private_subnet_ids`, `security_group_id`, `nat_enabled`)
- [x] Apply in homol with `enable_nat = false` and document (README 3.2)
- [ ] Optional: VPC endpoints (S3 gateway, STS/Kinesis interface) behind a flag
- [ ] Set `enable_nat = true` (planned soon; currently `false`) before workspace creation, and back to false/destroy after the session

## Phase 3 - IAM Databricks module
- [x] Cross-account role + policy (Databricks data sources, `customer` policy type)
- [x] Workspace root bucket (private, SSE-S3, bucket policy)
- [x] Unity Catalog bucket and role (self-assuming trust)
- [x] `databricks_mws_credentials` and module outputs
- [x] Wire provider and module into `environments/homol/main.tf`; credentials via git-ignored tfvars
- [x] Document setup, verification and common errors (README 3.3)
- [ ] Confirm `terraform apply` output and verification commands passed in homol, then merge `feature/iam-databricks` into `main`

## Phase 4 - Workspace module (`infra/modules/workspace`)
- [ ] `databricks_mws_storage_configurations` (root bucket)
- [ ] `databricks_mws_networks` (VPC, subnets, security group from the network module)
- [ ] `databricks_mws_workspaces` (credentials + storage + network; region `us-east-1`)
- [ ] Expose outputs (`workspace_id`, `workspace_url`, token/auth strategy for the workspace-level provider)
- [ ] Wire into `environments/homol`, `terraform validate` / `plan` review
- [ ] Document in README (3.4)

## Phase 5 - Unity Catalog module (`infra/modules/unity-catalog`)
- [ ] Metastore (one per account/region) and assignment to the workspace
- [ ] Storage credential (UC role) and external location; confirm self-assume trust works
- [ ] Catalogs `homol_catalog` and `prod_catalog`
- [ ] Schemas `bronze`, `silver`, `gold` per catalog
- [ ] Explicit grants (read/write per schema, groups or service principals)
- [ ] Workspace-level `databricks` provider alias in the environment
- [ ] Document in README (3.5)

## Phase 6 - Cluster policies and validation
- [ ] Cluster policies: job clusters by default, auto-termination 15-20 min, capped size/autoscaling
- [ ] S3 data bucket/prefixes for the integration: `raw/creditcard/`, `export/gold/creditcard/` (naming under `databricks-*` prefix or extend IAM policy)
- [ ] Validation job: read `creditcard.csv` from `raw/`, write Delta `homol_catalog.bronze.creditcard_raw`, confirm in Unity Catalog
- [ ] Document in README (3.6)

## Phase 7 - Prod environment
- [ ] Fill `infra/environments/prod/main.tf` (reuse modules, `environment = "prod"`, prod catalog)
- [ ] Per-environment tfvars; parameterize hardcoded `"homol"` and AWS profile
- [ ] Decide: separate workspace for prod vs only a separate catalog (brief assumes one catalog per env)

## Phase 8 - CI/CD (GitHub Actions) - required; scaffolded only

Workflow files were created empty as a sanity check of the structure; trial is already running, so write them in parallel with Phase 4-5.
- [ ] Create GitHub OIDC provider and `github-actions-terraform` role in AWS (add permissions to the deployer policy)
- [ ] Configure GitHub Environments: `homol` (no approval), `prod` (required reviewers)
- [ ] Store Databricks credentials as environment secrets (`TF_VAR_databricks_*`)
- [ ] Write `terraform-plan.yml` (PR, matrix homol/prod, fmt/init/validate/plan, PR comment) - file exists but is empty
- [ ] Write `terraform-apply-homol.yml` (push to main, concurrency group, environment homol) - empty
- [ ] Write `terraform-apply-prod.yml` (workflow_dispatch / release branch, environment prod) - empty
- [ ] Write `terraform-destroy-homol.yml` (workflow_dispatch, homol only) - empty
- [ ] Validate `terraform-plan.yml` with test PRs
- [ ] Commit `.github/` (currently untracked)

## Phase 9 - Pre-trial checklist (trial already active; treat as a quality checklist, not a blocker)
- [ ] All modules pass `terraform fmt` / `validate`
- [ ] `terraform plan` reviewed line by line
- [ ] Remote backend tested for both environments
- [ ] Workflows written and plan workflow validated
- [ ] Service principal and credentials organized
- [ ] AWS Budgets alert active

## Phase 10 - Trial execution (14 days from activation; trial is ACTIVE, day count unknown)
- [ ] Day 1-2: activate trial, apply network + IAM, create workspace, run `terraform-apply-homol.yml` end to end
- [ ] Day 3-9: metastore/catalogs/schemas, cluster policies, validation job, run Project 2 pipeline on the workspace, test homol -> prod promotion with manual approval
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
- [ ] Keep this file and README updated after each module
