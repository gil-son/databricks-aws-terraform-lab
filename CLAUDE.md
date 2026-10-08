# CLAUDE.md

Context for future sessions. Read this first; no need to re-read the original project briefs.
Track status in `PROGRESS.md`. Detailed setup/troubleshooting docs live in `README.md`.

## What this repo is

**Project 1** of two linked projects: `databricks-aws-terraform-lab` provisions the **platform** (Databricks workspace on AWS, Unity Catalog, cluster policies) with modular Terraform and promotes it across `homol` -> `prod` via GitHub Actions. No model code here.

**Project 2** (separate repo/briefing: `../projeto-2-databricks-sagemaker.md`) runs **on top of** this platform: Spark -> Delta Lake -> MLflow -> Parquet export to S3 -> SageMaker training/endpoint. Original briefs (Portuguese) are in the parent directory: `../projeto-1-databricks-terraform-cicd.md`, `../projeto-2-databricks-sagemaker.md`.

The purpose is job-interview/portfolio practice: Databricks in production, AWS architecture, Delta Lake + Unity Catalog, CI/CD, IaC.

## Integration contract with Project 2 (what this repo must provide)

- Working Databricks workspace per environment, Unity Catalog metastore (one per account).
- One catalog per environment: `homol_catalog`, `prod_catalog`; schemas `bronze` (`creditcard_raw`), `silver` (`creditcard_clean`), `gold` (`creditcard_features`), with explicit grants.
- S3 layout (in a data bucket governed by this repo): `raw/creditcard/` (input CSV), `export/gold/creditcard/` (Parquet export consumed by SageMaker). SageMaker must read the export prefix, never Delta directly (would bypass Unity Catalog permissions).
- Cluster policies: job clusters by default, short auto-termination (15-20 min) for interactive, capped size.
- GitHub OIDC role + GitHub Environments (`homol` no approval, `prod` required reviewers). Project 2 workflows (`databricks-pipeline-*`, `sagemaker-*`) will reuse OIDC and Databricks secrets; plan for SageMaker permissions (S3 export prefix, training, endpoint) in a separate role/policy.
- Dataset: Credit Card Fraud Detection (ULB/Worldline), ~284,807 rows, 492 frauds (0.17%); metrics are AUPRC/recall/precision, not accuracy.

## Repo layout

```
infra/
  bootstrap/            S3 state bucket, local state, applied once by hand (DONE)
  modules/
    network/            VPC, private subnets, SG; var enable_nat (DONE)
    iam-databricks/     cross-account role, root bucket, UC bucket/role, mws_credentials (DONE)
    workspace/          mws_storage_configurations, mws_networks, mws_workspaces (TODO, not created)
    unity-catalog/      metastore, catalogs, schemas, grants (TODO, not created)
  environments/
    homol/              main.tf, variables.tf, backend.tf (in use)
    prod/               backend.tf, main.tf EMPTY files
.github/workflows/      4 EMPTY files: terraform-plan, terraform-apply-homol, terraform-apply-prod, terraform-destroy-homol (untracked in git)
```

Module wiring: environments call modules; module outputs feed later modules.
- network outputs: `vpc_id`, `private_subnet_ids`, `security_group_id`, `nat_enabled`
- iam-databricks outputs: `credentials_id`, `cross_account_role_arn`, `root_bucket_name`, `unity_catalog_bucket_name`, `unity_catalog_role_arn`

## Conventions and key decisions

