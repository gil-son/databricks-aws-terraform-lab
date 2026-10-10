variable "environment" {
  description = "Environment name (homol, prod) - used in resource names."
  type        = string
}

variable "catalog_name" {
  description = "Catalog the validation job writes to (bronze schema), from the unity-catalog module"
  type        = string
}

variable "data_bucket_name" {
  description = "S3 data bucket holding raw/creditcard/creditcard.csv, from the iam-databricks module"
  type        = string
}

variable "pipeline_application_id" {
  description = "Application ID (OAuth client_id) of the pipeline service principal, from the unity-catalog module"
  type        = string
}

variable "admin_user_email" {
  description = "Human user (email) that can use the policies and run the jobs"
  type        = string
}

variable "account_id" {
  description = "Databricks account ID (used to address the service principal rule set)"
  type        = string
}

variable "deployer_application_id" {
  description = "Client ID of the service principal that runs Terraform; needs the Service Principal User role on the pipeline SP to create jobs with run_as"
  type        = string
}

variable "node_type_id" {
  description = "Only node type the policies allow (keeps cost capped)"
  type        = string
  default     = "m5d.large"
}

variable "max_workers" {
  description = "Maximum number of workers allowed by the policies"
  type        = number
  default     = 2
}

variable "interactive_autotermination_minutes" {
  description = "Auto-termination for interactive (all-purpose) clusters"
  type        = number
  default     = 20
}
