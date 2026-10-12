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
- [x] Add `ec2:AssociateAddress` and `ec2:DisassociateAddress` to `terraform-network-policy`; `apply -var enable_nat=false` re-run and `aws ec2 describe-addresses` returns an empty list (EIP released)
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
- [x] `enable_nat = true` applied for the workspace (NAT `nat-052076b3fa0e2d29f`). Turn off at the end of each session with `terraform apply -var enable_nat=false`. **Current state (end of session 2026-10-10): NAT OFF after the validation run, `describe-addresses` empty (EIP released, verified)**; turn it on again with `-var enable_nat=true` before running any cluster

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
- [x] Cluster policies (`infra/modules/compute`): job policy + interactive policy (auto-termination 20 min, max 2 workers), `CAN_USE` for SP and user (README 3.7)
- [x] S3 data bucket `databricks-<env>-data-<account>` with `raw/creditcard/` and `export/gold/creditcard/` + UC role policy + external location written, plan 8 to add (branch `feature/data-bucket`)
- [x] Data bucket applied; both external locations visible in Catalog Explorer once the user became metastore admin / got visibility (objects are owned by the service principal, so other users see nothing until granted)
- [x] Upload `creditcard.csv` to `raw/creditcard/` (143 MiB, verified in S3)
- [x] **Test connection** on `databricks-homol-data-location`: all checks succeeded
- [x] Validation job `databricks-homol-validate-bronze` ran as the pipeline SP: 284807 rows / 492 frauds in `homol_catalog.bronze.creditcard_raw`, table visible in Unity Catalog (2026-10-10)
- [x] Document data bucket in README (3.6)
- [x] Terraform grants applied: user (`admin_user_email` in git-ignored tfvars) has ALL_PRIVILEGES; pipeline SP has least privilege (README 3.5.2)
- [x] Pipeline SP: `CAN_USE` on both policies, `CAN_MANAGE_RUN` on the job, `workspace_access` entitlement, `servicePrincipal.user` rule set
- [ ] Pipeline SP: OAuth secret for GitHub Actions (needed for CI/CD)

## Phase 7 - Prod environment
- [ ] Fill `infra/environments/prod/main.tf` (reuse modules, `environment = "prod"`, prod catalog)
- [ ] Per-environment tfvars; parameterize hardcoded `"homol"` and AWS profile
- [x] Decision: prod gets its own workspace, VPC/NAT and `prod_catalog` (same account, separate state); shared metastore. Apply prod only when CI/CD is ready (duplicates NAT cost)

## Phase 8 - CI/CD (GitHub Actions) - homol DONE, prod pending

Plan on PRs and apply on merge work end to end for homol (README 3.8 and 3.9). Prod workflows wait for the prod environment (Phase 7).
- [x] Design decided (2026-10-10, see CLAUDE.md): one OIDC provider per account, one role per environment (`github-actions-terraform-homol`, `-prod`), trust by `sub`; homol applies on merge with no approval, prod needs manual approval; plan on PRs never waits (`prod-plan` environment without reviewers)
- [x] Write stack `infra/ci-oidc` (OIDC provider + 2 roles with the deployer policies attached); applied by hand with an IAM admin identity (9 resources, 2026-10-11), documented in README 3.8
- [x] Parameterize the hardcoded AWS `profile` in `environments/homol/main.tf` (variable `aws_profile`, default null; removed from `backend.tf`, use `AWS_PROFILE` locally)
- [x] GitHub Environments created with `AWS_ROLE_ARN` variable and `TF_VAR_*` secrets (2026-10-11); `homol` verified end to end. Pending check: `prod-plan` and `prod` (reviewer, deployment branches) once prod is enabled
- [ ] Branch protection on `main`: require the `terraform-plan` check, no required review (solo repo cannot self-approve); may need a paid plan on private repos
- [x] Databricks credentials stored as environment secrets (`TF_VAR_databricks_*`, `TF_VAR_admin_user_email`)
- [ ] Rotate the `terraform-deployer` OAuth secret (it was pasted in a chat on 2026-10-11) in the account console and update `terraform.tfvars` and the GitHub secrets
- [x] `terraform-plan.yml` (PR, fmt/init/validate/plan, PR comment); prod entry of the matrix commented out until prod exists (PR #9)
- [x] `terraform-apply-homol.yml` (push to main + manual run with `enable_nat` input, concurrency group, environment homol); first run on merge: No changes (PR #11, 2026-10-12)
- [ ] Write `terraform-apply-prod.yml` (workflow_dispatch / release branch, environment prod) - empty
- [ ] Write `terraform-destroy-homol.yml` (workflow_dispatch, homol only) - empty
- [x] `terraform-plan.yml` validated on PR #9: OIDC assume, init on remote state, plan No changes, PR comment
- [x] `.github/` committed (plan and apply-homol); `apply-prod` and `destroy-homol` are still empty and untracked
- [ ] Commit `.terraform.lock.hcl` (currently git-ignored, so CI resolves the latest providers in range)
- [ ] Pipeline SP OAuth secret as a `homol` environment secret (needed by Project 2 bundle workflows)

## Phase 9 - Quality checklist (trial already active; not a blocker)
- [ ] All modules pass `terraform fmt` / `validate`
- [ ] `terraform plan` reviewed line by line
- [ ] Remote backend tested for both environments
- [ ] Workflows written and plan workflow validated
- [ ] Service principal and credentials organized
- [ ] AWS Budgets alert active

## Phase 10 - Trial execution (trial ACTIVE, 13 days left on 2026-10-08, expires about 2026-10-21)
- [x] Network + IAM applied, homol workspace created and accessible
- [x] Run `terraform-apply-homol.yml` end to end (merge of PR #11, plus a manual run toggling the NAT)
- [x] Catalogs/schemas in homol
- [x] Cluster policies and validation job (homol)
- [ ] Run Project 2 pipeline on the workspace, test homol -> prod promotion with manual approval
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
- [x] Merge PR for `feature/uc-grants` (grants + docs)
- [x] `feature/cluster-policies` merged (PR #7: compute module, ReplaceRoute doc, SP entitlement)
- [ ] Keep this file and README updated after each module