- Terraform >= 1.5; providers `hashicorp/aws ~> 5.0` and `databricks/databricks ~> 1.0` (each module using Databricks needs its own `version.tf` with `source = "databricks/databricks"`).
- Region `us-east-1`. Local AWS profile `terraform-deployer` (assume-role from `terraform-cli-user`). CI must use GitHub OIDC instead (no static keys).
- Remote state in the bootstrap S3 bucket (`terraform-state-*`), state key per env (`homol/terraform.tfstate`, `prod/terraform.tfstate`).
- Databricks provider authenticates to the **account console** (`https://accounts.cloud.databricks.com`) with the service principal `terraform-deployer` (Account admin, OAuth M2M). Variables: `databricks_account_id`, `databricks_client_id`, `databricks_client_secret` (sensitive). Values live in git-ignored `terraform.tfvars`; in CI use `TF_VAR_*` from GitHub environment secrets.
- Naming: Databricks-related AWS resources are prefixed `databricks-<env>-...`; the deployer IAM policy (`terraform-iam-databricks-policy`) is scoped to `databricks-*` roles/policies/buckets, so new resources must keep that prefix or the policy must be extended. State bucket policy is scoped to `terraform-state-*`.
- The deployer role needs new IAM permissions whenever a module creates new resource types (e.g. OIDC provider, DynamoDB, Budgets, VPC endpoints). Policies are created by hand with an IAM-admin identity.
- `enable_nat` is currently `false` in homol (NAT ~US$33/mo). It **must be `true`** to provision a workspace and the user confirmed it will be switched to `true` soon (needed for Phase 4). Disable/destroy NAT at the end of sessions when not running workloads.
- Security group descriptions must be plain ASCII. SG `name`/`description` are immutable (force replacement).
- `tainted` resources: fix permission, verify manually, `terraform untaint`; never blindly recreate.
- After creating the cross-account role, `mws_credentials` can fail with "Failed credentials validation checks": wait ~20s and re-apply.
- `homol/main.tf` currently has `environment = "homol"` hardcoded and the AWS profile hardcoded; prod/CI will need these parameterized (tfvars per env, no profile in CI).
- Never commit tfvars, secrets or state. Never run `terraform destroy` on prod (the destroy workflow must expose homol only).

## Databricks trial constraints

- Trial = 14 days, ~US$400 DBU credit; AWS infra billed separately by AWS. Free Edition is unusable (no account console).
- **The trial is ALREADY ACTIVE** (started before the Terraform/CI work was finished, because Databricks changed its platform requirements). The original "do not activate until everything is written" rule no longer applies; the clock is running, so prioritize the critical path: NAT on -> workspace -> Unity Catalog -> CI/CD apply. Start date/expiry: unknown, ask the user and record it in `PROGRESS.md`.
- Day-by-day plan is in `PROGRESS.md` (Phase 10), counted from the real activation date.

## CI/CD design (to implement; GitHub Actions is required)

Current state: the 4 workflow files exist but are empty and untracked. They were scaffolded only as a sanity check that the project is on track; real content is still to be written.


- `terraform-plan.yml`: on PR touching `infra/**`, matrix [homol, prod]; fmt -check, init, validate, plan, post plan as PR comment.
- `terraform-apply-homol.yml`: push to `main` filtered by `infra/environments/homol/**` and `infra/modules/**`; `concurrency.group: terraform-homol`, `cancel-in-progress: false`; `environment: homol`.
- `terraform-apply-prod.yml`: `environment: prod` (required reviewers), `workflow_dispatch` or `release/*` branch; never automatic from `main`.
- `terraform-destroy-homol.yml`: `workflow_dispatch`, homol only.
- Auth: OIDC role `github-actions-terraform` + `aws-actions/configure-aws-credentials`; Databricks secrets at environment level.

## Cost cheat sheet

NAT Gateway ~US$0.045/h, public IPv4 US$0.005/h, interface endpoints US$0.01/endpoint/AZ/h; S3/IAM/VPC/SG negligible; Databricks clusters only while running (job clusters + auto-termination). SageMaker endpoints (Project 2) bill while they exist: always delete, prefer Serverless Inference.

## Working style for this repo

- User writes in Portuguese; repo docs, code, commits and these files are in English.
- Commits follow conventional style (`feat(network): ...`, `docs: ...`); branch per feature (current: `feature/iam-databricks`, main branch `main`).
- Document every completed module in `README.md` (section numbering 3.x) and tick it in `PROGRESS.md`.
